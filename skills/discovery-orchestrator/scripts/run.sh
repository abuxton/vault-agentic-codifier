#!/usr/bin/env bash
# discovery-orchestrator (TASK-014): run every discovery skill in order and write the run report.
#   EXPORTER_TOKEN=... bash skills/discovery-orchestrator/scripts/run.sh
#   FROM=discovery-auth-mounts ...   resume from a step (already-collected payloads are kept)
# Exit codes: 0 ok (non-200s allowed), 1 a skill failed, 2 a stop condition triggered.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
: "${EXPORTER_TOKEN:?EXPORTER_TOKEN is not set}"
RAW=${RAW:-discovered_terraform/raw}
OUTDIR=$(dirname "$RAW"); mkdir -p "$RAW"
REPORT=$RAW/run_report.jsonl
H=(--header "X-Vault-Token: ${EXPORTER_TOKEN}")
stop() { echo "STOP: $*" >&2; exit 2; }

# Stop conditions: token valid and not root, audit device enabled.
code=$(curl -sS -o /tmp/.orch.$$ -w '%{http_code}' "${H[@]}" "$VAULT_ADDR/v1/auth/token/lookup-self") || stop "Vault unreachable"
[ "$code" = 200 ] || { rm -f /tmp/.orch.$$; stop "exporter token invalid or expired (HTTP $code)"; }
jq -e '(.data.policies | index("root")) == null' /tmp/.orch.$$ >/dev/null || { rm -f /tmp/.orch.$$; stop "token carries the root policy"; }
rm -f /tmp/.orch.$$
audit=$(curl -sS "${H[@]}" "$VAULT_ADDR/v1/sys/audit" | jq '(.data // .) | [to_entries[] | select(.value|type=="object")] | length')
[ "${audit:-0}" -gt 0 ] || stop "no audit device enabled; discovery without an audit trail is not permitted"

RUN_ID=$(date -u +%Y%m%dT%H%M%SZ); START=$(date -u +%FT%TZ)
STATE=$OUTDIR/.state.json
[ -f "$STATE" ] || echo '{"completed":[]}' > "$STATE"
[ -n "${FROM:-}" ] || rm -f "$REPORT"      # a fresh run starts a fresh report; a resume appends

steps=(namespaces root-config policies auth-mounts secrets-engines identity-teams admin-config)
exit_code=0; skipping=${FROM:+1}
for s in "${steps[@]}"; do
  name=discovery-$s
  [ -n "${skipping:-}" ] && { [ "$name" = "$FROM" ] && skipping= || continue; }
  curl -sS -o /dev/null -w '%{http_code}' "${H[@]}" "$VAULT_ADDR/v1/auth/token/lookup-self" | grep -q 200 \
    || { exit_code=2; echo "token expired before $name" >&2; break; }
  if bash "$here/$s.sh"; then
    jq --arg n "$name" '.completed |= (. + [$n] | unique)' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  else
    echo "FAILED: $name" >&2; exit_code=1; [ "$s" = namespaces ] && exit_code=2; break
  fi
done

END=$(date -u +%FT%TZ)
nonok='[]'; [ -f "$REPORT" ] && nonok=$(jq -s -c 'unique | sort_by(.namespace,.endpoint)' "$REPORT")
nsl='[]'; [ -f "$RAW/namespaces.json" ] && nsl=$(jq -c '[.[].path]' "$RAW/namespaces.json")
jq -n -S --arg id "$RUN_ID" --arg addr "$VAULT_ADDR" --arg s "$START" --arg e "$END" \
  --argjson ns "$nsl" --argjson non "$nonok" --argjson ec "$exit_code" \
  '{run_id:$id,vault_addr:$addr,start_time:$s,end_time:$e,namespaces_discovered:$ns,non_200_responses:$non,exit_code:$ec}' \
  > "$OUTDIR/run_report.json"
exit "$exit_code"
