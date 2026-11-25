#!/usr/bin/env bash
# validation-variants (TASK-026): edge-case fixtures the base harness cannot reach.
#   bash run-variants.sh [report-dir]
# Starts two THROWAWAY Vault Enterprise dev containers on 127.0.0.1 (18200 variant, 18201 empty), never the
# committed harness on 8200, applies each fixture there, runs discovery -> assemble -> static gate -> zero-diff
# -> read-only and secrets checks, asserts the expected output, writes <report-dir>/variants.{json,md}, then
# removes both containers. The real harness is snapshotted before and after and must be identical.
# Needs: docker, terraform, vault, jq, curl, tflint; tmp/vault.hclic; the exporter policy in test/terraform/admin.
# Exit 0 only when every scenario passes.
set -uo pipefail
export PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin:$HOME/.rd/bin
export VAULT_CONFIG_PATH=/dev/null
ROOT=$(cd "$(dirname "$0")/../../.." && pwd); cd "$ROOT" || exit 2
sk=$ROOT/skills
REP=${1:-discovered_terraform/validation}; mkdir -p "$REP"
IMG=hashicorp/vault-enterprise:2.2.2-ent
LIC=$ROOT/tmp/vault.hclic
VAR=vault-codifier-variant; EMP=vault-codifier-empty; VP=18200; EP=18201
WORK=$(mktemp -d)
[ -f "$LIC" ] || { echo "STOP: $LIC not found" >&2; exit 2; }
command -v docker >/dev/null || { echo "STOP: docker not found" >&2; exit 2; }

results=(); failed=0
rec() { # scenario, id, status, detail
  results+=("$(jq -n -c --arg s "$1" --arg i "$2" --arg t "$3" --arg d "$4" '{scenario:$s,check:$i,status:$t,detail:$d}')")
  echo "$3 [$1] $2: $4"; [ "$3" = FAIL ] && failed=1; return 0
}
ok() { # scenario, id, detail, command...  (the command is the assertion)
  local s=$1 i=$2 d=$3; shift 3
  if "$@" >/dev/null 2>&1; then rec "$s" "$i" PASS "$d"; else rec "$s" "$i" FAIL "$d"; fi
}
cleanup() { docker rm -f $VAR $EMP >/dev/null 2>&1; rm -rf "$WORK"; }
trap cleanup EXIT

snapshot() { # digest of the committed harness, "unreachable" when it is not running
  curl -sf --max-time 3 http://127.0.0.1:8200/v1/sys/health >/dev/null 2>&1 || { echo unreachable; return; }
  { for ns in "" admin admin/platform admin/app-billing admin/app-identity; do
      for c in "namespace list" "policy list" "auth list" "secrets list"; do
        VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root VAULT_NAMESPACE=$ns vault $c -format=json 2>/dev/null | jq -S -c 'if type=="object" then (keys) else . end'
      done
    done
    VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault list -format=json identity/entity/name 2>/dev/null
  } | shasum | cut -c1-16
}

start() { # name port
  docker rm -f "$1" >/dev/null 2>&1
  docker run -d --name "$1" --cap-add IPC_LOCK -p 127.0.0.1:"$2":8200 \
    -e VAULT_DEV_ROOT_TOKEN_ID=root -e VAULT_DEV_HA_ENABLE=1 -e VAULT_DEV_TRANSACTIONAL=1 \
    -e VAULT_LICENSE_PATH=/vault/license/vault.hclic -v "$LIC":/vault/license/vault.hclic:ro \
    "$IMG" server -dev -dev-root-token-id=root -dev-ha -dev-transactional -dev-listen-address=0.0.0.0:8200 >/dev/null || return 1
  for _ in $(seq 1 40); do curl -sf "http://127.0.0.1:$2/v1/sys/health" >/dev/null 2>&1 && return 0; sleep 1; done; return 1
}

exporter_token() { # prints a token from the exporter AppRole at $VAULT_ADDR; extra policies are attached to a child
  local s r
  s=$(VAULT_TOKEN=root vault write -f -field=secret_id auth/approle/role/exporter/secret-id) || return 1
  r=$(VAULT_TOKEN=root vault read -field=role_id auth/approle/role/exporter/role-id) || return 1
  vault write -field=token auth/approle/login role_id="$r" secret_id="$s"
}

