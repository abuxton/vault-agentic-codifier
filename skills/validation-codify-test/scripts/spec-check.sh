#!/usr/bin/env bash
# validation-codify-test (TASK-030): check the harness-verifiable acceptance criteria of specs.md against the
# generated output, one result per criterion.
#   bash spec-check.sh [out-root] [report-dir]        (make spec-check)
# Reads discovered_terraform/terraform only; raw/ is git-ignored and not needed. CAP-005 AC7 compares namespace ids
# with `vault namespace list -detailed` when VAULT_TOKEN is set and the harness answers, and is SKIPped otherwise.
# Criteria that need a variant fixture, a plan or the audit log are verified by other targets (docs/traceability.md).
# Output has no timestamps, so a re-run leaves the reports unchanged. Exit 0 when no check fails.
set -uo pipefail
export PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin:$HOME/.rd/bin
export VAULT_CONFIG_PATH=/dev/null
ROOT=$(cd "$(dirname "$0")/../../.." && pwd); cd "$ROOT" || exit 2

if [ "${1:-}" = "--selftest" ]; then # mutate a copy of the output; the matching criterion must flip to FAIL
  W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; bad=0
  me=$ROOT/skills/validation-codify-test/scripts/spec-check.sh
  mut() { # id, description, shell command run inside a fresh copy of the output
    local id=$1 d=$2; shift 2
    rm -rf "$W/t"; mkdir -p "$W/t"; cp -R discovered_terraform/terraform/. "$W/t/"
    ( cd "$W/t" && eval "$@" ) >/dev/null 2>&1
    out=$(VAULT_TOKEN= bash "$me" "$W/t" "$W/rep" 2>&1)   # captured first: grep -q would SIGPIPE the writer under pipefail
    if grep -qE "^FAIL +$id +" <<<"$out"; then echo "SELFTEST ok: $d caught by $id"
    else echo "SELFTEST MISSED: $d (expected $id to FAIL)"; bad=1; fi
  }
  mut CAP-001-AC2 "quota rate changed"            "perl -pi -e 's/rate( +)= 1000/rate\$1= 5/' admin/quotas.tf"
  mut CAP-001-AC3 "root-config file declares a policy" "printf 'resource \"vault_policy\" \"x\" {}\n' >> admin/audit.tf"
  mut CAP-002-AC3 "human_auth.tf appears"         "touch admin/human_auth.tf"
  mut CAP-003-AC1 "a token auth backend emitted"  "perl -pi -e 's/type( +)= \"approle\"/type\$1= \"token\"/ and \$d=1 unless \$d' admin/root_auth_mounts.tf"
  mut CAP-003-AC3 "role TTL changed"              "perl -pi -e 's/token_ttl( +)= 3600/token_ttl\$1= 60/ and \$d=1 unless \$d' seed/admin_app_billing_auth_mounts.tf"
  mut CAP-003-AC5 "secret_id value written"       "printf 'secret_id = \"abc123\"\n' >> seed/providers.tf"
  mut CAP-004-AC3 "a KV secret resource emitted"  "printf 'resource \"vault_kv_secret_v2\" \"x\" {}\n' >> seed/providers.tf"
  mut CAP-004-AC3 "a SYNTHETIC marker leaks"      "printf '# SYNTHETIC-x\n' >> seed/providers.tf"
  mut CAP-005-AC6 "root namespace emitted"        "printf 'resource \"vault_namespace\" \"root\" {\n  path = \"\"\n}\n' >> namespaces/namespaces.tf"
  mut CAP-006-AC1 "a policy dropped"              "rm seed/admin_platform_policies.tf"
  mut CAP-006-AC8 "an EGP policy emitted"         "printf 'resource \"vault_egp_policy\" \"x\" {}\n' >> admin/admin_policies.tf"
  mut CAP-008-AC1 "a tenant Sentinel file dropped" "rm seed/admin_platform_sentinel.tf"
  mut CAP-008-AC2 "a Sentinel source edited"      "printf '// tampered\n' >> admin/policies/sentinel/root/egp-synthetic-egp-root-advisory.sentinel"
  mut CAP-009-AC1 "the MFA file dropped"          "rm admin/admin_mfa.tf"
  mut CAP-009-AC2 "a method id as a literal"      "perl -pi -e 's/vault_identity_mfa_totp\\.admin_totp\\.method_id/\"6907f873-6fb3-9dc7-c4bf-c2205d8f5c3c\"/' admin/admin_mfa.tf"
  mut CAP-009-AC3 "a Duo key written as a literal" "printf 'resource \"vault_identity_mfa_duo\" \"x\" {\\n  secret_key = \"abc\"\\n}\\n' >> admin/admin_mfa.tf"
  mut CAP-007-AC7 "a UUID literal in a .tf"       "printf '# 0a1b2c3d-0a1b-0a1b-0a1b-0a1b2c3d4e5f\n' >> admin/admin_identity.tf"
  [ $bad = 0 ] && echo "SELFTEST: all faults detected"; exit $bad
