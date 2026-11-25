---
name: codification-secrets-engines
description: >
  Use when you need to read per-namespace mounts.json and generate vault_mount plus engine-specific configuration
  resources (KV v2, PKI, database, AWS, transit, SSH). Never emits secret data. Run after discovery, then
  validate. USE FOR: generate secrets engine terraform; mount codification. DO NOT USE FOR: reading Vault (use the
  matching discovery-* skill), or applying the generated Terraform.
metadata:
  task: "TASK-019"
  capability: "CAP-004"
  role: "solution-architect"
  depends_on: "discovery-secrets-engines (TASK-011), vault-codifier-conventions (TASK-002, TASK-003, TASK-004), task-006-decision (TASK-006, done)"
  version: "1.0"
---

# Codification: Secrets Engines

## 1. Purpose

Generate `vault_mount` for every non-builtin secrets engine in every namespace,
plus the engine-specific configuration resources that Vault returns on read.
Secret **data** (KV contents, credentials, private keys) is never read or
emitted.

Input: `discovered_terraform/raw/<namespace>/mounts.json` and per-engine config
payloads (`kv_config.json`, `pki_*.json`, `database_*.json`, ...).
Output: `discovered_terraform/terraform/seed/` (`secrets_<namespace>.tf`),
`imports.tf`, `secrets-engines/coverage.md`.

## 2. Governance

- **NEVER emit** `vault_kv_secret_v2`, `vault_kv_secret` or
  `vault_generic_secret`. Only configuration resources are allowed.
- **Ownership**: `vault_mount` and engine config resources belong to this skill.
  No policies, auth backends, namespaces or identity objects.
- **Secret guard**: database `password`, AWS `secret_key`, Azure/GCP
  credentials, PKI private keys -> `variable "<label>_<field>" { sensitive =
  true }`, no default. No string `SYNTHETIC-` may appear in output.
- **Skipped built-ins**: `sys/`, `identity/`, `cubbyhole/`.
- A preloaded root `secret/` mount (Vault dev mode) is emitted once with a note
  in `coverage.md`; if absent, no root mount is emitted.
- All rules in `vault-codifier-conventions` apply (tool selection, secret guard, naming, header, layers).
- **Schema lookup (Terraform MCP).** Before emitting each resource type, call the
  Terraform MCP (`search_providers` / `get_provider_details` for `hashicorp/vault`
  `4.8.0`) to confirm argument names and the import syntax. Use the doc URL it
  returns in the file header. If it disagrees with `task-006-decision.md`, stop
  and report it (see `vault-codifier-conventions` section 1).
  If the Terraform MCP binary is not installed, fall back to the provider docs at
  `https://raw.githubusercontent.com/hashicorp/terraform-provider-vault/v4.8.0/website/docs/r/<resource>.html.md`
  and record the fallback in the run notes.

## 3. Prerequisites

1. `mounts.json` per namespace from `GET /v1/sys/mounts` plus
   `sys/mounts/<path>/tune`.
2. Engine config payloads where applicable (read-only, non-secret fields).
3. `vault-codifier-conventions` read; Terraform MCP reachable; TASK-006 import ID table (`task-006-decision.md`) available.

## 4. Process

For each namespace and each non-built-in mount:

1. **`vault_mount`**: `path` (trailing `/` stripped), `type`, `description`
   when non-empty, `options` as returned (KV v2 keeps `version = "2"`),
   `default_lease_ttl_seconds` / `max_lease_ttl_seconds` when **non-zero**,
   `seal_wrap` / `local` only when `true`, `plugin_version` only when pinned in
   Vault. Emit `type = "kv"` with `options = { version = "2" }` for KV v2.
2. **Engine-specific resources** by type:
   - KV v2 -> `vault_kv_secret_backend_v2` (`max_versions`, `cas_required`,
     `delete_version_after`).
   - PKI -> `vault_pki_secret_backend_config_urls`,
     `vault_pki_secret_backend_role`.
   - Database -> `vault_database_secret_backend_connection` (password ->
     sensitive variable), `vault_database_secret_backend_role`.
   - AWS -> `vault_aws_secret_backend`, `vault_aws_secret_backend_role`;
     `secret_key` -> sensitive variable.
   - Transit -> `vault_transit_secret_backend_key` (metadata only, no key
     material).
   - SSH -> `vault_ssh_secret_backend_role`.
   - Other types -> `vault_mount` only, listed in `coverage.md` as "mount only".
3. **Implicit dependency**: every engine resource sets
   `mount = vault_mount.<label>.path` so Terraform orders mount first.
4. **Imports**: `id = "<mount path>"` for mounts (namespace prefix per the
   TASK-006 table); engine resources use the provider's documented ID form,
   e.g. KV v2 config `id = "<mount path>/config"`.
5. **Coverage**: `coverage.md` lists each mount, resource type used or fallback.
6. Provenance header (`Capability: secrets-engines`), fmt, validate.

## 8. Stop conditions

- A payload field marked sensitive by Vault holds a non-masked value: stop,
  report the field name.
- Mount type is known but its engine config read failed with 403: record in
  `coverage.md`, emit `vault_mount` only, continue.
- Label collision in a layer, or an engine resource without a matching mount.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Example HCL: KV v2 in `admin/platform`](references/example-hcl-kv-v2-in-admin-platform.md)
- [Coding standards applied](references/coding-standards-applied.md)
- [Acceptance criteria (harness)](references/acceptance-criteria-harness.md)
- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
