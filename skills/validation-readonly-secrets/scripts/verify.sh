#!/usr/bin/env bash
# validation-readonly-secrets (TASK-025): prove the codifier only read, and that no secret reached the output.
#   bash verify.sh [out-root] [raw-root] [report-dir]
#   bash verify.sh --selftest            inject faults into scratch copies; every one must be caught
# Env: AUDIT_FILE   read this audit log instead of the harness container
#      VAULT_CONTAINER (default vault-codifier-dev), WINDOW_START / WINDOW_END override run_report.json
# Exit: 0 all checks pass, 1 a check failed, 2 usage or environment problem.
set -uo pipefail
export PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin:$HOME/.rd/bin
here=$(cd "$(dirname "$0")" && pwd)

if [ "${1:-}" = "--selftest" ]; then
  OUT=${OUT:-discovered_terraform/terraform}; RAW=${RAW:-discovered_terraform/raw}
  REPORT=${REPORT:-discovered_terraform/run_report.json}
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  src=${AUDIT_FILE:-$tmp/audit.src}
  [ -n "${AUDIT_FILE:-}" ] || docker exec "${VAULT_CONTAINER:-vault-codifier-dev}" cat /vault/logs/audit.log > "$src" || exit 2
  base() { rm -rf "$tmp/o" "$tmp/r"; cp -R "$OUT" "$tmp/o"; cp -R "$RAW" "$tmp/r"; cp "$REPORT" "$tmp/run_report.json"; cp "$src" "$tmp/audit"; }
  run() { AUDIT_FILE=$tmp/audit bash "$here/verify.sh" "$tmp/o" "$tmp/r" "$tmp/rep" "$tmp/run_report.json" >"$tmp/log" 2>&1; }
  fails=0
  expect() {   # name, check that must be reported FAIL
    if run; then echo "SELFTEST FAIL: $1 was not detected"; fails=$((fails+1))
    elif grep -q "FAIL $2" "$tmp/log"; then echo "SELFTEST ok: $1 caught by '$2'"
    else echo "SELFTEST FAIL: $1 failed, but not on '$2'"; cat "$tmp/log"; fails=$((fails+1)); fi
  }
  base; run || { echo "SELFTEST FAIL: unmodified inputs do not pass"; cat "$tmp/log"; exit 1; }
  echo "SELFTEST ok: unmodified inputs pass"
  start=$(jq -r '.start_time' "$REPORT")
  base; jq -c --arg s "${start:0:19}" 'select(type=="object" and .type=="request" and .time[0:19]>=$s and (.auth.policies//[]|index("exporter")))' "$src" 2>/dev/null \
    | head -1 | jq -c '.request.operation="update"|.request.path="sys/policies/acl/zz-injected"' >> "$tmp/audit"
  expect "injected write by the exporter token" "audit-read-only"
  base; jq -c --arg s "${start:0:19}" 'select(type=="object" and .type=="request" and .time[0:19]>=$s and (.auth.policies//[]|index("exporter")))' "$src" 2>/dev/null \
    | head -1 | jq -c '.request.operation="delete"' >> "$tmp/audit"
  expect "injected delete by the exporter token" "audit-read-only"
  base; jq -c --arg s "${start:0:19}" 'select(type=="object" and .type=="request" and .time[0:19]>=$s and (.auth.policies//[]|index("exporter")))' "$src" 2>/dev/null \
    | head -1 | jq -c '.request.path="secret/data/billing/api"' >> "$tmp/audit"
  expect "injected KV data read" "audit-no-secret-reads"
  base; : > "$tmp/audit"; expect "empty audit window" "audit-has-exporter-requests"
  base; printf '{"%s": "%s"}\n' secret_id "11111111-2222-3333-4444-555555555555" > "$tmp/r/leak.json"; expect "secret_id value in raw" "scan-secret-id"
  base; printf 'x = "SYNTHETIC-%s"\n' "MARKER" > "$tmp/r/leak.json"; expect "SYNTHETIC marker in raw" "scan-synthetic"
  base; printf '{"data":{"data":{"k":"v"},"metadata":{"created_time":"x"}}}\n' > "$tmp/r/kv.json"; expect "KV v2 payload in raw" "scan-kv-data"
  base; printf 'locals { id = "%s" }\n' "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" > "$tmp/o/admin/leak.tf"; expect "UUID literal in .tf" "scan-uuid-literals"
  base; printf 'provider "vault" { token = "%s" }\n' "hvs.CAESIAbcdefghijklmnopqrstuvwxyz0123456789" > "$tmp/o/admin/leak.tf"; expect "token literal in .tf" "scan-token-values"
  base; printf 'resource "x" "y" {\n  %s = "%s"\n}\n' bindpass "literal-value" > "$tmp/o/admin/leak.tf"; expect "sensitive argument literal" "scan-sensitive-args"
  base; echo '{}' > "$tmp/o/admin/terraform.tfstate"; expect "state file in output" "scan-no-state-files"
  [ "$fails" -eq 0 ] && { echo "SELFTEST: all faults detected"; exit 0; } || exit 1
