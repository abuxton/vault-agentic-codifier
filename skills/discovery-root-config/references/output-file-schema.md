## 6. Output File Schema

Output payloads are saved under `discovered_terraform/raw/root/`:

| Filename | Source Endpoint | Kept Fields | Stripped Fields |
|---|---|---|---|
| `audit.json` | `GET /v1/sys/audit` | `type`, `description`, `options`, `path` | `request_id`, `lease_id`, `renewable` |
| `quotas_rate_limit.json` | `GET /v1/sys/quotas/rate-limit/<name>` | `name`, `type`, `rate`, `interval`, `block_interval`, `path` | `request_id`, `lease_id` |
| `seal_status.json` | `GET /v1/sys/seal-status` | `type`, `initialized`, `sealed`, `t`, `n`, `version`, `cluster_name` | `nonce`, `migration` |
| `license_status.json` | `GET /v1/sys/license/status` | `license_id`, `start_time`, `expiration_time`, `features` | `license_text`, `request_id` |
| `replication_status.json` | `GET /v1/sys/replication/status` | `mode`, `dr`, `performance` | `request_id`, `lease_id` |
| `ui_headers.json` | `LIST /v1/sys/config/ui/headers` | `keys` (names only) | `request_id`, `lease_id` |
