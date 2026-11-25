#!/usr/bin/env bash
# validation-zero-diff (TASK-024)
#   zero-diff.sh [out-root] [report-dir]
# Harness only. For each layer in apply order (admin, namespaces, seed), in a scratch copy under mktemp so
# that no state file lands in the repo:
#   1. terraform init, plan; if the plan holds any add, update or destroy the layer stops before apply (import-only apply)
#   2. terraform plan -detailed-exitcode (must exit 0)
#   3. delete the scratch state, import again, plan again (state-only "destroy and reimport"; Vault is never touched)
# Results are grouped by capability (the file's "# Capability:" header) and written to
#   <report-dir>/zero-diff.json and zero-diff.md  (default discovered_terraform/validation)
# Every lifecycle ignore_changes entry is listed with its resource and the comment above it.
# Needs VAULT_ADDR on 127.0.0.1 and a token that can read every namespace (the harness root token).
set -uo pipefail
OUT=${1:-discovered_terraform/terraform}
REP=${2:-discovered_terraform/validation}
TF=${TERRAFORM:-terraform}
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
case "$VAULT_ADDR" in http://127.0.0.1:*|http://localhost:*) ;; *) echo "STOP: zero-diff runs against the local harness only (VAULT_ADDR=$VAULT_ADDR)" >&2; exit 2 ;; esac
: "${VAULT_TOKEN:?VAULT_TOKEN is not set (harness root token)}"
export TF_VAR_vault_address=$VAULT_ADDR TF_VAR_vault_token=$VAULT_TOKEN TF_IN_AUTOMATION=1
# sensitive alias name: the exporter AppRole role_id, read from the harness
if [ -z "${TF_VAR_exporter_agent_approle_name:-}" ] && grep -qs 'variable "exporter_agent_approle_name"' "$OUT"/admin/*.tf; then
  TF_VAR_exporter_agent_approle_name=$(vault read -field=role_id auth/approle/role/exporter/role-id) || { echo "STOP: cannot read the exporter role_id" >&2; exit 2; }
  export TF_VAR_exporter_agent_approle_name
fi
if grep -qE 'ignore_changes[[:space:]]*=[[:space:]]*(all|\[[[:space:]]*all[[:space:]]*\])' "$OUT"/*/*.tf 2>/dev/null; then
  echo "FAIL a blanket ignore_changes = all is not allowed"; exit 1
fi
mkdir -p "$REP"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
: > "$work/results.ndjson"
rc=0

# first Terraform error line of a step, for the FAIL message
first_error() { grep -m1 Error "$1" || head -n 1 "$1"; }

run_layer() {
  local layer=$1 src=$OUT/$1 d=$work/$1
  [ -f "$src/providers.tf" ] || { echo "SKIP $layer (not generated)"; return; }
  mkdir -p "$d"; cp "$src"/*.tf "$d"/; [ -d "$src/policies" ] && cp -r "$src/policies" "$d"/
  # resource address -> capability
  for f in "$d"/*.tf; do
    cap=$(sed -n 's/^# Capability: //p' "$f" | head -n 1)
    awk -v c="$cap" '/^resource "/ {t=$2; l=$3; gsub(/"/,"",t); gsub(/"/,"",l); print t"."l" "c}' "$f"
  done > "$d/.caps"

  "$TF" -chdir="$d" init -input=false -no-color >/dev/null 2>"$d/.err" || { echo "FAIL $layer: init: $(first_error "$d/.err")"; rc=1; return; }
  local phase
  for phase in import reimport; do
    [ "$phase" = reimport ] && rm -f "$d"/terraform.tfstate "$d"/terraform.tfstate.backup
    # the import plan: only imports, no add, change or destroy
    "$TF" -chdir="$d" plan -input=false -no-color -out="$d/imp.plan" >/dev/null 2>"$d/.err" || { echo "FAIL $layer/$phase: plan: $(first_error "$d/.err")"; rc=1; return; }
    "$TF" -chdir="$d" show -json "$d/imp.plan" > "$d/imp.json"
    bad=$(jq '[.resource_changes[]? | select((.change.actions|index("create")) or (.change.actions|index("update")) or (.change.actions|index("delete")))] | length' "$d/imp.json")
    if [ "$bad" != 0 ]; then
      echo "FAIL $layer/$phase: the import plan has $bad non-import change(s); not applied, Vault is unchanged"; rc=1
      jq -r '.resource_changes[] | select((.change.actions|index("create")) or (.change.actions|index("update")) or (.change.actions|index("delete"))) | "  \(.address) \(.change.actions|join(","))"' "$d/imp.json" | head -5
      return
    fi
    if ! "$TF" -chdir="$d" apply -input=false -no-color "$d/imp.plan" >/dev/null 2>"$d/.err"; then
      echo "FAIL $layer/$phase: apply: $(first_error "$d/.err")"; rc=1; return
    fi
    "$TF" -chdir="$d" plan -input=false -no-color -detailed-exitcode -out="$d/post.plan" >/dev/null 2>"$d/.err"; code=$?
    "$TF" -chdir="$d" show -json "$d/post.plan" > "$d/post.json" 2>/dev/null
    [ "$code" = 0 ] || { rc=1; echo "FAIL $layer/$phase: plan -detailed-exitcode returned $code"; }
    jq -c --arg layer "$layer" --arg phase "$phase" --argjson code "$code" --rawfile caps "$d/.caps" '
      ($caps | split("\n") | map(select(length>0) | split(" ") | {key:.[0], value:.[1]}) | from_entries) as $c
      | (.resource_changes // []) | map({layer:$layer, pass:$phase, exit:$code, address:.address, capability:($c[.address] // "unknown"),
          clean:(.change.actions == ["no-op"])}) | .[]' "$d/post.json" >> "$work/results.ndjson"
    echo "layer $layer ($phase): plan exit $code, $(jq '[.resource_changes[]?]|length' "$d/post.json") resource(s)"
  done
  # ignore_changes with the reason comment above it
  for f in "$src"/*.tf; do
    awk -v layer="$layer" -v file="$(basename "$f")" '
      /^resource "/ {addr=$2"."$3; gsub(/"/,"",addr)}
      /^[[:space:]]*#/ {c=$0; sub(/^[[:space:]]*# */,"",c)}
      /ignore_changes/ {a=$0; sub(/.*\[/,"",a); sub(/\].*/,"",a); gsub(/ /,"",a); printf "{\"layer\":\"%s\",\"file\":\"%s\",\"resource\":\"%s\",\"attributes\":\"%s\",\"reason\":\"%s\"}\n", layer, file, addr, a, c}' "$f"
  done >> "$work/ignores.ndjson"
}

