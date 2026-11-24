---
name: discovery-orchestrator
description: >
  Single entry point that runs all discovery skills (TASK-007 through TASK-013)
  in dependency order against a live Vault Enterprise cluster, producing the
  full raw payload tree and a consolidated run report. TASK-014.
triggers:
  - "run discovery"
  - "run all discovery"
  - "full discovery"
  - "TASK-014"
task: TASK-014
capability: cross-cutting
depends_on:
  - vault-exporter-setup (TASK-031)
  - discovery-namespaces (TASK-007)
  - discovery-root-config (TASK-008)
  - discovery-policies (TASK-009)
  - discovery-auth-mounts (TASK-010)
  - discovery-secrets-engines (TASK-011)
  - discovery-identity-teams (TASK-012)
  - discovery-admin-config (TASK-013)
role: vault-expert
---

# Discovery Orchestrator (TASK-014)

> **Tool choice.** This skill uses the `vault` CLI, `curl` and `jq` with the exporter token.
> The Vault MCP server cannot serve it: it has no namespace, auth, policy, identity,
> quota or `sys/*` read tools, and it exposes write tools. See `vault-codifier-conventions`
> section 1. Optional cross-check: Vault MCP `list_mounts` against `sys/mounts`.

## Purpose

The single entry point for a full brownfield survey. It runs the seven discovery
skills in strict dependency order against a live cluster and produces:

- the complete raw payload tree under `discovered_terraform/raw/`, and
- one consolidated run report (`discovered_terraform/run_report.json`).

Doc source (cite in every generated file): `https://developer.hashicorp.com/vault/docs`

---

## Governance

All shared rules apply to the orchestrator and every skill it invokes:

1. NEVER use a root/operator token; exporter AppRole token only.
2. ONLY `GET` and `LIST`.
3. NEVER read `*/data/*` or `*/metadata/*`.
4. NEVER log tokens.
5. 403 / 404 / empty = non-fatal; recorded in the run report.
6. Raw JSON with `jq -S` under `discovered_terraform/raw/<namespace>/`.
7. Byte-identical across runs: strip `request_id`, `lease_id`, `renewable`, `lease_duration`.
8. Provenance header citing `https://developer.hashicorp.com/vault/docs` on every generated file.
9. Sensitive values -> `variable` references with no default; never to disk.
10. Naming: see `vault-codifier-conventions` section 5 (`/` and `-` -> `_`, `r_` prefix for digit-leading, valid identifier).

Orchestrator-specific:

- MUST verify the exporter token is active before starting, and again before each step.
- MUST verify an audit device is enabled before starting. No audit log = stop (discovery without an audit trail is not permitted).
- MUST NOT provision the exporter if it already exists; only verify.

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN="${EXPORTER_TOKEN}"   # NEVER root
```

---

## Prerequisites

| Requirement | Check |
|---|---|
| `EXPORTER_TOKEN` set (from `vault-exporter-setup`) | `test -n "${EXPORTER_TOKEN}"` (never print it) |
| `VAULT_ADDR` reachable | `/opt/homebrew/bin/vault status` |
| Token valid, not root | `/opt/homebrew/bin/vault token lookup -format=json \| jq -e '(.data.policies \| index("root")) == null'` |
| Audit device enabled | `/opt/homebrew/bin/vault audit list -format=json \| jq -e 'length > 0'` |
| `discovered_terraform/raw/` exists | `mkdir -p discovered_terraform/raw` |
| Prerequisites of each of the 7 skills are satisfied | each skill checks its own; orchestrator surfaces failures |
| `jq`, `curl`, `shasum` installed | `command -v jq curl shasum` |

---

## Execution order (strict)

| # | Skill | Task | Requires | Notes |
|---|---|---|---|---|
| 1 | `vault-exporter-setup` | TASK-031 | none | Verify token only; do NOT re-provision if already done |
| 2 | `discovery-namespaces` | TASK-007 | 1 | Produces `namespaces.json`; blocks everything else |
| 3 | `discovery-root-config` | TASK-008 | 2 | Parallel-safe with 4, 5, 6 |
| 4 | `discovery-policies` | TASK-009 | 2 | Parallel-safe with 3, 5, 6 |
| 5 | `discovery-auth-mounts` | TASK-010 | 2 | Parallel-safe with 3, 4, 6; produces accessors |
| 6 | `discovery-secrets-engines` | TASK-011 | 2 | Parallel-safe with 3, 4, 5 |
| 7 | `discovery-identity-teams` | TASK-012 | 5 | Needs `auth_mounts.json` for accessor map |
| 8 | `discovery-admin-config` | TASK-013 | 4, 5, 7 | Reuses policies, auth, identity payloads |

Steps 3-6 may run concurrently; for deterministic logs, serial is the default. Output bytes must not depend on ordering.

```bash
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"; START="$(date -u +%FT%TZ)"
for step in discovery-namespaces discovery-root-config discovery-policies \
            discovery-auth-mounts discovery-secrets-engines \
            discovery-identity-teams discovery-admin-config; do
  /opt/homebrew/bin/vault token lookup >/dev/null 2>&1 || { echo "token expired"; exit 2; }
  run_skill "$step" || mark_failed "$step"      # see Re-run / resume
