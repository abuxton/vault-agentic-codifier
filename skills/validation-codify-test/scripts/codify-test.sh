#!/usr/bin/env bash
# validation-codify-test (TASK-027): one command from a running harness to a per-CAC verdict.
#   bash codify-test.sh [report-dir]          (make codify-test)
#   VARIANTS=1 bash codify-test.sh            also run the edge-case fixtures (about 3 more minutes)
# Stages: harness up -> smoke-test (before) -> discover + codify twice -> idempotence (CAC5) -> ownership
# (CAC6, CAC7) -> static gate (CAC1) -> import and zero-diff (CAC2) -> read-only and secrets (CAC3, CAC4)
# -> smoke-test (after) -> harness unchanged. Exit 0 only when every stage passes.
# Both codify runs go to a scratch directory, so the committed output tree is not rewritten; the zero-diff and
# verification reports are written to <report-dir>. Harness only: it mints exporter tokens with the dev root token.
set -uo pipefail
export PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin:$HOME/.rd/bin
export VAULT_CONFIG_PATH=/dev/null
ROOT=$(cd "$(dirname "$0")/../../.." && pwd); cd "$ROOT" || exit 2
sk=$ROOT/skills
REP=${1:-discovered_terraform/validation}; [ "$REP" = "--selftest" ] || mkdir -p "$REP"
export VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
case "$VAULT_ADDR" in http://127.0.0.1:*|http://localhost:*) ;; *) echo "STOP: harness only (VAULT_ADDR=$VAULT_ADDR)" >&2; exit 2 ;; esac
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
stages=(); failed=0

stage() { # name, cac, description, command...
  local n=$1 c=$2 d=$3; shift 3
  printf '== %-22s %s\n' "$n" "$d"
  if "$@" >"$WORK/$n.log" 2>&1; then
    stages+=("$(jq -n -c --arg n "$n" --arg c "$c" --arg d "$d" '{stage:$n,cac:$c,description:$d,status:"PASS"}')"); echo "   PASS"
  else
    stages+=("$(jq -n -c --arg n "$n" --arg c "$c" --arg d "$d" '{stage:$n,cac:$c,description:$d,status:"FAIL"}')"); failed=1
    echo "   FAIL; last lines:"; tail -n 12 "$WORK/$n.log" | sed 's/^/   | /'
  fi
}

