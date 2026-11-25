## Acceptance criteria

- [ ] `admin_config.json` exists under `discovered_terraform/raw/admin/` and validates against the schema above.
- [ ] Harness: `human_auth_mounts` is `[]` and the informational message was emitted.
- [ ] No `client_secret`, `oidc_client_secret`, or `bindpass` value appears anywhere in the output.
- [ ] No live calls to `identity/` or `sys/policies/` were made (check the audit log).
- [ ] Two consecutive runs are byte-identical.
- [ ] `grep -r SYNTHETIC discovered_terraform/raw/` is empty.

---
