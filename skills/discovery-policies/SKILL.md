---
name: discovery-policies
description: >
  Enumerate all ACL policies across root and all discovered namespaces, store verbatim
  HCL policy documents, and check Enterprise Sentinel EGP/RGP policies for coverage.
  TASK-009 — covers CAP-006 (policies).
triggers:
  - "discover policies"
  - "policy discovery"
  - "TASK-009"
capability: CAP-006
task: TASK-009
depends_on:
  - vault-exporter-setup (TASK-031)
  - discovery-namespaces (TASK-007)
role: vault-expert
---

# Policy Discovery Skill (`discovery-policies`)

> **Tool choice.** This skill uses the `vault` CLI, `curl` and `jq` with the exporter token.
> The Vault MCP server cannot serve it: it has no namespace, auth, policy, identity,
> quota or `sys/*` read tools, and it exposes write tools. See `vault-codifier-conventions`
> section 1. Optional cross-check: Vault MCP `list_mounts` against `sys/mounts`.

This skill discovers all Access Control List (ACL) policies and Enterprise Sentinel policies (EGP and RGP) across the root namespace and all tenant namespaces. It extracts and stores policy documents byte-for-byte as returned by Vault, outputting structured JSON payloads to `discovered_terraform/raw/<namespace>/policies.json`.

## 1. Purpose

Policies define authorization boundaries and capabilities within Vault. Capturing policies accurately and without mutation is essential for least-privilege auditing, identity correlation, and reproducible Terraform codification (`vault_policy`). This skill creates the policy catalog that feeds role correlation and identity group mapping.

## 2. Governance Rules

The following non-negotiable governance rules apply:
1. **Authentication**: Use ONLY the exporter AppRole token (`${EXPORTER_TOKEN}`). Never use root or operator tokens.
2. **Read-Only**: Execute ONLY `GET` and `LIST` operations (`LIST /v1/sys/policies/acl`, `GET /v1/sys/policies/acl/<name>`).
3. **Skip Builtins**: Always ignore and exclude the built-in `default`, `root` and `default-ceiling` policies. Vault 2.x creates `default-ceiling` (the agent-registry ceiling policy) in every namespace; it is managed internally and is not codified. They cannot be managed via standard `vault_policy` resources.
4. **Verbatim Policy Text**: Stored policy documents must preserve the raw string returned by Vault byte-for-byte (including comments and whitespace).
5. **No Mutation of Paths**: Path stanzas within policies (even if using relative paths like `secret/data/*`) must NOT be rewritten during discovery.
6. **Graceful Handling of Sentinel (EGP/RGP)**: On non-Enterprise editions or when permissions are missing, log 403/404 to the run report and record "none" / "unavailable" in coverage.
7. **Deterministic Storage**: Format output JSON with sorted keys (`jq -S`).
8. **Provenance**: Cite upstream HashiCorp documentation: `https://developer.hashicorp.com/vault/api-docs/system/policies` and `https://developer.hashicorp.com/vault/docs/concepts/policies`.

## 3. Prerequisites

| Prerequisite | Verification Command / Check | Purpose |
|---|---|---|
| Exporter Token | `test -n "${EXPORTER_TOKEN}"` | Authentication token with policy read access |
| Namespace Catalog | `test -f discovered_terraform/raw/namespaces.json` | Input list of namespaces from TASK-007 |
| Output Dirs | `mkdir -p discovered_terraform/raw/root` | Output directories per namespace |
| CLI Binaries | `/opt/homebrew/bin/vault version`, `jq --version` | CLI utilities for querying and formatting |
| Config Override | `export VAULT_CONFIG_PATH=/dev/null` | Ensure clean environment |

## 4. Discovery Process

```
[Start Policy Discovery]
       │
       ▼
[1. Load Namespaces: Root ("") + entries from namespaces.json]
       │
       ▼
[2. For each namespace (set X-Vault-Namespace)]
       ├──► [LIST /v1/sys/policies/acl]
       │       │
       │       ▼
       │    [Filter out 'default', 'root', 'default-ceiling']
       │       │
       │       ▼
       │    [For each policy name: GET /v1/sys/policies/acl/<name>]
       │
       ├──► [LIST /v1/sys/policies/egp (Sentinel Endpoint)]
       ├──► [LIST /v1/sys/policies/rgp (Sentinel Endpoint)]
       │
       ▼
[3. Write discovered_terraform/raw/<namespace>/policies.json via jq -S]
       │
       ▼
[4. Append Sentinel findings to discovered_terraform/raw/coverage.json]
       │
       ▼
[5. Log non-200 responses to discovered_terraform/raw/run_report.jsonl]
```

### Detailed Steps

1. **Step 1: Iterate Namespaces**  
   Load root (`""`) and all namespace paths from `discovered_terraform/raw/namespaces.json` (`admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`).
2. **Step 2: List ACL Policies**  
   Issue `LIST /v1/sys/policies/acl` with `X-Vault-Namespace` set to the current namespace.
3. **Step 3: Fetch Policy Contents**  
   For each policy name returned, check if it is `default`, `root` or `default-ceiling`. If so, skip. Otherwise, execute `GET /v1/sys/policies/acl/<name>` and retrieve the raw `policy` string.
4. **Step 4: Check Sentinel Policies (Enterprise)**  
   Execute `LIST /v1/sys/policies/egp` and `LIST /v1/sys/policies/rgp`. If empty or 403, record status as "none" or "unavailable".