codify() { # raw out
  bash "$sk/codification-layer-assembly/scripts/assemble.sh" "$1" "$2" >"$WORK/assemble.log" 2>&1
}

before=$(snapshot)
echo "== real harness snapshot before: $before"

# ============================== Scenario 1: variant cluster ==============================
S=variant
echo "== $S: start $VAR on 127.0.0.1:$VP"
start $VAR $VP || { rec $S start FAIL "container did not become healthy"; exit 1; }
export VAULT_ADDR=http://127.0.0.1:$VP
# base content: copy of the committed harness layers, without state or provider caches
rsync -a --exclude 'terraform.tfstate*' --exclude .terraform --exclude '.terraform.lock.hcl' test/terraform/ "$WORK/tf/" || exit 2
for l in admin namespaces seed; do
  ( cd "$WORK/tf/$l" && terraform init -input=false >/dev/null 2>&1 \
    && VAULT_TOKEN=root terraform apply -auto-approve -input=false -var=vault_address="$VAULT_ADDR" -var=vault_token=root >"$WORK/seed-$l.log" 2>&1 ) \
    || { rec $S "seed-$l" FAIL "seeding layer $l failed: $(tail -2 "$WORK/seed-$l.log" | tr '\n' ' ')"; exit 1; }
done
rec $S seed PASS "harness layers applied to the throwaway cluster"

R() { VAULT_TOKEN=root vault "$@"; }
MARK="VARIANT-MARKER-$$-$RANDOM"      # a value that must never reach any generated file
PH="plan-time-input-$RANDOM"          # stands in for the operator-supplied sensitive variable
# oidc in admin: a client secret that must never reach the output, a role, a role without optional fields
R auth enable -namespace=admin oidc >/dev/null
R write -namespace=admin auth/oidc/config oidc_discovery_url=https://accounts.google.com oidc_client_id=variant-client \
  "oidc_client_secret=$MARK" default_role=reader >/dev/null
R write -namespace=admin auth/oidc/role/reader user_claim=sub allowed_redirect_uris=https://vault.example.internal/callback \
  oidc_scopes=openid token_policies=namespace-admin bound_audiences=variant-client >/dev/null
R write -namespace=admin auth/oidc/role/viewer user_claim=email allowed_redirect_uris=https://vault.example.internal/callback >/dev/null
# external group and group alias on that mount
acc=$(R auth list -namespace=admin -format=json | jq -r '."oidc/".accessor')
grp=$(R write -namespace=admin -field=id identity/group name=oidc-external-admins type=external policies=namespace-admin)
R write -namespace=admin identity/group-alias name=oidc-admins mount_accessor="$acc" canonical_id="$grp" >/dev/null
# userpass in app-billing; pki and database in platform; nested namespace; a group in platform
R auth enable -namespace=admin/app-billing userpass >/dev/null
R secrets enable -namespace=admin/platform -path=pki pki >/dev/null
R secrets enable -namespace=admin/platform -path=db database >/dev/null
R namespace create -namespace=admin/platform sre-team >/dev/null
# default-readonly in two namespaces; a role naming a policy that does not exist in its namespace
R policy write -namespace=admin/platform default-readonly - <<<'path "secret/data/platform/*" { capabilities = ["read"] }' >/dev/null
R policy write -namespace=admin/app-billing default-readonly - <<<'path "secret/data/billing/*" { capabilities = ["read"] }' >/dev/null
R write -namespace=admin/platform identity/group name=platform-variant-group policies=default-readonly metadata=tenant=platform >/dev/null
R write -namespace=admin/platform auth/approle/role/ghost-role token_policies=does-not-exist >/dev/null
rec $S fixture PASS "oidc+role+external group/alias, userpass, pki, database, nested namespace, default-readonly x2, dangling role"

export EXPORTER_TOKEN; EXPORTER_TOKEN=$(exporter_token) || { rec $S exporter-login FAIL "AppRole login failed"; exit 1; }
RAW=$WORK/v/raw; mkdir -p "$WORK/v"
RAW=$RAW bash "$sk/discovery-orchestrator/scripts/run.sh" >"$WORK/discover.log" 2>&1; ec=$?
ok $S discovery "orchestrator exit 0 (got $ec)" test "$ec" = 0
codify "$RAW" "$WORK/v/terraform"; ec=$?
ok $S assemble "assemble.sh exit 0 (got $ec): $(tail -1 "$WORK/assemble.log")" test "$ec" = 0
T=$WORK/v/terraform

