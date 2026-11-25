## 5. Naming

Terraform labels are deterministic and unique per directory.

1. Build `<namespace>_<name>`; omit the namespace for root.
2. Lowercase. Replace every run of `/`, `-`, `+`, `.` or space with `_`. Collapse
   repeated `_`. Strip leading and trailing `_`.
3. If the first character is a digit, prefix `r_`. An empty result is `_empty`.
4. If two objects produce the same label in one directory, stop and report both
   (CAC6). Never append a counter.

Examples: `secret` in `admin/platform` becomes `admin_platform_secret`;
`synthetic-user-platform-sre` in `admin` becomes
`admin_synthetic_user_platform_sre`.

File names: `<namespace_normalised>_<capability>.tf`, for example
`admin_platform_auth_mounts.tf`.

Policy documents longer than 10 lines go to
`policies/<namespace>/<name>.hcl` with `/` replaced by `__` in both parts and
`root` for the root namespace, for example
`policies/admin__platform/platform-sre-read.hcl`.