5. **Step 5: Write Per-Namespace Payloads**  
   Write `discovered_terraform/raw/<namespace_path>/policies.json` with sorted keys. (For root, write to `discovered_terraform/raw/root/policies.json`).
6. **Step 6: Update Coverage & Run Report**  
   Log any Sentinel capabilities to `discovered_terraform/raw/coverage.json` and non-200 responses to `discovered_terraform/raw/run_report.jsonl`.

## 5. Exact API & CLI Calls

### List Policies at Root
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/policies/acl" | jq -S .data.keys
```

### Read Policy at Root (e.g., `operator`)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/policies/acl/operator" | jq -S .data
```

### List Policies in Namespace (e.g., `admin`)
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/policies/acl" | jq -S .data.keys
```

### Read Policy in Namespace (e.g., `platform-sre-read` in `admin/platform`)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/sys/policies/acl/platform-sre-read" | jq -S .data
```

### List Sentinel EGP/RGP Policies
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/policies/egp" | jq -S .

curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/policies/rgp" | jq -S .
```

## 6. Output Schema

### Per-Namespace `policies.json`
Saved to `discovered_terraform/raw/<namespace>/policies.json` (or `root/policies.json` for root):

```json
[
  {
    "name": "platform-sre-read",
    "namespace": "admin/platform",
    "policy_text": "path \"secret/data/platform/sre/*\" {\n  capabilities = [\"read\", \"list\"]\n}\n",
    "type": "acl"
  },
  {
    "name": "platform-devops-write",
    "namespace": "admin/platform",
    "policy_text": "path \"secret/data/platform/*\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]\n}\n",
    "type": "acl"
  }
]
```

### Coverage Record (`coverage.json`)
`LIST` on an empty EGP/RGP set returns 404, which is recorded as an empty list, not a failure.
```json
{
  "policies": {
    "acl_total": 10,
    "egp_policies": [],
    "rgp_policies": []
  }
}
```

### Reference implementation (validated against the harness)
Per namespace: `LIST sys/policies/acl`, drop built-ins, `GET` each, emit `{name, namespace, policy_text: .data.policy, type}`
sorted by name. Compare with `jq -j` (no trailing newline) when checking byte-for-byte against the API.
```bash
vget LIST "$ns" sys/policies/acl | jq -r '.data.keys[]? | select(. != "default" and . != "root" and . != "default-ceiling")' | LC_ALL=C sort
vget GET  "$ns" "sys/policies/acl/$n" | jq -c --arg ns "$ns" '.data | {name:.name,namespace:$ns,policy_text:.policy,type:"acl"}'
```

## 7. Deduplication & Namespace Scoping

- Policies are strictly scoped to their namespace. A policy named `read-only` in `admin/platform` and a policy named `read-only` in `admin/app-billing` are distinct objects.
- In downstream codification, resource labels are derived from both the namespace and policy name:
  - `admin/platform` + `platform-sre-read` → `vault_policy.admin_platform_platform_sre_read`
  - Root + `operator` → `vault_policy.root_operator`

## 8. Coding & Naming Standards

- **File Naming**: When codified into HCL files, policies over 10 lines will be emitted to `policies/<namespace>/<name>.hcl`.
- **String Handling**: Preserve literal newlines `\n` in JSON payloads; do not strip or trim document formatting.
- **Sorted Output**: Ensure all JSON files use sorted keys via `jq -S`.

## 9. Acceptance Criteria Checklist

- [ ] **AC-1 (CAP-006 AC1)**: Discovers exactly the 10 non-builtin ACL policies across namespaces:
  - Root: `operator`, `exporter` (2)
  - `admin`: `admin`, `namespace-admin` (2)
  - `admin/platform`: `platform-sre-read`, `platform-devops-write` (2)
  - `admin/app-billing`: `billing-developers-read`, `billing-owners-write` (2)
  - `admin/app-identity`: `identity-developers-read`, `identity-owners-write` (2)
- [ ] **AC-2 (CAP-006 AC1)**: Built-in policies `default`, `root` and `default-ceiling` are excluded from all output payloads.
- [ ] **AC-3 (CAP-006 AC2)**: Stored `policy_text` matches the live cluster API output byte-for-byte.
- [ ] **AC-4 (CAP-006 AC7)**: Path stanzas with namespace-relative paths (e.g. `secret/data/*`) are preserved without alterations.
- [ ] **AC-5 (CAP-006 AC8)**: EGP/RGP checks return "none" for the harness without causing errors.
- [ ] **AC-6 (CAC5)**: Two consecutive discovery runs produce byte-identical JSON payloads.

## 10. Stop Conditions & Failure Recovery

- **Fatal - Token Revocation**: If policy listing fails with HTTP 401 across all namespaces, abort and alert the operator.
- **Non-Fatal - Sentinel Endpoints 404/403**: Listing `sys/policies/egp` or `rgp` returning 404/403 is expected in standard environments; log and proceed.
- **Non-Fatal - Empty Policy Set**: A namespace with zero custom policies produces an empty JSON array `[]` without failing.

## 11. Related Skills

- [`vault-exporter-setup`](../vault-exporter-setup/SKILL.md) (TASK-031) — Grants policy read privileges.
- [`discovery-namespaces`](../discovery-namespaces/SKILL.md) (TASK-007) — Provides the namespace iteration list.
- [`discovery-identity-teams`](../discovery-identity-teams/SKILL.md) (TASK-012) — Correlates discovered policies to identity groups and entities.
- [`codification-policies`](../codification-policies/SKILL.md) (TASK-017) — Generates `vault_policy` HCL from these raw payloads.
