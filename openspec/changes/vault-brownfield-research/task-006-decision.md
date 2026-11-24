# TASK-006 decision note: resolve specs open items

**Date**: 2026-11-24
**Provider**: `hashicorp/vault` `4.8.0` (darwin_arm64), Terraform 1.15.5
**Cluster**: harness, Vault Enterprise `2.2.2+ent` (`make -C test all`)
**Method**: scratch directories outside the repo, `terraform plan` with `import {}` blocks against the live harness. No `apply` was run, so nothing was written to Vault.

## 1. Import IDs (verified)

"Verified" means `terraform plan` reported the object as imported and the resource as in-place or no-op, not "non-existent remote object". Every ID below is relative to the namespace the provider is configured for.

| Resource | Import `id` | Example (harness) | Status |
|---|---|---|---|
| `vault_namespace` | leaf path relative to the provider namespace | `admin` (root provider); `platform` (provider alias `admin`) | Verified. `admin/platform` fails with HTTP 400 `"/" is not allowed in namespace names`. |
| `vault_policy` | policy name | `operator`, `platform-sre-read` | Verified (root and alias `admin/platform`) |
| `vault_auth_backend` | mount path **without** `auth/` | `approle` | Verified. `auth/approle` fails with "non-existent remote object". |
| `vault_approle_auth_backend_role` | `auth/<mount>/role/<name>` | `auth/approle/role/platform-ci` | Verified (root and alias) |
| `vault_mount` | mount path | `secret` | Verified (alias `admin/platform`) |
| `vault_kv_secret_backend_v2` | `<mount>/config` | `secret/config` | Verified |
| `vault_identity_group` | group UUID | from `identity/group/name/<name>` `.id` | Verified (alias `admin`) |
| `vault_identity_entity` | entity UUID | from `identity/entity/name/<name>` `.id` | Verified (alias `admin`) |
| `vault_audit` | audit path | `file` | Verified |
| `vault_quota_rate_limit` | quota name | `global-rate-limit` | Verified |
| `vault_identity_group_alias` | alias UUID | not in harness | From provider 4.8.0 docs, not exercised |
| `vault_identity_entity_alias` | alias UUID | not in harness | From provider 4.8.0 docs, not exercised |
| `vault_jwt_auth_backend`, `vault_ldap_auth_backend` | mount path (no `auth/`) | not in harness | Assumed to follow `vault_auth_backend`; verify in TASK-026 |
| `vault_egp_policy`, `vault_rgp_policy`, `vault_quota_lease_count` | name | none in harness | Provider source 4.8.0 uses `ImportStatePassthrough`; not exercised |
| `vault_generic_endpoint` | **import not supported** | n/a | Provider docs. See section 3. |

Corrections this forces on the authored skills:

- `codification-auth-mounts`: backend import `id` is `<path>`, not `auth/<path>`.
- `codification-namespaces`: import `id` is the leaf name (`platform`), emitted under the provider alias of the parent namespace.
- `codification-policies`: the "`<ns>/<name>`" import form never applies. Delete that branch.

## 2. Namespace-targeting default: `aliased` (ratified)

Rationale, from the experiment:

- With the resource-level `namespace = "admin/app-billing"` argument, an `import {}` block does not know the namespace. Plan reports `+ namespace = "admin/app-billing" # forces replacement`, or fails with "non-existent remote object".
- The only workaround is the environment variable `TERRAFORM_VAULT_NAMESPACE_IMPORT`. It is process-global, so one `plan` can import objects from only one namespace. The harness has five.
- With a provider alias (`namespace = "admin/platform"` on the provider block, `provider = vault.platform` on the resource), imports resolve the namespace correctly. Resources import with no replacement, which is what CAC2 requires.

Decision: `aliased` is the default and the only style that satisfies CAC2 for multi-namespace layers. `resource` stays supported (conventions section 6) for single-namespace layers. Constraint when using it: the imports must run with `TERRAFORM_VAULT_NAMESPACE_IMPORT` set, one namespace per run.


## 3. Enterprise features

| Feature | Decision | Resource | Import | Reference |
|---|---|---|---|---|
| EGP | Dedicated resource | `vault_egp_policy` | name | https://registry.terraform.io/providers/hashicorp/vault/4.8.0/docs/resources/egp_policy |
| RGP | Dedicated resource | `vault_rgp_policy` | name | https://developer.hashicorp.com/vault/docs/enterprise/sentinel |
| MFA (identity-based, current) | Dedicated resources | `vault_identity_mfa_totp`, `_duo`, `_okta`, `_pingid`, `vault_identity_mfa_login_enforcement` | UUID (method), name (enforcement) | https://developer.hashicorp.com/vault/docs/enterprise/mfa |
| MFA (legacy login MFA) | Skip and document | `vault_mfa_*` exist but are the legacy path | path | same |
| Sentinel (policy language) | Covered by EGP/RGP | n/a | n/a | https://developer.hashicorp.com/vault/docs/enterprise/sentinel |
| Replication | Skip and document | none in provider. `vault_generic_endpoint` is write-only and enabling replication is a destructive operation | n/a | https://developer.hashicorp.com/vault/docs/enterprise/replication |

None of these exist in the harness (`sys/policies/egp`, `sys/policies/rgp` return no value; `sys/replication/status` reports `dr` and `performance` as `disabled`). The skills must correctly emit nothing for them and record "none" or "disabled" in `coverage.md` and `root/README.md`.

### `vault_generic_endpoint` has no import

The provider documents "Import is not supported for this resource." CAP-001 `root/sys_config.tf` uses `vault_generic_endpoint`. These resources cannot be adopted by `import {}` and `terraform plan` will show a create. Handling:

- Do not emit an `import {}` block for `vault_generic_endpoint`.
- List every generic endpoint in `root/README.md` as "adopted by apply (idempotent write), not import", so CAC2 zero-diff is claimed only for typed resources.
- Harness impact: none, since the harness has no such endpoint.

## 4. Other findings

- The shell variable `GID` is read-only in zsh. Use another name in skill shell snippets that capture group IDs.
- `vault_audit_request_header` needs no import: "will manage existing audited headers with matching names without requiring import".
