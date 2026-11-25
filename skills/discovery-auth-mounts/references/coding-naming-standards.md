## 8. Coding & Naming Standards

- **Terraform Resource Label Helper**: Normalise `<namespace>_<path>`:
  - `admin/platform` + `approle` mount → `vault_auth_backend.admin_platform_approle`
  - `admin/platform` + `platform-ci` role → `vault_approle_auth_backend_role.admin_platform_platform_ci`
- **Accessor Retention**: Keep exact `accessor` strings in the raw JSON payload so identity alias discovery (TASK-012) can resolve backend accessors without making extra API calls.