# CAP-002 AC4: one oidc backend with the discovery url; CAP-002 AC4 / CAC3: no secret literal anywhere
ok $S CAP-002-AC4 "one vault_jwt_auth_backend type=oidc with oidc_discovery_url" \
  bash -c "[ \$(grep -c '^resource \"vault_jwt_auth_backend\"' $T/admin/human_auth.tf) = 1 ] && grep -q 'type .*= \"oidc\"' $T/admin/human_auth.tf && grep -q 'oidc_discovery_url = \"https://accounts.google.com\"' $T/admin/human_auth.tf"
ok $S CAP-002-AC4-secret "client secret is a sensitive variable with no default; the marker appears in no file" \
  bash -c "! grep -rqI -- $MARK $T $RAW && grep -q 'oidc_client_secret = var\\.' $T/admin/human_auth.tf"
# CAP-003 AC7: a mount type with no dedicated resource is emitted and listed for manual review
ok $S CAP-003-AC7 "userpass emitted as vault_auth_backend and listed in coverage.md for manual review" \
  bash -c "grep -q 'resource \"vault_auth_backend\" \"admin_app_billing_userpass\"' $T/seed/admin_app_billing_auth_mounts.tf && grep -q 'userpass.*review manually' $T/auth-mounts/coverage.md"
# CAP-004 AC6: pki and database emit vault_mount without failure and are listed
ok $S CAP-004-AC6 "pki and database emitted as vault_mount; coverage.md lists them for review" \
  bash -c "grep -q 'vault_mount\" \"admin_platform_pki\"' $T/seed/admin_platform_secrets_engines.tf && grep -q 'vault_mount\" \"admin_platform_db\"' $T/seed/admin_platform_secrets_engines.tf && grep -c 'review manually' $T/secrets-engines/coverage.md | grep -qx 2"
# CAP-005 AC5: nested namespace at depth 3, after its parent
ok $S CAP-005-AC5 "admin/platform/sre-team at depth 3 in hierarchy.md, after admin/platform" \
  bash -c "grep -q 'admin/platform/sre-team.*| 3 |' $T/namespaces/hierarchy.md && [ \$(grep -n 'resource \"vault_namespace\"' $T/namespaces/namespaces.tf | wc -l) = 4 ]"
ok $S CAP-005-AC3 "parent before child in namespaces.tf" \
  bash -c "a=\$(grep -n 'vault_namespace\" \"admin_platform\"' $T/namespaces/namespaces.tf | cut -d: -f1); b=\$(grep -n 'vault_namespace\" \"admin_platform_sre_team\"' $T/namespaces/namespaces.tf | cut -d: -f1); [ \"\$a\" -lt \"\$b\" ]"
# CAP-006 AC6: same policy name in two namespaces, distinct labels and files
ok $S CAP-006-AC6 "default-readonly in two namespaces gives two distinct resources" \
  bash -c "grep -q 'vault_policy\" \"admin_platform_default_readonly\"' $T/seed/admin_platform_policies.tf && grep -q 'vault_policy\" \"admin_app_billing_default_readonly\"' $T/seed/admin_app_billing_policies.tf"
# CAP-006 AC5: dangling reference flagged, no policy fabricated
ok $S CAP-006-AC5 "does-not-exist flagged dangling in correlation.md; no vault_policy for it" \
  bash -c "grep -q 'does-not-exist. (dangling)' $T/policies/correlation.md && ! grep -rq 'does_not_exist' $T --include=*.tf"
# CAP-007 AC4: external group and alias; the alias reaches the mount by reference
ok $S CAP-007-AC4 "external group and one group alias whose mount_accessor is a resource reference" \
  bash -c "grep -q 'type .*= \"external\"' $T/admin/admin_identity.tf && grep -q 'mount_accessor = vault_jwt_auth_backend.admin_oidc.accessor' $T/admin/admin_identity_aliases.tf"
# CAP-007 AC8: a group in admin/platform is emitted under that namespace's provider alias
ok $S CAP-007-AC8 "platform-variant-group emitted with provider vault.admin_platform" \
  bash -c "grep -A2 'platform_variant_group\"' $T/seed/admin_platform_identity.tf | grep -q 'provider.*vault.admin_platform'"
