# Specs: vault-brownfield-research

This artifact defines seven measurable capability specs for the `vault-brownfield-research` change. Each spec describes what the **codifier agent** receives (live Vault API responses, optional existing Terraform state), what it produces (Terraform HCL using the `hashicorp/vault` provider), and acceptance criteria that can be checked against the synthetic test harness in [`test/`](../../../test/).

## Conventions (apply to all specs)

### Documentation source

All Vault documentation is sourced from the upstream repository `git@github.com:hashicorp/web-unified-docs.git`. Specs and generated artifacts cite documentation as repository-relative paths inside that repository, never as local filesystem paths. Paths already used by the harness:

- `content/validated-designs/docs/docs/vault/administration-guide/authentication-for-people.mdx`
- `content/validated-designs/docs/docs/vault/administration-guide/static-secrets-management.mdx`

Vault API and provider behaviour is cited from the `content/vault/` tree of the same repository.

### Provider and tooling baseline

- `hashicorp/vault` Terraform provider `>= 4.0` (the harness lock files pin `4.8.0`).
- Terraform `>= 1.9` (the harness Makefile requires it); import blocks (`import {}`) are used for adoption.
- Vault CLI `>= 1.17`; Vault Enterprise reachable via `VAULT_ADDR` and `VAULT_TOKEN`.
- The codifier is **read-only** against Vault. It issues only `GET`/`LIST` requests (and `sys/internal/ui/*` reads). No spec may cause a write to the cluster.

### Synthetic test harness (the oracle)

The harness at `test/` runs Vault Enterprise in dev-ha mode at `http://127.0.0.1:8200` with root token `root`. It is built by `make -C test all` (`up` then `seed`) from three Terraform layers: `test/terraform/admin`, `test/terraform/namespaces`, `test/terraform/seed`. Its known contents are the ground truth for acceptance criteria:

| Namespace | Auth mounts | Auth roles | KV mounts | ACL policies (non-builtin) | Identity |
|---|---|---|---|---|---|
| root (`""`) | `approle/` | `terraform-admin` | none created by the harness (dev mode may preload `secret/`) | `operator` | none created |
| `admin` | `approle/` | `namespace-provisioner` | none | `admin`, `namespace-admin` | 6 entities `synthetic-user-<tenant>-<team>`, 3 tenant-admin groups `vault-<tenant>-admin`, 6 team groups `vault-<tenant>-<team>` |
| `admin/platform` | `approle/` | `platform-ci` | `secret/` (KV v2) | `platform-sre-read`, `platform-devops-write` | none |
| `admin/app-billing` | `approle/` | `billing-service` | `secret/` (KV v2) | `billing-developers-read`, `billing-owners-write` | none |
| `admin/app-identity` | `approle/` | `identity-service` | `secret/` (KV v2) | `identity-developers-read`, `identity-owners-write` | none |

Other fixed facts:

- Audit device: one `file` device with `file_path = /vault/logs/audit.log` in the root namespace.
- Rate-limit quota: `global-rate-limit`, `path = ""`, `rate = 1000`, `interval = 60`, `block_interval = 60`.
- Namespaces: `admin` (no custom metadata), and children `platform`, `app-billing`, `app-identity`, each with `custom_metadata.description` set.
- Tenant teams: `platform` has `sre`, `devops`; `app-billing` and `app-identity` each have `developers`, `owners`.
- No OIDC/LDAP auth method, no group aliases and no entity aliases exist in the harness. Specs therefore require correct **empty-set** behaviour (no empty resources, no failure).
- Builtin objects (`token/` auth mount, `sys/`, `identity/`, `cubbyhole/` mounts, `default` and `root` policies) are not codified.

### Resource ownership (no duplicates)

Several specs touch the same Vault objects. To keep generated output free of duplicate resources, each resource type has exactly one owning spec; other specs reference the owner's resources by address and never re-declare them.

| Resource type | Owner |
|---|---|
| `vault_namespace` | `namespaces` |
| `vault_policy` | `policies` |
| `vault_auth_backend` and auth backend roles/config | `auth-mounts` (except top-level OIDC/LDAP in the admin namespace, owned by `admin-config`) |
| `vault_mount` and engine config | `secrets-engines` |
| `vault_identity_group`, `vault_identity_group_alias`, `vault_identity_entity`, `vault_identity_entity_alias` | `teams` |
| `vault_audit`, `vault_quota_*`, system-level `vault_generic_endpoint` | `root-config` |

