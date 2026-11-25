---
name: discovery-auth-mounts
description: >
  Use when you need to enumerate all authentication method mounts across all namespaces, capture mount metadata,
  tuning, and method-specific role and group configurations, strictly avoiding credential and secret paths. Run
  after exporter setup, then codify. USE FOR: discover auth mounts; auth mount discovery. DO NOT USE FOR: writing
  Terraform (use the matching codification-* skill), or any write to Vault.
metadata:
  task: "TASK-010"
  capability: "CAP-003"
  role: "vault-expert"
  depends_on: "vault-exporter-setup (TASK-031), discovery-namespaces (TASK-007)"
  version: "1.0"
---

# Auth Mounts Discovery Skill (`discovery-auth-mounts`)

> **Tool choice.** This skill uses the `vault` CLI, `curl` and `jq` with the exporter token.
> The Vault MCP server cannot serve it: it has no namespace, auth, policy, identity,
> quota or `sys/*` read tools, and it exposes write tools. See `vault-codifier-conventions`
> section 1. Optional cross-check: Vault MCP `list_mounts` against `sys/mounts`.

This skill discovers all enabled authentication backends, their tuning parameters, and associated role/group configurations across all namespaces. It captures non-sensitive configuration data for Terraform generation (`vault_auth_backend`, `vault_approle_auth_backend_role`, etc.) while strictly preventing any read of credential endpoints.

## 1. Purpose

Authentication backends control how identities authenticate to Vault. This skill inventories auth mounts across all namespaces, extracts configuration and role definitions (e.g. token policies, TTLs, CIDR restrictions), preserves mount accessors for identity alias resolution (TASK-012), and produces raw payloads in `discovered_terraform/raw/<namespace>/auth_mounts.json`.

## 2. Governance Rules

The following non-negotiable governance rules apply:
1. **Authentication**: Use ONLY the exporter AppRole token (`${EXPORTER_TOKEN}`).
2. **Read-Only**: Issue ONLY `GET` and `LIST` requests.
3. **STRICT CREDENTIAL PROHIBITION**: NEVER call `auth/<path>/role/<name>/role-id`, `auth/<path>/role/<name>/secret-id`, `auth/<path>/secret-id-accessor/lookup`, or any credential generation/lookup endpoints. These paths are denied by the exporter policy and must be self-enforced.
4. **Skip Builtin Token Mount**: Always ignore and exclude the built-in `token/` mount.
5. **Strip Sensitive Fields**: Strip sensitive fields (`bindpass`, `client_secret`, `oidc_client_secret`) prior to saving JSON.
6. **Preserve Accessor IDs**: Preserve the `accessor` attribute on auth mounts to enable downstream identity group/entity alias mapping.
7. **Deterministic Storage**: Format output JSON with sorted keys (`jq -S`). Strip volatile fields (`request_id`, `lease_id`).
8. **Provenance**: Cite upstream HashiCorp documentation: `https://developer.hashicorp.com/vault/api-docs/system/auth` and `https://developer.hashicorp.com/vault/api-docs/auth`.

## 3. Prerequisites

| Prerequisite | Verification Command / Check | Purpose |
|---|---|---|
| Exporter Token | `test -n "${EXPORTER_TOKEN}"` | Authentication token with auth read permissions |
| Namespace Catalog | `test -f discovered_terraform/raw/namespaces.json` | List of discovered namespaces from TASK-007 |
| Output Directory | `mkdir -p discovered_terraform/raw/root` | Destination directories per namespace |
| CLI Binaries | `vault version`, `jq --version` | CLI utilities |
| Config Override | `export VAULT_CONFIG_PATH=/dev/null` | Ensure clean environment |

## 4. Discovery Process

```
[Start Auth Mount Discovery]
       │
       ▼
[1. Load Namespaces: Root ("") + entries from namespaces.json]
       │
       ▼
[2. For each namespace (set X-Vault-Namespace)]
       ├──► [GET /v1/sys/auth (List all mounts)]
       │       │
       │       ▼
       │    [Filter out 'token/' mount]
       │       │
       │       ▼
       │    [For each mount path]
       │       ├──► [GET /v1/sys/auth/<path>/tune (TTL / tuning)]
       │       └──► [Read Method-Specific Config]
       │               ├── approle: LIST roles + GET role/<name> (NO role-id/secret-id)
       │               ├── oidc/jwt: GET config + LIST roles + GET role/<name>
       │               ├── ldap: GET config (strip bindpass) + LIST groups + LIST users
       │               ├── kubernetes: GET config + LIST roles
       │               ├── aws: GET config/client + LIST roles
       │               ├── cert: LIST certs + GET certs/<name>
       │               └── fallback: Mark unhandled types as "unsupported"
       │
       ▼
[3. Write discovered_terraform/raw/<namespace>/auth_mounts.json via jq -S]
       │
       ▼
[4. Record coverage into coverage.json & non-200s into run_report.jsonl]
```
## 10. Stop Conditions & Failure Recovery

- **Warning - Accessor Missing**: If `accessor` is empty on a mount, issue a warning to the run report but continue.
- **Fatal - Auth Mount List Denied**: If `GET /v1/sys/auth` returns HTTP 403 on root, abort and verify exporter AppRole permissions.
- **Non-Fatal - Empty Role List**: If an auth mount has 0 roles defined, record `"roles": []` and proceed.

## 11. Related Skills

- `vault-exporter-setup` (TASK-031) — Configures exporter permissions for auth endpoints.
- `discovery-namespaces` (TASK-007) — Supplies namespace list.
- `discovery-identity-teams` (TASK-012) — Uses mount accessors to map group and entity aliases.
- `codification-auth-mounts` (TASK-018) — Generates Terraform HCL for auth mounts and roles.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Exact API & CLI Calls](references/exact-api-cli-calls.md)
- [Output Schema](references/output-schema.md)
- [Sensitive Field Stripping Table](references/sensitive-field-stripping-table.md)
- [Coding & Naming Standards](references/coding-naming-standards.md)
- [Acceptance Criteria Checklist](references/acceptance-criteria-checklist.md)
- [Detailed Steps](references/detailed-steps.md)