fi

T=${1:-discovered_terraform/terraform}
REP=${2:-discovered_terraform/validation}
[ -d "$T/admin" ] || { echo "STOP: $T has no admin layer; run make assemble first" >&2; exit 2; }
mkdir -p "$REP"
res=(); fail=0

rec() { # id, status, detail
  res+=("$(jq -n -c --arg i "$1" --arg s "$2" --arg d "$3" '{id:$i,status:$s,detail:$d}')")
  [ "$2" = FAIL ] && fail=1
  printf '%-5s %-14s %s\n' "$2" "$1" "$3"
}
yn() { # id, detail; reads the exit status of the command run just before it
  local s=$?
  if [ $s -eq 0 ]; then rec "$1" PASS "$2"; else rec "$1" FAIL "$2"; fi
}
tf_files() { find "$T" -name '*.tf' -not -path '*/.terraform/*' | sort; }
blocks() { # every resource block of a type, across all layers
  tf_files | while IFS= read -r f; do
    awk -v t="$1" '$0 ~ "^resource \""t"\" " {p=1} p {print} p && /^}/ {p=0}' "$f"
  done
}
block() { # one named resource block
  tf_files | while IFS= read -r f; do
    awk -v t="$1" -v n="$2" '$0 ~ "^resource \""t"\" \""n"\" " {p=1} p {print} p && /^}/ {p=0}' "$f"
  done
}
owned_by() { # files whose provenance header names the capability
  tf_files | while IFS= read -r f; do grep -q "^# Capability: $1\$" "$f" && echo "$f"; done
}
nblk() { grep -c '^resource "' <<<"$1"; }
UUID='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

# ---------- CAP-001 root-config
a=$T/admin/audit.tf; ir=$T/admin/imports_root_config.tf; rr=$T/admin/root_config_README.md
[ "$(grep -c '^resource "vault_audit"' "$a")" = 1 ] && grep -q 'type = "file"' "$a" &&
  grep -q 'file_path = "/vault/logs/audit.log"' "$a" && grep -A2 'to = vault_audit.file' "$ir" | grep -q 'id = "file"'
yn CAP-001-AC1 "one vault_audit, type file, file_path /vault/logs/audit.log, import id file"
q=$(block vault_quota_rate_limit global_rate_limit)
[ "$(grep -c '^resource "vault_quota_rate_limit"' "$T/admin/quotas.tf")" = 1 ] && grep -q 'name  *= "global-rate-limit"' <<<"$q" &&
  grep -qE 'path +=  *""' <<<"$q" && grep -qE 'rate +=  *1000' <<<"$q" && grep -qE '^ +interval +=  *60' <<<"$q" && grep -qE 'block_interval +=  *60' <<<"$q"
