## 7. Deduplication & Namespace Scoping

- Policies are strictly scoped to their namespace. A policy named `read-only` in `admin/platform` and a policy named `read-only` in `admin/app-billing` are distinct objects.
- In downstream codification, resource labels are derived from both the namespace and policy name:
  - `admin/platform` + `platform-sre-read` → `vault_policy.admin_platform_platform_sre_read`
  - Root + `operator` → `vault_policy.root_operator`