: > "$work/ignores.ndjson"
for layer in admin namespaces seed; do run_layer "$layer"; done

# the seven capabilities are always reported; one that declares no resources is "none declared"
jq -s '
  def seven: ["namespaces","root-config","policies","auth-mounts","secrets-engines","teams","admin-config"];
  (group_by(.capability) | map({capability: .[0].capability, resources: (map(.address)|unique|length),
       result: (if all(.[]; .exit == 0 and .clean) then "pass" else "fail" end)})) as $found
  | ($found | map(.capability)) as $have
  | { layers: (group_by(.layer) | map({layer: .[0].layer, resources: (map(.address)|unique|length), pass: (all(.[]; .exit == 0 and .clean))})),
      capabilities: ($found + [seven[] | select(. as $c | $have | index($c) | not) | {capability: ., resources: 0, result: "none declared"}] | sort_by(.capability)),
      passes: (group_by([.layer,.pass]) | map({layer: .[0].layer, pass: .[0].pass, exit: .[0].exit}))}' "$work/results.ndjson" > "$work/summary.json"
jq -s --slurpfile s "$work/summary.json" '{summary: $s[0], ignore_changes: .}' "$work/ignores.ndjson" > "$REP/zero-diff.json"

{
  echo '# Zero-diff import report'; echo
  echo 'Imports applied in a scratch state (Vault is not modified), followed by `terraform plan -detailed-exitcode`. The "reimport" pass deletes the scratch state and imports again.'; echo
  echo '| Capability | Resources | Result |'; echo '|---|---|---|'
  jq -r '.summary.capabilities[] | "| \(.capability) | \(.resources) | \(.result) |"' "$REP/zero-diff.json"
  echo; echo '| Layer | Resources | Result |'; echo '|---|---|---|'
  jq -r '.summary.layers[] | "| \(.layer) | \(.resources) | \(if .pass then "pass" else "fail" end) |"' "$REP/zero-diff.json"
  echo; echo '## ignore_changes entries'; echo
  echo '| Layer | File | Resource | Attributes | Reason |'; echo '|---|---|---|---|---|'
  jq -r '.ignore_changes[] | "| \(.layer) | `\(.file)` | `\(.resource)` | `\(.attributes)` | \(.reason) |"' "$REP/zero-diff.json"
} > "$REP/zero-diff.md"

jq -r '.summary.capabilities[] | "capability \(.capability): \(.result) (\(.resources) resource(s))"' "$REP/zero-diff.json"
if [ "$rc" = 0 ] && jq -e '[.summary.capabilities[].result] | all(. == "pass" or . == "none declared")' "$REP/zero-diff.json" >/dev/null; then echo "zero-diff: ok"; exit 0; fi
echo "zero-diff: FAILED"; exit 1
