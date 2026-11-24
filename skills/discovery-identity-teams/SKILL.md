---
name: discovery-identity-teams
description: >
  Enumerate identity groups, entities, and aliases in every namespace and map
  alias mount accessors to auth mount paths using TASK-010 payloads. Never
  persists tokens or secret values. TASK-012.
triggers:
  - "identity discovery"
  - "teams discovery"
  - "TASK-012"
capability: CAP-007
task: TASK-012
depends_on:
  - vault-exporter-setup (TASK-031)
  - discovery-namespaces (TASK-007)
  - discovery-auth-mounts (TASK-010)
role: vault-expert
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
| Exporter token active | `/opt/homebrew/bin/vault token lookup -format=json \| jq -r .data.display_name` |
| `namespaces.json` (TASK-007) | `test -s discovered_terraform/raw/namespaces.json` |
| `auth_mounts.json` (TASK-010) exists for every namespace to be scanned | `ls discovered_terraform/raw/*/auth_mounts.json` |
| `jq`, `curl` | `command -v jq curl` |

If a namespace has no `auth_mounts.json`, aliases there cannot be resolved: set `mount_path: null` and log it, do not fail.

---

## Process

Run in `admin` and every child namespace from `namespaces.json`. Send `X-Vault-Namespace: <NS>` on every call.

1. **Groups**: `LIST /v1/identity/group/name`. For each name: `GET /v1/identity/group/name/<name>`; keep `name`, `type`, `policies`, `member_entity_ids`, `member_group_ids`, `metadata`. Add `namespace`.
2. **Entities**: `LIST /v1/identity/entity/name`. For each: `GET /v1/identity/entity/name/<name>`; keep `name`, `policies`, `metadata`, `disabled`. Add `namespace`.
3. **Group aliases**: `LIST /v1/identity/group-alias/id`. For each id: `GET /v1/identity/group-alias/id/<id>`; keep `name`, `mount_accessor`, `canonical_id`.
4. **Entity aliases**: `LIST /v1/identity/entity-alias/id`. For each id: `GET /v1/identity/entity-alias/id/<id>`; keep `name`, `mount_accessor`, `canonical_id`.
5. **Accessor resolution**: load every `discovered_terraform/raw/*/auth_mounts.json`; build `accessor_map = {accessor: {namespace, path, type}}`. Annotate each alias with `mount_path`, `mount_type` from that map.
6. **ID to name resolution**: replace `member_entity_ids` / `member_group_ids` / `canonical_id` with sibling names in a parallel field (`member_entity_names`, `member_group_names`, `canonical_name`); keep raw ids only for `imports.tf` generation.
7. Strip volatile keys, `jq -S`, write `discovered_terraform/raw/<NS>/identity.json` only if at least one object exists.

### Exact curl commands

```bash
NS="admin"
STRIP='del(.request_id,.lease_id,.renewable,.lease_duration)'

vreq() {  # usage: vreq <GET|LIST> <namespace> <path> <outfile>; echoes HTTP status
  curl -sS -X "$1" -o "$4" -w '%{http_code}' \
    -H "X-Vault-Token: ${VAULT_TOKEN}" -H "X-Vault-Namespace: $2" \
    "${VAULT_ADDR}/v1/$3"
}

# Groups
vreq LIST "$NS" identity/group/name /tmp/groups.raw
for g in $(jq -r '.data.keys[]?' /tmp/groups.raw); do
  vreq GET "$NS" "identity/group/name/${g}" "/tmp/group_${g}.raw"
  jq -S "$STRIP" "/tmp/group_${g}.raw" > "/tmp/group_${g}.json"
done

# Entities
vreq LIST "$NS" identity/entity/name /tmp/entities.raw
for e in $(jq -r '.data.keys[]?' /tmp/entities.raw); do
  vreq GET "$NS" "identity/entity/name/${e}" "/tmp/entity_${e}.raw"
  jq -S "$STRIP" "/tmp/entity_${e}.raw" > "/tmp/entity_${e}.json"
done
```

Never echo `VAULT_TOKEN`. Names containing spaces or `/` must be URL-encoded (`jq -rn --arg n "$g" '$n|@uri'`).

---

## Output schema

`discovered_terraform/raw/<namespace>/identity.json`:

