## 6. Coding standards applied

1. Provenance header on every `.tf` file.
2. Provider pin `hashicorp/vault ~> 4`, `>= "1.9"`, `skip_child_token = true`.
3. Label `<namespace>/<path>` -> `admin_platform_secret`; `r_` prefix for
   digit-leading.
4. One namespace targeting style per run.
5. Secret guard: sensitive variables, no defaults.
6. Ownership: mounts and engine config only.
7. `import {}` for every `vault_mount` and engine resource.
8. Zero TTLs omitted.
9. Engine resources reference `vault_mount.<label>.path`.
10. No mounts in a namespace -> no file.
11. `terraform fmt -check -recursive` and `terraform validate` pass.
