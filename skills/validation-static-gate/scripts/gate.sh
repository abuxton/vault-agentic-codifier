#!/usr/bin/env bash
# validation-static-gate (TASK-023)
#   gate.sh [out-root]
# For every layer under <out-root> (a directory holding providers.tf) runs, in order:
#   terraform init -backend=false, terraform validate, terraform fmt -check -recursive, tflint
# A syntax error is reported once (file, line, capability) and fmt and tflint are skipped for that layer.
# Every failure is reported as  FAIL <layer>/<file>[:line] [<capability>] <message>  so that the owner of the
# file is known. Exit 0 only when every layer passes every step. TFLINT may name another binary.
set -uo pipefail
OUT=${1:-discovered_terraform/terraform}
TF=${TERRAFORM:-terraform}
TFLINT=${TFLINT:-tflint}
command -v "$TFLINT" >/dev/null 2>&1 || { echo "STOP: $TFLINT not found (see skills/validation-static-gate/SKILL.md)" >&2; exit 2; }
fails=0
cap_of() { sed -n 's/^# Capability: //p' "$1" 2>/dev/null | head -n 1; }
fail() { # layer file line message
  local c; c=$(cap_of "$1/$2"); echo "FAIL $(basename "$1")/$2${3:+:$3} [${c:-unknown}] $4"; fails=$((fails + 1)); }

layers=0
for L in "$OUT"/*/; do
  L=${L%/}; [ -f "$L/providers.tf" ] || continue
  layers=$((layers + 1)); n=$(basename "$L"); before=$fails

  # 1. validate first: a syntax error is reported once, with file and line, and later steps are skipped
  parse_ok=1
  if ! "$TF" -chdir="$L" init -backend=false -input=false -no-color >/dev/null 2>"$L/.init.err"; then
    # a parse error stops init; recover file and line from validate -json, which also parses
    :
  fi
  "$TF" -chdir="$L" validate -json -no-color 2>/dev/null \
    | jq -r '.diagnostics[]? | select(.severity=="error") | "\(.range.filename // "")|\(.range.start.line // "")|\(.summary): \(.detail // "" | split("\n")[0])"' \
    | while IFS='|' read -r f ln msg; do
        c=""; [ -n "$f" ] && c=$(cap_of "$L/$f")
        echo "FAIL $n/${f:-?}${ln:+:$ln} [${c:-unknown}] validate: $msg"
      done > "$L/.val.out"
  if [ -s "$L/.val.out" ]; then cat "$L/.val.out"; fails=$((fails + $(wc -l < "$L/.val.out"))); parse_ok=0; fi
  rm -f "$L/.val.out"
  if [ "$parse_ok" = 1 ] && [ -s "$L/.init.err" ]; then
    echo "FAIL $n [init] $(sed 's/\x1b\[[0-9;]*m//g' "$L/.init.err" | grep -m1 -v '^[[:space:]]*$')"; fails=$((fails + 1)); parse_ok=0
  fi
  rm -f "$L/.init.err"

  # 2. fmt and tflint only when the configuration parses
  if [ "$parse_ok" = 1 ]; then
    while IFS= read -r f; do [ -n "$f" ] && fail "$L" "$f" "" "not formatted (terraform fmt)"; done \
      < <("$TF" -chdir="$L" fmt -check -recursive -list=true -no-color 2>/dev/null | grep -v '^$')

    ( cd "$L" && "$TFLINT" --format json 2>/dev/null ) \
      | jq -r '(.issues[]? | "\(.range.filename)|\(.range.start.line)|\(.rule.name): \(.message)"), (.errors[]? | "||tflint error: \(.message)")' \
      | while IFS='|' read -r f ln msg; do
          c=""; [ -n "$f" ] && c=$(cap_of "$L/$f")
          echo "FAIL $n/${f:-?}${ln:+:$ln} [${c:-unknown}] tflint $msg"
        done > "$L/.lint.out"
    if [ -s "$L/.lint.out" ]; then cat "$L/.lint.out"; fails=$((fails + $(wc -l < "$L/.lint.out"))); fi
    rm -f "$L/.lint.out"
  fi

  [ "$fails" -eq "$before" ] && echo "layer $n: fmt, validate, tflint ok"
done

[ "$layers" -gt 0 ] || { echo "FAIL no layer found under $OUT"; exit 1; }
if [ "$fails" -gt 0 ]; then echo "static gate: $fails failure(s)"; exit 1; fi
echo "static gate: ok"
