---
name: discovery-policies
description: >
  Use when you need to enumerate all ACL policies across root and all discovered namespaces, store verbatim HCL
  policy documents, and check Enterprise Sentinel EGP/RGP policies for coverage. Run after exporter setup, then
  codify. USE FOR: discover policies; policy discovery. DO NOT USE FOR: writing Terraform (use the matching
  codification-* skill), or any write to Vault.
metadata:
  task: "TASK-009"
  capability: "CAP-006"
  role: "vault-expert"
  depends_on: "vault-exporter-setup (TASK-031), discovery-namespaces (TASK-007)"
  version: "1.0"
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
6. **Graceful Handling of Sentinel (EGP/RGP)**: On non-Enterprise editions or when permissions are missing, log 403/404 to the run report and record "none" / "unavailable" in coverage. Where the list answers 200, `GET` each policy and store its body (CAP-008).
7. **Deterministic Storage**: Format output JSON with sorted keys (`jq -S`).
8. **Provenance**: Cite upstream HashiCorp documentation: `https://developer.hashicorp.com/vault/api-docs/system/policies` and `https://developer.hashicorp.com/vault/docs/concepts/policies`.

## 3. Prerequisites

| Prerequisite | Verification Command / Check | Purpose |
|---|---|---|
| Exporter Token | `test -n "${EXPORTER_TOKEN}"` | Authentication token with policy read access |
| Namespace Catalog | `test -f discovered_terraform/raw/namespaces.json` | Input list of namespaces from TASK-007 |
| Output Dirs | `mkdir -p discovered_terraform/raw/root` | Output directories per namespace |
| CLI Binaries | `vault version`, `jq --version` | CLI utilities for querying and formatting |
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
       │       └──► [GET /v1/sys/policies/<egp|rgp>/<name> for each name]
       │
       ▼
[3. Write <namespace>/policies.json and <namespace>/sentinel.json via jq -S]
       │
       ▼
[4. Append Sentinel findings to discovered_terraform/raw/coverage.json]
       │
       ▼
[5. Log non-200 responses to discovered_terraform/raw/run_report.jsonl]
```
## 10. Stop Conditions & Failure Recovery

- **Fatal - Token Revocation**: If policy listing fails with HTTP 401 across all namespaces, abort and alert the operator.
- **Non-Fatal - Sentinel Endpoints 404/403**: Listing `sys/policies/egp` or `rgp` returning 404/403 is expected in standard environments; log and proceed.
- **Non-Fatal - Empty Policy Set**: A namespace with zero custom policies produces an empty JSON array `[]` without failing.

## 11. Related Skills

- `vault-exporter-setup` (TASK-031) — Grants policy read privileges.
- `discovery-namespaces` (TASK-007) — Provides the namespace iteration list.
- `discovery-identity-teams` (TASK-012) — Correlates discovered policies to identity groups and entities.
- `codification-policies` (TASK-017) — Generates `vault_policy` HCL from these raw payloads.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Exact API & CLI Calls](references/exact-api-cli-calls.md)
- [Output Schema](references/output-schema.md)
- [Deduplication & Namespace Scoping](references/deduplication-namespace-scoping.md)
- [Coding & Naming Standards](references/coding-naming-standards.md)
- [Acceptance Criteria Checklist](references/acceptance-criteria-checklist.md)
- [Detailed Steps](references/detailed-steps.md)