```json
{
  "groups": [
    {"name": "", "type": "internal", "policies": [], "member_entity_ids": [],
     "member_group_ids": [], "metadata": {}, "namespace": "admin"}
  ],
  "entities": [
    {"name": "", "policies": [], "metadata": {}, "disabled": false, "namespace": "admin"}
  ],
  "group_aliases": [
    {"name": "", "mount_accessor": "", "mount_path": "", "mount_type": "", "canonical_id": ""}
  ],
  "entity_aliases": [
    {"name": "", "mount_accessor": "", "mount_path": "", "mount_type": "", "canonical_id": ""}
  ],
  "accessor_map": {"auth_approle_xxxx": {"namespace": "admin", "path": "approle/", "type": "approle"}}
}
```

Arrays are sorted by `name` (aliases by `mount_path`, then `name`). `accessor_map` keys are sorted by `jq -S`.

---

## Empty-set handling

- `LIST` returning 404 (Vault's "no keys") is not an error: treat as `[]` and do not log it as a failure beyond an informational run-report entry.
- Missing categories serialize as `[]`, never `null`.
- If a namespace has zero groups, entities, and aliases, **do not create** `identity.json` for it.

---

## Harness expectations

| Namespace | Groups | Entities | Group aliases | Entity aliases |
|---|---|---|---|---|
| root | 0 | 1 (`exporter-agent`) | 0 | 1 (approle, keyed on `role_id`) |
| `admin` | 9 | 6 | 0 | 0 |
| `admin/platform`, `admin/app-billing`, `admin/app-identity` | 0 | 0 | 0 | 0 (no file written) |

The root entity and alias exist once `vault-exporter-setup` has run. The alias `name` is the AppRole
`role_id` (a UUID that identifies the role, not a credential), so it is kept in the raw payload;
codification must emit it as a variable or `data` reference, not a literal.

Validated notes (harness, Vault 2.2.2+ent):
- `member_group_ids` and `metadata` come back as `null` when empty; normalise to `[]` / `{}` so downstream
  `length` checks do not fail.
- The group/entity `id` is kept in the raw payload (needed by `imports.tf`) but arrays of member names are
  resolved from it, so a codification skill never needs to print a UUID outside `imports.tf`.
- The exporter reads `identity/*` at root and in `admin` with no 403s, including entity and alias reads.

---

## Coding standards

- `set -euo pipefail` with per-request status handling so a 403/404 is logged, not fatal.
- Single `vreq` helper for all calls.
- `jq -S`, deterministic sort of every array; no timestamps or random ids in output.
- Full tool paths: `/opt/homebrew/bin/vault`, `/opt/homebrew/bin/terraform`.
- Run report line per non-200: `{"endpoint": "...", "namespace": "...", "http_status": NNN, "skipped": true}`.

---

## Acceptance criteria

- [ ] `admin/identity.json` contains 9 groups and 6 entities, 0 aliases.
- [ ] `root/identity.json` contains the `exporter-agent` entity and its 1 AppRole alias with `mount_path: "approle/"`.
- [ ] No `identity.json` exists for `admin/platform`, `admin/app-billing`, `admin/app-identity`.
- [ ] `accessor_map` covers every accessor in `auth_mounts.json` files; every alias (if any) has a non-null `mount_path`.
- [ ] No ID literal from group/entity appears outside raw JSON (grep generated `.tf` except `imports.tf`).
- [ ] No tokens or secret values present: `grep -r SYNTHETIC discovered_terraform/raw/` is empty.
- [ ] Two consecutive runs are byte-identical.
- [ ] Non-200 responses are listed in the run report.

---

## Stop conditions

- Token is root/operator, or exporter token expired (401/403 on token self-lookup).
- `namespaces.json` missing.
- `auth_mounts.json` missing for `admin` (TASK-010 incomplete): stop and run TASK-010 first.
- Single-endpoint 403/404 is non-fatal.

---

## Related skills

- `vault-exporter-setup` (TASK-031), `discovery-namespaces` (TASK-007), `discovery-auth-mounts` (TASK-010).
- `discovery-admin-config` (TASK-013) reuses this skill's `admin/identity.json`.
- `discovery-orchestrator` (TASK-014).
