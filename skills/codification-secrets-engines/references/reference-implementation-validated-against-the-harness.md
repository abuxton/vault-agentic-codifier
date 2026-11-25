## 9. Reference implementation (validated against the harness)

Run `skills/codification-secrets-engines/scripts/generate.sh [raw] [out-root]`.

- Layout: `admin/<ns>_secrets_engines.tf` + `admin/imports_secrets_engines.tf` (root and `admin`),
  `seed/...` (tenants), `secrets-engines/coverage.md`.
- Fully codified: `vault_mount` for every non-builtin mount and `vault_kv_secret_backend_v2` for KV v2.
  Every other type (PKI, database, AWS, transit, SSH, KV v1) gets `vault_mount` only and
  `coverage.md` flags it "review manually". The engine resources and sensitive variables listed in
  section 4 are not generated yet (variant fixtures, TASK-026).
- The harness has 4 mounts, not 3: the preloaded root `secret/` (KV v2, "key/value secret
  storage") is imported alongside the three tenant mounts. `admin` has none.
- TTLs: `default_lease_ttl_seconds` and `max_lease_ttl_seconds` are omitted when 0 or equal to the
  system default (2764800), because Vault reports the effective value for an untuned mount.
  Header lists are emitted only when non-empty. `plugin_version`, `seal_wrap` and `local` only when set.
- KV v2 config: `max_versions` (when > 0), `cas_required` (when true) and `delete_version_after`
  (when not `0s`). Harness values are all defaults, so the resource has only `mount`.
- Import IDs: mount = bare path (`secret`); KV v2 config = `secret/config`.
- Credential guard: exits 2 if the payload has a key named `password`, `secret_key`, `private_key`,
  `token` or `data`.

Validated: `fmt -check` and `validate` pass; `terraform plan` shows `14 to import` in `admin/` and
`18 to import` in `seed/`, with 0 add, 0 change, 0 destroy; second run byte-identical; grep for
`vault_kv_secret`, `vault_kv_secret_v2`, `vault_generic_secret`, `SYNTHETIC` and zero TTLs returns 0
(excluding `.terraform/`); a scratch `pki` mount with `plugin_version` and a 3600 s TTL is emitted
with both and flagged in `coverage.md`; a `password` key in a payload exits 2.
