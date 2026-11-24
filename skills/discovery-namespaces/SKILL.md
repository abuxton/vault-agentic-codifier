---
name: discovery-namespaces
description: >
  Recursively walk the Vault namespace tree from root (or a given anchor namespace)
  using LIST sys/namespaces with X-Vault-Namespace headers, read each namespace's
  metadata, and emit an ordered parent-before-child JSON list consumed by all other
  discovery skills. TASK-007 — prerequisite for all capability discovery.
triggers:
  - "discover namespaces"
  - "namespace walk"
  - "namespace discovery"
  - "TASK-007"
capability: CAP-005
task: TASK-007
depends_on:
  - vault-exporter-setup (TASK-031)
  - vault-codifier-conventions (TASK-003)
role: vault-expert
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
| CLI Binaries | `/opt/homebrew/bin/vault version`, `jq --version` | Required CLI utilities |
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

### Detailed Steps

1. **Step 1: Authenticate Check**  
   Verify that `${EXPORTER_TOKEN}` is valid and read-only by calling `GET /v1/auth/token/lookup-self`. Confirm policy matches `exporter`.
2. **Step 2: List Root Namespaces**  
   Execute `LIST /v1/sys/namespaces` with no `X-Vault-Namespace` header (or empty header) to retrieve immediate children of root.
3. **Step 3: Read Namespace Metadata**  
   For each discovered namespace path at the current level, issue `GET /v1/sys/namespaces/<path>` under the appropriate parent namespace header to capture `id`, `path`, and `custom_metadata`.
4. **Step 4: Recursive Walk**  
   For each namespace, set `X-Vault-Namespace: <full_parent_path>` and execute `LIST /v1/sys/namespaces`. Repeat depth-first traversal until no further child namespaces exist (empty list, 404, or 403 indicates a leaf node). Track `depth` (e.g., `admin` = 1, `admin/platform` = 2, `admin/platform/sre-team` = 3).
5. **Step 5: Build Ordered Payload**  
   Assemble the collection into a JSON array, excluding root. Sort entries primarily by `depth` ascending and secondarily by `path` ascending. Write the result to `discovered_terraform/raw/namespaces.json` using `jq -S`.
6. **Step 6: Write Run Report**  
   For any encountered HTTP status code other than 200, append a JSON line to `discovered_terraform/raw/run_report.jsonl`:
   `{"endpoint": "sys/namespaces/<path>", "namespace": "<parent>", "http_status": NNN, "skipped": true}`.

## 5. Exact API & CLI Calls

### Check Token
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/auth/token/lookup-self" | jq -S .data
```

### List Root Namespaces
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/namespaces" | jq -S .
```

### Read Namespace Details (at Root)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/namespaces/admin" | jq -S .data
```

### List Child Namespaces (under `admin`)
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/namespaces" | jq -S .
```

### Read Child Namespace Details (e.g., `platform` under `admin`)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/namespaces/platform" | jq -S .data
```

## 6. Output Schema

The output file `discovered_terraform/raw/namespaces.json` must adhere to the following schema:

```json
[
  {
    "path": "admin",
    "parent": "",
    "id": "c1f7b9e0-8a4d-4b9e-9d2a-1b2c3d4e5f60",
    "custom_metadata": null,
    "depth": 1
  },
  {
    "path": "admin/app-billing",
    "parent": "admin",
    "id": "e3a8c1f0-2b5d-4c8e-8f1a-3d4e5f607182",
    "custom_metadata": {
      "description": "Billing application team namespace"
    },
    "depth": 2
  },
  {
    "path": "admin/app-identity",
    "parent": "admin",
    "id": "f4b9d2e1-3c6e-4d9f-9a2b-4e5f60718293",
    "custom_metadata": {
      "description": "Identity service team namespace"
    },
    "depth": 2
  },
  {
    "path": "admin/platform",
    "parent": "admin",
    "id": "d2e8a0f1-1a3c-4b7d-8e0f-2a3b4c5d6e7f",
    "custom_metadata": {
      "description": "Platform engineering team namespace"
    },
    "depth": 2
  }
]
```

## 7. Coding & Naming Standards

- **Terraform Resource Label Helper**: Normalise full namespace paths by replacing `/` and `-` with underscores `_`:
  - `admin` → `admin`
  - `admin/platform` → `admin_platform`
  - `admin/app-billing` → `admin_app_billing`
  - `admin/app-identity` → `admin_app_identity`
- **JSON Formatting**: Always use `jq -S` to format JSON with deterministically sorted object keys.
- **Parent Referencing**: Do not hardcode string paths in downstream generators; use the `parent` and `path` structure to establish hierarchical references.

## 8. Acceptance Criteria Checklist

- [ ] **AC-1 (CAP-005 AC1)**: Against the harness, exactly 4 namespaces are discovered: `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`.
- [ ] **AC-2 (CAP-005 AC2)**: Custom metadata descriptions match harness configuration for tenant namespaces (`platform`, `app-billing`, `app-identity`), while `admin` has `null` custom metadata.
- [ ] **AC-3 (CAP-005 AC3)**: Topologically ordered such that every parent namespace precedes its child namespaces.
- [ ] **AC-4 (CAP-005 AC5)**: Handles arbitrary depth (`depth >= 3`) correctly without hardcoded level limits.
- [ ] **AC-5 (CAP-005 AC6)**: Root namespace `""` is excluded from the output list.
- [ ] **AC-6 (CAP-005 AC7)**: Namespace IDs in output match `vault namespace list -detailed` on the cluster.
- [ ] **AC-7 (CAC5)**: Two consecutive executions produce byte-identical `namespaces.json`.

## 9. Stop Conditions & Failure Recovery

- **Fatal - Expired / Invalid Token**: If `GET /v1/auth/token/lookup-self` returns HTTP 403 or 401, stop immediately and report: `ERROR: Exporter token is invalid or expired. Re-authenticate via vault-exporter-setup (TASK-031).`
- **Fatal - Root LIST Failure**: If root-level `LIST /v1/sys/namespaces` returns HTTP 5xx or connection refused, stop and report Vault connectivity failure.
- **Non-Fatal - Leaf 403 / 404**: Treat 404 or 403 on child namespace listing as leaf boundary; log to run report and resume recursion on sibling branches.

## 10. Related Skills

- [`vault-exporter-setup`](../vault-exporter-setup/SKILL.md) (TASK-031) — Creates the read-only AppRole token consumed by this skill.
- [`discovery-root-config`](../discovery-root-config/SKILL.md) (TASK-008) — Discovers cluster-wide settings at root.
- [`discovery-policies`](../discovery-policies/SKILL.md) (TASK-009) — Uses `namespaces.json` to iterate policies per namespace.
- [`discovery-auth-mounts`](../discovery-auth-mounts/SKILL.md) (TASK-010) — Uses `namespaces.json` to iterate auth mounts per namespace.
