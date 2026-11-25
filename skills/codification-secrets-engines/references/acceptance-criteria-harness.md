## 7. Acceptance criteria (harness)

- 3 `vault_mount` resources (path `secret`, `type = "kv"`,
  `options = { version = "2" }`) in `admin/platform`, `admin/app-billing`,
  `admin/app-identity`, with descriptions "Platform KV v2 secrets engine",
  "Billing app KV v2 secrets engine", "Identity service KV v2 secrets engine".
- 3 `vault_kv_secret_backend_v2`, each referencing its mount.
- No `vault_mount` in `admin`; `sys/`, `identity/`, `cubbyhole/` never emitted.
- `grep -rE 'vault_kv_secret(_v2)?"|vault_generic_secret'` returns 0.
- `grep -r SYNTHETIC discovered_terraform/terraform` returns 0.
- A mount with pinned `plugin_version` emits it; unpinned mounts do not.
- `grep -rE '_ttl_seconds\s*=\s*0'` returns 0.
- With a scratch `database` or `pki` mount, engine resources are emitted and
  sensitive fields appear as variables.
- fmt and validate pass.
