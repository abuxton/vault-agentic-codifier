---
name: codification-root-config
description: >
  Use when you need to read root-namespace system payloads (sys/audit, quotas, UI headers, license, seal,
  replication) and generate vault_audit and vault_quota_* resources, plus a "not managed by Terraform" README. Run
  after discovery, then validate. USE FOR: generate root config terraform; audit and quota codification. DO NOT
  USE FOR: reading Vault (use the matching discovery-* skill), or applying the generated Terraform.
metadata:
  task: "TASK-016"
  capability: "CAP-001"
  role: "solution-architect"
  depends_on: "discovery-root-config (TASK-008), vault-codifier-conventions (TASK-002, TASK-003, TASK-004)"
  version: "1.0"
---

# Codification: Root Config

## 1. Purpose

Turn raw root-namespace payloads into Terraform for the objects Terraform can
own at cluster level: audit devices and resource quotas. Anything that is
configured outside the API (seal type, licence, replication mode) is documented
in a README table with the reason it cannot be codified.

Input: `discovered_terraform/raw/root/`
Output: layer `admin/` under `discovered_terraform/terraform/admin/`, containing
`audit.tf`, `quotas.tf`, `imports_root_config.tf` and `root_config_README.md`
(flat files, so they sit beside the namespaces output; other capabilities own `imports.tf`).
`sys_config.tf` and `replication.tf` are not generated (see section 10).

## 2. Governance

- **Resource ownership.** This skill emits only `vault_audit`,
  `vault_quota_rate_limit`, `vault_quota_lease_count`, and
  `vault_generic_endpoint` for system endpoints that have no dedicated resource.
- It must NOT emit `vault_policy`, `vault_auth_backend`, `vault_mount`,
  `vault_namespace` or `vault_identity_*`. The root `operator` policy belongs to
  `codification-policies`.
- **Secret guard.** Never write licence text, root tokens, or masked audit
  option values. Record licence ID and expiry only.
- **No fabrication.** Audit options that Vault masks or omits (for example
  `hmac_accessor`) are not invented.
- All rules in `vault-codifier-conventions` apply (tool selection, secret guard, naming, header, layers).
- **Schema lookup (Terraform MCP).** Before emitting each resource type, call the
  Terraform MCP (`search_providers` / `get_provider_details` for `hashicorp/vault`
  `4.8.0`) to confirm argument names and the import syntax. Use the doc URL it
  returns in the file header. If it disagrees with `task-006-decision.md`, stop
  and report it (see `vault-codifier-conventions` section 1).
  If the Terraform MCP binary is not installed, fall back to
  `https://raw.githubusercontent.com/hashicorp/terraform-provider-vault/v4.8.0/website/docs/r/<resource>.html.md`
  and record the fallback in the run notes.

## 3. Prerequisites

1. `discovered_terraform/raw/root/` exists with at least `sys_audit.json`.
2. Optional payloads: `sys_quotas_rate_limit.json`, `sys_quotas_lease_count.json`,
   `sys_config_ui_headers.json`, `sys_seal_status.json`, `sys_license_status.json`,
   `sys_replication_status.json`.
3. `vault-codifier-conventions` read; Terraform MCP reachable for schema lookups.
4. `terraform` available for validation.

## 4. Process

1. **Load** payloads. A missing optional file (403/404 recorded by discovery) is
   treated as an empty set and noted in the run report, not an error. Only a
   failed `sys/audit` read is fatal.
2. **`root/audit.tf`** - one `vault_audit` per device in `sys_audit.json`.
   `type` from the payload, `path` from the map key (trailing `/` stripped),
   `description` only when non-empty, `local` only when `true`, `options` copied
   as returned. Import: `id = "<path>"` (for example `file`).
3. **`root/quotas.tf`** - one `vault_quota_rate_limit` per rate-limit quota with
   `name`, `path` (emitted even when `""`), `rate`, `interval`, `block_interval`.
   Emit `vault_quota_lease_count` (`name`, `path`, `max_leases`) only when
   present. Import: `id = "<quota name>"`.
4. **`root/sys_config.tf`** - `vault_generic_endpoint` only for endpoints with no
   dedicated provider resource (for example `sys/config/ui/headers/<name>`).
   Set `disable_read = false`; add `lifecycle { ignore_changes = [data_json] }`
   only where Vault redacts the read response.
5. **`root/replication.tf`** - only when `sys_replication_status.json` reports
   replication enabled (`performance` or `dr` mode not `disabled`). Otherwise do
   not create the file; record "replication disabled" in the README.
6. **`root/README.md`** - a "Not managed by Terraform" table:

   | Item | Value discovered | Why not codified |
   |---|---|---|
   | Seal type | from `sys/seal-status` | Set in the server config file, not the API |
   | Licence | ID and expiry only, never text | Auto-loaded from file/env at start |
   | Replication mode | from `sys/replication/status` | Enabled by operator workflow, secrets in activation tokens |

   Also state "no audit devices" if `sys/audit` was empty.
7. **`root/imports.tf`** - one `import {}` block per resource above.
8. Prepend the provenance header (`Capability: root-config`) to each `.tf`
   file; run `terraform fmt -check -recursive` and `terraform validate`.

## 7. Stop conditions

- `sys/audit` read failed (not merely empty): stop, exit non-zero.
- Raw payload contains licence text in a field about to be written: stop and
  report the field name (never print its value).
- Two quotas or audit devices normalise to the same label.
- Generated output would contain a resource type owned by another capability.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Example HCL (harness)](references/example-hcl-harness.md)
- [Acceptance criteria](references/acceptance-criteria.md)
- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