`admin-config` owns the *composition* of the admin layer (a module/directory that wires the above together for the admin namespace) and the top-level human auth method; `root-config` owns the root-namespace composition.

### Common acceptance criteria (CAC)

Every spec below inherits the following; they are not repeated per spec.

- **CAC1 (valid HCL)**: `terraform fmt -check -recursive` and `terraform validate` succeed on the generated directory (same checks as `make -C test fmt validate`).
- **CAC2 (zero-diff)**: after importing (using generated `import {}` blocks) against the harness, `terraform plan -detailed-exitcode` exits `0` for the resources produced by the spec. Attributes that Vault does not return (for example secret values) are handled with `lifecycle { ignore_changes = [...] }` and listed in the run report.
- **CAC3 (no secrets)**: no generated file contains the root token, AppRole `secret_id` values, KV secret data, or any value marked sensitive by Vault. Sensitive provider arguments are emitted as `variable` references.
- **CAC4 (read-only)**: the Vault audit log for the run contains no request with an operation other than `read` or `list` attributable to the codifier token.
- **CAC5 (idempotent)**: running the codifier twice against an unchanged cluster yields byte-identical output.
- **CAC6 (naming)**: resource labels are valid Terraform identifiers, unique per directory, deterministic (derived from namespace + path + name, `/` and `-` normalised to `_`), and stable across runs.
- **CAC7 (provenance)**: every generated file begins with a header comment naming the owning capability and the documentation path in `git@github.com:hashicorp/web-unified-docs.git` that justified the mapping.

### Namespace targeting in generated HCL

Resources in non-root namespaces are emitted using either an aliased provider (matching the harness pattern, `provider = vault.<alias>`) or the resource-level `namespace` argument supported by provider 4.x. One style is chosen per run and used consistently. Namespace paths are always full paths relative to root (for example `admin/platform`).

---

## CAP-001: Root namespace configuration

**Capability**: `root-config`
**Status**: Proposed
**Description**: Capture and codify configuration that lives in (or can only be managed from) the root namespace: audit devices, system backend tuning, quotas, cluster seal configuration, license state, replication configuration, and UI settings. Items that Vault does not let Terraform manage (seal stanzas, license files, listener and storage config) are documented rather than silently dropped.
**Inputs**:
- `GET /v1/sys/audit` (audit devices and options)
- `GET /v1/sys/mounts` and `GET /v1/sys/mounts/<path>/tune` for system-level tuning of root mounts (default and max lease TTLs)
- `LIST /v1/sys/quotas/rate-limit` and `GET /v1/sys/quotas/rate-limit/<name>`; `GET /v1/sys/quotas/config`
- `GET /v1/sys/seal-status`, `GET /v1/sys/health`, `GET /v1/sys/host-info` (seal type, HA/raft state)
- `GET /v1/sys/license/status` (license ID, expiry, features; no license text)
- `GET /v1/sys/replication/status` (DR/performance mode and state)
- `GET /v1/sys/config/ui/headers` and `GET /v1/sys/internal/ui/feature-flags`
- Existing Terraform state or `.tf` files in the target directory, if present
**Outputs**:
- `root/audit.tf` — `vault_audit`
- `root/quotas.tf` — `vault_quota_rate_limit`, `vault_quota_lease_count` (when present)
- `root/sys_config.tf` — `vault_generic_endpoint` for system endpoints without a dedicated resource (for example UI headers), with `disable_read = false` and `ignore_changes = [data_json]` only where Vault redacts output
- `root/replication.tf` — `vault_generic_endpoint` for replication endpoints when replication is enabled; otherwise a documented no-op
- `root/README.md` — a "not managed by Terraform" table listing seal type, license metadata and replication state with the reason each cannot be codified (configured via server config file or license auto-load)
- `root/imports.tf` — `import {}` blocks for every resource above
**Acceptance Criteria**:
- AC1: Against the harness, the output contains exactly one `vault_audit` resource with `type = "file"` and `options = { file_path = "/vault/logs/audit.log" }`, and its import block uses the audit path `file`.
- AC2: The output contains exactly one `vault_quota_rate_limit` named `global-rate-limit` with `path = ""`, `rate = 1000`, `interval = 60`, `block_interval = 60`.
- AC3: The output contains no `vault_policy`, `vault_auth_backend`, `vault_mount` or `vault_namespace` resources (ownership rules); `operator` appears only in the `policies` spec output.
- AC4: `root/README.md` records the seal type reported by `sys/seal-status`, the license ID/expiry from `sys/license/status` (never the license text), and the replication mode from `sys/replication/status`. For the harness, replication is reported as disabled and no `root/replication.tf` resources are emitted.
- AC5: Audit device options that Vault returns masked or omits (for example `hmac_accessor` flags) are not fabricated; CAC2 passes for `vault_audit`.
- AC6: If `sys/audit` returns an empty object, the codifier emits no `vault_audit` resource and records "no audit devices" in the README (verify by running against a fresh `make -C test up` without `seed`).
- AC7: If the token lacks read access to a `sys/` endpoint, the codifier records the endpoint and HTTP status in the run report, continues with the remaining inputs, and exits non-zero only if the audit-device read itself fails.

