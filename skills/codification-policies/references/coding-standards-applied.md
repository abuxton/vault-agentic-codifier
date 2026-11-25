## 6. Coding standards applied

1. Provenance header on every `.tf`; `.hcl` policy files are verbatim bodies
   without a header.
2. Provider pin `hashicorp/vault ~> 4`, `>= "1.9"`, `skip_child_token = true`.
3. Labels from `<namespace>/<path>/<name>` with `/` and `-` -> `_`;
   `r_` prefix when digit-leading.
4. One namespace targeting style per run (alias or `namespace` argument).
5. Secret guard: policy text is reviewed for embedded secrets; none expected.
6. Ownership: `vault_policy` only.
7. `import {}` for every policy in the layer's `imports.tf`.
8. Zero-TTL omission: not applicable.
9. Cross-references: correlation outputs use labels; `vault_policy.<label>.name`
   is the reference form other skills use.
10. Empty set: namespace with no non-builtin policies emits no `policies.tf`.
11. `terraform fmt -check -recursive` and `terraform validate` pass.
