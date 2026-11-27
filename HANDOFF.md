# Handoff Document — terraform-vault-vault-codifier

**Date**: 2026-11-25 (stage 2 in progress; stage 1 section dated 2026-11-26 earlier)
**Commit**: stage 1 is on `main` at `76bfcd8`. Stage 2 is on `feature/16-stage-2-enterprise-config` at `c67f857` (S05 notes, spec amendment and fixture committed as work in progress; no discovery or generator code yet). See section 10.
**Status**: **Stage 1 (34 of 34 tasks) is done and published.** **Stage 2 is in progress: TASK-S01 to S04 done, TASK-S05 in progress, TASK-S06 to S10 pending.** `bash skills/codification-layer-assembly/scripts/assemble.sh` regenerates and checks everything. Full numbers are in [`STATUS_REPORT.md`](STATUS_REPORT.md).

> **Approach**: the whole deliverable is a set of **agent skills** (`skills/*/SKILL.md`). There is no Python. See §3 for which tool each phase uses and why.

---

## 0. Stage 2 — resume here

Plan: `openspec/changes/vault-codifier-stage-2/{proposal,specs,design,tasks}.md` and `task-s01-decision.md`. GitHub issues #1 to #10, tracking issue #16. A separate change, `openspec/changes/vault-codifier-remote-review/` (CAP-013, TASK-R01 to R05, issues #11 to #15, tracking #17), is **not started** and needs the cluster owner's written approval.

### Task status

| Task | Issue | Title | Status | Commit |
|---|---|---|---|---|
| TASK-S01 | #1 | Verify provider resources and import ids | Done, closed | `dea74e7` |
| TASK-S02 | #2 | Synthetic EGP, RGP and TOTP MFA fixtures | Done, closed | `f624f82` |
| TASK-S03 | #3 | Sentinel EGP and RGP discovery and codification (CAP-008) | Done, closed | `3188dca`, `f332cf5` |
| TASK-S04 | #4 | MFA methods and login enforcement (CAP-009) | Done, closed | `97707a4` |
| TASK-S05 | #5 | Auth method configuration (CAP-010) | **In progress** (see below) | `c67f857` (WIP: notes and fixture only) |
| TASK-S06 | #6 | Engine configuration (CAP-011) | Ready to start | — |
| TASK-S07 | #7 | Verification extensions | Blocked on S03 to S06 | — |
| TASK-S08 | #8 | Waza eval suite scaffolding (mock executor, "harness only") | Blocked | — |
| TASK-S09 | #9 | Real-executor eval run | Blocked; **needs the owner's approval of model, trials and cost** | — |
| TASK-S10 | #10 | Docs, traceability, publish | Blocked | — |

Current numbers: `spec-check` has 51 criteria (40 stage 1, 5 CAP-008, 6 CAP-009), the self-test injects 17 faults, the harness has 2 EGP, 2 RGP, 1 TOTP method and 1 login enforcement (all in `admin`). The last full `make codify-test`, `make spec-check-selftest` and `make variants` were green at `97707a4` (nothing that affects them changed in `c67f857`).

### Resume commands

```bash
cd /Users/abuxton/src/github/terraform-vault-vault-codifier/.worktrees/feature-stage-2-enterprise-config
export PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin:$HOME/.rd/bin VAULT_CONFIG_PATH=/dev/null VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root
git status --short && git log --oneline -8
docker rm -f vault-codifier-s05 vault-codifier-mfa 2>/dev/null   # scratch containers from last session
docker ps --format '{{.Names}} {{.Ports}}' | grep vault-codifier  # expect only vault-codifier-dev on 8200
```

### Working rules

