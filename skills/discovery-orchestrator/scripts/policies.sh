#!/usr/bin/env bash
# discovery-policies (TASK-009). Writes $RAW/<ns>/policies.json and $RAW/coverage.json.
. "$(dirname "$0")/lib.sh"
: > "$TMP/sentinel.nd"
all_namespaces | while IFS= read -r ns; do
  d=$(ns_dir "$ns"); mkdir -p "$d"
  : > "$TMP/pol.nd"
  vget LIST "$ns" sys/policies/acl \
    | jq -r '.data.keys[]? | select(. != "default" and . != "root" and . != "default-ceiling")' \
    | LC_ALL=C sort | while IFS= read -r n; do
      vget GET "$ns" "sys/policies/acl/$(enc "$n")" \
        | jq -c --arg ns "$ns" '.data | {name:.name,namespace:$ns,policy_text:.policy,type:"acl"}' >> "$TMP/pol.nd"
    done
  jq -s -S 'sort_by(.name)' "$TMP/pol.nd" > "$d/policies.json"
  for t in egp rgp; do
    vget LIST "$ns" "sys/policies/$t" | jq -S -c --arg ns "$ns" --arg t "$t" '{namespace:$ns,type:$t,names:(.data.keys // [])}' >> "$TMP/sentinel.nd"
  done
done
jq -s -S -n --slurpfile s "$TMP/sentinel.nd" \
  --argjson total "$(for f in $(find "$RAW" -name policies.json | LC_ALL=C sort); do jq -c '.[]' "$f"; done | jq -s 'length')" \
  '{policies:{acl_total:$total,
     egp_policies:([$s[]|select(.type=="egp")|.names[]?]|sort),
     rgp_policies:([$s[]|select(.type=="rgp")|.names[]?]|sort)}}' > "$RAW/coverage.json"
