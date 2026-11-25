## 7. Acceptance criteria (harness)

- 5 `vault_auth_backend` resources, all `type = "approle"`, `path = "approle"`:
  root, `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`;
  `token/` not emitted.
- 6 `vault_approle_auth_backend_role` (harness drift: includes root `exporter`): `terraform-admin` (root),
  `namespace-provisioner` (`admin`), `platform-ci`, `billing-service`,
  `identity-service`.
- Each role: `token_ttl = 3600`, `token_max_ttl = 14400`,
  `secret_id_num_uses = 1`; `secret_id_ttl` = 900, 900, 1800, 900, 900
  respectively (integers).
- `grep -rEn '(^|[^A-Za-z0-9_])(role_id|secret_id|secret_id_accessor)([^A-Za-z0-9_]|$)' discovered_terraform/terraform --exclude-dir=.terraform` returns 0
  (a bare `role_id` also matches inside labels such as `approle_identity`; the word boundaries avoid that).
- `coverage.md` lists 5 mounts and 6 roles, none "unsupported".
- With `userpass` enabled in `admin/app-billing`, a fallback is emitted and
  documented.
- 11 `import {}` blocks (5 backends, 6 roles: the harness now includes the root `exporter` role); fmt and validate pass.
