## Coding standards

- `set -euo pipefail` with per-request status handling so a 403/404 is logged, not fatal.
- Single `vreq` helper for all calls.
- `jq -S`, deterministic sort of every array; no timestamps or random ids in output.
- Full tool paths: `vault`, `terraform`.
- Run report line per non-200: `{"endpoint": "...", "namespace": "...", "http_status": NNN, "skipped": true}`.

---
