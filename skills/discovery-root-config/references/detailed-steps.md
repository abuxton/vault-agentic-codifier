## Detailed Steps

1. **Step 1: Audit Devices (`GET /v1/sys/audit`)**  
   Read all enabled audit devices. If empty (e.g. unseeded fresh cluster), record an empty object `{}` in `audit.json`.
2. **Step 2: Quotas (`LIST /v1/sys/quotas/rate-limit` & `GET /v1/sys/quotas/config`)**  
   List all rate-limit quota names. For each quota name, call `GET /v1/sys/quotas/rate-limit/<name>` and collect rate, interval, block interval, and path. Query global quota configuration.
3. **Step 3: Seal & Health Status (`GET /v1/sys/seal-status`, `GET /v1/sys/health`)**  
   Capture seal type (shamir, transit, kms), initialization state, HA status, cluster name, and Vault version.
4. **Step 4: License Metadata (`GET /v1/sys/license/status`)**  
   Read license status to capture `license_id`, `start_time`, `expiration_time`, and licensed `features`. Strictly avoid `/v1/sys/license`.
5. **Step 5: Replication Status (`GET /v1/sys/replication/status`)**  
   Check replication mode (disabled, primary, secondary, performance, dr).
6. **Step 6: UI Configuration (`LIST /v1/sys/config/ui/headers`, `GET /v1/sys/internal/ui/feature-flags`)**
   Capture the names of custom UI headers and the UI feature flags. `sys/config/ui/headers` needs `sudo`, and `GET` on the bare path is 405: only `LIST` is valid. A `LIST` that returns 404 means "no headers configured" and is saved as `{"keys": []}`, not logged as a failure (applies to every `LIST` in the discovery skills).
7. **Step 7: Format and Write Payloads**  
   Format each payload with `jq -S` and save under `discovered_terraform/raw/root/`.
8. **Step 8: Log Non-200 Responses**  
   Log any 403/404 response to `discovered_terraform/raw/run_report.jsonl`.
