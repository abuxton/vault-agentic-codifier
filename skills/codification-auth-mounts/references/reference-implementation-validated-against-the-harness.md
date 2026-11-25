## 9. Reference implementation (validated against the harness)

Run `skills/codification-auth-mounts/scripts/generate.sh [raw] [out-root]`.

- Layout: `admin/<ns>_auth_mounts.tf` + `admin/imports_auth_mounts.tf` (root and `admin`),
  `seed/...` (tenants), `auth-mounts/coverage.md`.
- Fully codified: `vault_auth_backend` and `vault_approle_auth_backend_role`. Any other mount type
  gets `vault_auth_backend` only; `coverage.md` flags it "review manually". Method resources for
  OIDC/JWT, LDAP, Kubernetes, AWS and cert are not generated yet (variant fixtures, TASK-026).
- Roles reference `vault_policy.<label>.name` when the policy is in the same namespace's
  `policies.json`; otherwise a literal and a note in `coverage.md`.
- `tune {}` is emitted only when it deviates from the untuned default (32 days = 2764800 s, type
  `default-service`). Durations are `"<n>s"` strings; role TTLs are integer seconds.
- **Provider 4.8.0 import gotchas.** After import, `disable_remount` is unset and `tune` is
  empty in state, so the plan shows an in-place change. The generator adds
  `lifecycle { ignore_changes = [disable_remount, tune] }` for untuned mounts and
  `[disable_remount]` when a `tune {}` block is emitted. Result: `0 to change`.
- Credential guard: the generator exits 2 if the payload has a key exactly named `role_id`,
  `secret_id` or `secret_id_accessor`. Names such as `secret_id_ttl` and `bind_secret_id` are
  configuration and pass.

Validated: `fmt -check` and `validate` pass; `terraform plan` shows `12 to import, 0 to change`
in each of `admin/` and `seed/` (mounts, roles, and the earlier policies, namespace, audit and
quota); second run byte-identical; a `userpass` mount with a tuned config is emitted as the
backend with `tune {}` and flagged in `coverage.md`; a `role_id` key in a payload exits 2.
