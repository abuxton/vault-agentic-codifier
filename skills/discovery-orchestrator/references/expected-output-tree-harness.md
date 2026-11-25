## Expected output tree (harness)

```
discovered_terraform/
  run_report.json
  .state.json
  raw/
    namespaces.json
    coverage.json                 # policies: acl_total 10, no EGP/RGP
    root/                         # root namespace
      audit.json  health.json  license_status.json  replication_status.json  seal_status.json
      quotas_config.json  quotas_rate_limit_list.json  quota_rate_limit_global_rate_limit.json
      ui_headers.json  ui_feature_flags.json
      policies.json  auth_mounts.json  secrets_engines.json
      identity.json             # exporter-agent entity + its AppRole alias
    admin/
      policies.json  auth_mounts.json
      secrets_engines.json      # mounts: [] (agent-registry is skipped)
      identity.json             # 9 groups, 6 entities, 0 aliases
      admin_config.json
    admin/platform/  admin/app-billing/  admin/app-identity/
      policies.json  auth_mounts.json
      secrets_engines.json      # 1 KV v2 mount: secret/
```

There is no `root_config.json`: root-config writes one file per endpoint under `raw/root/`. No `identity.json`
in child namespaces (empty sets create no file). Nested namespaces use `discovered_terraform/raw/<namespace>/`
(the path keeps its slashes, e.g. `raw/admin/platform/`).

---
