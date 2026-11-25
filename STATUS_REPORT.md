# Status report — terraform-vault-vault-codifier

**Date**: 2026-11-25
**Branch / head**: `main` at `965cc07` (no remote yet)
**Scope**: agent skills that survey a live Vault Enterprise cluster read-only and generate Terraform HCL (`hashicorp/vault` 4.8.0, `import {}` blocks) with a zero-diff plan.

## Summary

Phase 1 (foundation) and Phase 2 (discovery, TASK-007..014) are validated against the harness. Phase 3 (codification) is complete: seven generators (TASK-015..021), the layer-assembly runner and ownership checker (TASK-022) and the documented Terraform MCP fallback (TASK-034). The validation and documentation phases (TASK-023..030) have no deliverables yet.

A first waza review of the 17 skills found no `ready: true`. The main causes are size (every `SKILL.md` is 4 to 7 times the default 500-token limit) and non-standard frontmatter. See TASK-033.

| Phase | Tasks | Done | Remaining |
|---|---|---|---|
| 1 Foundation | 001–006, 031 | 7 of 7 (TASK-005 superseded) | — |
| 2 Discovery | 007–014 | 8 of 8 | — |
| 3 Codification | 015–022, 034 | 9 of 9 | — |
| 4 Validation | 023–027, 033 | 0 of 6 | 023..027; 033 baseline captured |
| 5 Docs and delivery | 028–030, 032 | 0 of 4 | all |
| **Total** | 34 | **24** | **10** |

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
| 023–027 | Static gate, zero-diff plan, read-only check, variant fixtures, idempotence | Not started (no skills) |
| 028–030 | AGENTS.md, README, traceability | Not started |
| 032 | Create GitHub repository and publish | New, ready to start |
| 033 | Waza review of skills TASK-007..021 | New, baseline captured |
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

## Waza review baseline (TASK-033)

Tool: [microsoft/waza](https://github.com/microsoft/waza) 0.38.7 (`waza check --format json`); v0.42.0 is the current release. Raw output: `/tmp/waza_check.json` (not committed).

| Finding | Skills affected (of 17) |
|---|---|
| Over the 500-token limit (range 1,909 to 3,391; total 45,367) | 17 |
| Frontmatter fields outside the agentskills.io spec (`triggers`, `capability`, `task`, `depends_on`, `role`) | 17 |
| No examples and no troubleshooting section (by waza's definition) | 17 |
| Rated "comprehensive" complexity | 17 |
| Over-specificity (absolute paths, hard-coded URLs) | 16 |
| Description lacks procedural language | 11 |
| Negative-delta-risk patterns | 9 |
| Compliance level Low / Medium | 16 / 1 |
| Eval suites present | 0 |

The 500-token default is a poor fit for operational skills that carry acceptance criteria and reference output. The planned fix is to set limits deliberately in `.waza.yaml`, move example and reference blocks to `references/`, and move non-spec frontmatter under `metadata:`. The skills are not edited yet; the generators have been validated against their current text.

## Risks and open items

| Item | Owner role | Note |
|---|---|---|
| Terraform MCP not installed | Solution architect | Fallback (provider docs URL and `terraform providers schema -json`) is documented in `vault-codifier-conventions` and used throughout |
| Variant branches (EGP, RGP, MFA, OIDC, LDAP, group aliases, PKI, database, AWS) untested against Vault | Test engineer | The harness has none of them; scratch payloads were validated with `terraform validate` only; TASK-026 |
| Auth mounts other than AppRole, and secrets engines other than KV v2, are mount-only | Solution architect | Listed in `auth-mounts/coverage.md` and `secrets-engines/coverage.md` as "review manually" |
| The plan for `admin/` needs `TF_VAR_exporter_agent_approle_name` | Maintainer | The exporter alias name is a sensitive variable; set it from the role id at plan time |
| `design.md` §6.2 still shows Python pseudocode | Solution architect | Illustrative only; the skills are authoritative |
| Harness root token `root` and `terraform.tfstate` files under `test/terraform/` | Security | Confirm they are ignored before the first push (TASK-032) |
| `gh` was not authenticated in the last session | Maintainer | Needed for TASK-032 |
| `discovered_terraform/terraform/` is now committed | Maintainer | Decide in TASK-032 whether the harness output stays as a reference or is ignored |

## Next steps, in order

1. TASK-033: waza fixes on the 19 skills, then re-run `waza check` and `assemble.sh`.
2. TASK-023..027 (static gate, zero-diff plan, read-only check, variant fixtures, idempotence), then TASK-028..030.
3. TASK-032: authenticate `gh`, create the repository and push.