harness_up() {
  curl -sf --max-time 3 "$VAULT_ADDR/v1/sys/health" >/dev/null && return 0
  make -C test up seed && curl -sf --max-time 3 "$VAULT_ADDR/v1/sys/health" >/dev/null
}
digest() { # state of the harness that a codifier run must leave alone
  { for ns in "" admin admin/platform admin/app-billing admin/app-identity; do
      for c in "namespace list" "policy list" "auth list" "secrets list"; do
        VAULT_TOKEN=root VAULT_NAMESPACE=$ns vault $c -format=json 2>/dev/null | jq -S -c 'if type=="object" then (keys) else . end'
      done
    done
    VAULT_TOKEN=root vault list -format=json identity/entity/name 2>/dev/null
    VAULT_TOKEN=root vault list -format=json sys/policies/acl 2>/dev/null
  } | shasum | cut -c1-16
}
mint() { # exporter token, one-time secret-id
  local s r
  s=$(VAULT_TOKEN=root vault write -f -field=secret_id auth/approle/role/exporter/secret-id) || return 1
  r=$(VAULT_TOKEN=root vault read -field=role_id auth/approle/role/exporter/role-id) || return 1
  vault write -field=token auth/approle/login role_id="$r" secret_id="$s"
}
codify_run() { # n: discover into $WORK/run<n>/raw, generate into $WORK/run<n>/terraform
  local n=$1 d=$WORK/run$1
  mkdir -p "$d"
  EXPORTER_TOKEN=$(mint) || return 1; export EXPORTER_TOKEN
  RAW=$d/raw bash "$sk/discovery-orchestrator/scripts/run.sh" || return 1
  unset EXPORTER_TOKEN
  bash "$sk/codification-layer-assembly/scripts/assemble.sh" "$d/raw" "$d/terraform"
}
tree_hash() { # directory tree, ignoring provider caches and the volatile run report
  ( cd "$1" && find . -type f ! -path '*/.terraform/*' ! -name '.terraform.lock.hcl' ! -name 'run_report*' ! -name '.state.json' | LC_ALL=C sort \
      | while IFS= read -r f; do printf '%s ' "$f"; shasum < "$f" | cut -c1-40; done | shasum | cut -c1-16 )
}
idempotent() {
  local a b ra rb
  a=$(tree_hash "$WORK/run1/terraform"); b=$(tree_hash "$WORK/run2/terraform")
  ra=$(tree_hash "$WORK/run1/raw"); rb=$(tree_hash "$WORK/run2/raw")
  echo "output tree: run1=$a run2=$b"; echo "raw tree:    run1=$ra run2=$rb"
  [ "$a" = "$b" ] && [ "$ra" = "$rb" ] || { diff -r -q -x .terraform -x .terraform.lock.hcl -x 'run_report*' -x .state.json "$WORK/run1" "$WORK/run2" | head; return 1; }
  # a second generation pass over an existing tree changes nothing
  bash "$sk/codification-layer-assembly/scripts/assemble.sh" "$WORK/run1/raw" "$WORK/run1/terraform" >/dev/null || return 1
  [ "$(tree_hash "$WORK/run1/terraform")" = "$a" ] && echo "regeneration over an existing tree: unchanged"
}
static_gate() { bash "$sk/validation-static-gate/scripts/gate.sh" "$WORK/run1/terraform"; }
zero_diff()   { VAULT_TOKEN=root bash "$sk/validation-zero-diff/scripts/zero-diff.sh" "$WORK/run1/terraform" "$REP"; }
verify() { # window spans both discovery runs; both used exporter tokens
  local s e
  s=$(jq -r '.start_time' "$WORK/run1/run_report.json"); e=$(jq -r '.end_time' "$WORK/run2/run_report.json")
  WINDOW_START=$s WINDOW_END=$e bash "$sk/validation-readonly-secrets/scripts/verify.sh" "$WORK/run1/terraform" "$WORK/run1/raw" "$REP" "$WORK/run1/run_report.json" \
    && WINDOW_START=$s WINDOW_END=$e bash "$sk/validation-readonly-secrets/scripts/verify.sh" "$WORK/run2/terraform" "$WORK/run2/raw" "$WORK/rep2" "$WORK/run2/run_report.json"
}
harness_unchanged() { local a; a=$(digest); echo "before=$BEFORE after=$a"; [ "$a" = "$BEFORE" ]; }

if [ "${1:-}" = "--selftest" ]; then   # the idempotence check must fail on a one-byte difference, and on a missing file
  src=${OUT:-discovered_terraform/terraform}; rawsrc=${RAW:-discovered_terraform/raw}; n=0
  mk() { rm -rf "$WORK/run1" "$WORK/run2"; for r in run1 run2; do mkdir -p "$WORK/$r"; cp -R "$src" "$WORK/$r/terraform"; cp -R "$rawsrc" "$WORK/$r/raw"; done; }
  mk; idempotent >/dev/null 2>&1 && echo "SELFTEST ok: identical trees pass" || { echo "SELFTEST FAIL: identical trees rejected"; n=1; }
  mk; printf '\n# x\n' >> "$WORK/run2/terraform/admin/main.tf"
  idempotent >/dev/null 2>&1 && { echo "SELFTEST FAIL: a changed byte in the output was not detected"; n=1; } || echo "SELFTEST ok: changed output byte detected"
  mk; rm "$WORK/run2/terraform/admin/audit.tf"
  idempotent >/dev/null 2>&1 && { echo "SELFTEST FAIL: a missing file was not detected"; n=1; } || echo "SELFTEST ok: missing output file detected"
  mk; printf '{}\n' > "$WORK/run2/raw/root/extra.json"
  idempotent >/dev/null 2>&1 && { echo "SELFTEST FAIL: a changed raw payload was not detected"; n=1; } || echo "SELFTEST ok: extra raw payload detected"
  exit $n
