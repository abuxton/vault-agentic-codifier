#!/usr/bin/env bash
# discovery-admin-config (TASK-013). Writes $RAW/admin/admin_config.json from on-disk payloads
# plus one live read of sys/namespaces/admin. Never re-queries policies or identity.
. "$(dirname "$0")/lib.sh"
D=$RAW/admin; mkdir -p "$D"
for f in policies.json auth_mounts.json identity.json; do
  test -s "$D/$f" || { echo "STOP: $D/$f missing; run the matching discovery skill first" >&2; exit 1; }
done
meta=$(vget GET "" sys/namespaces/admin | jq -S -c '.data // null | if .==null then null else {id,path,custom_metadata} end')
jq -S -n --argjson meta "$meta" \
  --slurpfile pol "$D/policies.json" --slurpfile am "$D/auth_mounts.json" --slurpfile idn "$D/identity.json" '
  def human: IN("oidc","jwt","ldap","github","okta");
  def machine: IN("approle","kubernetes","aws","cert");
  ($pol[0] | map(select(.name|ascii_downcase|test("(^|[-_])(admin|operator)([-_]|$)"))) | map(.name) | sort) as $op |
  { namespace_meta: $meta,
    human_auth_mounts:   ($am[0].mounts | map(select(.type|human))   | map({path,type,accessor,config:{},roles_or_groups:[]}) | sort_by(.path)),
    machine_auth_mounts: ($am[0].mounts | map(select(.type|machine)) | map({path,type,accessor}) | sort_by(.path)),
    operator_policies: $op,
    operator_groups: ($idn[0].groups | map(select(.policies | any(. as $p | $op | index($p)))) | map({name,policies}) | sort_by(.name)) }' \
  > "$D/admin_config.json"
