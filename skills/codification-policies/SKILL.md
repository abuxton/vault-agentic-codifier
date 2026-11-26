---
name: codification-policies
description: >
  Use when you need to read per-namespace policies.json and generate vault_policy resources, policy HCL files, a
  policy correlation matrix (machine and human readable) and an EGP/RGP coverage report. Run after discovery, then
  validate. USE FOR: generate policy terraform; policy codification. DO NOT USE FOR: reading Vault (use the
  matching discovery-* skill), or applying the generated Terraform.
metadata:
  task: "TASK-017"
  capability: "CAP-006"
  role: "solution-architect"
  depends_on: "discovery-policies (TASK-010), codification-namespaces (TASK-015), vault-codifier-conventions (TASK-002, TASK-003, TASK-004), task-006-decision (TASK-006, done)"
  version: "1.0"
---

# Codification: Policies

## 1. Purpose

Generate one `vault_policy` per ACL policy in every discovered namespace and
produce a correlation matrix that shows which auth roles, identity groups and
identity entities reference each policy. The matrix is also emitted as JSON so
`codification-teams` can consume it.

Input: `discovered_terraform/raw/<namespace>/policies.json` and `sentinel.json` (plus
`auth_mounts.json` and `identity.json` for correlation, read-only).
Output: `discovered_terraform/terraform/<layer>/policies.tf`, `imports.tf`,
`policies/<namespace>/<name>.hcl`, `<ns>_sentinel.tf`, `imports_sentinel.tf`,
`policies/sentinel/<namespace>/<kind>-<name>.sentinel`, `policies/correlation.md`,
`policies/correlation.json`, `policies/coverage.md`.

## 2. Governance

- **Ownership**: only `vault_policy`, `vault_egp_policy` and `vault_rgp_policy` are emitted. No auth backend, role, mount,
  namespace or identity resources.
- Policies are placed in the layer matching their namespace: root -> `admin/`,
  `admin` -> `admin/`, tenant namespaces -> `seed/`.
- Policy bodies are copied verbatim. Namespace-relative `path` stanzas (for
  example `secret/data/platform/sre/*`) are never rewritten.
- Correlation is read-only analysis: no policy is fabricated for a dangling
  reference.
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

1. `policies.json` exists for every namespace listed in `namespaces.json`.
2. `auth_mounts.json` and `identity.json` exist for correlation (missing ->
   mark the affected column "unavailable", do not fail).
3. `vault-codifier-conventions` read; Terraform MCP reachable for schema lookups.
4. `terraform` available.

## 4. Process

1. **Load** each namespace's `policies.json` (`name`, `policy` text).
2. **Skip** `default`, `root` and `default-ceiling` (Vault 2.x built-in).
3. **Choose body style by line count** of the policy text:
   - More than 10 lines: write `policies/<namespace>/<name>.hcl` (namespace with
     `/` normalised to `_`) and emit
     `policy = file("${path.module}/policies/<namespace>/<name>.hcl")`.
   - 10 lines or fewer: emit a heredoc `policy = <<-EOT ... EOT`.
4. **Generate** `vault_policy` with `name` and `policy`; apply the namespace
   targeting style chosen for the run.
5. **Import blocks** per policy (section 5).
6. **Correlate**: for each policy, find (a) auth roles whose `token_policies` /
   `policies` list it, (b) identity groups and (c) entities that list it. A
   reference to a policy not in the same namespace's set is `dangling` and is
   marked as such. Write `correlation.md` (policy x auth role, identity group,
   entity, per namespace) and `correlation.json`.
7. **Sentinel** (CAP-008): emit one `vault_egp_policy` or `vault_rgp_policy` per `sentinel.json` entry with `name`,
   `enforcement_level`, `paths` (EGP, Vault's order) and `policy = file(...)`. The source always goes to a
   `.sentinel` file, byte-for-byte. Import id is the bare name.
8. **Coverage**: `coverage.md` lists the EGP/RGP names, a per-namespace count ("none" where empty) and a table of
   enforcement level and paths; "none discovered" if empty.
9. Prepend provenance header (`Capability: policies`); run fmt and validate.

## 8. Stop conditions

- A `policies.json` is unreadable or lacks `policy` text for a listed name.
- Two policies in one layer normalise to the same label.
- TASK-006 import ID table is unavailable and the format cannot be determined:
  stop and ask rather than guess.
- A policy name contains characters that cannot form a safe file name.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Example and import ID format](references/example-and-import-id-format.md)
- [Coding standards applied](references/coding-standards-applied.md)
- [Acceptance criteria (harness)](references/acceptance-criteria-harness.md)
- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
