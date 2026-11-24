---
name: discovery-admin-config
description: >
  Org-level discovery for the admin namespace per HVD layering: namespace
  metadata, human vs machine auth methods, and operator policy/group
  classification reusing earlier payloads. TASK-013.
triggers:
  - "admin config discovery"
  - "admin namespace discovery"
  - "TASK-013"
capability: CAP-002
task: TASK-013
depends_on:
  - vault-exporter-setup (TASK-031)
  - discovery-namespaces (TASK-007)
  - discovery-auth-mounts (TASK-010)
  - discovery-identity-teams (TASK-012)
role: vault-expert
---

# Discovery: Admin Namespace Config (TASK-013, CAP-002 `admin-config`)

> **Tool choice.** This skill uses the `vault` CLI, `curl` and `jq` with the exporter token.
> The Vault MCP server cannot serve it: it has no namespace, auth, policy, identity,
> quota or `sys/*` read tools, and it exposes write tools. See `vault-codifier-conventions`
> section 1. Optional cross-check: Vault MCP `list_mounts` against `sys/mounts`.

## Purpose

Discover what is specific to the `admin` (org-level) namespace under the HashiCorp
Validated Design layering: namespace metadata, how humans authenticate (OIDC,
LDAP, etc.) versus how machines authenticate, and which policies and identity
groups carry operator privileges. This skill cross-references payloads already
written by TASK-009 (policies) and TASK-012 (identity); it does not re-query them.

Doc source (cite in every generated file): `https://developer.hashicorp.com/vault/docs`

---

## Governance

Shared rules:

1. NEVER use a root/operator token; use the exporter AppRole token from `vault-exporter-setup`.
2. ONLY `GET` and `LIST`. No writes.
3. NEVER read `*/data/*` or `*/metadata/*` KV paths.
4. NEVER log tokens.
5. 403 / 404 / empty = non-fatal; log to run report.
6. Raw JSON stored with `jq -S` under `discovered_terraform/raw/<namespace>/`.
7. Two runs byte-identical: strip `request_id`, `lease_id`, `renewable`, `lease_duration`.
8. Provenance header citing `https://developer.hashicorp.com/vault/docs` on every generated file.
9. Sensitive values -> `variable` references with no default; never to disk.
10. Naming: `<namespace>/<path>/<name>`, `/` and `-` -> `_`, valid Terraform identifier.

Additional rules for this skill:

- NEVER read or persist an OIDC `oidc_client_secret` / `client_secret` or an LDAP `bindpass`.
- Detect human vs machine auth by mount `type` (table below); never infer from the mount path name.
- Reuse existing payloads (`policies.json`, `auth_mounts.json`, `identity.json`) from disk. Do NOT re-query policies or identity endpoints.

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN="${EXPORTER_TOKEN}"   # NEVER root
```

---

## Prerequisites

| Requirement | Check |
|---|---|
| Exporter token active | `/opt/homebrew/bin/vault token lookup -format=json \| jq -r .data.display_name` |
| `discovered_terraform/raw/admin/policies.json` (TASK-009) | `test -s ...` |
| `discovered_terraform/raw/admin/auth_mounts.json` (TASK-010) | `test -s ...` |
| `discovered_terraform/raw/admin/identity.json` (TASK-012) | `test -s ...` |
| `namespaces.json` lists `admin` (TASK-007) | `jq -e '.. \| strings \| select(.=="admin/")' ...` |

---

## Process

1. **Namespace metadata** (no namespace header): `GET /v1/sys/namespaces/admin`. Keep `id`, `path`, `custom_metadata`.
2. **Auth mounts** (`X-Vault-Namespace: admin`): `GET /v1/sys/auth`. (Alternatively read `admin/auth_mounts.json` if it already holds the mount list; prefer disk to avoid a duplicate call.) Classify each mount by `type`.
3. **Human auth config**, for each mount classified human:
   - `GET /v1/auth/<path>/config`; strip `client_secret`, `oidc_client_secret`, `bindpass`.
   - Role/group listing by type: `oidc`/`jwt` -> `LIST /v1/auth/<path>/role`; `ldap`/`okta` -> `LIST /v1/auth/<path>/groups`; `github` -> `LIST /v1/auth/<path>/map/teams`.
   - Per-item `GET` for each listed name; keep non-secret attributes (policies, bound claims, group mappings).
4. **Load from disk**: `admin/policies.json`, `admin/identity.json`. No further API calls for these.
5. **Classify operators**:
   - `operator_policies`: policy names matching `admin`, `operator`, or `namespace-admin` (case-insensitive, exact or hyphen/underscore-delimited token).
   - `operator_groups`: identity groups whose `policies` intersect `operator_policies`.
6. Strip volatile keys, `jq -S`, write `discovered_terraform/raw/admin/admin_config.json`.
7. If `human_auth_mounts` is empty, emit `"no human auth method detected"` to the run report (informational, not an error).

### Exact curl commands

```bash
STRIP='del(.request_id,.lease_id,.renewable,.lease_duration)'

