# Handoff Document — terraform-vault-vault-codifier

**Date**: 2026-11-25
**Commit**: `965cc07` on `main` (no remote yet; see TASK-032), plus this handoff and `STATUS_REPORT.md` update
**Status**: Phase 1 and Phase 2 **done and validated**. **Phase 3 and Phase 4 are complete** (33 of 34 tasks; TASK-015..027, TASK-033 and TASK-034 done). Next step: Phase 5, TASK-028..030 (docs), then TASK-032 (publish). `bash skills/codification-layer-assembly/scripts/assemble.sh` regenerates and checks everything. Full numbers are in [`STATUS_REPORT.md`](STATUS_REPORT.md).

> **Approach**: the whole deliverable is a set of **agent skills** (`skills/*/SKILL.md`). There is no Python. See §3 for which tool each phase uses and why.

---

## 1. What this project is

`terraform-vault-vault-codifier` is an agentic, spec-driven toolkit (agent skills with runnable bash and jq scripts; no Python) that surveys a **live HashiCorp Vault Enterprise cluster** through read-only API calls and produces **idiomatic Terraform HCL** that adopts the existing configuration into version control.

The goal is a Terraform baseline for which `terraform plan` shows **no changes** against the live cluster, aligned with HashiCorp Validated Design (HVD) best practices.

**It never writes to Vault.** Every API call is `GET` or `LIST`. Secrets are never read or emitted. Generators refuse to write when a payload contains a credential field.

---

## 2. Repository layout

```
terraform-vault-vault-codifier/
├── PROJECT_BRIEF.md
├── openspec/changes/vault-brownfield-research/
│   ├── proposal.md · specs.md · design.md · tasks.md
│   └── task-006-decision.md           ← verified import IDs, namespace style, Enterprise features
├── skills/                            ← 17 agent skills (the deliverable); runnable scripts under each `scripts/`
│   ├── vault-codifier-conventions/    ← START HERE: tool choice, secret guard, naming, header, providers, layers
│   ├── vault-exporter-setup/          ← TASK-031: provision the read-only exporter identity
│   ├── discovery-{namespaces,root-config,policies,auth-mounts,
│   │             secrets-engines,identity-teams,admin-config,orchestrator}/   ← TASK-007..014
│   └── codification-{namespaces,root-config,policies,auth-mounts,
│                     secrets-engines,teams,admin-config}/                     ← TASK-015..021
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

### Phase 5 — Not started

| Task | Title | Status |
|---|---|---|
| TASK-028..030 | AGENTS.md, README, traceability | Not started |
| **TASK-032** | Create the GitHub repository and publish to `https://github.com/abuxton/vault-agentic-codifier` | Ready. Needs `gh auth login`; review the committed `discovered_terraform/` output first |
| **TASK-034** | Terraform MCP installed, or fallback documented | **Done**. Fallback documented in `vault-codifier-conventions` and every codification skill |

### Waza review (TASK-033), done

Waza 0.42.0 reports 23 of 23 skills `ready`, no `spec-allowed-fields` warnings and no broken links. `.waza.yaml` sets a 1,500-token limit. Detail moved verbatim to `skills/*/references/` (101 files, 0 lines lost). Retained advisories (`body-structure`, `complexity`, `module-count`, `over-specificity`, `negative-delta-risk`, `cross-model-density`) and the skipped eval suite are recorded with reasons in [`docs/waza-review.md`](docs/waza-review.md). `waza check` also scans `.claude/skills` (the openspec skills); ignore those. Run it with `WAZA_NO_UPDATE_CHECK=1 WAZA_TELEMETRY_OPTOUT=1 waza check --format json`.

### Known discrepancies to resolve

