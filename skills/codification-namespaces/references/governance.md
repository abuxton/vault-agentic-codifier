## 2. Governance

All rules in `vault-codifier-conventions` apply. The table in section 7 shows
how they apply here. Additional rules specific to this skill:

- **Schema lookup (Terraform MCP).** Before emitting each resource type, call the
  Terraform MCP (`search_providers` / `get_provider_details` for `hashicorp/vault`
  `4.8.0`) to confirm argument names and the import syntax. Use the doc URL it
  returns in the file header. If it disagrees with `task-006-decision.md`, stop
  and report it (see `vault-codifier-conventions` section 1).
  If the Terraform MCP binary is not installed, fall back to the provider docs at
  `https://raw.githubusercontent.com/hashicorp/terraform-provider-vault/v4.8.0/website/docs/r/<resource>.html.md`
  and record the fallback in the run notes.


- **Root namespace is never emitted.** The root namespace (`""` / `root`) has no
  `vault_namespace` resource. Skip it even if present in `namespaces.json`.
- **Children are created through the parent's provider alias** (default
  `aliased` style, ratified by TASK-006): `provider = vault.admin`. A
  `namespace = "..."` argument or a literal parent path string such as `"admin"`
  or `"admin/"` inside a `vault_namespace` block is a defect. Resource-level
  `namespace` makes `import {}` plan a replacement, so it is only used when the
  run selects `--namespace-style resource`.
- **Ownership**: `vault_namespace` is owned by this skill only. Do not emit
  policies, mounts, auth backends or identity objects.
- **Layer placement**: `admin` goes to `admin/`; every other namespace goes to
  `namespaces/`. A child in `namespaces/` of a parent in `admin/` is a
  cross-layer dependency: the `namespaces/` layer declares
  `provider "vault" { alias = "admin" namespace = "admin" }` (conventions section 7), so no
  remote-state lookup is needed for the parent path.
