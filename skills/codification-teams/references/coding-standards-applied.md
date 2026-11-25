## 7. Coding standards applied

1. Provenance header on every `.tf`.
2. Provider pin `hashicorp/vault ~> 4`, `>= "1.9"`, `skip_child_token = true`.
3. Labels `<namespace>/<name>` with `/` and `-` -> `_`; `r_` prefix for digits.
4. One namespace targeting style per run.
5. Secret guard: no secrets exist on identity resources; reject any in payload.
6. Ownership: `vault_identity_*` only.
7. Imports for every group, entity and alias.
8. Zero-TTL omission: not applicable.
9. All entity/accessor/canonical references via resource references.
10. Empty alias lists -> no alias file.
11. `terraform fmt -check -recursive` and `terraform validate` pass.
