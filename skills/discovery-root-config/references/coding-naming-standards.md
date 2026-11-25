## 8. Coding & Naming Standards

- Resource labels for root constructs:
  - Audit device: `file` → `file` (`vault_audit.file`)
  - Quota: `global-rate-limit` → `global_rate_limit` (`vault_quota_rate_limit.global_rate_limit`)
- All JSON outputs must be generated with `jq -S` for consistent key ordering.
