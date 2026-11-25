## 7. Coding standards applied

| # | Standard | How it applies here |
|---|---|---|
| 1 | Provenance header | Every `.tf` file starts with the 4-line header, `Capability: namespaces` |
| 2 | Provider pin | `hashicorp/vault ~> 4`, `required_version >= "1.9"`, `skip_child_token = true` from TASK-002 |
| 3 | Naming | `admin/app-billing` -> `admin_app_billing`; `r_` prefix for digit-leading labels |
| 4 | Namespace targeting | One style per run; default `aliased` (TASK-006). Examples use `provider = vault.<parent_alias>`; under `resource` style use `namespace = ...` instead and set `TERRAFORM_VAULT_NAMESPACE_IMPORT` for imports. Never mixed |
| 5 | Secret guard | No secret-bearing fields exist on `vault_namespace` |
| 6 | Ownership | Only `vault_namespace` is emitted |
| 7 | Import blocks | One per resource in the layer's `imports.tf` |
| 8 | Zero-TTL omission | Not applicable |
| 9 | Cross-references | Child -> parent via provider alias (or `depends_on` in the same layer) |
| 10 | Empty set | If only the root namespace exists, emit no files and report "no namespaces" |
| 11 | Validation | `terraform fmt -check -recursive` and `terraform validate` must pass |