# CAP-003 AC4: a role naming an unknown policy keeps the literal and is reported
ok $S CAP-003-AC4 "ghost-role keeps literal does-not-exist and coverage.md reports it" \
  bash -c "grep -q 'policy not in namespace: does-not-exist' $T/auth-mounts/coverage.md"

bash "$sk/validation-static-gate/scripts/gate.sh" "$T" >"$WORK/gate.log" 2>&1; ec=$?
ok $S CAC1 "static gate exit 0 (got $ec)" test "$ec" = 0
VAULT_TOKEN=root TF_VAR_admin_oidc_oidc_client_secret=$PH \
  bash "$sk/validation-zero-diff/scripts/zero-diff.sh" "$T" "$WORK/v/validation" >"$WORK/zd.log" 2>&1; ec=$?
ok $S CAC2 "zero-diff exit 0 in every layer (got $ec); $(grep -c ': pass' "$WORK/zd.log") capabilities pass" test "$ec" = 0
VAULT_CONTAINER=$VAR bash "$sk/validation-readonly-secrets/scripts/verify.sh" "$T" "$RAW" "$WORK/v/validation" "$WORK/v/run_report.json" >"$WORK/vf.log" 2>&1; ec=$?
ok $S "CAC3+CAC4" "read-only and no-secrets exit 0 (got $ec); $(grep -c '^PASS' "$WORK/vf.log") checks pass" test "$ec" = 0

# ============================== Scenario 2: restricted token ==============================
S=restricted-403
R policy write zz-deny-sys - >/dev/null <<<'path "sys/quotas/config" { capabilities = ["deny"] }
path "sys/config/ui/headers" { capabilities = ["deny"] }
path "sys/config/ui/headers/*" { capabilities = ["deny"] }'
tok=$(R token create -policy=exporter -policy=zz-deny-sys -ttl=15m -field=token)
RAW=$WORK/r/raw; mkdir -p "$WORK/r"
EXPORTER_TOKEN=$tok RAW=$RAW bash "$sk/discovery-orchestrator/scripts/run.sh" >"$WORK/r.log" 2>&1; ec=$?
ok $S CAP-001-AC7a "run continues and exits 0 despite 403s (got $ec)" test "$ec" = 0
ok $S CAP-001-AC7b "run_report.json lists sys/quotas/config and sys/config/ui/headers with status 403" \
  jq -e '[.non_200_responses[] | select(.http_status==403) | .endpoint] | (index("sys/quotas/config")!=null and index("sys/config/ui/headers")!=null)' "$WORK/r/run_report.json"
ok $S token-hygiene "the token does not appear in the run report or raw payloads" bash -c "! grep -rqF -- '$tok' $WORK/r"
codify "$RAW" "$WORK/r/terraform"; ec=$?
ok $S assemble "codification still succeeds with missing optional payloads (got $ec)" test "$ec" = 0
# the mandatory audit-device read: a 403 there must stop codification of root-config
R policy write zz-deny-audit - >/dev/null <<<'path "sys/audit" { capabilities = ["deny"] }'
tok2=$(R token create -policy=exporter -policy=zz-deny-audit -ttl=15m -field=token)
rm -rf "$WORK/r2"; mkdir -p "$WORK/r2/raw"; cp "$RAW/namespaces.json" "$WORK/r2/raw/"
EXPORTER_TOKEN=$tok2 RAW=$WORK/r2/raw bash "$sk/discovery-orchestrator/scripts/root-config.sh" >/dev/null 2>&1
bash "$sk/codification-root-config/scripts/generate.sh" "$WORK/r2/raw/root" "$WORK/r2/terraform" >/dev/null 2>&1; ec=$?
ok $S CAP-001-AC7c "an audit-device 403 makes root-config codification exit non-zero (got $ec)" test "$ec" -ne 0
VAULT_CONTAINER=$VAR bash "$sk/validation-readonly-secrets/scripts/verify.sh" "$WORK/r/terraform" "$RAW" "$WORK/r/validation" "$WORK/r/run_report.json" >"$WORK/rv.log" 2>&1; ec=$?
ok $S "CAC3+CAC4" "403 run: read-only and no-secrets exit 0 (got $ec)" test "$ec" = 0