yn CAP-001-AC2 "one global-rate-limit quota: path empty, rate 1000, interval 60, block_interval 60"
bad=0; for f in $(owned_by root-config); do grep -qE '^resource "vault_(policy|auth_backend|mount|namespace)"' "$f" && bad=1; done
[ $bad = 0 ]; yn CAP-001-AC3 "files owned by root-config declare no vault_policy, vault_auth_backend, vault_mount or vault_namespace"
grep -q 'Seal type' "$rr" && grep -qE 'Licence.*ID .*expires' "$rr" && grep -q 'performance `disabled`' "$rr" &&
  [ -z "$(find "$T" -name replication.tf)" ] && ! grep -qiE 'license_text|BEGIN|hclic' "$rr"
yn CAP-001-AC4 "README records seal type, licence id and expiry, replication mode; no replication.tf; no licence text"
! grep -qE 'hmac_accessor|elide_list|log_raw' "$a"; yn CAP-001-AC5 "no fabricated audit options (hmac_accessor and similar are absent)"

# ---------- CAP-002 admin-config
ar=$T/admin/admin_config_README.md
grep -A3 'alias *= "admin"' "$T/admin/providers.tf" | grep -q 'namespace *= "admin"' && grep -q 'provider *= vault.admin$' "$T/admin/admin_policies.tf"
yn CAP-002-AC1 "admin layer declares provider alias admin for namespace admin; its resources use provider vault.admin"
grep -q '^| `admin` | admin' "$ar" && grep -q '`namespace-admin`' "$ar" && grep -qE 'operator.*(root-config|policies)' "$ar" &&
  grep -q 'vault-platform-admin' "$ar" && grep -q 'vault-app-billing-admin' "$ar" && grep -q 'vault-app-identity-admin' "$ar"
yn CAP-002-AC2 "README lists admin and namespace-admin, says operator belongs to root-config/policies, shows the three admin groups"
[ -z "$(find "$T" -name human_auth.tf)" ] && grep -q 'No human auth method detected in `admin`' "$ar"
yn CAP-002-AC3 "no human_auth.tf; README says no human auth method detected in admin"
bad=0; for f in $(owned_by admin-config); do grep -q '^resource "vault_auth_backend"' "$f" && bad=1; done
[ $bad = 0 ]; yn CAP-002-AC5 "files owned by admin-config declare no vault_auth_backend (auth-mounts files in the layer do)"
! awk '/^resource "vault_namespace" "admin" /{p=1} p{print} p&&/^}/{p=0}' "$T/admin/namespaces.tf" | grep -q custom_metadata
yn CAP-002-AC6 "the admin vault_namespace has no custom_metadata block"

# ---------- CAP-003 auth-mounts
ab=$(blocks vault_auth_backend)
n=$(nblk "$ab"); ap=$(grep -cE 'type +=  *"approle"' <<<"$ab"); pp=$(grep -cE 'path +=  *"approle"' <<<"$ab"); tk=$(grep -cE 'type +=  *"token"' <<<"$ab")
[ "$n" = 5 ] && [ "$ap" = 5 ] && [ "$pp" = 5 ] && [ "$tk" = 0 ]
yn CAP-003-AC1 "5 vault_auth_backend, all type approle path approle; token/ not emitted"
roles=$(blocks vault_approle_auth_backend_role)
names=$(sed -n 's/^ *role_name *= "\(.*\)"/\1/p' <<<"$roles" | sort | tr '\n' ' ')
[ "$names" = "billing-service exporter identity-service namespace-provisioner platform-ci terraform-admin " ]
yn CAP-003-AC2 "6 roles: the 5 specified plus the root exporter role (harness drift)"
ttl=$(awk '/role_name/{gsub(/"/,"",$3); n=$3} /secret_id_ttl/{print n"="$3}' <<<"$roles" | sort | tr '\n' ' ')
[ "$(grep -cE 'token_ttl +=  *3600' <<<"$roles")" = 6 ] && [ "$(grep -cE 'token_max_ttl +=  *14400' <<<"$roles")" = 6 ] &&
  [ "$(grep -cE 'secret_id_num_uses +=  *1$' <<<"$roles")" = 6 ] &&
  grep -q 'billing-service=900 ' <<<"$ttl " && grep -q 'identity-service=900 ' <<<"$ttl " && grep -q 'namespace-provisioner=900 ' <<<"$ttl " &&
  grep -q 'platform-ci=1800 ' <<<"$ttl " && grep -q 'terraform-admin=900 ' <<<"$ttl "
