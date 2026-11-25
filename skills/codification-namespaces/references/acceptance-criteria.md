## 8. Acceptance criteria

- 4 `vault_namespace` resources for the harness: `admin`, `admin_platform`,
  `admin_app_billing`, `admin_app_identity`.
- The three tenants carry `custom_metadata.description` with the expected text;
  `admin` carries no `custom_metadata`.
- Every child targets its parent through `provider = vault.<alias>`; this returns 0 lines:
  `grep -rnE 'namespace\s*=\s*"' discovered_terraform/terraform/*/namespaces.tf`
- No `"admin/"` string literal appears inside any `vault_namespace` block
  (import `id` values in `imports.tf` are exempt).
- 4 matching `import {}` blocks; `hierarchy.md` shows `admin` as parent of three
  tenants with depth 1 and 2.
- A scratch namespace `admin/platform/sre-team` is emitted at depth 3 with
  `provider = vault.admin_platform`.
- `terraform fmt -check -recursive` and `terraform validate` exit 0.