---

## CAP-002: Admin / org namespace configuration

**Capability**: `admin-config`
**Status**: Proposed
**Description**: Capture and codify the admin (org-level) namespace per the HashiCorp Validated Design layering: the namespace that holds operator-facing policies, the identity store used by platform operators, and the top-level OIDC or LDAP auth method for human operators. This spec defines the composition and the human-authentication method; the individual policy, namespace and identity resources are produced by their owning specs and wired in here.
**Inputs**:
- `GET /v1/sys/namespaces/admin` (existence, `id`, `custom_metadata`) with header `X-Vault-Namespace` unset
- With `X-Vault-Namespace: admin`: `GET /v1/sys/auth`, `GET /v1/auth/<mount>/config` and `LIST /v1/auth/<mount>/role` (or the method-specific role/group endpoints) for `oidc`, `jwt`, `ldap` and `approle` mounts
- With `X-Vault-Namespace: admin`: `LIST /v1/sys/policies/acl`, `LIST /v1/identity/group/name`, `LIST /v1/identity/entity/name`, `LIST /v1/identity/group-alias/id`
- Existing Terraform state, if present
**Outputs**:
- `admin/main.tf` — provider alias for the `admin` namespace and a module/composition that references resources owned by `namespaces`, `policies`, `auth-mounts` and `teams`
- `admin/human_auth.tf` — when an `oidc`/`jwt` mount exists: `vault_jwt_auth_backend` and `vault_jwt_auth_backend_role`; when an `ldap` mount exists: `vault_ldap_auth_backend` and `vault_ldap_auth_backend_group`. `bindpass`, `client_secret` and `oidc_client_secret` are emitted as sensitive variables with no default
- `admin/variables.tf`, `admin/outputs.tf`
- `admin/README.md` — documents which policies are the operator policies (names matching `admin`, `operator`, `namespace-admin`) and which identity groups grant them
- `admin/imports.tf`
**Acceptance Criteria**:
- AC1: The admin directory declares a provider alias for namespace `admin` and every resource under it resolves to namespace `admin` (verified by `terraform plan` showing no replacement and by CAC2).
- AC2: The README lists operator policies `admin` and `namespace-admin` (admin namespace) and states that root-namespace `operator` belongs to `root-config`/`policies` scope, with the identity groups `vault-platform-admin`, `vault-app-billing-admin`, `vault-app-identity-admin` shown as holders of `namespace-admin`.
- AC3: Against the harness (which has no OIDC/LDAP mount), `admin/human_auth.tf` is not created and the README states "no human auth method detected in `admin`". The run still exits `0`.
- AC4: Against a harness variant with an `oidc` mount enabled in `admin` (enabled out of band with `vault auth enable -namespace=admin oidc`), the output contains one `vault_jwt_auth_backend` with `type = "oidc"` and the matching `oidc_discovery_url`, and no client secret literal appears in any generated file (CAC3).
- AC5: The `approle/` mount and `namespace-provisioner` role in `admin` are emitted by `auth-mounts` and only referenced from `admin/main.tf`; a grep for `resource "vault_auth_backend"` in `admin/` returns zero matches (ownership rules).
- AC6: The admin namespace's `custom_metadata` is empty in the harness; the output for the `admin` `vault_namespace` has no `custom_metadata` block.

---

## CAP-003: Auth method mounts

