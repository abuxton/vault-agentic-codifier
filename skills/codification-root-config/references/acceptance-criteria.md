## 6. Acceptance criteria

- Exactly one `vault_audit` with `type = "file"` and
  `options = { file_path = "/vault/logs/audit.log" }`; import `id = "file"`.
- Exactly one `vault_quota_rate_limit` named `global-rate-limit` with
  `path = ""`, `rate = 1000`, `interval = 60`, `block_interval = 60`.
- `grep -rE 'resource "vault_(policy|auth_backend|mount|namespace)"' root/`
  returns 0 matches.
- `README.md` lists seal type, licence ID/expiry (no text) and replication
  "disabled"; `replication.tf` absent for the harness.
- Empty `sys/audit` -> no `audit.tf`, README says "no audit devices".
- 403 on an endpoint is logged with endpoint and status and the run continues.
- `terraform fmt -check -recursive` and `terraform validate` exit 0.
