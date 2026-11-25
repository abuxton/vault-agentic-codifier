# Variant fixtures

Throwaway containers on 127.0.0.1:18200 and :18201; the committed harness on 8200 is not touched.

| Scenario | Check | Result | Detail |
|---|---|---|---|
| variant | seed | PASS | harness layers applied to the throwaway cluster |
| variant | fixture | PASS | oidc+role+external group/alias, userpass, pki, database, nested namespace, default-readonly x2, dangling role |
| variant | discovery | PASS | orchestrator exit 0 (got 0) |
| variant | assemble | PASS | assemble.sh exit 0 (got 0): assembly: ok |
| variant | CAP-002-AC4 | PASS | one vault_jwt_auth_backend type=oidc with oidc_discovery_url |
| variant | CAP-002-AC4-secret | PASS | client secret is a sensitive variable with no default; the marker appears in no file |
| variant | CAP-003-AC7 | PASS | userpass emitted as vault_auth_backend and listed in coverage.md for manual review |
| variant | CAP-004-AC6 | PASS | pki and database emitted as vault_mount; coverage.md lists them for review |
| variant | CAP-005-AC5 | PASS | admin/platform/sre-team at depth 3 in hierarchy.md, after admin/platform |
| variant | CAP-005-AC3 | PASS | parent before child in namespaces.tf |
| variant | CAP-006-AC6 | PASS | default-readonly in two namespaces gives two distinct resources |
| variant | CAP-006-AC5 | PASS | does-not-exist flagged dangling in correlation.md; no vault_policy for it |
| variant | CAP-007-AC4 | PASS | external group and one group alias whose mount_accessor is a resource reference |
| variant | CAP-007-AC8 | PASS | platform-variant-group emitted with provider vault.admin_platform |
| variant | CAP-003-AC4 | PASS | ghost-role keeps literal does-not-exist and coverage.md reports it |
| variant | CAC1 | PASS | static gate exit 0 (got 0) |
| variant | CAC2 | PASS | zero-diff exit 0 in every layer (got 0); 7 capabilities pass |
| variant | CAC3+CAC4 | PASS | read-only and no-secrets exit 0 (got 0); 13 checks pass |
| restricted-403 | CAP-001-AC7a | PASS | run continues and exits 0 despite 403s (got 0) |
| restricted-403 | CAP-001-AC7b | PASS | run_report.json lists sys/quotas/config and sys/config/ui/headers with status 403 |
| restricted-403 | token-hygiene | PASS | the token does not appear in the run report or raw payloads |
| restricted-403 | assemble | PASS | codification still succeeds with missing optional payloads (got 0) |
| restricted-403 | CAP-001-AC7c | PASS | an audit-device 403 makes root-config codification exit non-zero (got 2) |
| restricted-403 | CAC3+CAC4 | PASS | 403 run: read-only and no-secrets exit 0 (got 0) |
| empty-cluster | stop-conditions | PASS | orchestrator refuses (root token, no audit device): exit 2 (got 2) |
| empty-cluster | assemble | PASS | codification of an empty cluster exits 0 (got 0) |
| empty-cluster | CAP-001-AC6 | PASS | no vault_audit resource; README says 'No audit devices were discovered' |
| empty-cluster | CAP-002-AC3 | PASS | no human_auth.tf and no admin_config files |
| empty-cluster | CAP-005-AC6 | PASS | no vault_namespace in an empty cluster |
| empty-cluster | CAC1 | PASS | static gate exit 0 (got 0) |
| empty-cluster | CAC2 | PASS | zero-diff exit 0 (got 0) |
| empty-cluster | CAC3 | PASS | content scans exit 0; the three audit checks are SKIP (got 0) |
| teardown | containers-removed | PASS | both throwaway containers removed |
| teardown | harness-unchanged | PASS | real harness digest 6877834785126726 before, 6877834785126726 after |

Verdict: **PASS**
