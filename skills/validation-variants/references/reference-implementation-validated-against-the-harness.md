## 4. Reference implementation (validated against the harness)

All checks PASS, and the real harness digest is identical before and after.

**Gaps the variants exposed, both fixed.**

1. `discovery-orchestrator/scripts/admin-config.sh` wrote `config:{}` and `roles_or_groups:[]` for every human auth
   mount, so an `oidc` mount produced a `vault_jwt_auth_backend` with no `oidc_discovery_url` and `terraform plan`
   failed ("exactly one of oidc_discovery_url, jwks_url or jwt_validation_pubkeys"). It now reads
   `auth/<path>/config` and the roles (oidc, jwt) or groups (ldap), with `client_secret`, `bindpass`, `api_token`
   and `password` keys masked to `REDACTED` before they reach disk. The base harness has no human mount, so its
   output is byte-identical.
2. On a cluster without an `admin` namespace both admin-config stages stopped with an error. They now skip
   cleanly (discovery exits 0, codification removes its own files and exits 0), as CAP-002 AC3 and CAP-001 AC6
   require.

**A wrong assertion, not a generator fault.** The first run failed `CAP-005-AC5` because the test expected five
`vault_namespace` resources in `namespaces/namespaces.tf`. The `admin` namespace belongs to the `admin` layer, so the
file holds four. The test was corrected.
