# spec-check

Harness-verifiable acceptance criteria of `specs.md` against the generated Terraform output. Criteria that need a fixture, a plan or the audit log are checked by other targets; see `docs/traceability.md`.

| Criterion | Result | Detail |
|---|---|---|
| CAP-001-AC1 | PASS | one vault_audit, type file, file_path /vault/logs/audit.log, import id file |
| CAP-001-AC2 | PASS | one global-rate-limit quota: path empty, rate 1000, interval 60, block_interval 60 |
| CAP-001-AC3 | PASS | files owned by root-config declare no vault_policy, vault_auth_backend, vault_mount or vault_namespace |
| CAP-001-AC4 | PASS | README records seal type, licence id and expiry, replication mode; no replication.tf; no licence text |
| CAP-001-AC5 | PASS | no fabricated audit options (hmac_accessor and similar are absent) |
| CAP-002-AC1 | PASS | admin layer declares provider alias admin for namespace admin; its resources use provider vault.admin |
| CAP-002-AC2 | PASS | README lists admin and namespace-admin, says operator belongs to root-config/policies, shows the three admin groups |
| CAP-002-AC3 | PASS | no human_auth.tf; README says no human auth method detected in admin |
| CAP-002-AC5 | PASS | files owned by admin-config declare no vault_auth_backend (auth-mounts files in the layer do) |
| CAP-002-AC6 | PASS | the admin vault_namespace has no custom_metadata block |
| CAP-003-AC1 | PASS | 5 vault_auth_backend, all type approle path approle; token/ not emitted |
| CAP-003-AC2 | PASS | 6 roles: the 5 specified plus the root exporter role (harness drift) |
| CAP-003-AC3 | PASS | token_ttl 3600, token_max_ttl 14400, secret_id_num_uses 1 on every role; secret_id_ttl per role as specified |
| CAP-003-AC4 | PASS | token_policies of all 6 roles are vault_policy references |
| CAP-003-AC5 | PASS | no role_id, secret_id or secret_id_accessor assigned a value in any .tf or .json file |
| CAP-003-AC6 | PASS | coverage.md lists 5 mounts as vault_auth_backend and 6 roles; none unsupported |
| CAP-004-AC1 | PASS | 3 tenant KV v2 mounts with the specified descriptions, plus the imported root secret/ (4 vault_mount) |
| CAP-004-AC2 | PASS | no vault_mount in admin; the root secret/ is emitted once and noted in coverage.md |
| CAP-004-AC3 | PASS | no vault_kv_secret_v2, vault_kv_secret or vault_generic_secret; no SYNTHETIC- string |
| CAP-004-AC4 | PASS | no sys, identity or cubbyhole mount emitted |
| CAP-004-AC5 | PASS | no default_lease_ttl_seconds or max_lease_ttl_seconds set to 0 |
| CAP-004-AC7 | PASS | no plugin_version emitted (no harness mount is pinned) |
| CAP-004-AC8 | PASS | every vault_kv_secret_backend_v2 references its vault_mount |
| CAP-005-AC1 | PASS | 4 namespaces, maximum depth 2, admin is the parent of the three tenants |
| CAP-005-AC2 | PASS | 4 vault_namespace; the 3 tenants carry the specified descriptions; admin has none |
| CAP-005-AC3 | PASS | parent listed before its children (admin first); no cycle (static gate, CAC1) |
| CAP-005-AC4 | PASS | children use provider = vault.<alias>; no namespace literal inside a vault_namespace block |
| CAP-005-AC6 | PASS | no vault_namespace for the root namespace |
| CAP-005-AC7 | PASS | namespace ids in hierarchy.md equal vault namespace list -detailed |
| CAP-006-AC1 | PASS | 10 policies: the 9 specified plus the root exporter (harness drift); default, root and default-ceiling not emitted |
| CAP-006-AC3 | PASS | correlation.md links operator, namespace-admin, platform-devops-write, billing-developers-read and identity-developers-read to their roles |
| CAP-006-AC4 | PASS | namespace-admin is correlated with the three admin groups in admin |
| CAP-006-AC7 | PASS | namespace-relative paths are preserved verbatim (secret/data/platform/sre/*) |
| CAP-006-AC8 | PASS | coverage.md lists the 2 EGP and 2 RGP fixture policies by name; they are emitted in *_sentinel.tf, not in *_policies.tf |
| CAP-008-AC1 | PASS | 2 EGP and 2 RGP: root without a provider, admin/platform under vault.admin_platform; names and enforcement levels match the fixture |
| CAP-008-AC2 | PASS | the four Sentinel sources are files, byte-identical to the fixture text |
| CAP-008-AC3 | PASS | EGP paths keep the order Vault returns; an RGP has no paths |
| CAP-008-AC4 | PASS | coverage.md states the EGP and RGP count per namespace and none where there is none |
| CAP-008-AC5 | PASS | four import blocks by bare policy name; labels carry the namespace so equal names in two namespaces cannot collide |
| CAP-007-AC1 | PASS | 9 internal groups in admin: 3 tenant admin groups with namespace-admin, 6 team groups |
| CAP-007-AC2 | PASS | 6 synthetic-user entities, each referenced exactly once by a team group (the exporter-agent entity is harness drift) |
| CAP-007-AC3 | PASS | no group alias and no alias in admin; teams.md says none for admin (the root exporter-agent alias is harness drift) |
| CAP-007-AC5 | PASS | teams.md: platform->sre,devops; app-billing and app-identity->developers,owners, each with its namespace |
| CAP-007-AC6 | PASS | teams.md says access is applied at the namespace layer and marks the policy links inferred |
| CAP-007-AC7 | PASS | no UUID literal in any .tf outside imports*.tf |

Verdict: **PASS** ({"PASS":45})