- **Git flow with a worktree.** All stage-2 work happens in `.worktrees/feature-stage-2-enterprise-config`. At the end merge the feature into `develop` with `--no-ff`. `main` is the published stage-1 line; ask the user before merging `develop` to `main`.
- **One conventional commit per task**, only that task's files, with `Refs #N, #16` in the body. Push after each task: `GIT_TERMINAL_PROMPT=0 git push -v origin HEAD:refs/heads/feature/16-stage-2-enterprise-config` with `background: true`, log to `tmp/work/push.log`, then verify the remote sha equals `git rev-parse HEAD`.
- **Scanners** (IBM Vault Radar pre-commit and pre-push) run. Fix the code, never bypass. Avoid the words `pass`, `password` and `secret` next to `=` or `:` in scripts, JSON keys and prose. The repo is **public**.
- **Scratch files go in `./tmp/work/` (git-ignored), never `/tmp`.**
- zsh on macOS: `GID` is read-only, BSD `sed -i ''`, quote globs, include `$HOME/.rd/bin` in PATH for `docker`. There is no `timeout` or `setsid`. Foreground tool calls die at about 30 s, so run `make codify-test` (about 60 s), `make spec-check-selftest` (about 30 s) and `make variants` (about 3 min) with `background: true` and poll the log.
- `waza`: `WAZA_NO_UPDATE_CHECK=1 WAZA_TELEMETRY_OPTOUT=1 $HOME/bin/waza check`. Skills stay within 1,500 tokens; put detail in `references/` and link each reference from `## References` in `SKILL.md` (an inline-only mention is reported as an orphan).
- Generators must stay byte-identical on re-run. Do not commit the run-specific `discovered_terraform/validation/readonly-secrets.*`; `git checkout` them first.
- After each task: close the GitHub issue with a comment, tick it in #16 (`/opt/homebrew/bin/gh`, `GH_PROMPT_DISABLED=1`, background), and update this file, `STATUS_REPORT.md`, `docs/traceability.md` and `tasks.md`.
- Acceptance: CAC8 `make codify-test` passes after every task; CAC9 fixtures are synthetic and local; CAC10 no secrets in payloads, files, reports or logs. The harness runs only on 127.0.0.1. `tmp/vault.hclic` is never committed.

### TASK-S05 (CAP-010) — what is done and what is left

**Done (committed in `c67f857`):**

- `specs.md`: CAP-010 AC1 amended with the cert-role exception.
- `task-s01-decision.md` section 6: the verified import-id table, taken from a scratch container where one configuration with 15 `import {}` blocks planned "15 to import, 0 to change", applied, and re-planned with exit 0.
- `skills/validation-variants/scripts/fixture-auth-config.sh`: new. `fixture_auth_config <ns> <marker> <workdir>` enables ldap, kubernetes, aws, cert, jwt, oidc and a token role with synthetic config, plus a `synthetic-ghost` Kubernetes role whose policy is missing. Marker values go into `bindpass`, `token_reviewer_jwt`, `access_key`, `secret_key`, `iam_server_id_header_value` and `oidc_client_secret`. It was last edited after the scratch container was set up, so **re-run it on a fresh container to check it**.

**Verified findings (provider 4.8.0, Vault 2.2.2+ent):**

| Resource | Import id and notes |
|---|---|
| `vault_ldap_auth_backend` | mount path; owns the mount. `bindpass` is never returned. Always emit `max_page_size = 0` (Vault returns 0, the provider default is -1). |
| `vault_ldap_auth_backend_group` / `_user` | `auth/<p>/groups/<n>` and `auth/<p>/users/<n>` |
| `vault_kubernetes_auth_backend_config` | `auth/<p>/config`. Vault returns `token_reviewer_jwt_set`, not the JWT. `kubernetes_ca_cert` is public. |
| `vault_kubernetes_auth_backend_role` | `auth/<p>/role/<n>` |
| `vault_aws_auth_backend_client` | `auth/<p>/config/client`. **`access_key` is returned in clear**; `secret_key` is never returned. Make both variables and ignore both. |
| `vault_aws_auth_backend_role` | `auth/<p>/role/<n>`. Vault returns singular names (`bound_iam_principal_arn`); the provider takes plurals. Emit `resolve_aws_unique_ids = false` when it is false. |
| `vault_cert_auth_backend_role` | **Not importable in 4.8.0**, and a `vault_generic_endpoint` stand-in also plans as a create. **Decision:** do not emit cert roles. Emit the mount as `vault_auth_backend` and list the roles in `coverage.md` as "review manually: provider 4.8.0 cannot import cert roles". |
| `vault_token_auth_backend_role` | `auth/token/roles/<n>`. `token/` is not in `sys/auth`, so read roles from `auth/token/roles`. |
| JWT and OIDC outside `admin` | `vault_jwt_auth_backend` plus `vault_jwt_auth_backend_role`, with `oidc_client_secret` as a variable and `ignore_changes`. |

**Left to do:**

