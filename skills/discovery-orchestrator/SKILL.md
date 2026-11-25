---
name: discovery-orchestrator
description: >
  Use when you need to single entry point that runs all discovery skills (. Run after exporter setup, then codify.
  USE FOR: run discovery; run all discovery. DO NOT USE FOR: writing Terraform (use the matching codification-*
  skill), or any write to Vault.
metadata:
  task: "TASK-014"
  capability: "cross-cutting"
  role: "vault-expert"
  depends_on: "vault-exporter-setup (TASK-031), discovery-namespaces (TASK-007), discovery-root-config (TASK-008), discovery-policies (TASK-009), discovery-auth-mounts (TASK-010), discovery-secrets-engines (TASK-011), discovery-identity-teams (TASK-012), discovery-admin-config (TASK-013)"
  version: "1.0"
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
## Stop conditions

- Audit log not enabled (checked before step 1): exit 2.
- Exporter token expired or revoked mid-run (self-lookup fails): exit 2; keep collected payloads; resume after re-auth.
- Token is root/operator: exit 2.
- Namespace LIST (TASK-007) fails completely: exit 2; nothing downstream can run.
- A single non-200 on one endpoint is NOT a stop condition.

---

## Related skills

`vault-exporter-setup`, `discovery-namespaces`, `discovery-root-config`, `discovery-policies`, `discovery-auth-mounts`, `discovery-secrets-engines`, `discovery-identity-teams`, `discovery-admin-config`.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Prerequisites](references/prerequisites.md)
- [Idempotency](references/idempotency.md)
- [Run report format](references/run-report-format.md)
- [Expected output tree (harness)](references/expected-output-tree-harness.md)
- [Re-run / resume](references/re-run-resume.md)
- [Coding standards](references/coding-standards.md)
- [Acceptance criteria](references/acceptance-criteria.md)
- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