fi

OUT=${1:-discovered_terraform/terraform}; RAW=${2:-discovered_terraform/raw}
REPDIR=${3:-discovered_terraform/validation}; RUNREP=${4:-$(dirname "$RAW")/run_report.json}
export VAULT_CONFIG_PATH=/dev/null
[ -d "$OUT" ] && [ -d "$RAW" ] && [ -f "$RUNREP" ] || { echo "usage: verify.sh [out-root] [raw-root] [report-dir]; missing input" >&2; exit 2; }
mkdir -p "$REPDIR"; tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# ---- audit log -------------------------------------------------------------
# NO_AUDIT_DEVICE=1 is for a scenario that has no audit device by definition (an empty cluster): the three
# audit checks are reported SKIP and every content scan still runs. Never set it for a real cluster.
results=(); failed=0; ws=; we=; total=0
check() { # name, status(PASS|FAIL|SKIP), detail
  results+=("$(jq -n -c --arg n "$1" --arg s "$2" --arg d "$3" '{check:$n,status:$s,detail:$d}')")
  echo "$2 $1: $3"; [ "$2" = FAIL ] && failed=1; return 0
}
: > "$tmp/other.jsonl"
if [ "${NO_AUDIT_DEVICE:-0}" = 1 ]; then
  for c in audit-has-exporter-requests audit-read-only audit-no-secret-reads; do check "$c" SKIP "no audit device in this scenario"; done
else
audit=${AUDIT_FILE:-$tmp/audit}
if [ -z "${AUDIT_FILE:-}" ]; then
  docker exec "${VAULT_CONTAINER:-vault-codifier-dev}" cat /vault/logs/audit.log > "$audit" 2>/dev/null \
    || { echo "cannot read the audit log from container ${VAULT_CONTAINER:-vault-codifier-dev}" >&2; exit 2; }
fi
ws=${WINDOW_START:-$(jq -r '.start_time' "$RUNREP")}; we=${WINDOW_END:-$(jq -r '.end_time' "$RUNREP")}
ws=${ws:0:19}; we=${we:0:19}

