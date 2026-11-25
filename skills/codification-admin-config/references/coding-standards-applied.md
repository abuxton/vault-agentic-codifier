## 7. Coding standards applied

1. Provenance header on every `.tf` file.
2. Provider pin `hashicorp/vault ~> 4`, `required_version >= "1.9"`,
   `skip_child_token = true` (see template; adjust the example constraint to
   match TASK-002 exactly).
3. Labels from `<namespace>/<path>/<name>` normalised to `_`.
4. One targeting style per run; the admin layer uses the provider alias.
5. Secret guard via sensitive variables, no defaults.
6. Ownership as in section 2.
7. Imports for every resource this skill declares.
8. Zero-TTL omission for any tune block.
9. Same-layer references use resource references, not literals.
10. Empty `human_auth_mounts` -> no `human_auth.tf`.
11. fmt and validate pass.
