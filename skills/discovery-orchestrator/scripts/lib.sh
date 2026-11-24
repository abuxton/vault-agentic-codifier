# Shared helpers for the discovery scripts. Source this file; do not execute it.
# Requires: bash, curl, jq. Run from the repository root.
#   EXPORTER_TOKEN  exporter AppRole token (never a root/operator token). Required.
#   VAULT_ADDR      defaults to http://127.0.0.1:8200
#   RAW             output root, defaults to discovered_terraform/raw
set -euo pipefail
export VAULT_CONFIG_PATH=/dev/null
VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
export VAULT_ADDR
: "${EXPORTER_TOKEN:?EXPORTER_TOKEN is not set (see vault-exporter-setup)}"
RAW=${RAW:-discovered_terraform/raw}
REPORT=$RAW/run_report.jsonl
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$RAW"

# ns_dir <namespace>  ("" is root)
ns_dir() { if [ -z "$1" ]; then echo "$RAW/root"; else echo "$RAW/$1"; fi; }

# all_namespaces: root ("") first, then namespaces.json in parent-before-child order
all_namespaces() { echo ""; jq -r '.[].path' "$RAW/namespaces.json"; }

report() { # report <endpoint> <namespace> <http_status>
  jq -nc --arg e "$1" --arg ns "$2" --argjson c "$3" \
    '{endpoint:$e,namespace:$ns,http_status:$c,skipped:true}' >> "$REPORT"
}

# vget <GET|LIST> <namespace> <api-path>
# Prints the response body on 200, otherwise prints {} and records the status
# in the run report. A LIST that returns 404 means "empty set" and is not recorded.
vget() {
  local m=$1 ns=$2 p=$3 code
  local h=()
  [ -n "$ns" ] && h=(--header "X-Vault-Namespace: $ns")
  code=$(curl -sS -o "$TMP/body" -w '%{http_code}' --request "$m" \
    --header "X-Vault-Token: ${EXPORTER_TOKEN}" ${h[@]+"${h[@]}"} "${VAULT_ADDR}/v1/$p")
  if [ "$code" = 200 ]; then
    cat "$TMP/body"
  else
    if ! { [ "$m" = LIST ] && [ "$code" = 404 ]; }; then report "$p" "$ns" "$code"; fi
    echo '{}'
  fi
}

# fetch <GET|LIST> <namespace> <api-path> <jq-filter> <outfile>
# Writes <outfile> only on 200 (or {"keys":[]} for LIST 404); otherwise records the status.
fetch() {
  local m=$1 ns=$2 p=$3 f=$4 o=$5 code
  local h=()
  [ -n "$ns" ] && h=(--header "X-Vault-Namespace: $ns")
  code=$(curl -sS -o "$TMP/body" -w '%{http_code}' --request "$m" \
    --header "X-Vault-Token: ${EXPORTER_TOKEN}" ${h[@]+"${h[@]}"} "${VAULT_ADDR}/v1/$p")
  if [ "$code" = 200 ]; then jq -S "$f" "$TMP/body" > "$o"
  elif [ "$m" = LIST ] && [ "$code" = 404 ]; then echo '{"keys":[]}' | jq -S . > "$o"
  else report "$p" "$ns" "$code"; fi
}

# enc <string>: URL-encode a path segment
enc() { jq -rn --arg n "$1" '$n|@uri'; }