1. Exporter policy `test/terraform/admin/policies/exporter.hcl`: add read and list grants at all four namespace depths for LDAP groups and users, cert roles, token roles and `auth/+/config/client` (it currently grants `auth/+/role`, `auth/+/role/*` and `auth/+/config` only). Apply the `admin` layer.
2. `skills/discovery-orchestrator/scripts/auth-mounts.sh` reads roles for approle only (`unsupported=true` otherwise). Extend it to read per-method config and roles. Extend the `admin-config.sh` mask (`client_secret|bindpass|api_token|password`) with `token_reviewer_jwt`, `secret_key` and `access_key`. Raw payloads must not hold any of them.
3. `skills/codification-auth-mounts/scripts/generate.sh` skips oidc, jwt and ldap mounts only when `$ns == "admin"` (admin-config owns those). Decide ownership outside `admin`, add the new resource types, and add `owner()` entries in `skills/codification-layer-assembly/scripts/check.sh` (`vault_kubernetes_auth_backend*`, `vault_aws_auth_backend*`, `vault_token_auth_backend_role`; `vault_jwt_auth_backend*` and `vault_ldap_auth_backend*` currently map to `admin-config`). `check.sh` also enforces one import per resource.
4. `skills/validation-variants/scripts/run-variants.sh`: source `fixture-auth-config.sh`, assert CAP-010 AC1 to AC7, and add `TF_VAR_*` placeholders for the new sensitive variables (it already passes the OIDC and MFA ones). `skills/validation-zero-diff/scripts/zero-diff.sh` needs the same placeholders.
5. `spec-check.sh` criteria and self-test mutations (extend the `mut` list near line 37), skill and reference updates within budget (`discovery-identity-teams` is at 1492 and `codification-teams` at 1400 tokens), `docs/traceability.md`, then `make codify-test`, `make spec-check-selftest` and `make variants`.
6. Commit with `Refs #5, #16`, push, close #5, tick it in #16.

### Remaining stage-2 tasks