yn CAP-003-AC3 "token_ttl 3600, token_max_ttl 14400, secret_id_num_uses 1 on every role; secret_id_ttl per role as specified"
[ "$(grep -cE 'token_policies +=  *\[vault_policy\.[a-z0-9_]+\.name\]' <<<"$roles")" = 6 ]
yn CAP-003-AC4 "token_policies of all 6 roles are vault_policy references"
# an argument or JSON key with a value; prose that names the field (a description, a README) is not a value
! grep -rEn '(^|[^A-Za-z0-9_"])"?(role_id|secret_id|secret_id_accessor)"? *[=:] *"?[A-Za-z0-9]' "$T" --include='*.tf' --include='*.json' --exclude-dir=.terraform | grep -q .
yn CAP-003-AC5 "no role_id, secret_id or secret_id_accessor assigned a value in any .tf or .json file"
grep -q 'Mounts: 5. Roles: 6. Not fully codified: 0.' "$T/auth-mounts/coverage.md" && ! grep -qi unsupported "$T/auth-mounts/coverage.md"
yn CAP-003-AC6 "coverage.md lists 5 mounts as vault_auth_backend and 6 roles; none unsupported"

# ---------- CAP-004 secrets-engines
mt=$(blocks vault_mount); nmt=$(nblk "$mt")
ok=1; for d in "Platform KV v2 secrets engine" "Billing app KV v2 secrets engine" "Identity service KV v2 secrets engine"; do grep -q "description *= \"$d\"" <<<"$mt" || ok=0; done
[ "$(grep -cE 'type +=  *"kv"' <<<"$mt")" = "$nmt" ] && [ "$(grep -cE 'version +=  *"2"' <<<"$mt")" = "$nmt" ] && [ "$nmt" = 4 ] && [ $ok = 1 ]
yn CAP-004-AC1 "3 tenant KV v2 mounts with the specified descriptions, plus the imported root secret/ (4 vault_mount)"
[ "$(grep -c '^resource "vault_mount" "secret" ' <<<"$mt")" = 1 ] && ! grep -q 'provider *= vault.admin$' <<<"$mt" && grep -q 'preloaded root mount' "$T/secrets-engines/coverage.md"
yn CAP-004-AC2 "no vault_mount in admin; the root secret/ is emitted once and noted in coverage.md"
! grep -rEn 'resource "vault_(kv_secret_v2|kv_secret|generic_secret)"' "$T" --include='*.tf' | grep -q . && ! grep -rn 'SYNTHETIC' "$T" --exclude-dir=.terraform | grep -q .
yn CAP-004-AC3 "no vault_kv_secret_v2, vault_kv_secret or vault_generic_secret; no SYNTHETIC- string"
! grep -qE 'path +=  *"(sys|identity|cubbyhole)"' <<<"$mt"; yn CAP-004-AC4 "no sys, identity or cubbyhole mount emitted"
! grep -rEn '_ttl_seconds *= *0' "$T" --include='*.tf' | grep -q .; yn CAP-004-AC5 "no default_lease_ttl_seconds or max_lease_ttl_seconds set to 0"
! grep -rn 'plugin_version' "$T" --include='*.tf' | grep -q .; yn CAP-004-AC7 "no plugin_version emitted (no harness mount is pinned)"
kv=$(blocks vault_kv_secret_backend_v2)
[ -n "$kv" ] && [ "$(grep -cE 'mount +=  *vault_mount\.[a-z0-9_]+\.path' <<<"$kv")" = "$(nblk "$kv")" ]
yn CAP-004-AC8 "every vault_kv_secret_backend_v2 references its vault_mount"

