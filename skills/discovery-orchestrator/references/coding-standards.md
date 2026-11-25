## Coding standards

- Orchestrator is thin: it invokes each skill and records status; it makes no Vault calls beyond token and audit checks.
- Skills are invoked by name and report non-200s to a shared JSONL that the orchestrator merges, sorts, and dedupes into `non_200_responses`.
- `set -euo pipefail`; never `set -x`; full tool paths `vault`, `terraform`.

---
