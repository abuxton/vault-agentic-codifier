## 6. Namespace targeting and imports

Default style is `aliased` (ratified by TASK-006). Each namespace gets
`provider "vault" { alias = "<label>" namespace = "<full path>" }` and each
resource sets `provider = vault.<label>`.

`resource` style (`namespace = "..."` on the resource) is allowed only for a
single-namespace layer. With it, `import {}` plans a replacement unless
`TERRAFORM_VAULT_NAMESPACE_IMPORT` is set, which allows one namespace per plan.

Import IDs are relative to the provider's namespace and never namespace
prefixed. Full table: `openspec/changes/vault-brownfield-research/task-006-decision.md`.