done
```

`run_id`, `start_time`, `end_time` appear **only** in the run report, never in raw payloads.

---

## Idempotency

Run twice into separate directories and compare:

```bash
cp -R discovered_terraform/raw /tmp/raw_run1
# ... second run ...
diff -r /tmp/raw_run1 discovered_terraform/raw && echo IDENTICAL

# or hash the tree
(cd discovered_terraform/raw && find . -type f | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256)
```

The run report is excluded from the comparison (it contains timestamps). Any diff means a volatile field leaked or an array is unsorted: fix the offending skill.

---

## Run report format

`discovered_terraform/run_report.json`:

```json
{
  "run_id": "20250101T000000Z",
  "vault_addr": "http://127.0.0.1:8200",
  "start_time": "2025-01-01T00:00:00Z",
  "end_time": "2025-01-01T00:02:10Z",
  "namespaces_discovered": ["admin", "admin/platform", "admin/app-billing", "admin/app-identity"],
  "non_200_responses": [
    {"endpoint": "sys/policies/acl", "namespace": "admin/platform", "http_status": 403, "skipped": true}
  ],
  "exit_code": 0
}
```

`exit_code`: `0` success (non-200s are allowed), `1` a skill failed, `2` a stop condition triggered. The token must never appear in this file.

---

## Expected output tree (harness)

```
discovered_terraform/
  run_report.json
  raw/
    namespaces.json
    admin/
      root_config.json
      policies.json
      auth_mounts.json
      secrets_engines.json      # mounts: [] (no KV in admin)
      identity.json             # 9 groups, 6 entities, 0 aliases
      admin_config.json
    admin/platform/             # path is flattened per skill convention (e.g. admin_platform/)
      policies.json
      auth_mounts.json
      secrets_engines.json      # 1 KV v2 mount: secret/
    admin/app-billing/
      policies.json
      auth_mounts.json
      secrets_engines.json
    admin/app-identity/
      policies.json
      auth_mounts.json
      secrets_engines.json
```

No `identity.json` in child namespaces (empty sets create no file). Directory layout for nested namespaces follows `discovered_terraform/raw/<namespace>/` as defined by TASK-007.

---

## Re-run / resume

- Each skill is idempotent and overwrites only its own files, so re-running is always safe.
- The orchestrator keeps `discovered_terraform/.state.json` (`{"completed": ["discovery-namespaces", ...]}`), excluded from the idempotency comparison.
- Resume from a step: `FROM=discovery-auth-mounts` skips every step recorded as completed and before `FROM`. Already-collected payloads are never deleted.
- Force a step to re-run: remove it from `completed` (never `rm -rf raw/`).
- Dependencies are re-checked on resume: if `FROM=discovery-identity-teams` and `auth_mounts.json` is absent, stop.
- If the token expired, re-issue via `vault-exporter-setup` (new secret-id), then resume.

---

## Coding standards

- Orchestrator is thin: it invokes each skill and records status; it makes no Vault calls beyond token and audit checks.
- Skills are invoked by name and report non-200s to a shared JSONL that the orchestrator merges, sorts, and dedupes into `non_200_responses`.
- `set -euo pipefail`; never `set -x`; full tool paths `/opt/homebrew/bin/vault`, `/opt/homebrew/bin/terraform`.

---

## Acceptance criteria

- [ ] One command runs all discovery end to end against the harness.
- [ ] `run_report.json` shows `non_200_responses: []` and `exit_code: 0` for the harness.
- [ ] Output tree matches the expected tree above.
- [ ] Two runs produce byte-identical `raw/` trees (`diff -r` clean).
- [ ] `grep -r SYNTHETIC discovered_terraform/raw/` is empty; no tokens in any file.
- [ ] Audit log shows only `GET`/`LIST` by the exporter alias and no `/data/` or `/metadata/` paths.

---

## Stop conditions

- Audit log not enabled (checked before step 1): exit 2.
- Exporter token expired or revoked mid-run (self-lookup fails): exit 2; keep collected payloads; resume after re-auth.
- Token is root/operator: exit 2.
- Namespace LIST (TASK-007) fails completely: exit 2; nothing downstream can run.
- A single non-200 on one endpoint is NOT a stop condition.

---

## Related skills

`vault-exporter-setup`, `discovery-namespaces`, `discovery-root-config`, `discovery-policies`, `discovery-auth-mounts`, `discovery-secrets-engines`, `discovery-identity-teams`, `discovery-admin-config`.