- `design.md` §6.2 still contains Python pseudocode. It is illustrative; the skills are authoritative.
- **Alias id** is now kept by discovery (`identity-teams.sh`), because alias imports use it. Raw payloads were refreshed.
- **Human auth in `admin`** (`oidc`, `jwt`, `ldap`) is emitted by admin-config; auth-mounts skips those mounts. admin-config's `vault_auth_backend` grep applies to its own files only.
- The harness has 4 KV mounts (root `secret/` is imported too), 7 entities, 9 groups and 1 alias.
- The AC-1 counts in the discovery skills and in `codification-policies` and `codification-auth-mounts` now include the `exporter` objects (10 policies, 6 roles). Skills must tolerate harness drift.
- Variant branches are covered by `make variants` (TASK-026) on throwaway containers; EGP, RGP and MFA are still not exercised.
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
| root `""` | `approle/` (role: `terraform-admin`) | — | `operator`, `exporter` | — |
| `admin` | `approle/` (role: `namespace-provisioner`) | — | `admin`, `namespace-admin` | 6 entities, 9 groups |
| `admin/platform` | `approle/` (role: `platform-ci`) | `secret/` (KV v2) | `platform-sre-read`, `platform-devops-write` | — |
| `admin/app-billing` | `approle/` (role: `billing-service`) | `secret/` (KV v2) | `billing-developers-read`, `billing-owners-write` | — |
| `admin/app-identity` | `approle/` (role: `identity-service`) | `secret/` (KV v2) | `identity-developers-read`, `identity-owners-write` | — |

Other fixed facts:
- Audit device: `file` at `/vault/logs/audit.log` in root namespace
- Rate-limit quota: `global-rate-limit`, rate=1000, interval=60
- No OIDC/LDAP, no group aliases, no entity aliases — discovery must handle empty-set correctly
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
5. **TASK-028..030** docs, then **TASK-032** publish. Commit after each task.

Per-generator recipe that worked seven times: load the raw JSON with `jq`, keep jq programs in single-quoted heredocs (`read -r -d '' PROG <<'JQ'`) and pass values with `--arg`/`--argjson`, call `scaffold-layer.sh` for `versions.tf` and `providers.tf`, write `<ns>_<capability>.tf` and `imports_<capability>.tf`, exit 2 on orphans, duplicate labels or credential fields, run `terraform fmt`, then re-run and diff for idempotence.

### Gotchas (macOS, zsh)

- `vault` and `terraform` are not on `PATH` by default: `export PATH=$PATH:/opt/homebrew/bin`.
- zsh: `GID` is read-only, `--include=*` globs fail unquoted, and `$var` is not word-split. `jq` treats `label` as reserved; use `lbl`.
- Scripts must run on `/bin/bash` 3.2: use `${arr[@]+"${arr[@]}"}` for empty arrays under `set -u`; no `mapfile`.
- `gh` and the `timeout` command are not available in the default shell; `gh auth status` can hang.
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
Branch:  main
Head:    965cc07  docs(conventions): ... (TASK-034)
         a0be155  feat(codification-layer-assembly): ... (TASK-022)
         3bb9c0f  docs: update status report and handoff after TASK-019..021
         08e35f9  feat(codification-admin-config): ... (TASK-021)
         f9ad41b  feat(codification-teams): ... (TASK-020)
         de99452  feat(codification-secrets-engines): ... (TASK-019)
         250a4ad  feat(codification-auth-mounts): ... (TASK-018)
         23e9e44  feat(codification-policies): ... (TASK-017)
         88c3cd8  feat(codification-root-config): ... (TASK-016)
         75c15f1  feat(codification-namespaces): ... (TASK-015)
         bfcb039  feat(discovery): validate TASK-007..014 ...
Remote:  (none; TASK-032)
Generated output under discovered_terraform/terraform/ and run_report.json is committed; TASK-032 decides whether it stays.
```

Before the first push (TASK-032) decide what to do with `discovered_terraform/terraform/` and `discovered_terraform/.state.json`, and confirm `test/terraform/**/terraform.tfstate*` and `*.hclic` are ignored. Then:

```bash
gh auth login
gh repo create <owner>/terraform-vault-vault-codifier --private --source=. --remote=origin
git push -u origin main
```

---

*Updated 2026-11-25 after TASK-022 and TASK-034. Convention: one commit per task.*
