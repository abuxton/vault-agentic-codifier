## Acceptance Criteria Checklist

Before marking TASK-031 complete, verify all of the following against the test
harness (`make -C test up && make -C test seed`):

- [ ] `test/terraform/admin/policies/exporter.hcl` exists and `terraform validate` returns no errors.
- [ ] `terraform apply` in `test/terraform/admin/` succeeds with zero diff on a second run (idempotent).
- [ ] The exporter AppRole token can run `vault auth list` and `vault namespace list` from root (exit 0).
- [ ] The exporter AppRole token receives HTTP 403 on `vault kv get -mount=secret billing-service/checkout -namespace=admin/app-billing`.
- [ ] `vault identity entity list` shows `exporter-agent`.
- [ ] The exporter token can `vault read sys/audit` (needs sudo) and `vault read -namespace=admin/platform secret/config`.
- [ ] It gets 403 on `vault read -namespace=admin/platform secret/data/x`, on `.../role-id`, and on any write.
- [ ] After a scan run, the audit log contains entries with `auth.display_name` matching `exporter-agent`.
- [ ] No `secret/data/` path appears in the audit log `request.path` for the exporter token's calls.

---
