# Teams: how identity is codified

- Group membership uses `member_entity_ids` on `vault_identity_group` (exclusive). Each entity is
  referenced from exactly one group. Switch to `vault_identity_group_member_entity_ids` with
  `exclusive = false` only if several Terraform configurations manage one group.
- `member_entity_ids`, `canonical_id` and `mount_accessor` are resource references. UUIDs appear only in
  `imports_identity.tf`.
- An alias whose name is a UUID (an AppRole `role_id`) is a sensitive variable `<label>_name` with no
  default. Supply it at plan time (`TF_VAR_<label>_name`).
- Inferred policy links are documented in `teams.md` and `teams.json` only.
