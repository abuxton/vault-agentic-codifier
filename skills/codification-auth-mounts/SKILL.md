---
name: codification-auth-mounts
description: >
  Use when you need to read per-namespace auth_mounts.json and generate vault_auth_backend plus method-specific
  config, role and group resources for every non-builtin auth mount, with a coverage report. Run after discovery,
  then validate. USE FOR: generate auth mount terraform; auth method codification. DO NOT USE FOR: reading Vault
  (use the matching discovery-* skill), or applying the generated Terraform.
metadata:
  task: "TASK-018"
  capability: "CAP-003"
  role: "solution-architect"
  depends_on: "discovery-auth-mounts (TASK-009), codification-policies (TASK-017), vault-codifier-conventions (TASK-002, TASK-003, TASK-004), task-006-decision (TASK-006, done)"
  version: "1.0"
---

# Codification: Auth Mounts

## 1. Purpose

Generate `vault_auth_backend` and the method-specific resources (config, roles,
groups, users) for every auth mount discovered in every namespace, so that
`terraform plan` after import shows no change.

Input: `discovered_terraform/raw/<namespace>/auth_mounts.json` and per-mount
role/config payloads.
Output: one file per namespace and mount, for example
`namespaces/admin_platform/auth_approle.tf`, plus `imports.tf` per layer and
`auth-mounts/coverage.md`.

## 2. Governance

- **Ownership**: this skill owns `vault_auth_backend` and every auth role,
  config, group and user resource. The only exception is a top-level OIDC/LDAP
  mount in the `admin` namespace, which belongs to `codification-admin-config`.
- **NEVER emit `role_id` or `secret_id`** (including `secret_id_accessor`
  values). Role IDs are server-generated and are not configuration.
- **NEVER emit `vault_identity_*`**; those belong to `codification-teams`.
- **Secret guard**: `client_secret`, `oidc_client_secret`, `bindpass`,
  `secret_key` and similar become `variable "<label>_<field>" { sensitive = true }`
  with no default.
- The `token/` mount is never emitted.
- Layer: root and `admin` mounts -> `admin/`; tenant mounts -> `seed/`.
- All rules in `vault-codifier-conventions` apply (tool selection, secret guard, naming, header, layers).
- **Schema lookup (Terraform MCP).** Before emitting each resource type, call the
  Terraform MCP (`search_providers` / `get_provider_details` for `hashicorp/vault`
  `4.8.0`) to confirm argument names and the import syntax. Use the doc URL it
  returns in the file header. If it disagrees with `task-006-decision.md`, stop
  and report it (see `vault-codifier-conventions` section 1).
  If the Terraform MCP binary is not installed, fall back to
  `https://raw.githubusercontent.com/hashicorp/terraform-provider-vault/v4.8.0/website/docs/r/<resource>.html.md`
  and record the fallback in the run notes.

## 3. Prerequisites

1. `auth_mounts.json` exists per namespace (from `sys/auth`, with `accessor`,
   `config`, `options`, `local`).
2. Policy labels from `codification-policies` are available (the policy set per
   namespace) so `token_policies` can be cross-referenced.
3. `vault-codifier-conventions` read; Terraform MCP reachable for schema lookups.

## 4. Process

For each namespace, for each mount (skip `token/`):

1. **`vault_auth_backend`**: `type`, `path` (trailing `/` stripped),
   `description` when non-empty, `local` only when `true`, and a `tune {}`
   block with `default_lease_ttl`, `max_lease_ttl`, etc. Zero values are omitted.
2. **Method-specific resources** by `type`:
   - `approle` -> `vault_approle_auth_backend_role` per role.
   - `oidc` / `jwt` -> `vault_jwt_auth_backend`, `vault_jwt_auth_backend_role`;
     `oidc_client_secret` -> sensitive variable.
   - `ldap` -> `vault_ldap_auth_backend`, `vault_ldap_auth_backend_group`,
     `vault_ldap_auth_backend_user`; `bindpass` -> sensitive variable.
   - `kubernetes` -> `vault_kubernetes_auth_backend_config`,
     `vault_kubernetes_auth_backend_role`.
   - `aws` -> `vault_aws_auth_backend_client`, `vault_aws_auth_backend_role`;
     `secret_key` -> sensitive variable.
   - `cert` -> `vault_cert_auth_backend_role`.
   - Unknown type -> `vault_auth_backend` plus a documented
     `vault_generic_endpoint` fallback; list it in `coverage.md`.
3. **Policy cross-reference**: for each `token_policies` entry that exists as a
   `vault_policy` in the same namespace, emit
   `vault_policy.<label>.name`; otherwise emit the literal string and add a
   warning to `coverage.md`.
4. **Role/backend linkage**: `backend = vault_auth_backend.<label>.path`.
5. **Import blocks**: backend `id = "<path>"` (no `auth/` prefix; verified in TASK-006); role
   `id = "auth/<path>/role/<name>"`. IDs are always relative to the provider's namespace (alias); never prefix the namespace.
6. **Coverage**: `auth-mounts/coverage.md` lists every mount with resource type,
   fallback or "unsupported", and any warnings.
7. Provenance header (`Capability: auth-mounts`), fmt, validate.

## 8. Stop conditions

- A payload contains a credential in a field that would be emitted: stop and
  report the field name, not the value.
- A role references a mount not in `auth_mounts.json`.
- Label collision within a layer.
- Mount type unknown **and** no fallback payload is available to document.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Example HCL: approle in `admin/platform`](references/example-hcl-approle-in-admin-platform.md)
- [Coding standards applied](references/coding-standards-applied.md)
- [Acceptance criteria (harness)](references/acceptance-criteria-harness.md)
- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
