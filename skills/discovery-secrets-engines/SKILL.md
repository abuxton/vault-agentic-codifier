---
name: discovery-secrets-engines
description: >
  Enumerate every secrets engine mount across all namespaces, capturing mount
  metadata, tuning, and engine-specific configuration. Never reads secret data
  paths. TASK-011.
triggers:
  - "secrets engine discovery"
  - "mount discovery"
  - "TASK-011"
capability: CAP-004
task: TASK-011
depends_on:
  - vault-exporter-setup (TASK-031)
  - discovery-namespaces (TASK-007)
role: vault-expert
---

# Discovery: Secrets Engines (TASK-011, CAP-004 `secrets-engines`)

> **Tool choice.** This skill uses the `vault` CLI, `curl` and `jq` with the exporter token.
> The Vault MCP server cannot serve it: it has no namespace, auth, policy, identity,
> quota or `sys/*` read tools, and it exposes write tools. See `vault-codifier-conventions`
> section 1. Optional cross-check: Vault MCP `list_mounts` against `sys/mounts`.

## Purpose

Enumerate every secrets engine mount in every namespace discovered by TASK-007
and capture, per mount: path, type, description, mount options, tuning
(TTLs, headers, listing visibility) and engine-specific **configuration**.
Configuration is read; secret **data** never is.

Doc source (cite in every generated file): `https://developer.hashicorp.com/vault/docs`

---

## Governance

Shared rules (apply to every discovery skill):

1. NEVER use a root/operator token. Use the exporter AppRole token from `vault-exporter-setup`.
2. ONLY `GET` and `LIST` requests. No writes.
3. NEVER read `*/data/*` or `*/metadata/*` KV paths.
4. NEVER log tokens (no `set -x`, no `curl -v`, no echoing headers).
5. 403 / 404 / empty = non-fatal. Append to the run report and continue.
6. Store raw JSON with sorted keys (`jq -S`) under `discovered_terraform/raw/<namespace>/`.
7. Two runs must be byte-identical: strip `request_id`, `lease_id`, `renewable`, `lease_duration`.
8. Every generated file carries a provenance header citing `https://developer.hashicorp.com/vault/docs`.
9. Sensitive values become `variable` references with no default; never written to disk.
10. Naming: `<namespace>/<path>/<name>`, with `/` and `-` replaced by `_`; must be a valid Terraform identifier.

Additional rules for this skill:

- NEVER issue `GET <mount>/data/*` or `<mount>/metadata/*`.
- NEVER persist password-bearing fields from `<mount>/config/root` or `<mount>/config/<name>`; redact (see strip table).
- ALWAYS skip `sys/`, `identity/`, `cubbyhole/`, `token/` (built-in skip list).

Always set before any CLI/curl call:

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN="${EXPORTER_TOKEN}"   # NEVER root
```

---

## Prerequisites

| Requirement | Check |
|---|---|
| Exporter token issued (TASK-031) | `/opt/homebrew/bin/vault token lookup -format=json \| jq -r .data.display_name` shows the exporter alias (never print the token) |
| `VAULT_ADDR` reachable | `/opt/homebrew/bin/vault status` |
| `discovered_terraform/raw/namespaces.json` exists (TASK-007) | `test -s discovered_terraform/raw/namespaces.json` |
| `jq` and `curl` installed | `command -v jq curl` |

---

## Process

For each namespace `NS` in `namespaces.json` (include the root-level `admin` and all children):

1. `GET /v1/sys/mounts` with `X-Vault-Namespace: NS`. Drop keys in the skip list. Remaining keys are the mounts.
2. For each mount `M`: `GET /v1/sys/mounts/<M>/tune`.
3. Dispatch on `type` and read engine config:

| Engine type | Requests | Notes |
|---|---|---|
| `kv` (version 2) | `GET /v1/<M>/config` | Keep `max_versions`, `cas_required`, `delete_version_after`. Never touch `data/` or `metadata/`. |
| `pki` | `GET /v1/<M>/config/urls`, `GET /v1/<M>/config/crl`, `LIST /v1/<M>/roles` then `GET /v1/<M>/roles/<name>` | No `/cert/*`, no `/issuer/*/pem`, no key export. |
| `database` | `LIST /v1/<M>/config` then `GET /v1/<M>/config/<name>`; `LIST /v1/<M>/roles` then `GET /v1/<M>/roles/<name>` | Strip `password`, and any password inside `connection_details`. |
| `aws`, `azure`, `gcp` | `GET /v1/<M>/config/root` | Non-secret fields only; strip `secret_key`, `credentials`, `client_secret`. |
| `transit` | `LIST /v1/<M>/keys` then `GET /v1/<M>/keys/<name>` | Metadata only. Drop the `keys` map (key material/public keys). |
| `ssh` | `LIST /v1/<M>/roles` then `GET /v1/<M>/roles/<name>` | No `/config/ca` private key (only public key exists, still skip). |
| other | none | Capture mount metadata + tune only. Add to `coverage` with `resource_type: null` and a `fallback` note. |

4. Strip volatile fields, redact sensitive fields, then write `discovered_terraform/raw/<NS>/secrets_engines.json` via `jq -S`.
5. On any non-200 append to the run report and continue.

### Exact curl commands (KV v2, the harness type)

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN="${EXPORTER_TOKEN}"
NS="admin/app-billing"; M="secret"
STRIP='del(.request_id,.lease_id,.renewable,.lease_duration)'

vget() {  # usage: vget <namespace> <path> <outfile>; echoes HTTP status
  curl -sS -o "$3.raw" -w '%{http_code}' \
    -H "X-Vault-Token: ${VAULT_TOKEN}" -H "X-Vault-Namespace: $1" \
    "${VAULT_ADDR}/v1/$2"
}

# 1. List mounts
vget "$NS" "sys/mounts" /tmp/mounts
jq -S "$STRIP" /tmp/mounts.raw > /tmp/mounts.json

# 2. Per-mount tune
vget "$NS" "sys/mounts/${M}/tune" /tmp/tune
jq -S "$STRIP" /tmp/tune.raw > /tmp/tune.json

# 3. KV v2 engine config (ONLY config; never data/ or metadata/)
vget "$NS" "${M}/config" /tmp/kvconfig
jq -S "$STRIP" /tmp/kvconfig.raw > /tmp/kvconfig.json
```

