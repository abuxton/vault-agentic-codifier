## 6. Coding standards applied

1. Provenance header on every `.tf` file.
2. Provider pin `hashicorp/vault ~> 4`, `>= "1.9"`, `skip_child_token = true`.
3. Labels from `<namespace>/<path>/<name>`, `/` and `-` -> `_`; `r_` prefix for
   digits.
4. One namespace targeting style per run; never mixed.
5. Secret guard (section 2); no `role_id`, no `secret_id`.
6. Ownership: auth resources only.
7. Every backend and role has an `import {}` block.
8. Zero TTL values are omitted (not emitted as `0`).
9. Same-namespace policies referenced as `vault_policy.<label>.name`.
10. No mounts in a namespace -> no file.
11. `terraform fmt -check -recursive` and `terraform validate` pass.

All TTL values are integer seconds unless the provider argument is a duration
string (`tune {}`), in which case the generator converts and documents it.
