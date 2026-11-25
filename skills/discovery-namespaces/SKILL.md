---
name: discovery-namespaces
description: >
  Use when you need to recursively walk the Vault namespace tree from root (or a given anchor namespace) using
  LIST sys/namespaces with X-Vault-Namespace headers, read each namespace's metadata, and emit an ordered parent-
  before-child JSON list consumed by all other discovery skills. Run after exporter setup, then codify. USE FOR:
  discover namespaces; namespace walk. DO NOT USE FOR: writing Terraform (use the matching codification-* skill),
  or any write to Vault.
metadata:
  task: "TASK-007"
  capability: "CAP-005"
  role: "vault-expert"
  depends_on: "vault-exporter-setup (TASK-031), vault-codifier-conventions (TASK-003)"
  version: "1.0"
---

# Namespace Discovery Skill (`discovery-namespaces`)

> **Tool choice.** This skill uses the `vault` CLI, `curl` and `jq` with the exporter token.
> The Vault MCP server cannot serve it: it has no namespace, auth, policy, identity,
> quota or `sys/*` read tools, and it exposes write tools. See `vault-codifier-conventions`
> section 1. Optional cross-check: Vault MCP `list_mounts` against `sys/mounts`.

This skill performs automated, deterministic, read-only discovery of the Vault Enterprise namespace tree. It walks namespaces depth-first starting from root, gathers namespace IDs and custom metadata, and outputs a parent-before-child ordered topology to `discovered_terraform/raw/namespaces.json`.

## 1. Purpose

Namespaces form the organizational boundary and tenant isolation container in Vault Enterprise. All downstream discovery modules (policies, auth mounts, secrets engines, identity teams) require the complete ordered list of namespaces to target their respective discovery calls using the `X-Vault-Namespace` header. Namespace discovery must execute first to establish this source of truth.

## 2. Governance Rules

The following non-negotiable governance and security rules apply:
1. **Authentication**: NEVER use root or operator tokens. Use the read-only exporter AppRole token (`${EXPORTER_TOKEN}`) created via `vault-exporter-setup` (TASK-031).
2. **Read-Only**: Issue ONLY `GET` and `LIST` requests (`LIST /v1/sys/namespaces` and `GET /v1/sys/namespaces/<path>`). Never send `POST`, `PUT`, `DELETE`, or `PATCH`.
3. **Root Exclusion**: Never emit a `vault_namespace` resource entry for root (`""` or `"root"`). Root is tracked separately as execution context.
4. **Ordering**: Output must strictly list parent namespaces before their child namespaces (sorted by depth ascending, then lexicographical path).
5. **No Secrets/Tokens**: Never log, store, or output token values or authorization headers.
6. **Idempotence**: Output JSON must be formatted with sorted keys (`jq -S`) and stripped of volatile runtime fields (`request_id`, `lease_id`, `warnings`).
7. **Error Handling**: 403, 404, or empty responses on child namespace traversal represent leaf boundaries or permission boundaries; log to the run report and continue.
8. **Provenance**: Cite upstream HashiCorp documentation: `https://developer.hashicorp.com/vault/api-docs/system/namespaces` and `https://developer.hashicorp.com/validated-designs/vault/administration-guide/introduction`.

## 3. Prerequisites

| Prerequisite | Verification Command / Check | Purpose |
|---|---|---|
| Exporter Token | `test -n "${EXPORTER_TOKEN}"` | Authentication token for discovery |
| Vault Address | `test -n "${VAULT_ADDR}"` (default: `http://127.0.0.1:8200`) | Target Vault cluster endpoint |
| CLI Binaries | `vault version`, `jq --version` | Required CLI utilities |
| Raw Output Dir | `mkdir -p discovered_terraform/raw` | Destination directory for raw payloads |
| Config Override | `export VAULT_CONFIG_PATH=/dev/null` | Prevent local config file interference |

## 4. Discovery Process

```
[Start Discovery]
       │
       ▼
[1. Verify Token & Endpoint] ──(fail)──► [Abort: Invalid Exporter Token]
       │
       ▼
[2. LIST /v1/sys/namespaces (Root)]
       │
       ▼
[3. For each child namespace path]
       ├──► [GET /v1/sys/namespaces/<path> (Read metadata & ID)]
       ├──► [Recurse: LIST /v1/sys/namespaces with X-Vault-Namespace: <path>]
       └──► [Detect Leaves: 404 / 403 / empty child list]
       │
       ▼
[4. Sort & Order: Parent-before-child (by depth ascending, then path)]
       │
       ▼
[5. Write discovered_terraform/raw/namespaces.json via jq -S]
       │
       ▼
[6. Record any non-200 responses into run report]
```
## 9. Stop Conditions & Failure Recovery

- **Fatal - Expired / Invalid Token**: If `GET /v1/auth/token/lookup-self` returns HTTP 403 or 401, stop immediately and report: `ERROR: Exporter token is invalid or expired. Re-authenticate via vault-exporter-setup (TASK-031).`
- **Fatal - Root LIST Failure**: If root-level `LIST /v1/sys/namespaces` returns HTTP 5xx or connection refused, stop and report Vault connectivity failure.
- **Non-Fatal - Leaf 403 / 404**: Treat 404 or 403 on child namespace listing as leaf boundary; log to run report and resume recursion on sibling branches.

## 10. Related Skills

- `vault-exporter-setup` (TASK-031) — Creates the read-only AppRole token consumed by this skill.
- `discovery-root-config` (TASK-008) — Discovers cluster-wide settings at root.
- `discovery-policies` (TASK-009) — Uses `namespaces.json` to iterate policies per namespace.
- `discovery-auth-mounts` (TASK-010) — Uses `namespaces.json` to iterate auth mounts per namespace.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Exact API & CLI Calls](references/exact-api-cli-calls.md)
- [Output Schema](references/output-schema.md)
- [Coding & Naming Standards](references/coding-naming-standards.md)
- [Acceptance Criteria Checklist](references/acceptance-criteria-checklist.md)
- [Detailed Steps](references/detailed-steps.md)
