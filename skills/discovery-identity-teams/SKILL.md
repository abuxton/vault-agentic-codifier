---
name: discovery-identity-teams
description: >
  Use when you need to enumerate identity groups, entities, and aliases in every namespace and map alias mount
  accessors to auth mount paths using Never persists tokens or secret values. Run after exporter setup, then
  codify. USE FOR: identity discovery; teams discovery. DO NOT USE FOR: writing Terraform (use the matching
  codification-* skill), or any write to Vault.
metadata:
  task: "TASK-012"
  capability: "CAP-007"
  role: "vault-expert"
  depends_on: "vault-exporter-setup (TASK-031), discovery-namespaces (TASK-007), discovery-auth-mounts (TASK-010)"
  version: "1.0"
---

# Discovery: Identity and Teams (TASK-012, CAP-007 `teams`)

> **Tool choice.** This skill uses the `vault` CLI, `curl` and `jq` with the exporter token.
> The Vault MCP server cannot serve it: it has no namespace, auth, policy, identity,
> quota or `sys/*` read tools, and it exposes write tools. See `vault-codifier-conventions`
> section 1. Optional cross-check: Vault MCP `list_mounts` against `sys/mounts`.

## Purpose

Enumerate identity **groups**, **entities**, **group aliases**, and **entity aliases**
in each namespace, and build an `accessor -> {namespace, path, type}` map from
the TASK-010 auth mount payloads so each alias is annotated with the auth mount
path it belongs to. Groups are the codified "teams".

Doc source (cite in every generated file): `https://developer.hashicorp.com/vault/docs`

---

## Governance

Shared rules:

1. NEVER use a root/operator token. Use the exporter AppRole token from `vault-exporter-setup`.
2. ONLY `GET` and `LIST`. No writes.
3. NEVER read `*/data/*` or `*/metadata/*` KV paths.
4. NEVER log tokens.
5. 403 / 404 / empty = non-fatal; log to the run report.
6. Raw JSON stored with `jq -S` under `discovered_terraform/raw/<namespace>/`.
7. Two runs byte-identical: strip `request_id`, `lease_id`, `renewable`, `lease_duration`.
8. Provenance header citing `https://developer.hashicorp.com/vault/docs` on every generated file.
9. Sensitive values -> `variable` references with no default; never to disk.
10. Naming: `<namespace>/<path>/<name>`, `/` and `-` -> `_`, valid Terraform identifier.

Additional rules for this skill:

- Group and entity **IDs are lookup keys only**. They are used to resolve `member_entity_ids` to names during discovery and must never appear as literals in generated HCL (the only exception is `imports.tf`).
- Accessor values come **only** from TASK-010 `auth_mounts.json`. Never obtain accessors from the identity API and never hard-code them.
- Use `LIST .../name` endpoints (not `.../id`) for groups and entities so ordering is by name and stable.

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
| `namespaces.json` (TASK-007) | `test -s discovered_terraform/raw/namespaces.json` |
| `auth_mounts.json` (TASK-010) exists for every namespace to be scanned | `ls discovered_terraform/raw/*/auth_mounts.json` |
| `jq`, `curl` | `command -v jq curl` |

If a namespace has no `auth_mounts.json`, aliases there cannot be resolved: set `mount_path: null` and log it, do not fail.

---

## Process

Run in `admin` and every child namespace from `namespaces.json`. Send `X-Vault-Namespace: <NS>` on every call.

1. **Groups**: `LIST /v1/identity/group/name`. For each name: `GET /v1/identity/group/name/<name>`; keep `name`, `type`, `policies`, `member_entity_ids`, `member_group_ids`, `metadata`. Add `namespace`.
2. **Entities**: `LIST /v1/identity/entity/name`. For each: `GET /v1/identity/entity/name/<name>`; keep `name`, `policies`, `metadata`, `disabled`. Add `namespace`.
3. **Group aliases**: `LIST /v1/identity/group-alias/id`. For each id: `GET /v1/identity/group-alias/id/<id>`; keep `id` (the import ID), `name`, `mount_accessor`, `canonical_id`.
4. **Entity aliases**: `LIST /v1/identity/entity-alias/id`. For each id: `GET /v1/identity/entity-alias/id/<id>`; keep `id` (the import ID), `name`, `mount_accessor`, `canonical_id`.
5. **Accessor resolution**: load every `discovered_terraform/raw/*/auth_mounts.json`; build `accessor_map = {accessor: {namespace, path, type}}`. Annotate each alias with `mount_path`, `mount_type` from that map.
6. **ID to name resolution**: replace `member_entity_ids` / `member_group_ids` / `canonical_id` with sibling names in a parallel field (`member_entity_names`, `member_group_names`, `canonical_name`); keep raw ids only for `imports.tf` generation.
7. Strip volatile keys, `jq -S`, write `discovered_terraform/raw/<NS>/identity.json` only if at least one object exists.
## Stop conditions

- Token is root/operator, or exporter token expired (401/403 on token self-lookup).
- `namespaces.json` missing.
- `auth_mounts.json` missing for `admin` (TASK-010 incomplete): stop and run TASK-010 first.
- Single-endpoint 403/404 is non-fatal.

---

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Output schema](references/output-schema.md)
- [Empty-set handling](references/empty-set-handling.md)
- [Harness expectations](references/harness-expectations.md)
- [Coding standards](references/coding-standards.md)
- [Acceptance criteria](references/acceptance-criteria.md)
- [Related skills](references/related-skills.md)
- [Exact curl commands](references/exact-curl-commands.md)
