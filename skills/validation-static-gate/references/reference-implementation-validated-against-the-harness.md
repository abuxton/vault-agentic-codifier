## 5. Reference implementation (validated against the harness)

Harness: `static gate: ok` for `admin/`, `namespaces/` and `seed/`; `make static-gate` exits 0.

The first run found one real issue: `local.operator_groups` in the admin-config output was declared and never
used (`terraform_unused_declarations`). The generator now exposes it as `output "operator_group_names"`;
nothing is suppressed.

Injected faults, each exit 1 with the owner named: a syntax error (`seed/admin_platform_policies.tf:33
[policies]`), an unformatted file (`admin/root_policies.tf [policies]`), a reference to an undeclared policy
(`admin/root_auth_mounts.tf:20 [auth-mounts]`), and an unused variable (`admin/audit.tf:15 [root-config]`).
