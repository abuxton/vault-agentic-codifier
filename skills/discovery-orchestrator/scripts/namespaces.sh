#!/usr/bin/env bash
# discovery-namespaces (TASK-007). Writes $RAW/namespaces.json, parent before child.
. "$(dirname "$0")/lib.sh"

# macOS /bin/bash is 3.2: an empty array is "unbound" under set -u, hence ${h[@]+"${h[@]}"}.
walk() {
  local parent="$1" h=() full k
  [ -n "$parent" ] && h=(--header "X-Vault-Namespace: $parent")
  curl -sS --request LIST --header "X-Vault-Token: ${EXPORTER_TOKEN}" ${h[@]+"${h[@]}"} \
      "${VAULT_ADDR}/v1/sys/namespaces" \
    | jq -r '.data.keys[]?' | LC_ALL=C sort | while IFS= read -r k; do
      k=${k%/}; full="${parent:+$parent/}$k"
      curl -sS --header "X-Vault-Token: ${EXPORTER_TOKEN}" ${h[@]+"${h[@]}"} \
          "${VAULT_ADDR}/v1/sys/namespaces/$k" \
        | jq -c --arg p "$full" --arg par "$parent" \
          '.data | {path:$p,parent:$par,id:.id,custom_metadata:(.custom_metadata // null),depth:($p|split("/")|length)}'
      walk "$full"
    done
}
walk "" | jq -s -S 'sort_by([.depth,.path])' > "$RAW/namespaces.json"
