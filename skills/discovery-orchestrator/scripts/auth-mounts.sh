#!/usr/bin/env bash
# discovery-auth-mounts (TASK-010). Writes $RAW/<ns>/auth_mounts.json.
# NEVER reads role-id, secret-id or secret-id-accessor endpoints.
. "$(dirname "$0")/lib.sh"
all_namespaces | while IFS= read -r ns; do
  d=$(ns_dir "$ns"); mkdir -p "$d"
  : > "$TMP/mounts.nd"
  list=$(vget GET "$ns" sys/auth | jq -c '.data // {}')
  echo "$list" | jq -r 'to_entries[] | select(.key != "token/" and (.value|type=="object")) | .key' \
    | LC_ALL=C sort | while IFS= read -r key; do
      p=${key%/}
      meta=$(echo "$list" | jq -c --arg k "$key" '.[$k] | {path:($k|rtrimstr("/")),type,accessor,description,local,seal_wrap}')
      tune=$(vget GET "$ns" "sys/auth/$p/tune" | jq -S -c '.data // {} | {default_lease_ttl,max_lease_ttl,token_type,listing_visibility,audit_non_hmac_request_keys,audit_non_hmac_response_keys,passthrough_request_headers,allowed_response_headers}')
      type=$(echo "$meta" | jq -r .type)
      roles='[]'; unsupported=true
      if [ "$type" = approle ]; then
        unsupported=false
        : > "$TMP/roles.nd"
        vget LIST "$ns" "auth/$p/role" | jq -r '.data.keys[]?' | LC_ALL=C sort | while IFS= read -r r; do
          vget GET "$ns" "auth/$p/role/$(enc "$r")" | jq -S -c --arg n "$r" \
            '.data | {name:$n,bind_secret_id,local_secret_ids,secret_id_bound_cidrs,secret_id_num_uses,secret_id_ttl,token_bound_cidrs,token_explicit_max_ttl,token_max_ttl,token_no_default_policy,token_num_uses,token_period,token_policies,token_ttl,token_type}' >> "$TMP/roles.nd"
        done
        roles=$(jq -s -c '.' "$TMP/roles.nd")
      fi
      jq -n -S -c --argjson m "$meta" --argjson t "$tune" --argjson r "$roles" --argjson u "$unsupported" \
        '$m + {tune:$t,roles:$r,unsupported:$u}' >> "$TMP/mounts.nd"
    done
  jq -s -S '{mounts: sort_by(.path)}' "$TMP/mounts.nd" > "$d/auth_mounts.json"
done
