## 10. Reference implementation (validated against the harness)

Run `skills/codification-root-config/scripts/generate.sh [raw/root] [out-root]`.

- Reads `audit.json`, `quotas_rate_limit_list.json`, `quota_rate_limit_<name>.json`,
  `seal_status.json`, `license_status.json` (ID and expiry only), `replication_status.json`
  and `ui_headers.json`.
- Exit 2 when `audit.json` is missing, when an audit option key looks like a secret
  (`password|secret|token|credential`), or when two labels collide.
- **Provider 4.8.0 does not read `inheritable` back on import** of `vault_quota_rate_limit`.
  Emitting `inheritable = true` plans an in-place change after import, so the generator omits it.
  A manual review item, not a drift.
- **`vault_audit.path` imports by bare path** (`file`); the payload key is `file/`, so the
  trailing slash is stripped.
- `sys_config.tf` (UI headers) is not generated: discovery lists header names only and
  never reads values, so there is nothing safe to codify. The README says so.
- `replication.tf` is not generated; the README records the discovered mode.

Validated: `fmt -check` and `validate` pass; `terraform plan` of the `admin` layer shows
`3 to import, 0 to add, 0 to change, 0 to destroy` (audit, quota, `admin` namespace); empty
audit payload produces no `audit.tf`; a secret-like option key exits 2; re-running is idempotent.