Never place the token in a URL or in a logged command line; the header is read from the environment.

---

## Built-in mount skip list

`sys/`, `identity/`, `cubbyhole/`, `token/`, and any mount whose **type** is `agent_registry`,
`ns_agent_registry`, `system`, `identity`, `cubbyhole`, `ns_system`, `ns_identity` or `ns_cubbyhole`.
Vault 2.x mounts an `agent-registry/` engine (type `agent_registry`, `ns_agent_registry` in namespaces)
in every namespace; it is built in, so match on type as well as path.

Validated against the harness (Vault 2.2.2+ent): the exporter reads `sys/mounts`, `sys/mounts/<m>/tune`
and `<m>/config` for KV v2 with no 403s and no `data/` or `metadata/` requests. The root namespace also
has the dev-mode `secret/` KV v2 mount; it is real cluster state and is discovered like any other mount.
A mount that was never tuned reports `0` TTLs here (system default), unlike auth mounts.

---

## Sensitive field strip table

| Field | Where it appears | Replacement in stored JSON |
|---|---|---|
| `password` | database `config/<name>`, `connection_details` | `"REDACTED-sensitive-variable-required"` |
| `secret_key` | aws `config/root` | `"REDACTED-sensitive-variable-required"` |
| `credentials` | gcp `config/root` | `"REDACTED-sensitive-variable-required"` |
| `private_key` | any engine config | `"REDACTED-sensitive-variable-required"` |
| `client_secret` | azure `config/root` | `"REDACTED-sensitive-variable-required"` |

The generator turns each redacted field into a `variable` with no default (rule 9).

---

## Output schema

`discovered_terraform/raw/<namespace>/secrets_engines.json`:

```json
{
  "mounts": [
    {
      "path": "secret/",
      "type": "kv",
      "description": "",
      "options": {"version": "2"},
      "tune": {"default_lease_ttl": 0, "max_lease_ttl": 0},
      "engine_config": {"max_versions": 0, "cas_required": false, "delete_version_after": "0s"}
    }
  ],
  "coverage": [
    {"path": "secret/", "type": "kv", "resource_type": "vault_mount + vault_kv_secret_backend_v2", "fallback": null}
  ]
}
```

Unknown engine types appear in `coverage` with `resource_type: null` and `fallback: "mount metadata only"`.

---

## Zero TTL handling

Capture the raw value `0` for `default_lease_ttl` and `max_lease_ttl` exactly as returned. `0` means "use system default"; the generator omits the attribute when the value is `0`. Do not substitute system defaults in the raw payload.

---

## Coding standards

- Bash with `set -euo pipefail`, but wrap each request so a non-200 does not abort the run.
- One helper (`vget`) for all requests; no ad-hoc `curl` calls.
- Always `jq -S`; sort `mounts` by `path` and `coverage` by `path` (`jq -S '.mounts|=sort_by(.path)'`).
- No timestamps, hostnames, or random IDs in raw output.
- Use full tool paths in non-interactive shells: `/opt/homebrew/bin/vault`, `/opt/homebrew/bin/terraform`.

---

## Acceptance criteria

- [ ] `admin` has 0 mounts after the skip list; `secrets_engines.json` is written (mounts `[]`) without error.
- [ ] Root, `admin/platform`, `admin/app-billing`, `admin/app-identity` each have exactly one KV v2 mount `secret/`.
- [ ] No `agent-registry/` mount appears in any output.
- [ ] No request path matches `/data/` or `/metadata/` (check the audit log and the run report).
- [ ] `grep -r SYNTHETIC discovered_terraform/raw/` returns nothing.
- [ ] No unredacted `password`, `secret_key`, `credentials`, `private_key`, `client_secret` values in output.
- [ ] Skip-list mounts are absent from `mounts`.
- [ ] Two consecutive runs produce byte-identical files (`diff -r`).
- [ ] Every non-200 is recorded as `{"endpoint","namespace","http_status","skipped":true}`.

---

## Stop conditions

- Exporter token is root/operator or lookup fails with 403/permission denied on self.
- `namespaces.json` missing or empty.
- Any attempted request would target `/data/` or `/metadata/`: abort that request, fail the run.
- Sensitive value detected in a payload after redaction.
- Non-200 (403/404/empty) on a single endpoint is NOT a stop condition; log and continue.

---

## Related skills

- `vault-exporter-setup` (TASK-031) - token provisioning.
- `discovery-namespaces` (TASK-007) - namespace list input.
- `discovery-auth-mounts` (TASK-010) - sibling mount discovery for auth.
- `discovery-orchestrator` (TASK-014) - runs this skill in order.
