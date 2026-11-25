## Prerequisites

| Requirement | Check |
|---|---|
| `EXPORTER_TOKEN` set (from `vault-exporter-setup`) | `test -n "${EXPORTER_TOKEN}"` (never print it) |
| `VAULT_ADDR` reachable | `vault status` |
| Token valid, not root | `vault token lookup -format=json \| jq -e '(.data.policies \| index("root")) == null'` |
| Audit device enabled | `vault audit list -format=json \| jq -e 'length > 0'` |
| `discovered_terraform/raw/` exists | `mkdir -p discovered_terraform/raw` |
| Prerequisites of each of the 7 skills are satisfied | each skill checks its own; orchestrator surfaces failures |
| `jq`, `curl`, `shasum` installed | `command -v jq curl shasum` |

---
