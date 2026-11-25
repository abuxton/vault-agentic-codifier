## 4. Reference implementation (validated against the harness)

Harness: all three layers exit 0 in both passes, 31, 3 and 18 resources; capabilities `auth-mounts`,
`namespaces`, `policies`, `root-config`, `secrets-engines` and `teams` pass; `admin-config` declares none.
Six `ignore_changes` entries, each with a reason: `disable_remount` and `tune` on five `vault_auth_backend`
resources, and `name` on the sensitive exporter alias.

**A failure of the script itself, and its fix.** The first version flagged a non-import change but still ran
`apply`. The drift fixture (renaming the entity `exporter-agent` in the generated code) therefore renamed the
live entity to `exporter-agentx`. It was restored by hand and the script now returns before `apply`. The
fixture was re-run: it exits 1, names `vault_identity_entity.exporter_agent update`, and the entity is
unchanged before and after. Keep a before-and-after snapshot in any new destructive-looking fixture.

Faults checked: blanket `ignore_changes = all` (exit 1 before any work), drifted generated code (exit 1, Vault
unchanged).
