## 8. Acceptance criteria (harness)

- 9 `vault_identity_group` (3 `vault-<tenant>-admin` with
  `policies = ["namespace-admin"]`, 6 team groups with no policies), all in
  `admin`, `type = "internal"`.
- 6 `vault_identity_entity` named `synthetic-user-<tenant>-<team>`, each
  referenced exactly once by a team group's `member_entity_ids`.
- 0 aliases: no `identity_aliases.tf` exists.
- The UUID grep in section 6 prints `0`.
- `teams.md` lists platform -> sre, devops; app-billing/app-identity ->
  developers, owners, with inferred links labelled.
- 15 `import {}` blocks (9 + 6); fmt and validate pass.
- Scratch `oidc` + external group: one `type = "external"` group, one alias with
  `mount_accessor = vault_auth_backend.<label>.accessor`.