# ---------- CAP-005 namespaces
h=$T/namespaces/hierarchy.md
rows=$(grep -cE '^\| `admin' "$h"); mx=$(grep -E '^\| `admin' "$h" | awk -F'|' '{gsub(/ /,"",$6); if($6+0>m)m=$6+0} END{print m}')
[ "$rows" = 4 ] && [ "$mx" = 2 ] && [ "$(grep -cE '^\| `admin/[a-z-]+` \| `admin` ' "$h")" = 3 ]
yn CAP-005-AC1 "4 namespaces, maximum depth 2, admin is the parent of the three tenants"
ns=$(blocks vault_namespace)
[ "$(nblk "$ns")" = 4 ] && [ "$(grep -c custom_metadata <<<"$ns")" = 3 ] && grep -q 'description *= "Platform engineering team namespace"' <<<"$ns" &&
  grep -q 'description *= "Billing application team namespace"' <<<"$ns" && grep -q 'description *= "Identity service team namespace"' <<<"$ns"
yn CAP-005-AC2 "4 vault_namespace; the 3 tenants carry the specified descriptions; admin has none"
[ "$(grep -E '^\| `admin' "$h" | head -1 | cut -d'|' -f2 | tr -d ' `')" = admin ]; yn CAP-005-AC3 "parent listed before its children (admin first); no cycle (static gate, CAC1)"
! grep -qE '(namespace|path) +=  *"admin/' <<<"$ns" && [ "$(grep -cE 'provider +=  *vault\.' <<<"$ns")" = 3 ]
yn CAP-005-AC4 "children use provider = vault.<alias>; no namespace literal inside a vault_namespace block"
! grep -qE 'path +=  *""' <<<"$ns"; yn CAP-005-AC6 "no vault_namespace for the root namespace"
if [ -n "${VAULT_TOKEN:-}" ] && command -v vault >/dev/null 2>&1 && VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200} vault status >/dev/null 2>&1; then
  export VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
  live=$( { vault namespace list -detailed -format=json | jq -r 'to_entries[]|"\(.key|rtrimstr("/"))\t\(.value.id)"'
            VAULT_NAMESPACE=admin vault namespace list -detailed -format=json | jq -r 'to_entries[]|"admin/\(.key|rtrimstr("/"))\t\(.value.id)"'; } | sort)
  doc=$(grep -E '^\| `admin' "$h" | awk -F'|' '{gsub(/[ `]/,"",$2); gsub(/[ `]/,"",$4); print $2"\t"$4}' | sort)
  [ -n "$live" ] && [ "$live" = "$doc" ]; yn CAP-005-AC7 "namespace ids in hierarchy.md equal vault namespace list -detailed"
else
  rec CAP-005-AC7 SKIP "needs the harness and VAULT_TOKEN"
fi

# ---------- CAP-006 policies
pol=$(blocks vault_policy)
pn=$(sed -n 's/^ *name *= "\(.*\)"/\1/p' <<<"$pol" | sort | tr '\n' ' ')
[ "$pn" = "admin billing-developers-read billing-owners-write exporter identity-developers-read identity-owners-write namespace-admin operator platform-devops-write platform-sre-read " ]
yn CAP-006-AC1 "10 policies: the 9 specified plus the root exporter (harness drift); default, root and default-ceiling not emitted"
c=$T/policies/correlation.md
grep -q '`operator` | `approle/terraform-admin`' "$c" && grep -q '`namespace-admin` | `approle/namespace-provisioner`' "$c" &&
  grep -q '`platform-devops-write` | `approle/platform-ci`' "$c" && grep -q '`billing-developers-read` | `approle/billing-service`' "$c" &&
  grep -q '`identity-developers-read` | `approle/identity-service`' "$c"
