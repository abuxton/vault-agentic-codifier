## Coding standards

- Bash with `set -euo pipefail`, but wrap each request so a non-200 does not abort the run.
- One helper (`vget`) for all requests; no ad-hoc `curl` calls.
- Always `jq -S`; sort `mounts` by `path` and `coverage` by `path` (`jq -S '.mounts|=sort_by(.path)'`).
- No timestamps, hostnames, or random IDs in raw output.
- Use full tool paths in non-interactive shells: `vault`, `terraform`.

---
