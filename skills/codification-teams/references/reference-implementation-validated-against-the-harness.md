## 10. Reference implementation (validated against the harness)

Run `skills/codification-teams/scripts/generate.sh [raw] [out-root]` after the namespaces, root-config,
policies and auth-mounts generators.

- Layout: `admin/<ns>_identity.tf`, `admin/<ns>_identity_aliases.tf` (only when aliases exist) and
  `admin/imports_identity.tf` for root and `admin`; `seed/...` for tenants; `teams/teams.md`,
  `teams/teams.json`, `teams/README.md`. The generator writes to the `admin/` and `seed/` layers, not
  `namespaces/`, so that `vault_policy` and `vault_auth_backend` references resolve inside one state.
- Harness counts differ from section 8 because the root namespace is now covered: 7 entities (6 synthetic
  users plus root `exporter-agent`), 9 groups, 1 alias (the exporter's AppRole alias). `admin` has no alias
  file; `teams.md` says "No aliases found for `admin`".
- Policies are `vault_policy.<label>.name` references when the policy is codified in the same namespace,
  otherwise a literal. Policy links inferred from names (for example `platform-sre-read` for
  `vault-platform-sre`) are written to `teams.md` and `teams.json` only, with the text "inferred".
- An alias whose name is a UUID (the AppRole `role_id`) becomes `variable "<label>_name"` (sensitive, no
  default) and `lifecycle { ignore_changes = [name] }`, because provider 4.8.0 imports a sensitive name
  unmarked and plans an in-place change otherwise. Supply it with `TF_VAR_<label>_name`.
- Import IDs are the identity UUIDs. The alias `id` is now kept by discovery (`identity-teams.sh` and
  `discovery-identity-teams`), because `vault_identity_*_alias` imports by alias id.
- Credential guard: exits 2 on keys named `password`, `secret_id`, `token`, `client_secret` or `bindpass`.
  An unresolved `mount_accessor`, `canonical_id` or member id also exits 2.

Validated: fmt and validate pass; `terraform plan` shows `31 to import` in `admin/` and `18 to import` in
`seed/`, 0 add, 0 change, 0 destroy; second run byte-identical; the UUID grep in section 6 prints `0`;
a scratch `oidc` mount with an external group and group alias emits `type = "external"` and
`mount_accessor = vault_auth_backend.admin_oidc.accessor`; an unresolved accessor and a credential key
each exit 2.