**Capability**: `auth-mounts`
**Status**: Proposed
**Description**: Enumerate every auth method mount in every discovered namespace, including mount options and tuning, method configuration, and the roles and groups defined on each method, and emit the corresponding Terraform resources. Method-specific resources are used where the provider has them; otherwise `vault_generic_endpoint` is used and the gap is noted.
**Inputs**:
- The namespace list produced by `namespaces` (CAP-005), or discovered by recursive `LIST /v1/sys/namespaces`
- For each namespace (header `X-Vault-Namespace`): `GET /v1/sys/auth` (type, description, `config`, `options`, `accessor`, `local`, `seal_wrap`)
- `GET /v1/sys/auth/<path>/tune`
- Method-specific: `LIST /v1/auth/<path>/role`, `GET /v1/auth/<path>/role/<name>`, `GET /v1/auth/<path>/config`, `LIST /v1/auth/<path>/groups` (ldap/okta/github), `LIST /v1/auth/<path>/users`
- Existing Terraform state, if present
**Outputs**:
- One file per namespace and mount, for example `namespaces/admin_platform/auth_approle.tf`
- `vault_auth_backend` (with `type`, `path`, `description`, `local`, `tune { ... }`) for every non-builtin mount
- Role and configuration resources by type, for example:
  - `approle` → `vault_approle_auth_backend_role`
  - `jwt`/`oidc` → `vault_jwt_auth_backend`, `vault_jwt_auth_backend_role`
  - `ldap` → `vault_ldap_auth_backend`, `vault_ldap_auth_backend_group`, `vault_ldap_auth_backend_user`
  - `kubernetes` → `vault_kubernetes_auth_backend_config`, `vault_kubernetes_auth_backend_role`
  - `aws` → `vault_aws_auth_backend_client`, `vault_aws_auth_backend_role`
  - `cert` → `vault_cert_auth_backend_role`
  - `userpass` → `vault_generic_endpoint` (credentials never emitted)
