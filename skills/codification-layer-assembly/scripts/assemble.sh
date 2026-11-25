#!/usr/bin/env bash
# codification-layer-assembly (TASK-022)
#   assemble.sh [raw-dir] [out-root]
# Runs the seven generators in dependency order, then the ownership check, then fmt, init and validate
# in every layer. Stops at the first failure. Every generator is idempotent, so a re-run is safe.
# Set TERRAFORM to use another binary. Layers are independent state: each is init-able on its own.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
sk=$here/../..
RAW=${1:-discovered_terraform/raw}
OUT=${2:-discovered_terraform/terraform}
TF=${TERRAFORM:-terraform}
export TERRAFORM=$TF

run() { echo "== $1"; shift; "$@"; }
run namespaces       bash "$sk/codification-namespaces/scripts/generate.sh"      "$RAW/namespaces.json" "$OUT"
run root-config      bash "$sk/codification-root-config/scripts/generate.sh"     "$RAW/root" "$OUT"
run policies         bash "$sk/codification-policies/scripts/generate.sh"        "$RAW" "$OUT"
run auth-mounts      bash "$sk/codification-auth-mounts/scripts/generate.sh"     "$RAW" "$OUT"
run secrets-engines  bash "$sk/codification-secrets-engines/scripts/generate.sh" "$RAW" "$OUT"
run teams            bash "$sk/codification-teams/scripts/generate.sh"           "$RAW" "$OUT"
run admin-config     bash "$sk/codification-admin-config/scripts/generate.sh"    "$RAW" "$OUT"

echo "== ownership check"
bash "$here/check.sh" "$OUT"

for L in "$OUT"/*/; do
  L=${L%/}; [ -f "$L/providers.tf" ] || continue
  echo "== $(basename "$L"): fmt, init, validate"
  "$TF" -chdir="$L" fmt -check -recursive >/dev/null
  "$TF" -chdir="$L" init -backend=false -input=false >/dev/null
  "$TF" -chdir="$L" validate -no-color | head -n 1
done
echo "assembly: ok"