# ============================== Scenario 3: empty cluster ==============================
S=empty-cluster
unset EXPORTER_TOKEN
start $EMP $EP || { rec $S start FAIL "container did not become healthy"; exit 1; }
export VAULT_ADDR=http://127.0.0.1:$EP
EXPORTER_TOKEN=root RAW=$WORK/e/raw bash "$sk/discovery-orchestrator/scripts/run.sh" >/dev/null 2>&1; ec=$?
ok $S stop-conditions "orchestrator refuses (root token, no audit device): exit 2 (got $ec)" test "$ec" = 2
# fixture-only: collect with the dev root token, which the orchestrator correctly refuses to accept
mkdir -p "$WORK/e"; export RAW=$WORK/e/raw
for s in namespaces root-config policies auth-mounts secrets-engines identity-teams admin-config; do
  EXPORTER_TOKEN=root bash "$sk/discovery-orchestrator/scripts/$s.sh" >/dev/null 2>&1 || true
done
codify "$WORK/e/raw" "$WORK/e/terraform"; ec=$?
ok $S assemble "codification of an empty cluster exits 0 (got $ec)" test "$ec" = 0
ok $S CAP-001-AC6 "no vault_audit resource; README says 'No audit devices were discovered'" \
  bash -c "! grep -rq 'resource \"vault_audit\"' $WORK/e/terraform --include=*.tf && grep -q 'No audit devices were discovered' $WORK/e/terraform/admin/root_config_README.md"
ok $S CAP-002-AC3 "no human_auth.tf and no admin_config files" bash -c "[ ! -e $WORK/e/terraform/admin/human_auth.tf ] && [ ! -e $WORK/e/terraform/admin/admin_config_README.md ]"
ok $S CAP-005-AC6 "no vault_namespace in an empty cluster" bash -c "! grep -rq 'resource \"vault_namespace\"' $WORK/e/terraform --include=*.tf"
bash "$sk/validation-static-gate/scripts/gate.sh" "$WORK/e/terraform" >/dev/null 2>&1; ec=$?
ok $S CAC1 "static gate exit 0 (got $ec)" test "$ec" = 0
VAULT_TOKEN=root bash "$sk/validation-zero-diff/scripts/zero-diff.sh" "$WORK/e/terraform" "$WORK/e/validation" >/dev/null 2>&1; ec=$?
ok $S CAC2 "zero-diff exit 0 (got $ec)" test "$ec" = 0
printf '{"start_time":"","end_time":""}\n' > "$WORK/e/run_report.json"
NO_AUDIT_DEVICE=1 bash "$sk/validation-readonly-secrets/scripts/verify.sh" "$WORK/e/terraform" "$WORK/e/raw" "$WORK/e/validation" "$WORK/e/run_report.json" >/dev/null 2>&1; ec=$?
ok $S CAC3 "content scans exit 0; the three audit checks are SKIP (got $ec)" test "$ec" = 0

# ============================== teardown and report ==============================
docker rm -f $VAR $EMP >/dev/null 2>&1
ok teardown containers-removed "both throwaway containers removed" bash -c "! docker ps -a --format '{{.Names}}' | grep -qE '^($VAR|$EMP)\$'"
after=$(snapshot)
if [ "$before" = unreachable ]; then rec teardown harness-unchanged SKIP "real harness not running"
else ok teardown harness-unchanged "real harness digest $before before, $after after" test "$before" = "$after"; fi

jq -n -S --argjson r "$(printf '%s\n' "${results[@]}" | jq -s -c .)" \
  '{results:$r, scenarios:($r|group_by(.scenario)|map({scenario:.[0].scenario, pass:(map(select(.status=="PASS"))|length), fail:(map(select(.status=="FAIL"))|length)})),
    verdict:(if ($r|map(select(.status=="FAIL"))|length)==0 then "PASS" else "FAIL" end)}' > "$REP/variants.json"
{
  echo "# Variant fixtures"; echo
  echo "Throwaway containers on 127.0.0.1:$VP and :$EP; the committed harness on 8200 is not touched."; echo
  echo "| Scenario | Check | Result | Detail |"; echo "|---|---|---|---|"
  jq -r '.results[] | "| \(.scenario) | \(.check) | \(.status) | \(.detail | gsub("\\|";"/")) |"' "$REP/variants.json"; echo
  echo "Verdict: **$(jq -r .verdict "$REP/variants.json")**"
} > "$REP/variants.md"
[ "$failed" -eq 0 ] && { echo "VARIANTS PASS"; exit 0; } || { echo "VARIANTS FAIL"; exit 1; }