yn CAP-006-AC3 "correlation.md links operator, namespace-admin, platform-devops-write, billing-developers-read and identity-developers-read to their roles"
grep '`namespace-admin`' "$c" | grep -q 'vault-app-billing-admin.*vault-app-identity-admin.*vault-platform-admin'
yn CAP-006-AC4 "namespace-admin is correlated with the three admin groups in admin"
grep -q 'path "secret/data/platform/sre/\*"' "$T/seed/admin_platform_policies.tf"; yn CAP-006-AC7 "namespace-relative paths are preserved verbatim (secret/data/platform/sre/*)"
# Stage 2 (CAP-008): the Sentinel fixtures are listed in coverage.md and emitted in *_sentinel.tf, never in *_policies.tf.
grep -q '^- EGP: .*synthetic-egp-platform-advisory' "$T/policies/coverage.md" && grep -q '^- EGP: .*synthetic-egp-root-advisory' "$T/policies/coverage.md" &&
  grep -q '^- RGP: .*synthetic-rgp-platform-soft' "$T/policies/coverage.md" && grep -q '^- RGP: .*synthetic-rgp-root-soft' "$T/policies/coverage.md" &&
  ! grep -Eq 'resource "vault_(egp|rgp)_policy"' "$T"/*/*_policies.tf
yn CAP-006-AC8 "coverage.md lists the 2 EGP and 2 RGP fixture policies by name; they are emitted in *_sentinel.tf, not in *_policies.tf"

# ---------- CAP-008 sentinel-policies (stage 2)
eg=$(blocks vault_egp_policy); rg=$(blocks vault_rgp_policy)
[ "$(nblk "$eg")" = 2 ] && [ "$(nblk "$rg")" = 2 ] &&
  grep -q '^resource "vault_egp_policy" "synthetic_egp_root_advisory"' "$T/admin/root_sentinel.tf" && ! grep -q '^  provider' "$T/admin/root_sentinel.tf" &&
  grep -A1 '^resource "vault_egp_policy" "admin_platform_synthetic_egp_platform_advisory"' "$T/seed/admin_platform_sentinel.tf" | grep -q 'provider *= vault.admin_platform' &&
  grep -A1 '^resource "vault_rgp_policy" "admin_platform_synthetic_rgp_platform_soft"' "$T/seed/admin_platform_sentinel.tf" | grep -q 'provider *= vault.admin_platform' &&
  [ "$(grep -c 'enforcement_level *= "advisory"' <<<"$eg")" = 2 ] && [ "$(grep -c 'enforcement_level *= "soft-mandatory"' <<<"$rg")" = 2 ]
yn CAP-008-AC1 "2 EGP and 2 RGP: root without a provider, admin/platform under vault.admin_platform; names and enforcement levels match the fixture"
want=$(printf '// Harness fixture: always passes.\nmain = rule { true }\n'); ok=1
for f in "$T/admin/policies/sentinel/root/egp-synthetic-egp-root-advisory.sentinel" "$T/admin/policies/sentinel/root/rgp-synthetic-rgp-root-soft.sentinel" \
         "$T/seed/policies/sentinel/admin__platform/egp-synthetic-egp-platform-advisory.sentinel" "$T/seed/policies/sentinel/admin__platform/rgp-synthetic-rgp-platform-soft.sentinel"; do
  [ -f "$f" ] && [ "$(cat "$f"; echo x)" = "$want"$'\n'x ] || ok=0
done
[ $ok = 1 ]; yn CAP-008-AC2 "the four Sentinel sources are files, byte-identical to the fixture text"
grep -q 'paths *= \["secret/\*", "auth/approle/\*"\]' "$T/admin/root_sentinel.tf" && grep -q 'paths *= \["secret/\*"\]' "$T/seed/admin_platform_sentinel.tf" &&
  ! grep -q 'paths' <<<"$rg"
yn CAP-008-AC3 "EGP paths keep the order Vault returns; an RGP has no paths"
grep -q '^| root | 1 | 1 |$' "$T/policies/coverage.md" && grep -q '^| admin/platform | 1 | 1 |$' "$T/policies/coverage.md" &&
  grep -q '^| admin | none | none |$' "$T/policies/coverage.md" && grep -q '^| admin/app-billing | none | none |$' "$T/policies/coverage.md"
yn CAP-008-AC4 "coverage.md states the EGP and RGP count per namespace and none where there is none"
ie=$T/admin/imports_sentinel.tf; is=$T/seed/imports_sentinel.tf
grep -q 'to = vault_egp_policy.synthetic_egp_root_advisory' "$ie" && grep -A1 'to = vault_rgp_policy.synthetic_rgp_root_soft' "$ie" | grep -q 'id = "synthetic-rgp-root-soft"' &&
  grep -A1 'to = vault_egp_policy.admin_platform_synthetic_egp_platform_advisory' "$is" | grep -q 'id = "synthetic-egp-platform-advisory"' &&
  [ "$(grep -c '^import {' "$ie" "$is" | awk -F: '{s+=$2} END {print s}')" = 4 ]
yn CAP-008-AC5 "four import blocks by bare policy name; labels carry the namespace so equal names in two namespaces cannot collide"

# ---------- CAP-007 teams
gr=$(blocks vault_identity_group)
gn=$(sed -n 's/^ *name *= "\(.*\)"/\1/p' <<<"$gr" | sort | tr '\n' ' ')
[ "$(nblk "$gr")" = 9 ] && [ "$gn" = "vault-app-billing-admin vault-app-billing-developers vault-app-billing-owners vault-app-identity-admin vault-app-identity-developers vault-app-identity-owners vault-platform-admin vault-platform-devops vault-platform-sre " ] &&
  [ "$(grep -cE 'type +=  *"internal"' <<<"$gr")" = 9 ] && [ "$(grep -c 'provider *= vault.admin$' <<<"$gr")" = 9 ] &&
  [ "$(grep -c 'policies *= \[vault_policy.admin_namespace_admin.name\]' <<<"$gr")" = 3 ]
yn CAP-007-AC1 "9 internal groups in admin: 3 tenant admin groups with namespace-admin, 6 team groups"
en=$(blocks vault_identity_entity); okr=1
for e in $(sed -n 's/^resource "vault_identity_entity" "\(admin_synthetic_user_[a-z_]*\)".*/\1/p' <<<"$en"); do
  [ "$(grep -c "vault_identity_entity\.$e\.id" <<<"$gr")" = 1 ] || okr=0
