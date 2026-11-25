---
name: codification-teams
description: >
  Use when you need to read identity.json and auth_mounts.json and generate vault_identity_group,
  vault_identity_entity and alias resources with resource references (never UUID literals), plus a team-to-access
  matrix. Run after discovery, then validate. USE FOR: generate identity terraform; teams codification. DO NOT USE
  FOR: reading Vault (use the matching discovery-* skill), or applying the generated Terraform.
metadata:
  task: "TASK-020"
  capability: "CAP-007"
  role: "solution-architect"
  depends_on: "discovery-identity (TASK-012), codification-policies (TASK-017), codification-auth-mounts (TASK-018), vault-codifier-conventions (TASK-002, TASK-003, TASK-004)"
  version: "1.0"
---

# Codification: Teams

## 1. Purpose

Map organisational teams to Vault identity constructs: emit
`vault_identity_group`, `vault_identity_entity`, `vault_identity_group_alias`
and `vault_identity_entity_alias`, and produce a team-to-access matrix so
reviewers can see who can do what.

Input: `discovered_terraform/raw/<namespace>/identity.json`,
`auth_mounts.json`, and `policies/correlation.json` from
`codification-policies`.
Output: `discovered_terraform/terraform/namespaces/` (`identity_groups.tf`,
`identity_entities.tf`, `identity_aliases.tf` when non-empty, `imports.tf`),
`teams/teams.md`, `teams/teams.json`, `teams/README.md`.

## 2. Governance

- **Ownership**: `vault_identity_*` are owned here only.
- **No UUID literals in `.tf` files except `imports.tf`.** `member_entity_ids`
  is always `[vault_identity_entity.<label>.id]`; `canonical_id` is always a
  resource reference.
- **`mount_accessor` is always `vault_auth_backend.<label>.accessor`**, resolved
  from the accessor -> label map built from `auth_mounts.json`. Accessor strings
  never appear literally. If an accessor cannot be resolved, stop.
- External groups carry no `member_entity_ids`.
- Inferred policy links are never written into Terraform; they exist only in
  `teams.md` / `teams.json`, marked "inferred".
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

1. `identity.json` per namespace (groups, entities, group aliases, entity aliases).
2. `auth_mounts.json` per namespace (accessor, path, type).
3. `policies/correlation.json` (policy -> roles/groups/entities).
4. `vault-codifier-conventions` read; Terraform MCP reachable for schema lookups.

## 4. Process

1. **Build the accessor map**: `accessor -> vault_auth_backend.<label>` using the
   same labels `codification-auth-mounts` generated.
2. **Entities**: one `vault_identity_entity` per entity with `name`, `policies`
   (when non-empty), `metadata` (when non-empty), `disabled` only when `true`.
3. **Groups**: one `vault_identity_group` with `name`, `type`, `policies`,
   `metadata`. For `internal` groups, `member_entity_ids` is a list of entity
   references (sorted by label for stable output). External groups: none.
4. **Membership choice**: use `member_entity_ids` on the group (exclusive
   membership) when groups own their members; use
   `vault_identity_group_member_entity_ids` with `exclusive = false` only when
   several Terraform configs manage one group. Default is the group argument.
   Document the choice in `teams/README.md`.
5. **Aliases**: `vault_identity_group_alias` (`name`, `mount_accessor`,
   `canonical_id = vault_identity_group.<label>.id`) and
   `vault_identity_entity_alias` with the same pattern. If the alias list is
   empty, create **no** alias file.
6. **Matrix**: `teams/teams.md` columns team -> namespace -> group -> entities
   -> auth roles -> policies. Namespace is derived from the `tenant` metadata
   key. Policies recorded on the group in Vault are "recorded"; policies found
   by matching names in the tenant namespace (via `correlation.json`) are
   "inferred". Emit the same data as `teams/teams.json`.
7. **Imports**: IDs from `identity.json` (the only place UUIDs are written).
8. Provenance header (`Capability: teams`), fmt, validate.

## 9. Stop conditions

- An alias `mount_accessor` is not in the accessor map.
- A group member entity id is not in `identity.json`.
- Entity or group label collision in a layer.
- A UUID would be written to a non-import file.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Example HCL (harness)](references/example-hcl-harness.md)
- [UUID prohibition and policy-link provenance](references/uuid-prohibition-and-policy-link-provenance.md)
- [Coding standards applied](references/coding-standards-applied.md)
- [Acceptance criteria (harness)](references/acceptance-criteria-harness.md)
- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