fi
stage harness-up      -     "harness reachable at $VAULT_ADDR (starts and seeds it if not)" harness_up
[ "$failed" = 0 ] || { echo "STOP: harness is not available" >&2; exit 1; }
BEFORE=$(digest)
stage smoke-before    -     "make -C test smoke-test" make -C test smoke-test
stage codify-run-1    -     "discover with a fresh exporter token and generate" codify_run 1
stage codify-run-2    -     "second run against the unchanged cluster" codify_run 2
stage idempotence     CAC5  "two runs give byte-identical output and raw trees" idempotent
stage ownership       "CAC6,CAC7" "labels unique and deterministic; provenance header on every file" bash "$sk/codification-layer-assembly/scripts/check.sh" "$WORK/run1/terraform"
stage spec-check      CAP   "45 harness criteria of specs.md against the generated output" env VAULT_TOKEN=root bash "$sk/validation-codify-test/scripts/spec-check.sh" "$WORK/run1/terraform" "$REP"
stage static-gate     CAC1  "validate, fmt -check and tflint in every layer" static_gate
stage zero-diff       CAC2  "import into a scratch state; plan exits 0 in every layer" zero_diff
stage readonly-secrets "CAC3,CAC4" "audit log read-only and no secrets in output or raw" verify
[ "${VARIANTS:-0}" = 1 ] && stage variants "CAC1-CAC4" "edge-case fixtures on throwaway containers" bash "$sk/validation-variants/scripts/run-variants.sh" "$REP"
stage smoke-after     -     "make -C test smoke-test, after the codifier ran" make -C test smoke-test
stage harness-unchanged -   "harness state identical before and after" harness_unchanged

# ---- summary ---------------------------------------------------------------------------------------------
sj=$(printf '%s\n' "${stages[@]}" | jq -s -c .)
st() { jq -r --arg s "$1" '.[] | select(.stage==$s) | .status' <<<"$sj"; }
gate_fail() { grep -c "^FAIL .*\[$1\]" "$WORK/static-gate.log" 2>/dev/null || true; }
caps=$(jq -c '.summary.capabilities' "$REP/zero-diff.json")
cac_row() { printf '%s\n' "$1"; }
{
  echo "# codify-test"; echo
  echo "Run against $VAULT_ADDR. Output generated twice into a scratch directory; reports in this folder."; echo
  echo "## Per CAC"; echo; echo "| CAC | Meaning | Stage | Result |"; echo "|---|---|---|---|"
  echo "| CAC1 | valid HCL | static-gate | $(st static-gate) |"
  echo "| CAC2 | zero diff after import | zero-diff | $(st zero-diff) |"
  echo "| CAC3 | no secrets | readonly-secrets | $(st readonly-secrets) |"
  echo "| CAC4 | read-only | readonly-secrets | $(st readonly-secrets) |"
  echo "| CAC5 | idempotent | idempotence | $(st idempotence) |"
  echo "| CAC6 | naming | ownership | $(st ownership) |"
  echo "| CAC7 | provenance | ownership | $(st ownership) |"
  echo "| CAP-001 to CAP-007 | harness criteria (45: 40 stage 1, 5 CAP-008) | spec-check | $(st spec-check) |"
  echo; echo "## Per capability"; echo; echo "| Capability | Resources | CAC1 (static gate) | CAC2 (zero diff) |"; echo "|---|---|---|---|"
  jq -r '.[] | [.capability, (.resources|tostring), .result] | @tsv' <<<"$caps" | while IFS=$'\t' read -r c n r; do
    g=$(gate_fail "$c"); [ "$(st static-gate)" = PASS ] && gs=pass || { [ "${g:-0}" -gt 0 ] && gs="FAIL ($g)" || gs="pass"; }
    echo "| $c | $n | $gs | $r |"
  done
  echo; echo "## Stages"; echo; echo "| Stage | CAC | Result | What it checks |"; echo "|---|---|---|---|"
  jq -r '.[] | "| \(.stage) | \(.cac) | \(.status) | \(.description | gsub("\\|";"/")) |"' <<<"$sj"
  echo; echo "Verdict: **$([ "$failed" = 0 ] && echo PASS || echo FAIL)**"
} > "$REP/codify-test.md"
jq -n -S --argjson s "$sj" --argjson caps "$caps" --arg v "$([ "$failed" = 0 ] && echo PASS || echo FAIL)" '{stages:$s,capabilities:$caps,verdict:$v}' > "$REP/codify-test.json"
echo; cat "$REP/codify-test.md" | sed -n '/## Per CAC/,$p'
[ "$failed" = 0 ]
