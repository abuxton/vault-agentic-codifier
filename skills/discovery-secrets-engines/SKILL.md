---
name: discovery-secrets-engines
description: >
  Use when you need to enumerate every secrets engine mount across all namespaces, capturing mount metadata,
  tuning, and engine-specific configuration. Never reads secret data paths. Run after exporter setup, then codify.
  USE FOR: secrets engine discovery; mount discovery. DO NOT USE FOR: writing Terraform (use the matching
  codification-* skill), or any write to Vault.
metadata:
  task: "TASK-011"
  capability: "CAP-004"
  role: "vault-expert"
  depends_on: "vault-exporter-setup (TASK-031), discovery-namespaces (TASK-007)"
  version: "1.0"
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
| Exporter token issued (TASK-031) | `vault token lookup -format=json \| jq -r .data.display_name` shows the exporter alias (never print the token) |
| `VAULT_ADDR` reachable | `vault status` |
| `discovered_terraform/raw/namespaces.json` exists (TASK-007) | `test -s discovered_terraform/raw/namespaces.json` |
| `jq` and `curl` installed | `command -v jq curl` |

---

## Process

For each namespace `NS` in `namespaces.json` (include the root-level `admin` and all children):

1. `GET /v1/sys/mounts` with `X-Vault-Namespace: NS`. Drop keys in the skip list. Remaining keys are the mounts.
2. For each mount `M`: `GET /v1/sys/mounts/<M>/tune`.
3. Dispatch on `type` and read engine config:

> Table moved verbatim: see [engine-dispatch-table](references/engine-dispatch-table.md).

4. Strip volatile fields, redact sensitive fields, then write `discovered_terraform/raw/<NS>/secrets_engines.json` via `jq -S`.
5. On any non-200 append to the run report and continue.
## Stop conditions

- Exporter token is root/operator or lookup fails with 403/permission denied on self.
- `namespaces.json` missing or empty.
- Any attempted request would target `/data/` or `/metadata/`: abort that request, fail the run.
- Sensitive value detected in a payload after redaction.
- Non-200 (403/404/empty) on a single endpoint is NOT a stop condition; log and continue.

---

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Built-in mount skip list](references/built-in-mount-skip-list.md)
- [Sensitive field strip table](references/sensitive-field-strip-table.md)
- [Output schema](references/output-schema.md)
- [Zero TTL handling](references/zero-ttl-handling.md)
- [Coding standards](references/coding-standards.md)
- [Acceptance criteria](references/acceptance-criteria.md)
- [Related skills](references/related-skills.md)
- [Exact curl commands (KV v2, the harness type)](references/exact-curl-commands-kv-v2-the-harness-type.md)
- [engine-dispatch-table](references/engine-dispatch-table.md)
