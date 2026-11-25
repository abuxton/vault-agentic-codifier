---
name: codification-admin-config
description: >
  Use when you need to generate the admin-layer composition for the admin namespace: provider alias, references to
  resources owned by other capabilities, optional human auth method (OIDC/JWT/LDAP), variables, outputs, README
  and imports. Run after discovery, then validate. USE FOR: generate admin config terraform; admin namespace
  composition. DO NOT USE FOR: reading Vault (use the matching discovery-* skill), or applying the generated
  Terraform.
metadata:
  task: "TASK-021"
  capability: "CAP-002"
  role: "solution-architect"
  depends_on: "discovery-admin-config (TASK-013), codification-namespaces (TASK-015), codification-policies (TASK-017), codification-auth-mounts (TASK-018), codification-teams (TASK-020), vault-codifier-conventions (TASK-002, TASK-003, TASK-004)"
  version: "1.0"
---

# Codification: Admin Config

## 1. Purpose

Compose the `admin` layer per the HashiCorp Validated Design: a provider alias
for namespace `admin`, references to the namespace, policy, auth-mount and team
resources owned by other capabilities, and - only when one exists - the
top-level human auth method (OIDC/JWT or LDAP).

Input: `discovered_terraform/raw/admin_config.json` (from TASK-013).
Output: `discovered_terraform/terraform/admin/` - `main.tf`, `human_auth.tf`
(conditional), `variables.tf`, `outputs.tf`, `README.md`, `imports.tf`.

## 2. Governance

- **This skill references; it does not re-declare.** Namespaces, policies, auth
  mounts/roles and identity objects are emitted by their owning skills. Here
  they appear only as references, locals, outputs or data sources.
- Verification: `grep -rn 'resource "vault_auth_backend"' discovered_terraform/terraform/admin/`
  must return 0 matches (the `admin` AppRole mount is emitted by `auth-mounts`).
- The only resources this skill may declare: `vault_jwt_auth_backend`,
  `vault_jwt_auth_backend_role`, `vault_ldap_auth_backend`,
  `vault_ldap_auth_backend_group` for a top-level human auth method.
- **Secret guard**: `oidc_client_secret`, `client_secret`, `bindpass` ->
  `variable "<label>_<field>" { sensitive = true }`, no default.
- All rules in `vault-codifier-conventions` apply (tool selection, secret guard, naming, header, layers).
- **Schema lookup (Terraform MCP).** Before emitting each resource type, call the
  Terraform MCP (`search_providers` / `get_provider_details` for `hashicorp/vault`
  `4.8.0`) to confirm argument names and the import syntax. Use the doc URL it
  returns in the file header. If it disagrees with `task-006-decision.md`, stop
  and report it (see `vault-codifier-conventions` section 1).
  If the Terraform MCP binary is not installed, fall back to the provider docs at
  `https://raw.githubusercontent.com/hashicorp/terraform-provider-vault/v4.8.0/website/docs/r/<resource>.html.md`
  and record the fallback in the run notes.

## 3. Prerequisites

1. `admin_config.json` exists (fields: `namespace`, `human_auth_mounts`,
   `operator_policies`, `operator_groups`).
2. Outputs from TASK-015, 017, 018, 020 are generated, so labels can be resolved.
3. `vault-codifier-conventions` read; Terraform MCP reachable for schema lookups.

## 4. Process

1. **Load** `admin_config.json`.
2. **`admin/main.tf`**: terraform/provider block with the provider alias
   `vault.admin` (`namespace = "admin"`, `skip_child_token = true`), plus
   `locals` that reference namespace, policy, auth-mount and team resources by
   label. Do not copy their arguments.
3. **Human auth** - if `human_auth_mounts` is non-empty, write
   `admin/human_auth.tf` with `vault_jwt_auth_backend` (`type = "oidc"` or
   `"jwt"`, `oidc_discovery_url`, `oidc_client_id`) and
   `vault_jwt_auth_backend_role`, or the LDAP equivalents. Sensitive fields ->
   variables. If empty, do **not** create the file; the README states
   "no human auth method detected in `admin`".
4. **`admin/variables.tf`**: `vault_address`, the sensitive variables from step
   3, and nothing with a default for secrets. **`admin/outputs.tf`**:
   `namespace_paths`, `operator_policy_names`, plus accessor outputs consumed
   by downstream layers.
5. **`admin/README.md`**: operator policies (names `admin`, `operator`,
   `namespace-admin`), which identity groups hold them, human auth status.
6. **`admin/imports.tf`**: `import {}` for the resources this skill declares
   (human auth only). If none, no `imports.tf` is created by this skill (the
   layer `imports.tf` is assembled from other skills' blocks).
7. Provenance header (`Capability: admin-config`), fmt, validate.

## 9. Stop conditions

- `admin_config.json` missing or unparseable.
- An upstream label needed for a reference is not generated (run the owning
  skill first).
- A human auth payload contains an unmasked secret.
- Any declared resource type is outside the allowed list in section 2.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Example `admin/main.tf` (harness, no human auth)](references/example-admin-main-tf-harness-no-human-auth.md)
- [Example `admin/README.md` (harness)](references/example-admin-readme-md-harness.md)
- [Coding standards applied](references/coding-standards-applied.md)
- [Acceptance criteria (harness)](references/acceptance-criteria-harness.md)
- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