# Namespace metadata: NO X-Vault-Namespace header
curl -sS -o /tmp/ns_admin.raw -w '%{http_code}' \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/namespaces/admin"
jq -S "$STRIP" /tmp/ns_admin.raw > /tmp/ns_admin.json

# Auth mount list inside admin
curl -sS -o /tmp/auth.raw -w '%{http_code}' \
  -H "X-Vault-Token: ${VAULT_TOKEN}" -H "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/auth"
jq -S "$STRIP" /tmp/auth.raw > /tmp/auth.json

# Human mount config (example: an OIDC mount at oidc/), then redact
curl -sS -o /tmp/oidc_cfg.raw -w '%{http_code}' \
  -H "X-Vault-Token: ${VAULT_TOKEN}" -H "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/auth/oidc/config"
jq -S "$STRIP | (.data | select(.) | .. | objects) |= with_entries(
  if (.key|test(\"client_secret|bindpass\")) then .value=\"REDACTED\" else . end)" \
  /tmp/oidc_cfg.raw > /tmp/oidc_cfg.json
```

---

## Human vs machine auth detection

| Mount `type` | Class | Config/read endpoint | Secret fields to strip |
|---|---|---|---|
| `oidc` | human | `auth/<p>/config`, `LIST auth/<p>/role` | `oidc_client_secret`, `client_secret` |
| `jwt` | human | `auth/<p>/config`, `LIST auth/<p>/role` | `jwt_validation_pubkeys` kept; `oidc_client_secret` stripped |
| `ldap` | human | `auth/<p>/config`, `LIST auth/<p>/groups` | `bindpass` |
| `github` | human | `auth/<p>/config`, `LIST auth/<p>/map/teams` | none expected |
| `okta` | human | `auth/<p>/config`, `LIST auth/<p>/groups` | `api_token` |
| `approle` | machine | none (roles covered by TASK-010) | - |
| `kubernetes` | machine | none | - |
| `aws` | machine | none | - |
| `cert` | machine | none | - |
| `token`, other | skipped / `unknown` | mount metadata only | - |

---

## Output schema

`discovered_terraform/raw/admin/admin_config.json`:

```json
{
  "namespace_meta": {"id": "", "path": "admin/", "custom_metadata": {}},
  "human_auth_mounts": [
    {"path": "", "type": "", "accessor": "", "config": {}, "roles_or_groups": []}
  ],
  "machine_auth_mounts": [{"path": "", "type": "", "accessor": ""}],
  "operator_policies": ["admin"],
  "operator_groups": [{"name": "", "policies": []}]
}
```

All arrays sorted by `path` or `name`. `namespace_meta.id` is a Vault-assigned lookup value; do not emit it as a literal in generated HCL (use only in `imports.tf`).

---

## Sensitive field strip

| Field | Replacement |
|---|---|
| `client_secret` | `"REDACTED"` |
| `oidc_client_secret` | `"REDACTED"` |
| `bindpass` | `"REDACTED"` |

The generator emits a `variable` with no default per redacted field (rule 9).

---

## Harness expectation

- `human_auth_mounts = []`; run report entry: `no human auth method detected`.
- `machine_auth_mounts` contains the `approle` mount(s) of `admin` (the harness has 5 approle mounts overall; only those in `admin` appear here).
- `operator_policies` contains the admin-type policies found in `admin/policies.json`; `operator_groups` lists the identity groups that hold them.

---

## Coding standards

- `set -euo pipefail`; per-request status check so 403/404 are logged and skipped.
- `jq -S`, sorted arrays, no timestamps or random ids.
- Prefer on-disk payloads to API calls; the only live calls are `sys/namespaces/admin`, `sys/auth` (if not on disk), and human-mount config.
- Full tool paths: `/opt/homebrew/bin/vault`, `/opt/homebrew/bin/terraform`.
- Non-200 -> run report `{"endpoint","namespace","http_status","skipped":true}`.

---

## Acceptance criteria

- [ ] `admin_config.json` exists under `discovered_terraform/raw/admin/` and validates against the schema above.
- [ ] Harness: `human_auth_mounts` is `[]` and the informational message was emitted.
- [ ] No `client_secret`, `oidc_client_secret`, or `bindpass` value appears anywhere in the output.
- [ ] No live calls to `identity/` or `sys/policies/` were made (check the audit log).
- [ ] Two consecutive runs are byte-identical.
- [ ] `grep -r SYNTHETIC discovered_terraform/raw/` is empty.

---

## Stop conditions

- Token is root/operator or has expired.
- `policies.json`, `auth_mounts.json`, or `identity.json` missing for `admin`: stop and run TASK-009/010/012.
- A secret field cannot be redacted (unrecognised shape): fail rather than persist.
- 403/404 on `sys/namespaces/admin` is non-fatal: set `namespace_meta` to `null`, log, continue.

---

## Related skills

`vault-exporter-setup` (TASK-031), `discovery-namespaces` (TASK-007), `discovery-auth-mounts` (TASK-010), `discovery-identity-teams` (TASK-012), `discovery-orchestrator` (TASK-014).
