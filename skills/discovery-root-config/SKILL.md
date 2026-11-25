---
name: discovery-root-config
description: >
  Use when you need to discover root-namespace structural configuration including audit devices, rate-limit
  quotas, seal and health state, license metadata, replication status, and UI settings. Run after exporter setup,
  then codify. USE FOR: discover root config; root config discovery. DO NOT USE FOR: writing Terraform (use the
  matching codification-* skill), or any write to Vault.
metadata:
  task: "TASK-008"
  capability: "CAP-001"
  role: "vault-expert"
  depends_on: "vault-exporter-setup (TASK-031), discovery-namespaces (TASK-007)"
  version: "1.0"
---

# Root Configuration Discovery Skill (`discovery-root-config`)

> **Tool choice.** This skill uses the `vault` CLI, `curl` and `jq` with the exporter token.
> The Vault MCP server cannot serve it: it has no namespace, auth, policy, identity,
> quota or `sys/*` read tools, and it exposes write tools. See `vault-codifier-conventions`
> section 1. Optional cross-check: Vault MCP `list_mounts` against `sys/mounts`.

This skill discovers root-namespace structural configurations in a Vault Enterprise cluster. It captures audit devices, rate-limit quotas, health status, replication state, license metadata, and UI configuration, saving raw JSON payloads under `discovered_terraform/raw/root/`.

## 1. Purpose

The root namespace contains global infrastructure constructs that apply cluster-wide and can only be managed from root. This skill queries system endpoints to establish the baseline for Layer 1 (`admin/` / root Terraform configuration), identifying resources that will be codified (e.g. `vault_audit`, `vault_quota_rate_limit`) and unmanaged operational attributes (license, seal state, replication mode) to document in `root/README.md`.

## 2. Governance Rules

The following non-negotiable governance rules apply:
1. **Authentication**: Use ONLY the exporter AppRole token (`${EXPORTER_TOKEN}`) from `vault-exporter-setup` (TASK-031). Never use root or operator tokens.
2. **Read-Only**: Execute ONLY `GET` and `LIST` requests. Never write, mutate, or trigger cluster lifecycle actions.
3. **License Protection**: NEVER read `/v1/sys/license` (which returns raw license text). ONLY read `/v1/sys/license/status` for metadata (features, expiration date, license ID). Never emit license text.
4. **No Secret / Sensitive Data**: Never capture or store tokens, unseal keys, or sensitive backend parameters.
5. **Deterministic Payloads**: Store payloads formatted with sorted keys (`jq -S`). Strip volatile fields (`request_id`, `lease_id`, `lease_duration`, `renewable`). `sys/health` also carries `server_time_utc`, `last_wal`, `echo_duration_ms`, `clock_skew_ms` and `replication_primary_canary_age_ms`; `sys/seal-status` carries `nonce` and `progress`. Delete all of them or re-runs will differ. Prefer `.data` (the envelope is volatile) where the endpoint wraps its response.
6. **Non-Fatal Graceful Degradation**: On HTTP 403 or 404 for optional system endpoints, record a line in `discovered_terraform/raw/run_report.jsonl` and continue.
7. **Provenance**: Cite upstream HashiCorp documentation: `https://developer.hashicorp.com/vault/api-docs/system` and `https://developer.hashicorp.com/vault/docs/configuration`.

## 3. Prerequisites

| Prerequisite | Verification Command / Check | Purpose |
|---|---|---|
| Exporter Token | `test -n "${EXPORTER_TOKEN}"` | Authentication token with root discovery access |
| Vault Address | `test -n "${VAULT_ADDR}"` (default: `http://127.0.0.1:8200`) | Cluster API endpoint |
| CLI Binaries | `vault version`, `jq --version` | Required CLI utilities |
| Raw Root Dir | `mkdir -p discovered_terraform/raw/root` | Output directory for root payloads |
| Config Override | `export VAULT_CONFIG_PATH=/dev/null` | Prevent local config file overrides |

## 4. Discovery Process

```
[Start Root Discovery]
       │
       ▼
[1. GET /v1/sys/audit] ──(403 & critical)──► [Abort: Audit read denied]
       │
       ▼
[2. LIST & GET /v1/sys/quotas/rate-limit + GET sys/quotas/config]
       │
       ▼
[3. GET /v1/sys/seal-status & GET /v1/sys/health]
       │
       ▼
[4. GET /v1/sys/license/status] (Never /sys/license)
       │
       ▼
[5. GET /v1/sys/replication/status]
       │
       ▼
[6. LIST /v1/sys/config/ui/headers (sudo) & GET sys/internal/ui/feature-flags]
       │
       ▼
[7. Write raw payloads to discovered_terraform/raw/root/*.json via jq -S]
       │
       ▼
[8. Append non-200 responses to discovered_terraform/raw/run_report.jsonl]
```
## 10. Stop Conditions & Failure Recovery

- **Fatal - Audit Read Denied at Root**: If `GET /v1/sys/audit` fails with HTTP 403 when authenticated as the exporter token, abort with: `ERROR: Exporter AppRole lacks read capability on sys/audit. Verify TASK-031 exporter policy.`
- **Non-Fatal - Replication / Quotas 404/403**: Quota endpoints returning 404 (e.g. feature not enabled) or 403 are logged to `run_report.jsonl` and skipped.

## 11. Related Skills

- `vault-exporter-setup` (TASK-031) — Grants read permissions on `sys/audit`, `sys/quotas`, `sys/license/status`.
- `discovery-namespaces` (TASK-007) — Traverses tenant namespaces.
- `discovery-policies` (TASK-009) — Discovers root-level operator policy.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Exact API & CLI Calls](references/exact-api-cli-calls.md)
- [Output File Schema](references/output-file-schema.md)
- [What NOT to Capture](references/what-not-to-capture.md)
- [Coding & Naming Standards](references/coding-naming-standards.md)
- [Acceptance Criteria Checklist](references/acceptance-criteria-checklist.md)
- [Detailed Steps](references/detailed-steps.md)
