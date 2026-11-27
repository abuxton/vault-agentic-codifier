#!/usr/bin/env bash
# discovery-identity-teams (TASK-012). Writes $RAW/<ns>/identity.json and $RAW/<ns>/mfa.json (each only when non-empty).
# MFA (CAP-009) reads LIST and GET only, never the generate or admin-generate endpoints. Method payloads are filtered
# to an allowlist per type, so a key Vault does not return today could not reach the raw output either.
# Needs every auth_mounts.json first (accessor map).
. "$(dirname "$0")/lib.sh"
amap=$(for f in $(find "$RAW" -name auth_mounts.json | LC_ALL=C sort); do
  n=${f#"$RAW"/}; n=${n%/auth_mounts.json}; [ "$n" = root ] && n=""
  jq -c --arg ns "$n" '.mounts[] | {key:.accessor,value:{namespace:$ns,path:(.path+"/"),type:.type}}' "$f"
done | jq -s -S 'from_entries')

all_namespaces | while IFS= read -r ns; do
  d=$(ns_dir "$ns"); mkdir -p "$d"
  : > "$TMP/g.nd"; : > "$TMP/e.nd"; : > "$TMP/ga.nd"; : > "$TMP/ea.nd"
  vget LIST "$ns" identity/group/name | jq -r '.data.keys[]?' | while IFS= read -r g; do
    vget GET "$ns" "identity/group/name/$(enc "$g")" | jq -S -c --arg ns "$ns" \
      '.data | {name,type,policies,member_entity_ids:(.member_entity_ids // []),member_group_ids:(.member_group_ids // []),metadata:(.metadata // {}),namespace:$ns,id}' >> "$TMP/g.nd"
  done
  vget LIST "$ns" identity/entity/name | jq -r '.data.keys[]?' | while IFS= read -r e; do
    vget GET "$ns" "identity/entity/name/$(enc "$e")" | jq -S -c --arg ns "$ns" \
      '.data | {name,policies,metadata:(.metadata // {}),disabled,namespace:$ns,id}' >> "$TMP/e.nd"
  done
  vget LIST "$ns" identity/group-alias/id | jq -r '.data.keys[]?' | while IFS= read -r a; do
    vget GET "$ns" "identity/group-alias/id/$a" | jq -S -c '.data | {id,name,mount_accessor,canonical_id}' >> "$TMP/ga.nd"
  done
  vget LIST "$ns" identity/entity-alias/id | jq -r '.data.keys[]?' | while IFS= read -r a; do
    vget GET "$ns" "identity/entity-alias/id/$a" | jq -S -c '.data | {id,name,mount_accessor,canonical_id}' >> "$TMP/ea.nd"
  done
  # MFA methods and login enforcement rules (CAP-009). Per namespace: a method in admin is not visible from root.
  : > "$TMP/m.nd"; : > "$TMP/l.nd"
  vget LIST "$ns" identity/mfa/method > "$TMP/mlist.json"
  # A child namespace also lists the methods of its ancestors; keep only those the namespace owns (namespace_path).
  jq -r --arg own "${ns:+$ns/}" '.data.key_info // {} | to_entries[] | select((.value.namespace_path // "") == $own) | "\(.value.type)\t\(.key)"' "$TMP/mlist.json" | LC_ALL=C sort | while IFS=$'\t' read -r t id; do
    case "$t" in totp|duo|okta|pingid) ;; *) continue ;; esac
    vget GET "$ns" "identity/mfa/method/$t/$(enc "$id")" | jq -S -c --arg ns "$ns" --arg t "$t" '.data | {type:$t, id:.id, namespace:$ns, config:(
      if   $t == "totp"   then {algorithm,digits,issuer,key_size,max_validation_attempts,period,qr_size,skew}
      elif $t == "duo"    then {api_hostname,pushinfo,use_passcode,username_format}
      elif $t == "okta"   then {org_name,base_url,username_format}
      else {} end)}' >> "$TMP/m.nd"
  done
  vget LIST "$ns" identity/mfa/login-enforcement | jq -r '.data.keys[]?' | while IFS= read -r l; do
    vget GET "$ns" "identity/mfa/login-enforcement/$(enc "$l")" | jq -S -c --arg ns "$ns" \
      '.data | {name, id, namespace:$ns, mfa_method_ids:(.mfa_method_ids // []), identity_group_ids:(.identity_group_ids // []), identity_entity_ids:(.identity_entity_ids // []), auth_method_accessors:(.auth_method_accessors // []), auth_method_types:(.auth_method_types // [])}' >> "$TMP/l.nd"
  done
  if [ -s "$TMP/m.nd" ] || [ -s "$TMP/l.nd" ]; then
    jq -s -S -n --slurpfile m "$TMP/m.nd" --slurpfile l "$TMP/l.nd" '{methods:($m|sort_by(.type,.id)), enforcements:($l|sort_by(.name))}' > "$d/mfa.json"
  else rm -f "$d/mfa.json"; fi
  cnt=$(cat "$TMP/g.nd" "$TMP/e.nd" "$TMP/ga.nd" "$TMP/ea.nd" | wc -l | tr -d ' ')
  if [ "$cnt" = 0 ]; then rm -f "$d/identity.json"; continue; fi
  jq -S -n --argjson amap "$amap" \
    --slurpfile g "$TMP/g.nd" --slurpfile e "$TMP/e.nd" --slurpfile ga "$TMP/ga.nd" --slurpfile ea "$TMP/ea.nd" '
    ($e | map({(.id):.name}) | add // {}) as $en | ($g | map({(.id):.name}) | add // {}) as $gn |
    def ann: . + {mount_path:($amap[.mount_accessor].path // null), mount_type:($amap[.mount_accessor].type // null)};
    { groups: ($g | map(. + {member_entity_names:(.member_entity_ids|map($en[.] // null)|sort), member_group_names:(.member_group_ids|map($gn[.] // null)|sort)}) | sort_by(.name)),
      entities: ($e | sort_by(.name)),
      group_aliases: ($ga | map(ann + {canonical_name:($gn[.canonical_id] // null)}) | sort_by(.mount_path,.name)),
      entity_aliases: ($ea | map(ann + {canonical_name:($en[.canonical_id] // null)}) | sort_by(.mount_path,.name)),
      accessor_map: $amap }' > "$d/identity.json"
done