# Requests inside the discovery window made with a token that carries the exporter policy and not root.
jq -c --arg s "$ws" --arg e "$we" '
  select(type=="object" and .type=="request" and .time[0:19]>=$s and .time[0:19]<=$e
         and ((.auth.policies // []) | index("exporter")) != null and ((.auth.policies // []) | index("root")) == null)
  | {time, op:.request.operation, path:.request.path, ns:(.request.namespace.path // "")}' "$audit" 2>/dev/null > "$tmp/exp.jsonl"
# Everything else in the window, for information (the setup steps: secret-id mint and login).
jq -c --arg s "$ws" --arg e "$we" '
  select(type=="object" and .type=="request" and .time[0:19]>=$s and .time[0:19]<=$e
         and (((.auth.policies // []) | index("exporter")) == null))
  | {op:.request.operation, path:.request.path, as:((.auth.policies // ["none"]) | join(","))}' "$audit" 2>/dev/null \
  | sort -u > "$tmp/other.jsonl"

total=$(wc -l < "$tmp/exp.jsonl" | tr -d ' ')
[ "$total" -gt 0 ] && check audit-has-exporter-requests PASS "$total requests by the exporter token between $ws and $we" \
                   || check audit-has-exporter-requests FAIL "no exporter requests found in $ws..$we; the check would be vacuous"
bad=$(jq -c 'select(.op!="read" and .op!="list")' "$tmp/exp.jsonl")
[ -z "$bad" ] && check audit-read-only PASS "0 operations other than read or list ($(jq -s -c 'group_by(.op)|map({(.[0].op):length})|add' "$tmp/exp.jsonl"))" \
              || check audit-read-only FAIL "$(echo "$bad" | wc -l | tr -d ' ') non-read operations, first: $(echo "$bad" | head -1)"
sens=$(jq -c 'select(.path|test("/data/|/creds/|/issue/|/sign/|secret-id$|^sys/raw|/kv/data|/decrypt/|/encrypt/"))' "$tmp/exp.jsonl")
[ -z "$sens" ] && check audit-no-secret-reads PASS "no KV data, dynamic credential, secret-id or sys/raw path was read" \
               || check audit-no-secret-reads FAIL "secret-bearing path read: $(echo "$sens" | head -1)"

fi

# ---- content scans -----------------------------------------------------------
UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
SENS='secret_id|bindpass|bind_pass|client_secret|oidc_client_secret|private_key|root_token|client_token|api_key|passwd|credentials|token_value'
scan() { # name, description, grep args... ; reads $tmp/targets, fails on any match
  local name=$1 desc=$2; shift 2
  local hits; hits=$(xargs -0 grep -InE "$@" < "$tmp/targets" 2>/dev/null | head -3)
  [ -z "$hits" ] && check "$name" PASS "$desc: none" || check "$name" FAIL "$desc: $(echo "$hits" | head -1 | cut -c1-160 | sed -E 's/(:[0-9]+:).*(.{0})/\1<redacted>/')"
}
find "$OUT" "$RAW" -type f -print0 > "$tmp/targets"
find "$OUT" -type f \( -name '*.tfstate*' -o -name '*.tfvars' -o -name '.terraform' -o -name '*.tfplan' \) > "$tmp/state"
[ ! -s "$tmp/state" ] && check scan-no-state-files PASS "no state, plan or tfvars file in the output" \
                      || check scan-no-state-files FAIL "$(head -1 "$tmp/state")"
scan scan-synthetic "SYNTHETIC markers" 'SYNTHETIC'
# A non-null string value for a secret_id key (config keys such as secret_id_ttl are not values).
scan scan-secret-id "secret_id values" "\"?secret_id\"?[[:space:]]*[:=][[:space:]]*\"[^\"]"
scan scan-secret-id-accessor "secret_id_accessor values" "secret_id_accessor\"?[[:space:]]*[:=][[:space:]]*\"[^\"]"
scan scan-token-values "Vault token values" '\bhv[sbr]\.[A-Za-z0-9_-]{16,}|(^|[^A-Za-z0-9])s\.[A-Za-z0-9]{24}\b|X-Vault-Token'
# Literal harness root token in a token context, and any live token passed in the environment.
scan scan-root-token "root token literal" "(token|client_token|root_token)\"?[[:space:]]*[:=][[:space:]]*\"root\""
for v in VAULT_TOKEN EXPORTER_TOKEN; do
  val=${!v:-}; [ "${#val}" -ge 16 ] || continue
  hits=$(xargs -0 grep -IlF -- "$val" < "$tmp/targets" 2>/dev/null | head -1)
  [ -z "$hits" ] && check "scan-env-$v" PASS "value of $v not present" || check "scan-env-$v" FAIL "value of $v found in $hits"
done
# KV v2 read payloads: data.data plus metadata.created_time.
find "$RAW" -type f -name '*.json' -print0 | xargs -0 jq -e -r 'select(type=="object" and (.data?|type=="object") and (.data.data?|type=="object") and (.data.metadata?|type=="object")) | "kv-shape"' 2>/dev/null | head -1 > "$tmp/kv"
if [ ! -s "$tmp/kv" ]; then
  find "$RAW" -type f -name '*.json' -print0 | xargs -0 grep -lE '"data":[[:space:]]*\{[[:space:]]*"data":' 2>/dev/null | head -1 > "$tmp/kv"
fi
[ ! -s "$tmp/kv" ] && check scan-kv-data PASS "no KV v2 data payload in raw" || check scan-kv-data FAIL "KV v2 payload shape in $(cat "$tmp/kv")"

find "$OUT" -type f -name '*.tf' ! -name 'imports*.tf' -print0 > "$tmp/targets"
scan scan-uuid-literals "UUID literals in .tf outside imports*.tf" "$UUID"
scan scan-sensitive-args "literal values for sensitive arguments in .tf" "^[[:space:]]*($SENS)[[:space:]]*=[[:space:]]*\"[^\"]+\""

# ---- report ------------------------------------------------------------------
jq -n -S --arg s "$ws" --arg e "$we" --argjson total "$total" --argjson r "$(printf '%s\n' "${results[@]}" | jq -s -c .)" \
  --argjson other "$(jq -s -c . "$tmp/other.jsonl")" \
  '{window:{start:$s,end:$e},exporter_requests:$total,checks:$r,non_exporter_requests_in_window:$other,verdict:(if ($r|map(select(.status=="FAIL"))|length)==0 then "PASS" else "FAIL" end)}' \
  > "$REPDIR/readonly-secrets.json"
{
  echo "# Read-only and no-secrets verification"; echo
  echo "Window: \`$ws\` to \`$we\` (from run_report.json). Exporter requests audited: $total."; echo
  echo "| Check | Result | Detail |"; echo "|---|---|---|"
  jq -r '.checks[] | "| \(.check) | \(.status) | \(.detail | gsub("\\|";"/")) |"' "$REPDIR/readonly-secrets.json"; echo
  echo "Requests in the window made by something other than the exporter token (the setup steps, not the codifier):"; echo
  jq -r '.non_exporter_requests_in_window[] | "- \(.op) `\(.path)` as `\(.as)`"' "$REPDIR/readonly-secrets.json"
  echo; echo "Verdict: **$(jq -r .verdict "$REPDIR/readonly-secrets.json")**"
} > "$REPDIR/readonly-secrets.md"
[ "$failed" -eq 0 ] && { echo "VERDICT PASS"; exit 0; } || { echo "VERDICT FAIL"; exit 1; }
