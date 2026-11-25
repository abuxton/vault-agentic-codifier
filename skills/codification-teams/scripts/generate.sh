#!/usr/bin/env bash
# codification-teams (TASK-020)
#   generate.sh [raw-dir] [out-root]
# Reads <raw>/<ns>/identity.json and auth_mounts.json for the root namespace and every namespace in
# <raw>/namespaces.json (plus <out-root>/policies/correlation.json when present) and writes under <out-root>:
#   admin/<ns>_identity.tf, admin/<ns>_identity_aliases.tf (only when aliases exist), admin/imports_identity.tf
#   seed/...   same names for tenant namespaces
#   teams/teams.md, teams/teams.json, teams/README.md
# Codified: vault_identity_entity, vault_identity_group, vault_identity_entity_alias, vault_identity_group_alias.
# References, never literals: member_entity_ids, canonical_id, mount_accessor and policies (when the policy
# is codified in the same namespace). The only UUIDs written are the import IDs in imports_identity.tf.
# An alias whose name is a UUID (an AppRole role_id) becomes a sensitive variable with no default.
# Inferred policy links appear in teams.md and teams.json only, never in HCL.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
RAW=${1:-discovered_terraform/raw}
OUT=${2:-discovered_terraform/terraform}
TF=${TERRAFORM:-terraform}
DOC=https://registry.terraform.io/providers/hashicorp/vault/4.8.0/docs/resources
scaffold=$here/../../vault-codifier-conventions/scripts/scaffold-layer.sh
{ test -s "$RAW/namespaces.json" && jq -e 'type=="array"' "$RAW/namespaces.json" >/dev/null; } \
  || { echo "STOP: $RAW/namespaces.json missing or invalid" >&2; exit 2; }

dir_of() { if [ -z "$1" ]; then echo "$RAW/root"; else echo "$RAW/$1"; fi; }
layer_of() { case "$1" in ""|admin) echo admin ;; *) echo seed ;; esac; }
nss=$( { echo ""; jq -r '.[] | select(.path != "" and .path != "root") | .path' "$RAW/namespaces.json"; } )

read -r -d '' LIB <<'JQ' || true
def lbl: ascii_downcase | gsub("[/+. -]+";"_") | gsub("_+";"_") | sub("^_";"") | sub("_$";"")
         | if test("^[0-9]") then "r_"+. else . end | if .=="" then "_empty" else . end;
def nsjoin($ns; $x): if $ns == "" then $x else $ns + "/" + $x end;
JQ