- `auth-mounts/coverage.md` — table of every discovered mount with the resource type used, or `vault_generic_endpoint` fallback, or "unsupported"
- `imports.tf` — one `import {}` block per resource (`id` forms such as `auth/approle` for mounts and `auth/approle/role/platform-ci` for AppRole roles; namespace-qualified IDs follow the provider's `<namespace>/` import convention)
**Acceptance Criteria**:
- AC1: Against the harness, exactly five `vault_auth_backend` resources are produced, each `type = "approle"`, `path = "approle"`, one per namespace: root, `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`. The `token/` mount is not emitted.
- AC2: Exactly five `vault_approle_auth_backend_role` resources are produced with these role names and namespaces: `terraform-admin` (root), `namespace-provisioner` (`admin`), `platform-ci` (`admin/platform`), `billing-service` (`admin/app-billing`), `identity-service` (`admin/app-identity`).
- AC3: Each emitted AppRole role reproduces `token_ttl = 3600`, `token_max_ttl = 14400` and `secret_id_num_uses = 1`. `secret_id_ttl` is `terraform-admin = 900`, `namespace-provisioner = 900`, `platform-ci = 1800`, `billing-service = 900`, `identity-service = 900`. Values are integers in seconds.
- AC4: `token_policies` on each role is emitted as a list of policy names that are cross-referenced to a `vault_policy` resource owned by `policies` (for example `vault_policy.admin_namespace_admin.name`) where one exists in the same namespace; if the policy is not in the set of codified policies the literal string is kept and a warning is written to the run report.
- AC5: No `role_id` or `secret_id` value appears in any generated file (CAC3). `vault_approle_auth_backend_role` emits `role_id` only if it was explicitly set (verify: harness roles have auto-generated IDs, so the attribute is omitted).
- AC6: `coverage.md` lists all five harness mounts with `resource type = vault_auth_backend` and every role with `vault_approle_auth_backend_role`; no entry is marked "unsupported".
- AC7: When a mount type with no dedicated provider resource is present (verify by enabling `userpass` in `admin/app-billing`), the codifier emits `vault_auth_backend` plus a documented `vault_generic_endpoint` fallback and lists it in `coverage.md`.
- AC8: Each namespaced resource resolves to the correct namespace; destroying and re-importing in a scratch state yields zero diff (CAC2).

---

## CAP-004: Secrets engine mounts

**Capability**: `secrets-engines`
**Status**: Proposed
**Description**: Enumerate every secrets engine mount across all namespaces (KV v1/v2, PKI, database, AWS, Azure, GCP, Transit, SSH, TOTP, and others), capture mount-level options and tuning, and capture engine-specific configuration that Vault returns on read. Secret **data** (KV contents, credentials, private keys) is never read or emitted.
**Inputs**:
- Namespace list from `namespaces` (CAP-005)
- Per namespace: `GET /v1/sys/mounts` (type, description, `config`, `options`, `local`, `seal_wrap`, `external_entropy_access`, `plugin_version`)
- `GET /v1/sys/mounts/<path>/tune`
- Engine configuration endpoints, read-only:
  - KV v2: `GET /v1/<mount>/config` (`max_versions`, `cas_required`, `delete_version_after`)
  - PKI: `GET /v1/<mount>/config/urls`, `GET /v1/<mount>/config/crl`, `LIST /v1/<mount>/roles`
  - Database: `GET /v1/<mount>/config/<name>` (connection details minus password), `LIST /v1/<mount>/roles`
  - AWS/Azure/GCP: `GET /v1/<mount>/config/root` (non-secret fields only), `LIST /v1/<mount>/roles`
  - Transit: `LIST /v1/<mount>/keys` and `GET /v1/<mount>/keys/<name>` (metadata only; no key material)
- Existing Terraform state, if present
**Outputs**:
- `vault_mount` (`path`, `type`, `description`, `options`, `default_lease_ttl_seconds`, `max_lease_ttl_seconds`, `seal_wrap`, `local`) for each non-builtin mount; for KV v2 `options = { version = "2" }` is retained
- Engine-specific resources where applicable: `vault_kv_secret_backend_v2`, `vault_pki_secret_backend_config_urls`, `vault_pki_secret_backend_role`, `vault_database_secret_backend_connection`, `vault_database_secret_backend_role`, `vault_aws_secret_backend`, `vault_aws_secret_backend_role`, `vault_transit_secret_backend_key`, `vault_ssh_secret_backend_role`, `vault_azure_secret_backend`, `vault_gcp_secret_backend`
- Never emitted: `vault_kv_secret_v2`, `vault_kv_secret`, `vault_generic_secret`, and `vault_database_secret_backend_connection` passwords
- `secrets-engines/coverage.md` — mount inventory with resource type used or fallback
- `imports.tf` — import blocks (for example `id = "secret"` for a mount, namespace-prefixed per provider convention)
**Acceptance Criteria**:
- AC1: Against the harness, exactly three `vault_mount` resources are produced for non-root namespaces: path `secret`, `type = "kv"`, `options = { version = "2" }` in each of `admin/platform`, `admin/app-billing`, `admin/app-identity`, with descriptions "Platform KV v2 secrets engine", "Billing app KV v2 secrets engine", "Identity service KV v2 secrets engine" respectively.
- AC2: No `vault_mount` is produced for the `admin` namespace (the harness defines none). If the root namespace has a preloaded `secret/` mount (Vault dev mode default), it is emitted once with a note in `coverage.md`; if absent, no root mount is emitted.
- AC3: The output contains zero `vault_kv_secret_v2`, `vault_kv_secret` or `vault_generic_secret` resources and no file contains the strings `SYNTHETIC-` (the harness marker for secret values). A `grep -r SYNTHETIC` over the output returns no matches (CAC3).
- AC4: Built-in mounts `sys/`, `identity/` and `cubbyhole/` are never emitted.
- AC5: Where Vault returns `default_lease_ttl`/`max_lease_ttl` of `0`, the attributes are omitted rather than emitted as `0`, so CAC2 passes.
- AC6: For a mount type with engine configuration (verify by enabling `database` or `pki` in `admin/platform` using a scratch fixture), the codifier emits the engine-specific resource and does not fail; secrets-valued fields are replaced with sensitive variables with no default.
- AC7: Mount `plugin_version` is emitted only when pinned in Vault; unversioned mounts omit it.
- AC8: Mounts are emitted in dependency-safe order: `vault_mount` before engine-specific resources via implicit references (for example `mount = vault_mount.admin_platform_secret.path`), and CAC1 passes.

---

## CAP-005: Namespace hierarchy

**Capability**: `namespaces`
**Status**: Proposed
**Description**: Discover the full namespace tree rooted at the admin namespace, map parent–child relationships, and produce `vault_namespace` resources that preserve the hierarchy (admin → tenant → application/environment), custom metadata, and creation order. This spec is also the namespace source of truth for all other specs: they consume its ordered list.
**Inputs**:
- Recursive traversal: `LIST /v1/sys/namespaces` at root, then with `X-Vault-Namespace: <ns>` for each discovered child, until no children remain
- `GET /v1/sys/namespaces/<path>` for `id`, `path`, `custom_metadata`
- Existing Terraform state, if present
**Outputs**:
- `namespaces/namespaces.tf` — `vault_namespace` resources; the root-level `admin` namespace has no `namespace` argument; children use the aliased provider (`provider = vault.admin`; resource-level `namespace` only under `--namespace-style resource`) and `path = "<child>"` so parentage is expressed through the provider rather than string concatenation
- `namespaces/hierarchy.md` — Mermaid diagram of the tree plus a table with columns: full path, parent, namespace ID, custom metadata, depth
- `namespaces/namespaces.auto.tfvars.json` or equivalent data structure (a `locals` map), consumed by other specs as the ordered namespace list
- `imports.tf` — one `import {}` per namespace
**Acceptance Criteria**:
- AC1: Against the harness, the discovered set is exactly `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity` (4 namespaces, maximum depth 2), and `hierarchy.md` shows `admin` as parent of the three tenants.
- AC2: Four `vault_namespace` resources are produced. The three tenant resources carry `custom_metadata = { description = "<text>" }` with these descriptions: `platform` → "Platform engineering team namespace", `app-billing` → "Billing application team namespace", `app-identity` → "Identity service team namespace". `admin` has no `custom_metadata`.
- AC3: The ordered list places every parent before its children (`admin` precedes `admin/*`), and `terraform validate` reports no dependency cycles (CAC1).
- AC4: Each child resource reaches its parent through the parent's provider alias (`provider = vault.admin`, per the TASK-006 default) and not by a hard-coded string; a grep for `"admin/` literals inside `vault_namespace` blocks returns zero matches.
- AC5: Namespaces nested deeper than two levels are discovered (verify by creating `admin/platform/sre-team` in a scratch run); the codifier emits it with `depth = 3` in `hierarchy.md` and in correct order.
- AC6: The codifier does not emit a `vault_namespace` for the root namespace; the harness root `""` never appears in output.
- AC7: Namespace IDs reported in `hierarchy.md` match `vault namespace list -detailed` output for the harness.

---

## CAP-006: ACL policies

**Capability**: `policies`
**Status**: Proposed
**Description**: Enumerate all ACL policies in every namespace, preserve policy documents faithfully, and correlate each policy to the auth roles, identity groups and identity entities that reference it. Correlation is emitted both as Terraform references and as a human-readable matrix.
**Inputs**:
- Namespace list from `namespaces` (CAP-005), plus the root namespace
- Per namespace: `LIST /v1/sys/policies/acl`, `GET /v1/sys/policies/acl/<name>` (the `policy` string)
- Per namespace correlation data:
  - auth roles from `auth-mounts` inputs (`token_policies`/`policies` on each role)
  - `GET /v1/identity/group/name/<name>` (`policies`)
  - `GET /v1/identity/entity/name/<name>` (`policies`)
- Optional (Enterprise): `LIST /v1/sys/policies/egp`, `LIST /v1/sys/policies/rgp` — recorded in `coverage.md`; emitted as `vault_egp_policy` and `vault_rgp_policy`
- Existing Terraform state, if present
**Outputs**:
- `vault_policy` for every ACL policy except `default` and `root`
- Policy documents stored as separate `.hcl` files under `policies/<namespace>/<name>.hcl` and loaded with `file("${path.module}/policies/<namespace>/<name>.hcl")` for policies longer than 10 lines; short policies use a heredoc. The document text is byte-identical to what Vault returns (after Vault's own normalisation)
- `policies/correlation.md` — a matrix: policy × (auth mount/role, identity group, identity entity), per namespace
- `policies/correlation.json` — the same matrix, machine readable; consumed by `teams`
- `imports.tf` — `import {}` blocks with `id = "<name>"`
**Acceptance Criteria**:
- AC1: Against the harness, `vault_policy` resources are produced with exactly these names per namespace: root → `operator`; `admin` → `admin`, `namespace-admin`; `admin/platform` → `platform-sre-read`, `platform-devops-write`; `admin/app-billing` → `billing-developers-read`, `billing-owners-write`; `admin/app-identity` → `identity-developers-read`, `identity-owners-write` (9 policies total). `default` and `root` are not emitted.
- AC2: For each emitted policy, a round trip is lossless: the policy document in the generated output compared with `vault policy read -namespace=<ns> <name>` is identical after whitespace normalisation of trailing newlines.
- AC3: `operator` is referenced by `terraform-admin` (root) and `namespace-admin` by `namespace-provisioner` (`admin`); both references appear in `correlation.md`. `platform-devops-write` is referenced by role `platform-ci`; `billing-developers-read` by `billing-service`; `identity-developers-read` by `identity-service`.
- AC4: `namespace-admin` is correlated with the three identity groups `vault-platform-admin`, `vault-app-billing-admin`, `vault-app-identity-admin` in the `admin` namespace.
- AC5: Policies referenced by a role or group but not present in the namespace (for example a role in `admin/platform` naming a policy that exists only in `admin`) are flagged "dangling" in `correlation.md`; no `vault_policy` is fabricated for them.
- AC6: Policy files are namespace-scoped: two policies with the same name in different namespaces do not collide in file paths or Terraform labels (CAC6). Verify by creating `default-readonly` in two namespaces in a scratch run.
- AC7: Any `path` stanza in an emitted policy that uses a namespace-relative path is preserved without rewriting (for example `secret/data/platform/sre/*` remains unchanged).
- AC8: For the harness, no EGP/RGP policies exist; `coverage.md` records "none" and no `vault_egp_policy`/`vault_rgp_policy` resources are emitted.

---

## CAP-007: Teams — organisational units mapped to Vault identity

**Capability**: `teams`
**Status**: Proposed
**Description**: Map organisational units (platform teams, application owners, service consumers) to Vault identity constructs. For each team the codifier identifies the identity group, its member entities, any group aliases tying it to an external auth method, and the auth roles and policies that grant its access. The output is both Terraform resources and a team-to-access matrix that lets reviewers see who can do what.
**Inputs**:
- Per namespace (header `X-Vault-Namespace`): `LIST /v1/identity/group/name`, `GET /v1/identity/group/name/<name>` (`type`, `policies`, `member_entity_ids`, `member_group_ids`, `metadata`)
- `LIST /v1/identity/entity/name`, `GET /v1/identity/entity/name/<name>` (`policies`, `metadata`, `disabled`, `aliases`)
- `LIST /v1/identity/group-alias/id`, `GET /v1/identity/group-alias/id/<id>` (`mount_accessor`, `name`, `canonical_id`)
- `LIST /v1/identity/entity-alias/id`, `GET /v1/identity/entity-alias/id/<id>`
- `GET /v1/sys/auth` for accessor → mount path resolution
- `policies/correlation.json` from `policies` (CAP-006) and auth role data from `auth-mounts` (CAP-003)
- Existing Terraform state, if present
**Outputs**:
- `vault_identity_group` (`name`, `type`, `policies`, `metadata`, `member_entity_ids`, `member_group_ids`); external groups carry no `member_entity_ids`
- `vault_identity_entity` (`name`, `policies`, `metadata`, `disabled`)
- `vault_identity_group_alias` (`name`, `mount_accessor`, `canonical_id`) with `mount_accessor` expressed as a reference to the owning `vault_auth_backend.<label>.accessor`, never as a literal accessor string
- `vault_identity_entity_alias` (`name`, `mount_accessor`, `canonical_id`) with the same accessor-by-reference rule
- Where the provider supports it, `vault_identity_group_policies`, `vault_identity_group_member_entity_ids` and `vault_identity_group_member_group_ids` are used only if the source group in Vault is not managed by a single `vault_identity_group` (exclusive vs. non-exclusive pattern; the codifier chooses one and records the choice in the README)
- `teams/teams.md` — a team matrix: team (derived from group name and metadata `tenant`/`team`) → namespace → group → member entities → auth roles → policies
- `teams/teams.json` — machine-readable form of the matrix
- `imports.tf` — import blocks (`id = <group/entity id>`)
**Acceptance Criteria**:
- AC1: Against the harness, nine `vault_identity_group` resources are produced, all in namespace `admin`, all `type = "internal"`: three tenant admin groups `vault-platform-admin`, `vault-app-billing-admin`, `vault-app-identity-admin` (each with `policies = ["namespace-admin"]` and `metadata = { tenant = "<tenant>" }`), and six team groups `vault-platform-sre`, `vault-platform-devops`, `vault-app-billing-developers`, `vault-app-billing-owners`, `vault-app-identity-developers`, `vault-app-identity-owners` (each with `policies = []`, `metadata = { tenant = "<tenant>", team = "<team>" }`).
- AC2: Six `vault_identity_entity` resources are produced, named `synthetic-user-<tenant>-<team>` for each tenant/team pair, each with `metadata = { tenant, team, type = "synthetic" }`, and each is referenced exactly once from the `member_entity_ids` of the matching team group, using resource references (for example `vault_identity_entity.admin_synthetic_user_platform_sre.id`) and not literal IDs.
- AC3: The harness has no group or entity aliases; no `vault_identity_group_alias` or `vault_identity_entity_alias` is emitted, no empty file is created, and `teams.md` states "no aliases found" for `admin`.
- AC4: Against a variant where an `oidc` mount in `admin` and an external group with a group alias are created out of band, the codifier emits one `vault_identity_group` with `type = "external"` and one `vault_identity_group_alias` whose `mount_accessor` is a reference to the auth backend resource from `auth-mounts`, and `terraform plan` shows no change (CAC2).
- AC5: `teams.md` lists the following team-to-tenant relationships: `platform` → `sre`, `devops`; `app-billing` → `developers`, `owners`; `app-identity` → `developers`, `owners`; and shows, for each team, the namespace of the tenant (`admin/platform`, `admin/app-billing`, `admin/app-identity`) as the namespace the team's access applies to, derived from the `tenant` metadata key.
- AC6: Where a team group has `policies = []` in `admin`, `teams.md` states that access is "applied at the namespace layer" and lists the policies in the tenant namespace whose names match the team (for example `platform-sre-read` for `vault-platform-sre`) as **inferred** links, clearly marked as inferred versus Vault-recorded.
- AC7: Entity and group IDs never appear as literals in generated resource arguments (CAC2 relies on imports; `member_entity_ids` is always a reference). A grep for UUID patterns in `*.tf` files other than `imports.tf` returns zero matches.
- AC8: Groups in other namespaces (none in the harness) are discovered and emitted under the correct provider alias; verify by creating a group in `admin/platform` in a scratch run.

---

## Traceability

| Spec | Proposal capability | Harness layer that creates the fixtures | Primary provider resources |
|---|---|---|---|
| CAP-001 `root-config` | `root-config` | `test/terraform/admin` (audit, quota) | `vault_audit`, `vault_quota_rate_limit`, `vault_generic_endpoint` |
| CAP-002 `admin-config` | `admin-config` | `test/terraform/admin`, `test/terraform/namespaces` | composition; `vault_jwt_auth_backend`, `vault_ldap_auth_backend` when present |
| CAP-003 `auth-mounts` | `auth-mounts` | all three layers (AppRole mounts and roles) | `vault_auth_backend`, `vault_approle_auth_backend_role` |
| CAP-004 `secrets-engines` | `secrets-engines` | `test/terraform/seed` (KV v2 mounts) | `vault_mount`, `vault_kv_secret_backend_v2` |
| CAP-005 `namespaces` | `namespaces` | `test/terraform/admin`, `test/terraform/namespaces` | `vault_namespace` |
| CAP-006 `policies` | `policies` | all three layers | `vault_policy` |
| CAP-007 `teams` | `teams` | `test/terraform/namespaces` (groups, entities) | `vault_identity_group`, `vault_identity_entity`, `vault_identity_group_alias`, `vault_identity_entity_alias` |

## Dependency order

The codifier runs specs in this order because later specs consume earlier outputs: `namespaces` → `root-config` → `policies` → `auth-mounts` → `secrets-engines` → `teams` → `admin-config` (composition last).

## Open items (resolved by TASK-006)

Full evidence and tables: [`task-006-decision.md`](task-006-decision.md).

- **Import IDs: resolved.** IDs are relative to the provider namespace and never namespace-prefixed. `vault_auth_backend` uses the bare mount path (`approle`, not `auth/approle`); `vault_namespace` uses the leaf name (`platform`, not `admin/platform`); AppRole roles use `auth/<mount>/role/<name>`; identity objects use UUIDs. `vault_generic_endpoint` does not support import.
- **Namespace-targeting default: `aliased`.** Resource-level `namespace` makes `import {}` plan a replacement or fail, so only aliased providers satisfy CAC2 across several namespaces.
- **Enterprise features: resolved.** EGP, RGP and identity MFA get dedicated resources; replication and legacy MFA are documented, not codified. None exist in the harness.
