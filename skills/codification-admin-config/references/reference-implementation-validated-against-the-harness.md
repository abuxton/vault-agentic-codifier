## 10. Reference implementation (validated against the harness)

Run `skills/codification-admin-config/scripts/generate.sh [raw] [out-root]` last, after namespaces,
root-config, policies, auth-mounts and teams. It stops with exit 2 if a policy, group or the `admin`
namespace it references is not declared in `admin/`.

- Layout, in the `admin/` layer: `main.tf` (locals), `outputs.tf`, `admin_config_README.md`, and only
  when a top-level `oidc`, `jwt` or `ldap` mount exists, `human_auth.tf` and
  `imports_admin_config.tf`. The provider alias `vault.admin` already comes from `scaffold-layer.sh`
  (`providers.tf`, `versions.tf`), so there is no second provider block. The README is prefixed
  because the `admin/` layer holds other generators' files.
- `main.tf` holds `local.operator_policies` and `local.operator_groups` as resource references.
  `outputs.tf` holds `namespace_paths`, `operator_policy_names` and `auth_mount_accessors`.
- The harness has no human auth mount: no `human_auth.tf`, and the README says "No human auth method
  detected in `admin`". It lists `admin` (no recorded holder) and `namespace-admin` (three tenant
  admin groups), and notes that root `operator` belongs to root-config and policies.
- **Ownership split.** The auth-mounts generator now skips `oidc`, `jwt` and `ldap` mounts in the
  `admin` namespace; this skill emits them. The teams generator resolves an alias accessor to
  `vault_jwt_auth_backend.<label>` or `vault_ldap_auth_backend.<label>` for those mounts.
- **Acceptance criterion correction.** The `grep 'resource "vault_auth_backend"'` check in section 8
  applies to the files this skill writes (`main.tf`, `outputs.tf`, `human_auth.tf`), not the whole
  `admin/` directory. The directory holds `admin_auth_mounts.tf` and `root_auth_mounts.tf` from
  auth-mounts, which are correct. The `admin` namespace resource has no `custom_metadata` block.
- Secrets: `oidc_client_secret` and `bindpass` become sensitive variables with no default
  (`<label>_oidc_client_secret`, `<label>_bindpass`) and are in `ignore_changes`, because Vault never
  returns them. The generator exits 2 when the payload holds a non-empty value other than `REDACTED`.
- Not codified, listed in the README when human auth exists: non-string `bound_claims`,
  `claim_mappings`, `verbose_oidc_logging` and `tune`.
- Import IDs: backend = path; JWT role = `auth/<path>/role/<name>`; LDAP group = `auth/<path>/groups/<name>`.

Validated: fmt and validate pass; `terraform plan` in `admin/` shows `31 to import, 0 to add, 0 to
change, 0 to destroy`; re-run byte-identical; a scratch `oidc` mount with a role and an `ldap` mount with
a group validate and format cleanly, emit no client-secret or bind-password literal, and produce the
imports above; an unmasked secret and a missing upstream resource each exit 2. Variant output was
validated with `terraform validate` only; there is no live OIDC or LDAP mount (TASK-026).