- **TASK-S06 (#6)**: PKI, database, AWS, transit and SSH engine config. Verify each import id first and append them to `task-s01-decision.md`. Generator: `skills/codification-secrets-engines/scripts/generate.sh`.
- **TASK-S07 (#7)**: verification extensions in `spec-check`, `verify` and `variants`.
- **TASK-S08 (#8)**: waza eval suite scaffolding with a mock executor labelled "harness only", plus `make evals`.
- **TASK-S09 (#9)**: needs the owner's approval of model, trials and cost before any real-executor run.
- **TASK-S10 (#10)**: update the README limits (line 81 still says "EGP, RGP and MFA are not exercised against a live cluster"), `AGENTS.md`, `docs/usage-guide.md`, this file and `STATUS_REPORT.md`; run a whole-history `vault-radar scan repo` in the background; merge the feature into `develop` with `--no-ff`; push.

### Open decisions for the user

- The repo is public, though TASK-032 said private unless told otherwise.
- The stage-2 slice of auth methods and engines is my choice: CAP-010 covers LDAP, Kubernetes, AWS, cert, token roles and JWT/OIDC outside `admin`; CAP-011 covers PKI, database, AWS, transit and SSH.
- TASK-S09 cost approval (above), and the cluster owner's approval for the remote-review change.

### Stage-2 discoveries

- **S03**: discovery writes `<ns>/sentinel.json`. The generator emits `<ns>_sentinel.tf`, `imports_sentinel.tf` and `policies/sentinel/<root|ns__path>/<kind>-<name>.sentinel`. Fixture Sentinel text must not contain `SYNTHETIC-` (CAP-004-AC3 forbids it); it reads "Harness fixture: always passes."
- **S04**: a child namespace's `LIST identity/mfa/method` also returns its ancestors' methods, so discovery filters on `namespace_path`. Vault never returns Duo, Okta or PingID keys; Okta never returns `primary_email`. Each method type is allowlisted in `mfa.json`. A TOTP method's `name` is empty. Details in `task-s01-decision.md` sections 2 and 5.
- `openspec/changes/vault-brownfield-research/design.md` links a non-existent `../../test/PREREQUISITES.md`. Not fixed.
- `tmp/tasklist` and `existing-terraform-change-plan.md` in the main checkout are the user's files. Do not commit them.

---

## 1. What this project is

`terraform-vault-vault-codifier` is an agentic, spec-driven toolkit (agent skills with runnable bash and jq scripts; no Python) that surveys a **live HashiCorp Vault Enterprise cluster** through read-only API calls and produces **idiomatic Terraform HCL** that adopts the existing configuration into version control.

The goal is a Terraform baseline for which `terraform plan` shows **no changes** against the live cluster, aligned with HashiCorp Validated Design (HVD) best practices.

**It never writes to Vault.** Every API call is `GET` or `LIST`. Secrets are never read or emitted. Generators refuse to write when a payload contains a credential field.

---

## 2. Repository layout

```
terraform-vault-vault-codifier/
├── README.md · AGENTS.md · PROJECT_BRIEF.md
├── Makefile                           ← validation targets (static-gate, zero-diff, verify, variants, codify-test)
├── docs/                              ← usage-guide.md, waza-review.md traceability.md
├── openspec/changes/vault-brownfield-research/
│   ├── proposal.md · specs.md · design.md · tasks.md
│   └── task-006-decision.md           ← verified import IDs, namespace style, Enterprise features
├── skills/                            ← 23 agent skills (the deliverable); scripts in `scripts/`, detail in `references/`
│   ├── vault-codifier-conventions/    ← START HERE: tool choice, secret guard, naming, header, providers, layers
│   ├── vault-exporter-setup/          ← TASK-031: provision the read-only exporter identity
│   ├── discovery-{namespaces,root-config,policies,auth-mounts,
│   │             secrets-engines,identity-teams,admin-config,orchestrator}/   ← TASK-007..014
│   ├── codification-{namespaces,root-config,policies,auth-mounts,
│   │                 secrets-engines,teams,admin-config,layer-assembly}/       ← TASK-015..022
│   └── validation-{static-gate,zero-diff,readonly-secrets,variants,codify-test}/  ← TASK-023..027
├── STATUS_REPORT.md                   ← point-in-time status, evidence and risks
├── test/                              ← synthetic brownfield harness (docker-compose + 3 Terraform layers)
├── tmp/                               ← research notes (never commit vault.hclic)
└── discovered_terraform/              ← skill output: raw/ (git-ignored), terraform/{admin,namespaces,seed}/ (generated), run_report.json
```

**Removed**: the `codifier/` Python package and `tests/`. The skills never imported them, and 15 of the files were `NotImplementedError` stubs. The useful rules (naming, secret guard, forbidden resources, provider template, header, layer map) moved into `vault-codifier-conventions`.

---

## 3. Task status

### Phase 1 — Foundation (all done)

| Task | Title | Deliverable |
|---|---|---|
| TASK-001 | Scaffolding, layout | `vault-codifier-conventions` §2, §8 |
| TASK-002 | Provider template | `vault-codifier-conventions` §7 |
| TASK-003 | Naming rules | `vault-codifier-conventions` §5 |
| TASK-004 | Header + secret guard | `vault-codifier-conventions` §3, §4 (checked by grep, not unit tests) |
| TASK-005 | Vault API client | **Superseded**: discovery uses `vault` CLI + `curl` + `jq` with the exporter token |
| TASK-006 | Resolve open items | `task-006-decision.md` |
| TASK-031 | Exporter identity | `test/terraform/admin/policies/exporter.hcl` + `skills/vault-exporter-setup/SKILL.md` |

### Tool choice by phase (and why)

| Phase | Tool | Why |
|---|---|---|
| Discovery | `vault` CLI, `curl`, `jq` | The Vault MCP server only exposes mount, KV and PKI tools. It has none for namespaces, auth, policies, identity, quotas or `sys/*`, and it exposes write tools. |
| Codification | Terraform MCP (`search_providers`, `get_provider_details`, `search_provider_docs`) | Look up resource schemas and import syntax for `hashicorp/vault` 4.8.0 before writing HCL. |
| Validation | `terraform fmt`, `validate`, `plan` | The Terraform MCP does not run them. |

Read-only is enforced by the exporter policy and the audit log (TASK-025), not by client code.

**Status legend for Phases 2–3**: *Validated* = executed against the harness with its acceptance criteria checked. *Authored* = `SKILL.md` written, not yet run. Evidence is in [`STATUS_REPORT.md`](STATUS_REPORT.md).

### Phase 2 — Discovery Engine (all validated)

| Task | Skill | Status |
|---|---|---|
| TASK-007 | `discovery-namespaces` | Validated |
| TASK-008 | `discovery-root-config` | Validated |
| TASK-009 | `discovery-policies` | Validated |
| TASK-010 | `discovery-auth-mounts` | Validated |
| TASK-011 | `discovery-secrets-engines` | Validated |
| TASK-012 | `discovery-identity-teams` | Validated |
| TASK-013 | `discovery-admin-config` | Validated |
| TASK-014 | `discovery-orchestrator` (`scripts/run.sh`) | Validated: exit 0 in about 6 s, byte-identical re-run, 221 read or list requests in the audit log |

`skills/discovery-orchestrator/scripts/run.sh` runs the discovery scripts in dependency order and writes `discovered_terraform/raw/<namespace>/*.json`, `run_report.json` and `.state.json`. It requires `EXPORTER_TOKEN` and an enabled audit device, and refuses to run with a root token.

### Phase 3 — Codification Engine

| Task | Skill | Status | Generator |
|---|---|---|---|
| TASK-015 | `codification-namespaces` | **Validated** | `scripts/generate.sh` |
| TASK-016 | `codification-root-config` | **Validated** | `scripts/generate.sh` |
| TASK-017 | `codification-policies` | **Validated** | `scripts/generate.sh` |
| TASK-018 | `codification-auth-mounts` | **Validated** for AppRole; other method types are backend-only | `scripts/generate.sh` |
| TASK-019 | `codification-secrets-engines` | **Validated** for KV v2; other engine types are mount-only | `scripts/generate.sh` |
| TASK-020 | `codification-teams` | **Validated** (entities, groups, aliases) | `scripts/generate.sh` |
| TASK-021 | `codification-admin-config` | **Validated**; OIDC and LDAP on scratch payloads only | `scripts/generate.sh` |
| TASK-022 | layer assembly, imports, ownership check | **Validated** (`codification-layer-assembly`) | `scripts/assemble.sh`, `scripts/check.sh` |

All seven generators run from the repo root, read `discovered_terraform/raw/`, write `discovered_terraform/terraform/`, and are idempotent. Generate in this order: namespaces, root-config, policies, auth-mounts, secrets-engines, teams, admin-config. They share the `admin/` and `seed/` layers, and `vault-codifier-conventions/scripts/scaffold-layer.sh` merges provider aliases through `<layer>/.namespaces`.

Latest plan (harness root token, `terraform plan`): `admin/` 31 import, `namespaces/` 3 import, `seed/` 18 import, with **0 add, 0 change, 0 destroy** in each. The `admin/` plan needs `TF_VAR_exporter_agent_approle_name` (the exporter alias name is a sensitive variable; use `vault read -field=role_id auth/approle/role/exporter/role-id` with the root token).

### Phase 4 — Validation (complete)

| Task | Skill | Make target | Result on the harness |
|---|---|---|---|
| TASK-023 | `validation-static-gate` | `make static-gate` | `terraform fmt`, `validate` and `tflint` pass in every layer |
| TASK-024 | `validation-zero-diff` | `make zero-diff` | Import into a scratch state, then plan: 0 add, 0 change, 0 destroy in every layer |
| TASK-025 | `validation-readonly-secrets` | `make verify`, `make verify-selftest` | 12 checks pass on the run window; the self-test injects 10 faults and catches all; a live exporter write returned 403 |
| TASK-026 | `validation-variants` | `make variants` | `variant`, `restricted-403` and `empty-cluster` scenarios on throwaway containers (ports 18200 and 18201) pass; the real harness digest is unchanged |
| TASK-027 | `validation-codify-test` | `make codify-test` | 11 stages PASS, CAC1 to CAC7; output byte-identical on re-run; harness unchanged |
| TASK-033 | all 23 skills | `waza check` | 23 of 23 `ready`, 27,407 tokens (from 53,723); see [`docs/waza-review.md`](docs/waza-review.md) |

Reports are written to `discovered_terraform/validation/`. Run the root `Makefile` with `export PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin:$HOME/.rd/bin VAULT_CONFIG_PATH=/dev/null VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root`. `tflint` is at `~/.local/bin`.

Two real generator gaps were found by the TASK-026 variants and fixed:

1. `discovery-orchestrator/scripts/admin-config.sh` never read human-auth config or roles, so an `oidc` mount produced a `vault_jwt_auth_backend` with no `oidc_discovery_url`. It now reads `auth/<p>/config` and the roles or groups, and masks `client_secret`, `bindpass`, `api_token` and `password` keys as `REDACTED`.
2. Both admin-config stages (discovery and codification) errored when no `admin` namespace exists. They now skip cleanly.

Audit-log verification is scoped to the discovery window in `run_report.json` and to tokens with the `exporter` policy and without `root`. `NO_AUDIT_DEVICE=1` marks the audit checks SKIP, for the empty-cluster variant only.

### Phase 5 — Docs and delivery (4 of 4 done)

| Task | Title | Status |
|---|---|---|
| TASK-028 | `AGENTS.md` | **Done** (`79f1147`). Commands in it were run as written. |
| TASK-029 | `README.md`, `docs/usage-guide.md` | **Done** (`0ba207f`). The guide's flow was run on the harness: exporter login, discovery, `make assemble`, `make zero-diff`, `make verify`, and a seed-layer plan of 18 import, 0 add, 0 change, 0 destroy. |
| TASK-030 | Traceability matrix and handoff review | **Done**, see below |
| TASK-032 | Publish to `https://github.com/abuxton/vault-agentic-codifier` | **Done**, see below |
| TASK-034 | Terraform MCP installed, or fallback documented | **Done**. Fallback documented in `vault-codifier-conventions` and every codification skill |

**TASK-030, result:**

- [`docs/traceability.md`](docs/traceability.md) maps all 59 criteria (52 CAP and 7 CAC) to the implementing task and the verifying check. 40 CAP criteria are checked by `make spec-check` (40 of 40 pass; `--selftest` catches 12 of 12 injected faults). The other 12 map to `make variants` or `make zero-diff`. No criterion is unmet. Four partial coverages, the harness drift and the risk list with owners are in sections 4 to 6.
- The four `tmp/*.md` research notes carry a dated reconciliation note, and the resource map corrects its rows in place (approle x5, 6 roles, 10 policies, 4 mounts, KV v2 config emitted, secret data never emitted, 7 entities, 1 alias, aliased providers instead of resource-level `namespace`).
- OpenSpec verification (done by hand): see section 7 of the traceability doc (the `openspec` CLI is not installed, so it was done by hand).
- Final `make codify-test`: see the result block at the end of this section.

**Final `make codify-test` (2026-11-26, harness at 127.0.0.1:8200): Verdict PASS.** CAC1 static-gate, CAC2 zero-diff, CAC3 and CAC4 readonly-secrets, CAC5 idempotence, CAC6 and CAC7 ownership, and the CAP-001 to CAP-007 row (`spec-check`, 40 of 40) all PASS. The smoke test passed before and after, and the harness state was identical before and after. Report: `discovered_terraform/validation/codify-test.md`.

**TASK-032, result (2026-11-26):**

- Remote: `https://github.com/abuxton/vault-agentic-codifier`, `origin/main` equals local `main`. The pre-push secret scan passes.
- **Visibility is PUBLIC.** The task said private unless told otherwise; the repository was already public when it was checked. Confirm this is intended, or run `gh repo edit abuxton/vault-agentic-codifier --visibility private --accept-visibility-change-consequences`.
- Description and topics `vault`, `terraform`, `agent-skills` are set with `gh repo edit`. `gh` works with the keychain login.
- Tracked-file checks pass: no `.hclic`, `terraform.tfstate*`, `discovered_terraform/raw/`, `.state.json`, `run_report.json`, `.opencode/`, `.github/prompts/` or `.github/skills/`; `openspec/`, `.mcp.json`, `skills-lock.json`, `LICENSE` and `NOTICE` are tracked.
- Whole-history scan (`vault-radar scan repo --clone-dir . --skip-activeness`): 13 low-severity findings, none a credential. They are listed in `docs/traceability.md` section 6 and accepted. The history was not rewritten.

### Waza review (TASK-033), done

Waza 0.42.0 reports 23 of 23 skills `ready`, no `spec-allowed-fields` warnings and no broken links. `.waza.yaml` sets a 1,500-token limit. Detail moved verbatim to `skills/*/references/` (101 files, 0 lines lost). Retained advisories (`body-structure`, `complexity`, `module-count`, `over-specificity`, `negative-delta-risk`, `cross-model-density`) and the skipped eval suite are recorded with reasons in [`docs/waza-review.md`](docs/waza-review.md). `waza check` also scans `.claude/skills` (the openspec skills); ignore those. Run it with `WAZA_NO_UPDATE_CHECK=1 WAZA_TELEMETRY_OPTOUT=1 waza check --format json`.

### Known discrepancies to resolve

- `design.md` §6.2 still contains Python pseudocode. It is illustrative; the skills are authoritative.
- **Alias id** is now kept by discovery (`identity-teams.sh`), because alias imports use it. Raw payloads were refreshed.
- **Human auth in `admin`** (`oidc`, `jwt`, `ldap`) is emitted by admin-config; auth-mounts skips those mounts. admin-config's `vault_auth_backend` grep applies to its own files only.
- The harness has 4 KV mounts (root `secret/` is imported too), 7 entities, 9 groups and 1 alias.
- The AC-1 counts in the discovery skills and in `codification-policies` and `codification-auth-mounts` now include the `exporter` objects (10 policies, 6 roles). Skills must tolerate harness drift.
- Variant branches are covered by `make variants` (TASK-026) on throwaway containers. EGP, RGP and TOTP MFA are now exercised on the harness (stage 2, TASK-S02 to S04); LDAP, Kubernetes, AWS and cert auth config and the secrets-engine config (CAP-010, CAP-011) are not yet.
- Provider 4.8.0 import quirks handled in generators: `vault_auth_backend` needs `lifecycle { ignore_changes }` for `disable_remount` and an untuned `tune`; `vault_quota_rate_limit` does not read back `inheritable`; `vault_audit` imports by bare path.

---

## 4. Specs open items (TASK-006) — resolved

Evidence and tables are in [`task-006-decision.md`](openspec/changes/vault-brownfield-research/task-006-decision.md). Summary:

1. **Import IDs**: relative to the provider namespace, never namespace-prefixed. `vault_auth_backend` uses the bare mount path (`approle`); `vault_namespace` uses the leaf name; AppRole roles use `auth/<mount>/role/<name>`; identity objects use UUIDs. `vault_generic_endpoint` cannot be imported.
2. **Namespace targeting**: `aliased` is ratified. Resource-level `namespace` makes `import {}` plan a replacement.
3. **Enterprise features**: EGP, RGP and identity MFA get dedicated resources; replication and legacy MFA are documented only.

Skills `codification-namespaces`, `codification-auth-mounts` and `codification-policies` were corrected to match. The dangling `discovery-client-setup` dependency was removed from `discovery-namespaces`.

## 5. Key constraints (must not be violated)

| Constraint | Enforced by |
|---|---|
| `vault_kv_secret_v2` (and `vault_kv_secret`, `vault_generic_secret`, AppRole `secret_id` resource) are **forbidden** | `vault-codifier-conventions` §2 |
| No secret values on disk | conventions §3 (replace with `var.*`, grep check after generation) |
| Read-only Vault access | exporter policy + audit log check (TASK-025). Never call Vault MCP write tools or `read_secret` |
| Never root/operator token for discovery | exporter AppRole token only (`vault-exporter-setup`) |
| Builtin objects not codified | conventions §2 (`default`, `root`, `token/`, `sys/`, `identity/`, `cubbyhole/`) |
| Tokens never logged or in the run report | run report holds endpoint + namespace + status only |
| Doc refs are public HTTPS URLs | conventions §4 |

---

## 6. Test harness facts

The synthetic brownfield cluster (started with `make -C test all`) contains:

| Namespace | Auth mounts | KV mounts | Policies (non-builtin) | Identity |
|---|---|---|---|---|
| root `""` | `approle/` (roles: `terraform-admin`, `exporter`) | `secret/` (KV v2, preloaded) | `operator`, `exporter` | 1 entity (`exporter-agent`) and its alias |
| `admin` | `approle/` (role: `namespace-provisioner`) | — | `admin`, `namespace-admin` | 6 entities, 9 groups |
| `admin/platform` | `approle/` (role: `platform-ci`) | `secret/` (KV v2) | `platform-sre-read`, `platform-devops-write` | — |
| `admin/app-billing` | `approle/` (role: `billing-service`) | `secret/` (KV v2) | `billing-developers-read`, `billing-owners-write` | — |
| `admin/app-identity` | `approle/` (role: `identity-service`) | `secret/` (KV v2) | `identity-developers-read`, `identity-owners-write` | — |

Other fixed facts:
- Audit device: `file` at `/vault/logs/audit.log` in root namespace
- Rate-limit quota: `global-rate-limit`, rate=1000, interval=60
- No OIDC/LDAP and no group aliases; one entity alias (`exporter-agent`, root). Discovery must handle empty sets; `make variants` covers the cases the harness lacks
- Builtin objects (`token/`, `sys/`, `identity/`, `cubbyhole/`, `default`, `root`) must be skipped

Start the harness:

```bash
# Requires: Docker, /opt/homebrew/bin/vault, /opt/homebrew/bin/terraform
# and tmp/vault.hclic (never committed)
make -C test up        # start Vault container
make -C test all       # apply all three Terraform layers
make -C test smoke-test  # verify 6/6 checks pass
```

---

## 7. Environment and tool paths

| Tool | Path |
|---|---|
| Vault CLI | `/opt/homebrew/bin/vault` |
| Terraform | `/opt/homebrew/bin/terraform` |
| Docker | `~/.rd/bin/docker` (Rancher Desktop) |
| tflint | `~/.local/bin/tflint` (0.66.0), used by `make static-gate` |
| gh | `/opt/homebrew/bin/gh` (not on the default PATH; auth unconfirmed, TASK-032) |
| jq, curl | on `PATH` |
| waza | `~/bin/waza` (0.42.0), used by TASK-033 |
| Vault licence | `./tmp/vault.hclic` (never committed) |

**Always set before any `vault` CLI call:**

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root  # harness only — never production
```

Vault Enterprise dev-HA flags required: `-dev-ha -dev-transactional -dev-listen-address=0.0.0.0:8200`

---

## 8. Important technical discoveries

| Discovery | Detail |
|---|---|
| `disable_mlock = true` required | Vault Enterprise 2.2.2+ent needs it explicit in config |
| `secret_id_ttl` is integer seconds | Not a duration string in `vault_approle_auth_backend_role`; the `tune {}` block takes `"<n>s"` strings |
| `sys/health` has no `enterprise` key | Vault Enterprise 2.2.2 — do not check for it |
| Stale `~/.config/vault-enterprise/server.hcl` | Always set `VAULT_CONFIG_PATH=/dev/null` |
| `vault_kv_secret_v2` is FORBIDDEN | CAP-004 AC3 — supersedes the design.md resource map |
| Provider `skip_child_token` | Must be `true` in layer 1 (`admin/`) and layer 2 (`namespaces/`) provider blocks |
| Namespace-targeting default | `aliased`, ratified by TASK-006 (resource-level `namespace` breaks `import {}`) |

---

## 9. How to continue

### Recommended start order

1. ~~TASK-006~~, ~~Phase 2 (TASK-007..014)~~, ~~TASK-015..018~~: done and validated.
2. ~~TASK-019 secrets-engines, TASK-020 teams, TASK-021 admin-config~~: done and validated, one commit each.
3. ~~TASK-022 layer assembly~~ and ~~TASK-034 MCP fallback~~: done.
4. ~~TASK-023..027 validation skills~~ and ~~TASK-033 waza fixes~~: done, one commit each.
5. ~~TASK-028 `AGENTS.md`~~ and ~~TASK-029 README and usage guide~~: done, one commit each.
6. ~~TASK-030 traceability~~ and ~~TASK-032 publish~~: done.
7. Follow-ups are two OpenSpec changes. `openspec/changes/vault-codifier-stage-2/` (tracking issue #16; CAP-008 to CAP-012; 10 tasks) is **in progress**: S01 to S04 are done, S05 is in progress. See section 0. `openspec/changes/vault-codifier-remote-review/` (tracking issue #17; CAP-013: a guarded review on a non-harness cluster, needs the cluster owner's written approval; 5 tasks) is not started. Owners are in `docs/traceability.md` section 6.

Per-generator recipe that worked seven times: load the raw JSON with `jq`, keep jq programs in single-quoted heredocs (`read -r -d '' PROG <<'JQ'`) and pass values with `--arg`/`--argjson`, call `scaffold-layer.sh` for `versions.tf` and `providers.tf`, write `<ns>_<capability>.tf` and `imports_<capability>.tf`, exit 2 on orphans, duplicate labels or credential fields, run `terraform fmt`, then re-run and diff for idempotence.

### Gotchas (macOS, zsh)

- `vault` and `terraform` are not on `PATH` by default: `export PATH=$PATH:/opt/homebrew/bin`.
- zsh: `GID` is read-only, `--include=*` globs fail unquoted, and `$var` is not word-split. `jq` treats `label` as reserved; use `lbl`.
- Scripts must run on `/bin/bash` 3.2: use `${arr[@]+"${arr[@]}"}` for empty arrays under `set -u`; no `mapfile`.
- `gh` and the `timeout` command are not available in the default shell.
- Never print or commit the exporter token. Mint one with the `exporter` AppRole at `auth/approle/` (secret-id TTL 900 s, 1 use).

### Running against the harness

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
make -C test up && make -C test all && make -C test smoke-test

# Skills must use the exporter token, never root (see skills/vault-exporter-setup/SKILL.md)
export EXPORTER_TOKEN=...      # from the exporter AppRole login; never print or commit
```

### MCP servers for agents

Terraform and Vault MCP servers are configured for Bob (`.bob/mcp.json`), Claude Code (`.mcp.json`) and VS Code Copilot (`.vscode/mcp.json`). They need `terraform-mcp-server` and `vault-mcp-server` on `PATH`, plus `TFE_TOKEN` and `VAULT_TOKEN`. `.bob/` and `.vscode/` are gitignored, so only `.mcp.json` is shareable.

- The **Terraform MCP** is used by the codification skills for schema and import lookups.
- The **Vault MCP** is **not** used for discovery (see §3). It can return secret values and has write tools, so point it only at the harness. Optional use: `list_mounts` as a cross-check.

---

## 10. Git state

```
main     76bfcd8  published stage-1 line (origin/main)
develop  0f2db79  branches from main; stage 2 merges here with --no-ff
feature/16-stage-2-enterprise-config  checked out at .worktrees/feature-stage-2-enterprise-config
  dea74e7 S01   f624f82 S02   3188dca + f332cf5 S03   ab5af83 gitignore tmp/work/   97707a4 S04   c67f857 S05 WIP (notes, fixture)
Remote:  origin  https://github.com/abuxton/vault-agentic-codifier  (public)
Run state (run_report.json, .state.json) is git-ignored. Generated output under discovered_terraform/terraform/ and the evidence under discovered_terraform/validation/ are committed.
```

The harness container `vault-codifier-dev` (Vault 2.2.2+ent, 127.0.0.1:8200) is shared by both checkouts. In the worktree, `tmp/vault.hclic` is a symlink to the main checkout's licence (git-ignored) and Terraform state, `.terraform` and lock files are copied into `test/terraform/{admin,namespaces,seed}`.

Push commands are in section 0. The pre-commit and pre-push hooks run the Vault Radar secret scan; fix findings, never bypass.

---

*Updated 2026-11-25 for the stage-2 handoff. Stage 1: 34 of 34 tasks done. Stage 2: S01 to S04 done, S05 in progress. Convention: one commit per task.*
