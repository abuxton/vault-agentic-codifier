#!/usr/bin/env bash
# discovery-admin-config (TASK-013). Writes $RAW/admin/admin_config.json from on-disk payloads
# plus one live read of sys/namespaces/admin. Never re-queries policies or identity.
. "$(dirname "$0")/lib.sh"
D=$RAW/admin
# No org namespace (for example an empty cluster): nothing to discover here, which is not an error.
if ! jq -e 'any(.[]?; .path == "admin")' "$RAW/namespaces.json" >/dev/null 2>&1; then
  echo "discovery-admin-config: no admin namespace; skipped" >&2; exit 0
fi
mkdir -p "$D"
for f in policies.json auth_mounts.json identity.json; do
  test -s "$D/$f" || { echo "STOP: $D/$f missing; run the matching discovery skill first" >&2; exit 1; }
done
# Human auth mounts (SKILL step 3): read auth/<p>/config and the roles or groups. Secret-bearing keys are masked
# before anything reaches disk; the codifier supplies those values through sensitive variables instead.
MASK='walk(if type=="object" then with_entries(if (.key|test("client_secret|bindpass|api_token|password")) then .value="REDACTED" else . end) else . end)'
: > "$TMP/human.jsonl"
while IFS=$'\t' read -r hp ht; do
  hp=${hp%/}; cfg=$(vget GET admin "auth/$hp/config" | jq -S -c ".data // {} | $MASK")
  items='[]'
  case "$ht" in
    oidc|jwt) kind=role ;;
    ldap)     kind=groups ;;
    *)        kind= ;;
  esac
  if [ -n "$kind" ]; then
    for n in $(vget LIST admin "auth/$hp/$kind" | jq -r '.data.keys // [] | sort[]'); do
      items=$(vget GET admin "auth/$hp/$kind/$(enc "$n")" | jq -S -c --arg n "$n" --argjson acc "$items" '$acc + [(.data // {} | {name:$n} + .)]')
    done
    items=$(jq -S -c "$MASK" <<<"$items")
  fi
  jq -n -S -c --arg p "$hp" --arg t "$ht" --argjson c "$cfg" --argjson i "$items" '{path:$p,type:$t,config:$c,roles_or_groups:$i}' >> "$TMP/human.jsonl"
done < <(jq -r '.mounts[] | select(.type|IN("oidc","jwt","ldap","github","okta")) | [.path,.type] | @tsv' "$D/auth_mounts.json")
meta=$(vget GET "" sys/namespaces/admin | jq -S -c '.data // null | if .==null then null else {id,path,custom_metadata} end')
jq -S -n --argjson meta "$meta" --slurpfile hum "$TMP/human.jsonl" \
  --slurpfile pol "$D/policies.json" --slurpfile am "$D/auth_mounts.json" --slurpfile idn "$D/identity.json" '
  def human: IN("oidc","jwt","ldap","github","okta");
  def machine: IN("approle","kubernetes","aws","cert");
  ($pol[0] | map(select(.name|ascii_downcase|test("(^|[-_])(admin|operator)([-_]|$)"))) | map(.name) | sort) as $op |
  { namespace_meta: $meta,
    human_auth_mounts:   ($am[0].mounts | map(select(.type|human)) | map(. as $m | ($hum | map(select(.path == ($m.path|rtrimstr("/")))) | .[0] // {config:{},roles_or_groups:[]}) as $h | {path:($m.path|rtrimstr("/")),type,accessor,config:$h.config,roles_or_groups:$h.roles_or_groups}) | sort_by(.path)),
    machine_auth_mounts: ($am[0].mounts | map(select(.type|machine)) | map({path,type,accessor}) | sort_by(.path)),
    operator_policies: $op,
    operator_groups: ($idn[0].groups | map(select(.policies | any(. as $p | $op | index($p)))) | map({name,policies}) | sort_by(.name)) }' \
  > "$D/admin_config.json"
