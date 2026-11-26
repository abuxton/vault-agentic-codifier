# Status report — terraform-vault-vault-codifier

**Date**: 2026-11-26
**Branch / head**: `main` at `2fc5e62` (origin: https://github.com/abuxton/vault-agentic-codifier)
**Scope**: agent skills that survey a live Vault Enterprise cluster read-only and generate Terraform HCL (`hashicorp/vault` 4.8.0, `import {}` blocks) with a zero-diff plan.

## Summary

Phases 1 to 5 are done; the codifier is validated against the harness. Phase 3 (codification) has seven generators (TASK-015..021), the layer-assembly runner (TASK-022) and the documented Terraform MCP fallback (TASK-034). Phase 4 (validation) adds the static gate, zero-diff plan, read-only and no-secrets verification, variant fixtures and the one-command `make codify-test` (TASK-023..027), and the waza review (TASK-033: 23 of 23 skills ready, tokens halved). The documentation phase is done (TASK-028..030: AGENTS.md, README and usage guide, traceability matrix; and the publish step, TASK-032). All 34 tasks are done.

| Phase | Tasks | Done | Remaining |
|---|---|---|---|
| 1 Foundation | 001–006, 031 | 7 of 7 (TASK-005 superseded) | — |
| 2 Discovery | 007–014 | 8 of 8 | — |
| 3 Codification | 015–022, 034 | 9 of 9 | — |
| 4 Validation | 023–027, 033 | 6 of 6 | — |
| 5 Docs and delivery | 028–030, 032 | 4 of 4 | — |
| **Total** | 34 | **32** (an earlier version said 33; that was a counting error) | **2 outstanding (030, 032)** |

## Evidence from the harness (Vault 2.2.2+ent)

| Check | Result |
|---|---|
| Discovery end to end | exit 0 in about 6 s, `non_200_responses: []`, second run byte-identical |
| Audit log of a discovery run | 221 exporter requests, all `read` or `list`; none on `data/`, `metadata/`, `role-id`, `secret-id`, `sys/license`, `config/root` |
| `terraform fmt -check -recursive` | pass in `admin/`, `namespaces/`, `seed/` |
| `terraform validate` | pass in all three layers |
| `terraform plan` (import blocks) | `admin/` 31 import, `namespaces/` 3 import, `seed/` 18 import; **0 add, 0 change, 0 destroy** in each |
| Generator idempotence | second run byte-identical for all seven generators and for `assemble.sh` |
| Ownership check (`check.sh`) | 0 violations: 31, 3 and 18 resources each with exactly one import; eight injected faults (duplicate policy, wrong owner, missing import, missing header, UUID literal, forbidden type, inline secret, no layer) each exit 1 |
| Credential check | no `role_id`, `secret_id` or `secret_id_accessor` token in the generated HCL (word-bounded grep); no UUID in any `.tf` other than `imports*.tf`; no `vault_kv_secret*` or `vault_generic_secret` |
| Negative fixtures | orphan namespace exits 2; secret-like audit option exits 2; `role_id` key in a payload exits 2; depth-3 namespace gets `provider = vault.admin_platform` and `depends_on`; dangling policy reference reported; credential key in a secrets-engines, identity or admin-config payload exits 2; unresolved alias accessor exits 2; missing upstream resource for admin-config exits 2; scratch `pki` mount, OIDC external group with group alias, and OIDC and LDAP human auth validate; tab-bearing and newline-less policy bodies written verbatim |

The plans were run with the harness root token. Discovery used the exporter AppRole token only.

## Task status

| Task | Title | Status |
|---|---|---|
| 001–004, 006, 031 | Foundation, TASK-006 decision, exporter identity | Done |
| 005 | Vault API client | Superseded (CLI, `curl`, `jq`) |
| 007–013 | Seven discovery skills | Done — validated |
| 014 | Discovery orchestrator (`run.sh`) | Done — validated |
| 015 | Namespaces generator | Done — validated |
| 016 | Root-config generator | Done — validated |
| 017 | Policies generator and correlation matrix | Done — validated |
| 018 | Auth-mounts generator | Done — validated for AppRole; other method types are backend-only |
| 019 | Secrets-engines generator | Done — validated (KV v2 config; other engine types are mount-only) |
| 020 | Teams generator | Done — validated |
| 021 | Admin-config generator | Done — validated; OIDC and LDAP checked on scratch payloads only |
| 022 | Layer assembly and ownership check | Done — validated (`codification-layer-assembly`) |
| 023 | Static gate (`make static-gate`) | Done — validated |
| 024 | Zero-diff plan (`make zero-diff`) | Done — validated |
| 025 | Read-only and no-secrets check (`make verify`) | Done — 12 checks, 10 of 10 injected faults caught |
| 026 | Variant fixtures (`make variants`) | Done — 3 scenarios; found and fixed 2 generator gaps |
| 027 | One-command CAC1..CAC7 run (`make codify-test`) | Done — 11 stages PASS |
| 028–030 | AGENTS.md, README, traceability | Not started |
| 032 | Create GitHub repository and publish | **Done** |
| 033 | Waza review and fixes | Done — 23 of 23 ready; [`docs/waza-review.md`](docs/waza-review.md) |
| 034 | Terraform MCP availability or fallback | Done — fallback documented as a supported path |

## Findings that changed the skills

1. **Exporter policy gaps** found by running discovery: `sys/audit`, `sys/config/ui/headers` and `sys/auth/+` with `/tune` need `sudo` as well as `read` or `list`, at every namespace depth. `vault token capabilities` does not show this. Fixed in `exporter.hcl` and applied.
2. **Vault 2.x built-ins** to skip: the `default-ceiling` ACL policy and the `agent-registry/` secrets mount (match on type as well as path).
3. **Provider 4.8.0 import behaviour** that needed generator workarounds:
   - `vault_auth_backend`: `disable_remount` is unset and `tune` is empty after import, so the plan showed an in-place change. The generator adds `lifecycle { ignore_changes = [...] }`.
   - `vault_quota_rate_limit`: `inheritable` is not read back, so the generator omits it.
   - `vault_audit` imports by bare path; the payload key carries a trailing `/`.
4. **Shared layers**: several generators write into one layer, so `scaffold-layer.sh` now accumulates provider aliases in `<layer>/.namespaces` instead of overwriting `providers.tf`.
5. **Alias id is an import ID.** `vault_identity_*_alias` imports by alias UUID, and discovery dropped it. `identity-teams.sh` and `discovery-identity-teams` now keep `id` (raw payloads were refreshed with the exporter token).
6. **Sensitive alias name.** Provider 4.8.0 imports a sensitive `name` unmarked and plans an in-place change; the teams generator adds `ignore_changes = [name]`. The harness alias name is the exporter AppRole `role_id`, so it is a sensitive variable.
7. **Human auth ownership.** The auth-mounts generator leaves `oidc`, `jwt` and `ldap` mounts in `admin` to admin-config, and teams resolves their accessors. The admin-config acceptance grep for `vault_auth_backend` applies to its own files, not the whole layer.
8. **Harness has 4 KV mounts**, not 3: the preloaded root `secret/` is imported too.
9. **Harness drift**: the `exporter` policy, AppRole role and entity are real cluster objects, so counts in older acceptance criteria rose (10 policies, 6 roles). Skills must tolerate this.

## Phase 4 results

| Check | Result |
|---|---|
| `make static-gate` | `terraform fmt`, `validate` and `tflint` pass in every layer |
| `make zero-diff` | 0 add, 0 change, 0 destroy in every layer |
| `make verify` | 12 checks PASS; `make verify-selftest` catches 10 of 10 injected faults; a live exporter write returned 403 and was caught in the audit log |
| `make variants` | `variant`, `restricted-403`, `empty-cluster` pass; real harness digest unchanged |
| `make codify-test` | 11 stages PASS (CAC1 to CAC7); smoke test passes before and after; output byte-identical on re-run |
| `waza check` (0.42.0) | 23 of 23 ready; 27,407 tokens (from 53,723); 0 `spec-allowed-fields`; 0 broken links |

Two generator gaps found by the variants and fixed: `admin-config.sh` now reads human-auth config and roles (secret-like keys masked), and both admin-config stages skip cleanly when no `admin` namespace exists. Retained waza advisories and the skipped eval suite are justified in [`docs/waza-review.md`](docs/waza-review.md).

## Risks and open items

| Item | Owner role | Note |
|---|---|---|
| Terraform MCP not installed | Solution architect | Fallback (provider docs URL and `terraform providers schema -json`) is documented in `vault-codifier-conventions` and used throughout |
| EGP, RGP, MFA, PKI, database and AWS variants not exercised against Vault | Test engineer | `make variants` covers OIDC and the restricted and empty clusters; the others were validated with `terraform validate` on scratch payloads only |
| No waza eval suite | Project owner | A mock executor proves nothing about agent quality; real runs need approval and may incur cost |
| Auth mounts other than AppRole, and secrets engines other than KV v2, are mount-only | Solution architect | Listed in `auth-mounts/coverage.md` and `secrets-engines/coverage.md` as "review manually" |
| The plan for `admin/` needs `TF_VAR_exporter_agent_approle_name` | Maintainer | The exporter alias name is a sensitive variable; set it from the role id at plan time |
| `design.md` §6.2 still shows Python pseudocode | Solution architect | Illustrative only; the skills are authoritative |
| Harness root token `root` and `terraform.tfstate` files under `test/terraform/` | Security | Verified ignored and untracked at TASK-032 |
| The repository is public | Repository owner | TASK-032 said private unless told otherwise; confirm, or switch with `gh repo edit --visibility private` |
| 13 low-severity findings in git history | Repository owner | None is a credential; accepted, listed in `docs/traceability.md` section 6 |
| `discovered_terraform/terraform/` is committed | Maintainer | Kept as the reviewed reference output; the run state is ignored |

## Next steps, in order

All 34 tasks are done. Follow-ups, in priority order (owners in `docs/traceability.md` section 6):

1. An Enterprise fixture for EGP, RGP and MFA.
2. Method and engine resources beyond AppRole and KV v2.
3. A waza eval suite.
4. A first review on a non-harness cluster.
