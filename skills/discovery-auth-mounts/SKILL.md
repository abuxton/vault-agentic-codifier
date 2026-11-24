---
name: discovery-auth-mounts
description: >
  Enumerate all authentication method mounts across all namespaces, capture mount
  metadata, tuning, and method-specific role and group configurations, strictly avoiding
  credential and secret paths. TASK-010 — covers CAP-003 (auth-mounts).
triggers:
  - "discover auth mounts"
  - "auth mount discovery"
  - "TASK-010"
capability: CAP-003
task: TASK-010
depends_on:
  - vault-exporter-setup (TASK-031)
  - discovery-namespaces (TASK-007)
role: vault-expert
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
| CLI Binaries | `/opt/homebrew/bin/vault version`, `jq --version` | CLI utilities |
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

### Detailed Steps

1. **Step 1: Iterate Namespaces**  
   Load root (`""`) and all tenant namespaces from `namespaces.json`.
2. **Step 2: List Auth Mounts (`GET /v1/sys/auth`)**  
   Fetch all auth backends. Filter out the default `token/` mount.
3. **Step 3: Capture Mount Tuning (`GET /v1/sys/auth/<path>/tune`)**  
   Fetch default and max lease TTLs for each mount.
4. **Step 4: Method-Specific Role/Config Extraction**  
   - **AppRole**: Call `LIST /v1/auth/<path>/role`. For each role name, call `GET /v1/auth/<path>/role/<name>` to retrieve `token_policies`, `token_ttl`, `token_max_ttl`, `secret_id_num_uses`, and `secret_id_ttl`. DO NOT query `role-id` or `secret-id`.
   - **OIDC/JWT**: Read `GET /v1/auth/<path>/config` and list/read roles. Strip any client secrets.
   - **LDAP**: Read `GET /v1/auth/<path>/config` (strip `bindpass`), list groups and users.
   - **Kubernetes / AWS / Cert**: Read respective config and roles.
   - **Other/Generic**: Capture mount metadata and tuning; mark role management as generic fallback.
5. **Step 5: Write Per-Namespace Payloads**  
   Output structured JSON to `discovered_terraform/raw/<namespace>/auth_mounts.json`.

## 5. Exact API & CLI Calls

### 1. AppRole Discovery (Harness Oracle)
```bash
# List auth mounts in namespace admin/platform
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/sys/auth" | jq -S .data

# Get mount tuning
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/sys/auth/approle/tune" | jq -S .data

# List AppRole roles
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/auth/approle/role" | jq -S .data.keys

# Read AppRole role definition (NEVER query role-id or secret-id)
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/auth/approle/role/platform-ci" | jq -S .data
```

### 2. OIDC / JWT Discovery
```bash
# Read OIDC configuration
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/auth/oidc/config" | jq -S 'del(.client_secret, .oidc_client_secret)'
```

### 3. LDAP Discovery
```bash
# Read LDAP configuration
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/auth/ldap/config" | jq -S 'del(.bindpass)'
```

## 6. Output Schema

The output payload is written to `discovered_terraform/raw/<namespace>/auth_mounts.json`:

```json
{
  "mounts": [
    {
      "path": "approle",
      "type": "approle",
      "accessor": "auth_approle_d1a2b3c4",
      "description": "AppRole auth backend for platform namespace",
      "local": false,
      "seal_wrap": false,
      "tune": {
        "default_lease_ttl": 0,
        "max_lease_ttl": 0
      },
      "roles": [
        {
          "name": "platform-ci",
          "token_policies": ["platform-devops-write"],
          "token_ttl": 3600,
          "token_max_ttl": 14400,
          "secret_id_num_uses": 1,
          "secret_id_ttl": 1800,
          "token_type": "default"
        }
      ]
    }
  ],
  "coverage": [
    {
      "path": "approle",
      "type": "approle",
      "resource_type": "vault_auth_backend",
      "role_resource_type": "vault_approle_auth_backend_role"
    }
  ]
}
```

## 7. Sensitive Field Stripping Table

| Endpoint / Backend | Sensitive Field Name | Handling Strategy |
|---|---|---|
| AppRole (`auth/approle/role/*`) | `role_id` | **NEVER QUERY** endpoint; omit unless user-pinned |
| AppRole (`auth/approle/role/*`) | `secret_id` | **NEVER QUERY** endpoint; never write to disk |
| LDAP (`auth/ldap/config`) | `bindpass` | Strip via `jq 'del(.bindpass)'`; emit variable ref |
| OIDC / JWT (`auth/oidc/config`) | `client_secret` | Strip via `jq 'del(.client_secret)'`; emit variable ref |
| Kubernetes (`auth/kubernetes/config`) | `token_reviewer_jwt` | Strip from raw json; emit variable ref |

## 8. Coding & Naming Standards

- **Terraform Resource Label Helper**: Normalise `<namespace>_<path>`:
  - `admin/platform` + `approle` mount → `vault_auth_backend.admin_platform_approle`
  - `admin/platform` + `platform-ci` role → `vault_approle_auth_backend_role.admin_platform_platform_ci`
- **Accessor Retention**: Keep exact `accessor` strings in the raw JSON payload so identity alias discovery (TASK-012) can resolve backend accessors without making extra API calls.

## 9. Acceptance Criteria Checklist

- [ ] **AC-1 (CAP-003 AC1)**: Discovers exactly 5 `approle` mounts (one per namespace: root, `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`). `token/` is skipped.
- [ ] **AC-2 (CAP-003 AC2)**: Discovers exactly 5 roles: `terraform-admin` (root), `namespace-provisioner` (`admin`), `platform-ci` (`admin/platform`), `billing-service` (`admin/app-billing`), `identity-service` (`admin/app-identity`).
- [ ] **AC-3 (CAP-003 AC3)**: Roles capture `token_ttl = 3600`, `token_max_ttl = 14400`, `secret_id_num_uses = 1`, and correct `secret_id_ttl` (900s for root/admin/billing/identity, 1800s for platform-ci).
- [ ] **AC-4 (CAP-003 AC5)**: Zero `role_id` or `secret_id` values appear in raw payloads.
- [ ] **AC-5 (CAP-003 AC6)**: `coverage` records all 5 mounts with `vault_auth_backend` and roles with `vault_approle_auth_backend_role`.
- [ ] **AC-6 (CAP-003 AC7)**: Unhandled auth types (e.g. `userpass`) are captured with mount metadata and flagged for fallback.

## 10. Stop Conditions & Failure Recovery

- **Warning - Accessor Missing**: If `accessor` is empty on a mount, issue a warning to the run report but continue.
- **Fatal - Auth Mount List Denied**: If `GET /v1/sys/auth` returns HTTP 403 on root, abort and verify exporter AppRole permissions.
- **Non-Fatal - Empty Role List**: If an auth mount has 0 roles defined, record `"roles": []` and proceed.

## 11. Related Skills

- [`vault-exporter-setup`](../vault-exporter-setup/SKILL.md) (TASK-031) — Configures exporter permissions for auth endpoints.
- [`discovery-namespaces`](../discovery-namespaces/SKILL.md) (TASK-007) — Supplies namespace list.
- [`discovery-identity-teams`](../discovery-identity-teams/SKILL.md) (TASK-012) — Uses mount accessors to map group and entity aliases.
- [`codification-auth-mounts`](../codification-auth-mounts/SKILL.md) (TASK-018) — Generates Terraform HCL for auth mounts and roles.
