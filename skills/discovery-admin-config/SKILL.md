---
name: discovery-admin-config
description: >
  Use when you need org-level discovery for the admin namespace per HVD layering: namespace metadata, human versus
  machine auth methods, and operator policy and group classification that reuses earlier payloads. Run after
  exporter setup, then codify. USE FOR: admin config discovery; admin namespace discovery. DO NOT USE FOR: writing
  Terraform (use the matching codification-* skill), or any write to Vault.
metadata:
  task: "TASK-013"
  capability: "CAP-002"
  role: "vault-expert"
  depends_on: "vault-exporter-setup (TASK-031), discovery-namespaces (TASK-007), discovery-auth-mounts (TASK-010), discovery-identity-teams (TASK-012)"
  version: "1.0"
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
| Exporter token active | `vault token lookup -format=json \| jq -r .data.display_name` |
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
## Stop conditions

- Token is root/operator or has expired.
- `policies.json`, `auth_mounts.json`, or `identity.json` missing for `admin`: stop and run TASK-009/010/012.
- A secret field cannot be redacted (unrecognised shape): fail rather than persist.
- 403/404 on `sys/namespaces/admin` is non-fatal: set `namespace_meta` to `null`, log, continue.

---

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Human vs machine auth detection](references/human-vs-machine-auth-detection.md)
- [Output schema](references/output-schema.md)
- [Sensitive field strip](references/sensitive-field-strip.md)
- [Harness expectation](references/harness-expectation.md)
- [Coding standards](references/coding-standards.md)
- [Acceptance criteria](references/acceptance-criteria.md)
- [Related skills](references/related-skills.md)
- [Exact curl commands](references/exact-curl-commands.md)
