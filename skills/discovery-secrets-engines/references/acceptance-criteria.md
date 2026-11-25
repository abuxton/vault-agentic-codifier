## Acceptance criteria

- [ ] `admin` has 0 mounts after the skip list; `secrets_engines.json` is written (mounts `[]`) without error.
- [ ] Root, `admin/platform`, `admin/app-billing`, `admin/app-identity` each have exactly one KV v2 mount `secret/`.
- [ ] No `agent-registry/` mount appears in any output.
- [ ] No request path matches `/data/` or `/metadata/` (check the audit log and the run report).
- [ ] `grep -r SYNTHETIC discovered_terraform/raw/` returns nothing.
- [ ] No unredacted `password`, `secret_key`, `credentials`, `private_key`, `client_secret` values in output.
- [ ] Skip-list mounts are absent from `mounts`.
- [ ] Two consecutive runs produce byte-identical files (`diff -r`).
- [ ] Every non-200 is recorded as `{"endpoint","namespace","http_status","skipped":true}`.

---
