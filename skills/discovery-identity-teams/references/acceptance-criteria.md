## Acceptance criteria

- [ ] `admin/identity.json` contains 9 groups and 6 entities, 0 aliases.
- [ ] `root/identity.json` contains the `exporter-agent` entity and its 1 AppRole alias with `mount_path: "approle/"`.
- [ ] No `identity.json` exists for `admin/platform`, `admin/app-billing`, `admin/app-identity`.
- [ ] `accessor_map` covers every accessor in `auth_mounts.json` files; every alias (if any) has a non-null `mount_path`.
- [ ] No ID literal from group/entity appears outside raw JSON (grep generated `.tf` except `imports.tf`).
- [ ] No tokens or secret values present: `grep -r SYNTHETIC discovered_terraform/raw/` is empty.
- [ ] Two consecutive runs are byte-identical.
- [ ] Non-200 responses are listed in the run report.

---