# ---- accessor -> {label, path, layer} from every auth_mounts.json --------------------------
AMAP='{}'
while IFS= read -r ns; do
  d=$(dir_of "$ns"); [ -s "$d/auth_mounts.json" ] || continue
  AMAP=$(echo "$AMAP" | jq -c --slurpfile m "$d/auth_mounts.json" --arg ns "$ns" --arg layer "$(layer_of "$ns")" "$LIB"'
    . + ( [ $m[0].mounts[] | select(.path != "token" and .path != "token/" and (.accessor // "") != "")
            | (.path|sub("/$";"")) as $p | {key:.accessor, value:{label:(nsjoin($ns;$p)|lbl), p:$p, layer:$layer,
              ref:((if $ns == "admin" and (.type|IN("oidc","jwt")) then "vault_jwt_auth_backend" elif $ns == "admin" and .type == "ldap" then "vault_ldap_auth_backend" else "vault_auth_backend" end) + "." + (nsjoin($ns;$p)|lbl))}} ] | from_entries )')
done <<< "$nss"

# ---- load: one record per namespace that has identity objects ------------------------------
ALL='[]'
while IFS= read -r ns; do
  d=$(dir_of "$ns")
  [ -s "$d/identity.json" ] || continue
  jq -e '.groups|type=="array"' "$d/identity.json" >/dev/null || { echo "STOP: $d/identity.json unreadable" >&2; exit 2; }
  if jq -e '[.. | objects | keys[] | select(. == "password" or . == "secret_id" or . == "token" or . == "client_secret" or . == "bindpass")] | length > 0' "$d/identity.json" >/dev/null; then
    echo "STOP: $d/identity.json contains a credential field (value not printed)" >&2; exit 2
  fi
  pols='[]'; [ -s "$d/policies.json" ] && pols=$(cat "$d/policies.json")
  ALL=$(echo "$ALL" | jq -c --slurpfile i "$d/identity.json" --argjson pols "$pols" --argjson amap "$AMAP" \
      --arg ns "$ns" --arg layer "$(layer_of "$ns")" "$LIB"'
    def pol($pmap): ((.policies // []) | sort | map(if $pmap[.] then {ref:$pmap[.]} else {lit:.} end));
    def uuid: test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$");
    def al($cmap; $amap; $layer; $ns):
      ($amap[.mount_accessor] // error("unresolved mount_accessor")) as $m
      | if $m.layer != $layer then error("alias mount is in another layer") else . end
      | ($cmap[.canonical_id] // error("unresolved canonical_id")) as $c
      | {id:.id, name:.name, namevar:(.name|uuid), label:($c + "_" + ($m.p|lbl)), canonical:$c, mount:$m.ref, mpath:$m.p};
    ($pols | map({key:.name, value:(nsjoin($ns; .name)|lbl)}) | from_entries) as $pmap
    | ($i[0].entities // []) as $E | ($i[0].groups // []) as $G
    | ($E | map({key:.id, value:(nsjoin($ns; .name)|lbl)}) | from_entries) as $emap
    | ($G | map({key:.id, value:(nsjoin($ns; .name)|lbl)}) | from_entries) as $gmap
    | . + [ {ns:$ns, layer:$layer, nsl:(if $ns=="" then "root" else ($ns|lbl) end),
        entities:[ $E[] | {id:.id, name:.name, label:(nsjoin($ns;.name)|lbl), disabled:(.disabled // false),
                          metadata:(.metadata // {}), pols:pol($pmap)} ],
        groups:[ $G[] | {id:.id, name:.name, label:(nsjoin($ns;.name)|lbl), type:(.type // "internal"),
                         metadata:(.metadata // {}), pols:pol($pmap), policies:(.policies // []),
                         members:[ (.member_entity_ids // [])[] | ($emap[.] // error("member entity not in identity.json")) ] | sort,
                         membernames:(.member_entity_names // []),
                         subgroups:[ (.member_group_ids // [])[] | ($gmap[.] // error("member group not in identity.json")) ] | sort } ],
        ealiases:[ ($i[0].entity_aliases // [])[] | al($emap; $amap; $layer; $ns) ],
        galiases:[ ($i[0].group_aliases // [])[] | al($gmap; $amap; $layer; $ns) ] } ]') \
    || { echo "STOP: could not resolve identity references in $d/identity.json (see message above)" >&2; exit 2; }
done <<< "$nss"

echo "$ALL" | jq -e '
  [ .[] | .layer as $l | (.entities[] | {t:"e", layer:$l, label}), (.groups[] | {t:"g", layer:$l, label}),
    (.ealiases[] | {t:"ea", layer:$l, label}), (.galiases[] | {t:"ga", layer:$l, label}) ]
  | group_by([.t,.layer,.label]) | map(select(length>1)) | length == 0' >/dev/null \
  || { echo "STOP: duplicate label within a layer" >&2; exit 2; }

hdr() { printf '# Generated by vault-brownfield-codifier\n# Capability: teams\n# Doc ref: %s/%s\n# Namespace: %s\n\n' "$DOC" "$1" "$2"; }

# ---- program that renders the resources of one namespace -----------------------------------
read -r -d '' RENDER <<'JQ' || true
def prov: if $ns != "" then "  provider = vault.\($alias)\n" else "" end;
def pols: if length > 0 then "  policies = [" + (map(if .ref then "vault_policy.\(.ref).name" else (.lit|tojson) end) | join(", ")) + "]\n" else "" end;
def meta: if length > 0 then "  metadata = {\n" + (to_entries | sort_by(.key) | map("    \(.key|tojson) = \(.value|tojson)\n") | join("")) + "  }\n" else "" end;
def refs($k; $t): if length > 0 then "  \($k) = [" + (map("\($t).\(.).id") | join(", ")) + "]\n" else "" end;
.[] | select(.ns == $ns) |
  ( [ .entities | sort_by(.name)[]
      | "resource \"vault_identity_entity\" \"\(.label)\" {\n" + prov
        + "  name = \(.name|tojson)\n" + (.pols|pols)
        + (if .disabled then "  disabled = true\n" else "" end) + (.metadata|meta) + "}\n" ]
  + [ .groups | sort_by(.name)[]
      | "resource \"vault_identity_group\" \"\(.label)\" {\n" + prov
        + "  name = \(.name|tojson)\n  type = \(.type|tojson)\n" + (.pols|pols)
        + (if .type == "internal" then (.members|refs("member_entity_ids"; "vault_identity_entity")) + (.subgroups|refs("member_group_ids"; "vault_identity_group")) else "" end)
        + (.metadata|meta) + "}\n" ] ) | join("\n")
JQ

read -r -d '' RENDER_AL <<'JQ' || true
def prov: if $ns != "" then "  provider = vault.\($alias)\n" else "" end;
def one($res; $ctype): . as $a
  | (if $a.namevar then "variable \"\($a.label)_name\" {\n  description = \("Alias name for \($a.label) (a role_id or other identifier; supply at plan time)"|tojson)\n  type        = string\n  sensitive   = true\n}\n\n" else "" end)
  + "resource \"\($res)\" \"\($a.label)\" {\n" + prov
  + "  name           = " + (if $a.namevar then "var.\($a.label)_name" else ($a.name|tojson) end) + "\n"
  + "  mount_accessor = \($a.mount).accessor\n"
  + "  canonical_id   = \($ctype).\($a.canonical).id\n"
  + (if $a.namevar then "\n  # a sensitive name is imported unmarked; ignoring it avoids a no-op in-place change\n  lifecycle {\n    ignore_changes = [name]\n  }\n" else "" end)
  + "}\n";
.[] | select(.ns == $ns) |
  ( [ .ealiases | sort_by(.label)[] | one("vault_identity_entity_alias"; "vault_identity_entity") ]
  + [ .galiases | sort_by(.label)[] | one("vault_identity_group_alias"; "vault_identity_group") ] ) | join("\n")
JQ

for layer in admin seed; do
  sub=$(echo "$ALL" | jq -c --arg l "$layer" '[.[]|select(.layer==$l and ((.entities|length)+(.groups|length)) > 0)]')
  L=$OUT/$layer
  rm -f "$L"/*_identity.tf "$L"/*_identity_aliases.tf "$L/imports_identity.tf"
  [ "$(echo "$sub" | jq length)" = 0 ] && continue
  mkdir -p "$L"
  aliases=(); for n in $(echo "$sub" | jq -r '[.[].ns|select(.!="")]|unique|.[]'); do aliases+=("$n"); done
  bash "$scaffold" "$L" ${aliases[@]+"${aliases[@]}"} >/dev/null

  for ns in $(echo "$sub" | jq -r '[.[].ns]|unique|.[]' | sed 's/^$/@root/'); do
    [ "$ns" = "@root" ] && ns=""
    nsl=$(echo "$sub" | jq -r --arg ns "$ns" '[.[]|select(.ns==$ns)][0].nsl')
    { hdr identity_group "${ns:-(root)}"
      echo "$sub" | jq -r --arg ns "$ns" --arg alias "$nsl" "$LIB $RENDER"
    } > "$L/${nsl}_identity.tf"
    if [ "$(echo "$sub" | jq --arg ns "$ns" '[.[]|select(.ns==$ns)|(.ealiases|length)+(.galiases|length)]|add')" != 0 ]; then
      { hdr identity_entity_alias "${ns:-(root)}"
        echo "$sub" | jq -r --arg ns "$ns" --arg alias "$nsl" "$LIB $RENDER_AL"
      } > "$L/${nsl}_identity_aliases.tf"
    fi
  done
  { hdr identity_group "(per resource provider)"
    echo "$sub" | jq -r '
      def imp($res; $label; $id): "import {\n  to = \($res).\($label)\n  id = \($id|tojson)\n}\n";
      sort_by(.ns) | map(
        ([.entities|sort_by(.name)[] | imp("vault_identity_entity"; .label; .id)]
       + [.groups|sort_by(.name)[]   | imp("vault_identity_group"; .label; .id)]
       + [.ealiases|sort_by(.label)[] | imp("vault_identity_entity_alias"; .label; .id)]
       + [.galiases|sort_by(.label)[] | imp("vault_identity_group_alias"; .label; .id)]) | join("\n")) | join("\n")'
  } > "$L/imports_identity.tf"
done

# ---- team-to-access matrix --------------------------------------------------------------------
mkdir -p "$OUT/teams"
corr='[]'; [ -s "$OUT/policies/correlation.json" ] && corr=$(cat "$OUT/policies/correlation.json")
nsl_all=$(jq -c '[.[].path]' "$RAW/namespaces.json")
echo "$ALL" | jq -S --argjson corr "$corr" --argjson nsall "$nsl_all" '
  [ .[] | .groups[] | select(.metadata.tenant != null)
    | . as $g | $g.metadata.tenant as $tenant | ($g.metadata.team // null) as $team
    | (($nsall | map(select(. == $tenant or endswith("/" + $tenant))) | first) // $tenant) as $tns
    | ( if $team == null then [] else
          [ $corr[] | select(.namespace == $tns and .dangling != true and (("-" + .policy + "-") | contains("-" + $team + "-"))
                             and ((.policy as $p | $g.policies | index($p)) == null)) ] end ) as $inf
    | { team: ($team // "(tenant admin)"), namespace: $tns, group: $g.name, entities: ($g.membernames | sort),
        recorded_policies: ($g.policies | sort),
        inferred_policies: ($inf | map(.policy) | unique),
        auth_roles: ($inf | map(.auth_roles) | add // [] | unique) } ]
  | sort_by([.namespace, .team, .group])' > "$OUT/teams/teams.json"

{
  echo '# Teams'; echo
  echo 'Recorded policies are on the Vault identity group. Inferred policies are matched by name in the tenant namespace (`policies/correlation.json`) and are never written into Terraform.'; echo
  echo '| Team | Namespace | Group | Entities | Auth roles | Recorded policies | Inferred policies |'
  echo '|---|---|---|---|---|---|---|'
  jq -r '.[] | "| \(.team) | `\(.namespace)` | `\(.group)` | \(.entities|map("`"+.+"`")|join(", ")) | \(.auth_roles|map("`"+.+"`")|join(", ") | if .=="" then "-" else . end) | \(.recorded_policies|map("`"+.+"`")|join(", ") | if .=="" then "-" else . end) | \(.inferred_policies|map("`"+.+"` (inferred; access applied at the namespace layer)")|join(", ") | if .=="" then "-" else . end) |"' "$OUT/teams/teams.json"
  echo
  echo "$ALL" | jq -r '
    "Aliases found: \([.[]|(.ealiases|length)+(.galiases|length)]|add // 0)." as $n
    | ( [ .[] | select((.ealiases|length)+(.galiases|length)==0 and (.groups|length)>0) | "No aliases found for `\(if .ns=="" then "root" else .ns end)`." ] | join(" ") ) as $none
    | $n + (if $none == "" then "" else " " + $none end)'
} > "$OUT/teams/teams.md"

cat > "$OUT/teams/README.md" <<'EOF'
# Teams: how identity is codified

- Group membership uses `member_entity_ids` on `vault_identity_group` (exclusive). Each entity is
  referenced from exactly one group. Switch to `vault_identity_group_member_entity_ids` with
  `exclusive = false` only if several Terraform configurations manage one group.
- `member_entity_ids`, `canonical_id` and `mount_accessor` are resource references. UUIDs appear only in
  `imports_identity.tf`.
- An alias whose name is a UUID (an AppRole `role_id`) is a sensitive variable `<label>_name` with no
  default. Supply it at plan time (`TF_VAR_<label>_name`).
- Inferred policy links are documented in `teams.md` and `teams.json` only.
EOF

for l in admin seed; do [ -d "$OUT/$l" ] && "$TF" fmt -recursive "$OUT/$l" >/dev/null; done
echo "teams: $(echo "$ALL" | jq '[.[].entities|length]|add // 0') entit(ies), $(echo "$ALL" | jq '[.[].groups|length]|add // 0') group(s), $(echo "$ALL" | jq '[.[]|(.ealiases|length)+(.galiases|length)]|add // 0') alias(es)"
