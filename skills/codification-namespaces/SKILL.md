---
name: codification-namespaces
description: >
  Use when you need to read namespaces.json (from discovery-namespaces) and generate vault_namespace resources
  with correct parent-child references, import blocks, and a Mermaid hierarchy diagram. Run after discovery, then
  validate. USE FOR: generate namespace terraform; namespace codification. DO NOT USE FOR: reading Vault (use the
  matching discovery-* skill), or applying the generated Terraform.
metadata:
  task: "TASK-015"
  capability: "CAP-005"
  role: "solution-architect"
  depends_on: "discovery-namespaces (TASK-007), vault-codifier-conventions (TASK-002, TASK-003, TASK-004)"
  version: "1.0"
---

# Codification: Namespaces

## 1. Purpose

Transform the raw namespace inventory captured by `discovery-namespaces` into
idiomatic Terraform HCL. The skill emits one `vault_namespace` resource per
discovered namespace, wires children to parents with resource references (never
string paths), emits one `import {}` block per resource, and renders a Mermaid
hierarchy diagram plus a reference table for reviewers.

Input: `discovered_terraform/raw/namespaces.json`
Output: `discovered_terraform/terraform/admin/` (the `admin` namespace) and
`discovered_terraform/terraform/namespaces/` (tenant namespaces), plus
`namespaces/hierarchy.md`.

## 3. Prerequisites

1. `discovered_terraform/raw/namespaces.json` exists and parses as JSON. If it
   is missing, stop and ask the user to run `discovery-namespaces` (TASK-007).
2. `vault-codifier-conventions` read; Terraform MCP reachable for schema lookups.
3. Provider and naming rules come from the conventions skill (sections 5 and 7).
4. `terraform` is present for the validation step.

## 4. Process

1. **Load** `discovered_terraform/raw/namespaces.json`. Each record carries
   `path` (full path), `id`, `custom_metadata`.
2. **Compute depth** as the number of `/`-separated segments in the full path
   (`admin` = 1, `admin/platform` = 2). Drop the root namespace.
3. **Detect cycles / orphans.** Build the parent map (`parent = dirname(path)`).
   Every parent other than the root must itself be in the set. A missing parent
   or a cycle triggers a stop condition (section 9).
4. **Sort by depth ascending**, then alphabetically, so parents are always
   emitted before children.
5. **Generate one `vault_namespace` block per namespace:**
   - Depth 1: `path = "<segment>"`, default provider, no `namespace` argument.
   - Depth >= 2: `path = "<last segment>"` and
     `provider = vault.<parent_alias>`, where the alias maps to the parent's
     full path (`admin/platform` for a depth-3 child).
   - Emit `custom_metadata = { ... }` **only** when the map is non-empty.
   - Label = conventions section 5 applied to the full path (`admin/app-billing` ->
     `admin_app_billing`).
6. **Generate `import {}` blocks** in `imports.tf` of the same layer:
   `to = vault_namespace.<label>`, `id = "<leaf name>"`, emitted under the
   provider alias of the parent namespace (TASK-006: a full path such as
   `admin/platform` fails with HTTP 400). Depth 1 uses the root provider.
7. **Generate `namespaces/hierarchy.md`** with a Mermaid `graph TD` tree and a
   table with columns: full path, parent, id, custom_metadata, depth.
8. **Add the provenance header** to every `.tf` file and run
   `terraform fmt -check -recursive` and `terraform validate`.

## 9. Stop conditions

- **Cycle detected** in the parent map: stop, print the cycle members, write
  nothing.
- **Orphan detected** (parent not in the set and not root): stop and report the
  missing parent; do not fabricate a `vault_namespace` for it.
- `namespaces.json` missing or invalid JSON.
- Two namespaces normalise to the same Terraform label: stop and report both
  paths (CAC6, label uniqueness).

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Governance](references/governance.md)
- [Example HCL output (harness)](references/example-hcl-output-harness.md)
- [Example `namespaces/hierarchy.md` (harness)](references/example-namespaces-hierarchy-md-harness.md)
- [Coding standards applied](references/coding-standards-applied.md)
- [Acceptance criteria](references/acceptance-criteria.md)
- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
