## Coding standards

- `set -euo pipefail`; per-request status check so 403/404 are logged and skipped.
- `jq -S`, sorted arrays, no timestamps or random ids.
- Prefer on-disk payloads to API calls; the only live calls are `sys/namespaces/admin`, `sys/auth` (if not on disk), and human-mount config.
- Full tool paths: `vault`, `terraform`.
- Non-200 -> run report `{"endpoint","namespace","http_status","skipped":true}`.

---
