#!/usr/bin/env bash
# discovery-secrets-engines (TASK-011). Writes $RAW/<ns>/secrets_engines.json.
# Reads mount config only; NEVER <mount>/data/* or <mount>/metadata/*.
. "$(dirname "$0")/lib.sh"
all_namespaces | while IFS= read -r ns; do
  d=$(ns_dir "$ns"); mkdir -p "$d"
  : > "$TMP/sm.nd"
  mounts=$(vget GET "$ns" sys/mounts | jq -c '.data // {}')
  echo "$mounts" | jq -r 'to_entries[] | select(.value|type=="object") | "\(.key)\t\(.value.type)"' \
    | LC_ALL=C sort | while IFS="$(printf '\t')" read -r key type; do
      case "$key" in sys/|identity/|cubbyhole/|token/) continue;; esac
      case "$type" in agent_registry|ns_agent_registry|system|identity|cubbyhole|ns_system|ns_identity|ns_cubbyhole) continue;; esac
      m=${key%/}
      meta=$(echo "$mounts" | jq -c --arg k "$key" '.[$k] | {path:$k,type,description,accessor,local,seal_wrap,options}')
      tune=$(vget GET "$ns" "sys/mounts/$m/tune" | jq -S -c '.data // {} | {default_lease_ttl,max_lease_ttl,listing_visibility,audit_non_hmac_request_keys,audit_non_hmac_response_keys,passthrough_request_headers,allowed_response_headers}')
      cfg=null
      if [ "$type" = kv ] && [ "$(echo "$meta" | jq -r '.options.version // ""')" = 2 ]; then
        cfg=$(vget GET "$ns" "$m/config" | jq -S -c '.data // null | if .==null then null else {max_versions,cas_required,delete_version_after} end')
      fi
      jq -n -S -c --argjson m "$meta" --argjson t "$tune" --argjson c "$cfg" '$m + {tune:$t,engine_config:$c}' >> "$TMP/sm.nd"
    done
  jq -s -S '{mounts: sort_by(.path)}
    + {coverage: (sort_by(.path) | map({path,type,
        fallback: (if .type=="kv" then null else "mount metadata only" end),
        resource_type: (if .type=="kv" then "vault_mount + vault_kv_secret_backend_v2" else null end)}))}' \
    "$TMP/sm.nd" > "$d/secrets_engines.json"
done
