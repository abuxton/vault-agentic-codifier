# HVD Alignment Matrix — terraform-vault-vault-codifier

> Purpose: show how the codifier's design and its test harness line up with HashiCorp Validated Design (HVD) guidance for Vault Enterprise, and where they do not.
> Harness: Vault Enterprise 2.2.2+ent at `http://127.0.0.1:8200`; namespaces `root`, `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`; AppRole per namespace; KV v2 `secret/` per tenant namespace; provider `hashicorp/vault` 4.8.0.
> Evidence paths are relative to the repository root.

---

## 1. Overview of HVD for Vault Enterprise

Source: `git@github.com:hashicorp/web-unified-docs.git`, `content/validated-designs/docs/docs/vault/` (public mirror: <https://github.com/hashicorp/web-unified-docs/tree/main/content/validated-designs/docs/docs/vault>). It contains three guides — `installation-guide`, `administration-guide`, `user-guide`. Pages in `administration-guide/` relevant to the codifier:

| HVD page (`administration-guide/`) | Relevance to the codifier |
|---|---|
| `vault-organizational-concepts.mdx` | Root namespace for operators only; `admin` namespace with tenant namespaces under it; centralised human auth; configure Vault with Terraform from a `vault-admin-config` repo; admin team provides modules, app teams consume them through consumer repos; separate test cluster mirrors prod |
| `authentication-for-people.mdx` | Human access (OIDC/LDAP → external groups → policies); operator/admin policy patterns (the harness' `operator.hcl` and policy headers cite it) |
| `authentication-for-applications.mdx` | Machine auth (AppRole and others), one auth path/role per workload |
| `static-secrets-management.mdx` | KV v2 layout and path-based separation (cited in `seed/main.tf`) |
| `dynamic-secrets-management.mdx`, `pki-certificate-management.mdx`, `transit-and-transform-management.mdx`, `secrets-sync-management.mdx`, `key-lifecycle-management-administration.mdx` | Other engines — not in the harness |
| `resource-quotas.mdx` | Rate-limit and lease-count quotas |
| `sentinel-policy-management.mdx` | EGP/RGP policy-as-code |
| `mfa-administration.mdx` | MFA methods and login enforcement |
| `monitoring-and-observability.mdx` | Audit logging, telemetry |
| `backup-and-restore-operations.mdx`, `disaster-recovery-operations.mdx`, `performance-replication-operations.mdx` | Raft snapshots, DR/PR replication |
| `upgrade-procedures.mdx` | Version upgrades |
| `people-and-process.mdx`, `support-readiness.mdx` | Operating model |

The page I read in full (`vault-organizational-concepts.mdx`) is the source for principles 1, 8, 9 below. For the other principles, the *page names above* are the HVD references; the matrix describes the principle at the level the harness code cites it, and exact HVD wording should be confirmed against the page before quoting. Where I have not read the page, the "Description" column states the general Vault best practice and is marked **(HVD page not re-read)**.

---

## 2. Alignment matrix

Status key: ✅ addressed and evidenced · 🟡 partially · ❌ not addressed.

| # | HVD Principle | Description | How the Codifier Addresses It | Test Harness Evidence | Status |
|---|---|---|---|---|---|
| 1 | **Namespace isolation** (admin namespace + tenant namespaces) | Reserve root for operators; create `admin` under root; put tenant namespaces under `admin`; each namespace holds its own mounts, auth methods and policies. (`vault-organizational-concepts.mdx`) | Domain model treats Namespace as the isolation unit; discovery walks namespaces recursively; generated Terraform uses one provider alias per namespace path and splits state into tiers (root → admin → tenants). | `test/terraform/admin/main.tf`: `vault_namespace.admin` (comment: "Root namespace is kept only for cluster operators"). `test/terraform/namespaces/main.tf`: `vault_namespace.tenant` `for_each = var.tenants` via `provider = vault.admin` → `admin/platform`, `admin/app-billing`, `admin/app-identity`. `seed/providers.tf`: one aliased provider per tenant (`namespace = "admin/<tenant>"`). `Makefile smoke-test` asserts `admin/` exists. | ✅ (single level of tenant nesting only; no per-environment sub-namespaces) |
| 2 | **Least-privilege policies** (per-namespace operator/admin policy) | Policies grant the minimum capabilities needed; operator-level access limited to root; tenant admins limited to their namespace. **(HVD page not re-read: `authentication-for-people.mdx`)** | Codifier emits policies verbatim from live HCL (`vault policy read`) and flags overly broad ones (`path "*"`, `sudo`). Discovery runs with a read-only, no-secret-data policy (see discovery guide §1.2). | Positive: tenant policies are path-scoped, e.g. `billing-developers-read` = `read, list` on `secret/data/billing-service/*` and `secret/metadata/billing-service/*`; `billing-owners-write` adds create/update/delete. `namespace-admin` (`namespaces/policies/namespace_admin.hcl`) is bounded to its own namespace. **Negative:** root `operator` = `path "*"` with `sudo`; `namespace-admin` grants `auth/*` and `sys/auth/*` with `sudo` and `identity/*` full — broad. **Observation:** `billing-owners-write`, `identity-owners-write`, `platform-sre-read` are not attached to any AppRole or group in the harness (roles use only the read / devops-write policy). | 🟡 |
| 3 | **Auth method per team/workload** (AppRole per namespace) | Each application/namespace gets its own auth mount and role; short-lived, single-use SecretIDs; people authenticate centrally. (`authentication-for-applications.mdx`, `vault-organizational-concepts.mdx`) | Resource map: `vault_auth_backend` + `vault_approle_auth_backend_role`; SecretIDs never codified; import by `auth/<mount>/role/<name>`. | `approle/` mounted in root, `admin`, and all 3 tenants (`admin/main.tf`, `namespaces/main.tf`, `seed/main.tf`). Roles `terraform-admin`, `namespace-provisioner`, `platform-ci`, `billing-service`, `identity-service` all use `token_ttl = 3600`, `token_max_ttl = 14400`, `secret_id_num_uses = 1`, `secret_id_ttl` 900–1800 s. Smoke test: `auth list` in `admin` contains `approle/`. | ✅ AppRole only; **no human auth** (OIDC/LDAP) in harness |
| 4 | **Secrets engine per workload** (KV v2 per namespace) | One KV v2 engine per tenant namespace, path-based separation inside (`<mount>/data/<app>/...`). (`static-secrets-management.mdx`, cited in `seed/main.tf`) | `vault_mount` (`type=kv`, `options.version=2`) + optional `vault_kv_secret_backend_v2` config; only path inventory is captured, never values. | `vault_mount.{platform,billing,identity}_secret` at `secret/`, `options = { version = "2" }`. Secrets at `platform/sre/config`, `platform/devops/ci-cd`, `billing-service/checkout`, `billing-service/payment-processor`, `identity-service/ldap`, `identity-service/mfa`. Smoke test reads `secret/` in `admin/platform`, `admin/app-billing`, `admin/app-identity`. | ✅ (no `vault_kv_secret_backend_v2` config, no dynamic/PKI/transit engines) |
| 5 | **Identity-based access** (entity + group model) | Policies attach to groups, not individuals; external groups mapped from IdP via group aliases; entities de-duplicate identities. **(HVD page not re-read: `authentication-for-people.mdx`)** | Domain model + resource map cover entity, group, entity-alias, group-alias; discovery guide separates authored identities from auto-created ones. | `namespaces/main.tf`: `vault_identity_group.tenant_admin` (3, policy `namespace-admin`), `vault_identity_group.team` (6, `policies = []`, one member entity each), `vault_identity_entity.team_member` (6, metadata `type = "synthetic"`). **Gaps:** all groups `internal`; **0 group aliases, 0 entity aliases**; team groups carry no policies; groups live in `admin` while the tenant policies live in the tenant namespaces, so nothing links the identities to the tenant policies in the harness. | 🟡 |
| 6 | **Audit logging** (audit device at root) | At least one audit device on the cluster (root); HVD recommends redundancy so the loss of one sink does not block requests. (`monitoring-and-observability.mdx`) | `vault_audit` captured from `sys/audit`; flagged as root-only; discovery reads `vault audit list -detailed`. | `admin/main.tf`: `vault_audit.file`, `type = "file"`, `file_path = "/vault/logs/audit.log"`. Only **one** device; no syslog/socket sink; log shipping not modelled. | 🟡 |
| 7 | **Rate limiting** (quota per namespace) | Protect the cluster from noisy tenants with rate-limit (and lease-count) quotas at global, namespace and mount scope. (`resource-quotas.mdx`) | `vault_quota_rate_limit` mapped; discovery lists `sys/quotas/rate-limit` and `sys/quotas/config`; `path` scoping documented. | `admin/main.tf`: `vault_quota_rate_limit.global` — `path = ""`, `rate = 1000`, `interval = 60`, `block_interval = 60`. **No per-namespace quota**, no lease-count quota. | 🟡 (global only; the per-namespace requirement is **not** met) |
| 8 | **Infrastructure-as-code** (Terraform, layered state) | Configure Vault with Terraform from a Git repo; PR-driven; modules for app consumption; separate test cluster mirroring prod. (`vault-organizational-concepts.mdx`) | Output is Terraform HCL with `import {}` blocks; plan-equality check (`plan -detailed-exitcode` = 0) is the acceptance test; `fmt`/`validate` gates. | `Makefile`: `tf-init`, `seed`, `fmt`, `validate`, `seed-destroy`; `required_version >= 1.9`, provider `~> 4`; lock files; harness itself is a disposable Vault dev-HA cluster separate from any real cluster. **Gaps:** state is **local** (`terraform.tfstate` present in each layer dir; git-ignored by `test/.gitignore`); no remote backend/TFC workspaces; no CI pipeline; no reusable modules for app teams. | 🟡 |
| 9 | **Separation of concerns** (root / admin / namespace / seed layers) | Operators own root; Vault admins own `admin`/tenant provisioning; application owners own what lives in their namespace and consume modules through consumer repos. (`vault-organizational-concepts.mdx`) | Codified output keeps one Terraform root module/state per tier; dependencies only flow downward; provider alias per namespace. | Three directories applied in dependency order by `make seed`: `terraform/admin` (root-namespace resources: audit, `admin` namespace, operator policy, bootstrap AppRole, global quota) → `terraform/namespaces` (inside `admin`: admin policies, AppRole, tenant namespaces, identity) → `terraform/seed` (inside tenants: KV mounts, policies, AppRole, secrets). `seed-destroy` reverses. Note: the directory called `admin` operates in the **root** namespace, which is confusing relative to namespace `admin`. | ✅ (3 dirs map to 4 conceptual tiers: root, admin, tenant namespaces, seed data; `seed` stacks all tenants in one state, which production should not do) |
| 10 | **No hardcoded secrets** (`SYNTHETIC-*` convention) | Secrets are managed via the Vault UI/CLI/API and not committed to repositories; Terraform holds only configuration. (`vault-organizational-concepts.mdx`: "Application owners should then use the Vault UI, CLI, or API to manage secrets to ensure that secrets are not committed into the repository.") | Discovery policy denies `+/data/*`; codifier never emits KV values; sensitive provider fields supplied from variables; licence and tokens excluded from VCS. | All seeded KV values are `SYNTHETIC-*-REPLACE-IN-PRODUCTION` (`seed/main.tf`). `vault_token` variable is `sensitive = true`, default `null`, "Set via VAULT_TOKEN env var; do not hardcode" (`namespaces/variables.tf`). `test/.gitignore` excludes `*.hclic`, `.vault-init-state.json`, `.vault-env`, `terraform.tfstate*`, `*.tfvars`. Licence at `tmp/vault.hclic` with `guard-license` Makefile check. **Caveats:** `Makefile` defaults `VAULT_TOKEN ?= root` and passes `-var="vault_token=root"` (dev only); KV secret values land in local state (synthetic); one `database_url` embeds `SYNTHETIC-PASS`. | ✅ for harness; 🟡 for production (see gaps) |

---

## 3. Gap analysis — HVD principles not (fully) addressed by the harness

Ordered by importance for a production-grade codifier.

### 3.1 Not covered at all

| Gap | HVD reference | Why it matters for codification | Needed addition |
|---|---|---|---|
| **DR replication / performance replication** | `disaster-recovery-operations.mdx`, `performance-replication-operations.mdx` | Replication state (`sys/replication/*`) is root-only, promotes/demotes secondaries, and affects which clusters may write config. A codifier must detect it and refuse to apply config to a DR secondary (read-only) or a perf standby. Harness is a single dev-HA node with Raft (`test/vault/config.hcl`). | Two-cluster harness (primary + DR secondary); discovery of `sys/replication/status`; guard in generated code; document which objects are local (`local = true` mounts) vs replicated. |
| **HSM / auto-unseal seal config** | `installation-guide` (seal/key management), `key-lifecycle-management-administration.mdx` | Seal stanza is **server config** (`seal "pkcs11"`, `awskms`, …). Not API-managed and not in the provider, so it cannot be codified by `hashicorp/vault`; the codifier should detect seal type from `sys/seal-status` and record it as documentation / a separate infrastructure module. Dev harness uses Shamir seal in dev mode, `disable_mlock = true`, `tls_disable = true`. | Capture `sys/seal-status` + `sys/ha-status`; emit an "infrastructure assumptions" report rather than HCL. |
| **Sentinel policies (EGP/RGP)** | `sentinel-policy-management.mdx` | Enterprise guardrails (e.g. require MFA, restrict mount types, time-of-day). Resources `vault_egp_policy` / `vault_rgp_policy`. Missing from harness, so discovery/import and `file()`-based emission untested. | Add EGP + RGP fixtures at root and in one tenant; discovery for `sys/policies/egp|rgp`; import by name. |
| **MFA (TOTP/Duo/Okta/PingID + login enforcement)** | `mfa-administration.mdx` | Required for human operators in HVD. Resources `vault_identity_mfa_*`, `vault_identity_mfa_login_enforcement` (verify names/availability in 4.8.0). The `identity-service/mfa` KV secret in `seed` is just data, **not** MFA configuration. | Add TOTP method + enforcement tied to a group; discovery of `identity/mfa/*`. |
| **Human authentication (OIDC / LDAP) + external groups + group aliases** | `authentication-for-people.mdx` | HVD's central access model: one top-level auth method in `admin`, IdP groups → external groups → policies. Harness has only AppRole; 0 aliases. Highest-value codification target: OIDC `oidc_client_secret` and LDAP `bindpass` are write-only. | Add a mock OIDC (e.g. a local IdP or the `userpass`/`jwt` stand-in) and LDAP container; external groups and `vault_identity_group_alias` fixtures; test write-only handling. |
| **Per-namespace quotas / lease-count quotas** | `resource-quotas.mdx` | HVD wants protection per tenant. Harness has only the global rate limit. | Add `vault_quota_rate_limit` per tenant (`path = "admin/platform/"` etc.) and `vault_quota_lease_count`. |
| **Mount tuning and KV v2 config** | `static-secrets-management.mdx` | `max_versions`, `cas_required`, TTLs are the typical sources of drift on brownfield. Harness uses defaults, so tune/config drift detection is untested. | Fixtures with non-default tune and `vault_kv_secret_backend_v2`. |
| **PKI, dynamic secrets, Transit, secrets sync** | `pki-certificate-management.mdx`, `dynamic-secrets-management.mdx`, `transit-and-transform-management.mdx`, `secrets-sync-management.mdx` | Real clusters have them; they bring generated key material and external credentials that must be skipped or parameterised. | Add one of each to the harness; extend the "capture vs skip" matrix. |
| **Backup / snapshot automation** | `backup-and-restore-operations.mdx` | `vault_raft_snapshot_agent_config` (Enterprise). Harness has raft storage but no snapshot schedule. | Add auto-snapshot config fixture. |
| **Monitoring / telemetry** | `monitoring-and-observability.mdx` | Telemetry is server config; audit-device redundancy and request-header auditing are API-managed. | Second audit device; `vault_audit_request_header`. |

### 3.2 Partially covered — to be hardened

| Gap | Current state | Production-grade requirement |
|---|---|---|
| **Least privilege** | `operator` is `path "*"` + `sudo`; `namespace-admin` has `sudo` on `auth/*`, full `identity/*`, full `secret/*` in its namespace. | Split operator into scoped policies (sys/audit, sys/namespaces, sys/quotas, replication); remove blanket `sudo`; give `namespace-admin` no read of KV data (admins manage config, not secrets). Add policy-lint step in the codifier that flags `path "*"`, `sudo`, and `capabilities` supersets. |
| **Policy ↔ identity wiring** | Team groups have `policies = []`; tenant policies are attached only to AppRoles; 3 policies unused. | Demonstrate the HVD flow: external group (in `admin`) → policy in the tenant namespace; add tests proving read vs write separation. |
| **Audit** | Single file device. | ≥ 2 audit devices (e.g. file + syslog/socket); log shipping. |
| **State management** | Local state; one `seed` state covering three tenants; provider token via `-var`. | Remote encrypted backend (e.g. HCP Terraform workspaces, one per tier/tenant/environment); AppRole auth for the provider instead of `root`; separate state per tenant; CI plan on PR. |
| **Module layer for application teams** | None; app resources are inline in `seed/main.tf`. | Reusable "static-secrets onboarding" module (policy + group + role + KV path), consumed from per-app consumer repos, as HVD describes. |
| **Environment parity** | One dev-HA cluster. | HVD recommends a test cluster mirroring prod; harness should be parameterised to simulate dev/test/prod (and nested env namespaces below tenants). |
| **Secrets in state** | KV values (synthetic) are stored in local state; `database_url` contains a fake password. | In production, never manage KV values in Terraform; use write-only attributes where provider supports it (verify in 4.8.0), or exclude. |
| **TLS and listener security** | `tls_disable = true`, `disable_mlock = true`, dev root token `root`. | TLS everywhere, token auth via AppRole/OIDC, no static root token. The codifier must not assume any of these dev settings. |
| **Namespace depth** | One tenant level beneath `admin`. | Test at least one nested environment namespace (`admin/app-billing/prod`) to validate recursive traversal and alias generation. |

### 3.3 Suggested priority for harness extension

1. OIDC (or JWT) + external group + group alias (HVD core path, highest drift risk).
2. Per-namespace quotas + mount tuning + KV v2 config (cheap, high value).
3. Sentinel EGP/RGP and MFA (Enterprise-specific resource types).
4. Second audit device and least-privilege operator split.
5. DR secondary cluster (largest effort; changes the harness topology).
6. Remote state + modules (process, not Vault surface).

---

## 4. Summary scorecard

| Principle | Status |
|---|---|
| 1 Namespace isolation | ✅ |
| 2 Least privilege | 🟡 |
| 3 Auth per workload | ✅ (machine only) |
| 4 Secrets engine per workload | ✅ |
| 5 Identity-based access | 🟡 |
| 6 Audit logging | 🟡 |
| 7 Rate limiting | 🟡 |
| 8 Infrastructure-as-Code | 🟡 |
| 9 Separation of concerns | ✅ |
| 10 No hardcoded secrets | ✅ (harness) |

5 of 10 fully evidenced by the harness, 5 partial. None are absent, but 10 additional HVD areas (§3.1) have no coverage.
