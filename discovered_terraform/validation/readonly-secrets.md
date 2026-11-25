# Read-only and no-secrets verification

Window: `2026-11-25T15:02:12` to `2026-11-25T15:02:35` (from run_report.json). Exporter requests audited: 242.

| Check | Result | Detail |
|---|---|---|
| audit-has-exporter-requests | PASS | 242 requests by the exporter token between 2026-11-25T15:02:12 and 2026-11-25T15:02:35 |
| audit-read-only | PASS | 0 operations other than read or list ({"list":94,"read":148}) |
| audit-no-secret-reads | PASS | no KV data, dynamic credential, secret-id or sys/raw path was read |
| scan-no-state-files | PASS | no state, plan or tfvars file in the output |
| scan-synthetic | PASS | SYNTHETIC markers: none |
| scan-secret-id | PASS | secret_id values: none |
| scan-secret-id-accessor | PASS | secret_id_accessor values: none |
| scan-token-values | PASS | Vault token values: none |
| scan-root-token | PASS | root token literal: none |
| scan-kv-data | PASS | no KV v2 data payload in raw |
| scan-uuid-literals | PASS | UUID literals in .tf outside imports*.tf: none |
| scan-sensitive-args | PASS | literal values for sensitive arguments in .tf: none |

Requests in the window made by something other than the exporter token (the setup steps, not the codifier):

- read `auth/approle/role/exporter/role-id` as `root`
- read `secret/data/billing-service/checkout` as `root`
- read `secret/data/identity-service/ldap` as `root`
- read `sys/auth` as `root`
- read `sys/internal/ui/mounts/secret` as `root`
- read `sys/mounts` as `root`
- update `auth/approle/login` as `none`
- update `auth/approle/role/exporter/secret-id` as `root`

Verdict: **PASS**