done
[ "$(grep -c 'name *= "synthetic-user-' <<<"$en")" = 6 ] && [ $okr = 1 ]
yn CAP-007-AC2 "6 synthetic-user entities, each referenced exactly once by a team group (the exporter-agent entity is harness drift)"
[ "$(nblk "$(blocks vault_identity_group_alias)")" = 0 ] && grep -q 'No aliases found for `admin`' "$T/teams/teams.md"
yn CAP-007-AC3 "no group alias and no alias in admin; teams.md says none for admin (the root exporter-agent alias is harness drift)"
tm=$T/teams/teams.md; ok=1
for r in "developers|app-billing" "owners|app-billing" "developers|app-identity" "owners|app-identity" "devops|platform" "sre|platform"; do
  grep -q "^| ${r%%|*} | \`admin/${r#*|}\`" "$tm" || ok=0
done
[ $ok = 1 ]; yn CAP-007-AC5 "teams.md: platform->sre,devops; app-billing and app-identity->developers,owners, each with its namespace"
grep -q 'applied at the namespace layer' "$tm" && grep -q 'inferred' "$tm" && grep -q 'platform-sre-read' "$tm"
yn CAP-007-AC6 "teams.md says access is applied at the namespace layer and marks the policy links inferred"
! grep -rEn "$UUID" "$T" --include='*.tf' --exclude='imports*.tf' --exclude-dir=.terraform | grep -q .
yn CAP-007-AC7 "no UUID literal in any .tf outside imports*.tf"

# ---------- CAP-009 mfa (stage 2)
mf=$T/admin/admin_mfa.tf; mi=$T/admin/imports_mfa.tf
[ "$(grep -c '^resource "vault_identity_mfa_totp"' "$mf")" = 1 ] && [ "$(grep -c '^resource "vault_identity_mfa_login_enforcement"' "$mf")" = 1 ] &&
  [ "$(blocks vault_identity_mfa_totp | grep -c '^resource ')" = 1 ] && [ "$(blocks vault_identity_mfa_login_enforcement | grep -c '^resource ')" = 1 ] &&
  [ "$(grep -c 'provider *= vault.admin$' "$mf")" = 2 ]
yn CAP-009-AC1 "one vault_identity_mfa_totp and one vault_identity_mfa_login_enforcement, both under vault.admin, and none anywhere else"
en=$(block vault_identity_mfa_login_enforcement admin_synthetic_platform_admin_totp)
grep -q 'mfa_method_ids *= \[vault_identity_mfa_totp\.admin_totp\.method_id\]' <<<"$en" && grep -q 'identity_group_ids *= \[vault_identity_group\.admin_vault_platform_admin\.id\]' <<<"$en" &&
  ! grep -Eq "$UUID" "$mf"
yn CAP-009-AC2 "the enforcement references the method and the vault-platform-admin group by resource reference, no UUID literal"
! grep -rEn '(secret_key|integration_key|api_token|settings_file_base64) *= *"' "$T" --include='*.tf' | grep -q . &&
  ! grep -rEn 'identity/mfa/.*(generate|admin-generate)' "$T" "$ROOT/skills/discovery-orchestrator/scripts" | grep -q .
yn CAP-009-AC3 "no Duo, Okta or PingID key argument is a string literal; discovery never calls a generate endpoint (Duo, Okta and PingID are proven by the mfa variant)"
grep -A1 'to = vault_identity_mfa_totp.admin_totp' "$mi" | grep -Eq "id = \"$UUID\"" && grep -A1 'to = vault_identity_mfa_login_enforcement.admin_synthetic_platform_admin_totp' "$mi" | grep -q 'id = "synthetic-platform-admin-totp"' &&
  ! grep -Eq "$UUID" "$mf"
yn CAP-009-AC5 "the method is imported by its UUID and the enforcement by its name; the UUID is only in imports_mfa.tf"
grep -q 'vault_identity_mfa_totp.admin_totp' "$T/teams/mfa.md" && grep -q 'admin_vault_platform_admin' "$T/teams/mfa.md" && grep -q '| `admin` | login enforcement |' "$T/teams/mfa.md"
yn CAP-009-AC6 "mfa.md lists the method and the enforcement with their namespace and the group they target"
[ "$(find "$T" -name '*_mfa.tf' ! -name 'imports_*' | wc -l | tr -d ' ')" = 1 ] && [ ! -e "$T/seed/imports_mfa.tf" ] && [ ! -e "$T/seed/admin_platform_mfa.tf" ]
yn CAP-009-AC7 "only admin has MFA objects, so no other namespace gets an MFA file"

# ---------- report
printf '%s\n' "${res[@]}" | jq -s -S --argjson f "$fail" '{verdict:(if $f==0 then "PASS" else "FAIL" end), counts:(group_by(.status)|map({(.[0].status):length})|add), results:.}' > "$REP/spec-check.json"
{
  echo "# spec-check"
  echo
  echo "Harness-verifiable acceptance criteria of \`specs.md\` against the generated Terraform output. Criteria that need a fixture, a plan or the audit log are checked by other targets; see \`docs/traceability.md\`."
  echo
  echo "| Criterion | Result | Detail |"
  echo "|---|---|---|"
  jq -r '.results[] | "| \(.id) | \(.status) | \(.detail) |"' "$REP/spec-check.json"
  echo
  echo "Verdict: **$(jq -r .verdict "$REP/spec-check.json")** ($(jq -c .counts "$REP/spec-check.json"))"
} > "$REP/spec-check.md"
echo "spec-check: $(jq -r .verdict "$REP/spec-check.json") $(jq -c .counts "$REP/spec-check.json")"
exit $fail
