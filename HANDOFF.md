# Handoff Document — terraform-vault-vault-codifier

**Date**: 2026-11-24
**Commit**: `3b84fd0` (branch `main`, no remote yet), plus uncommitted work from the TASK-006 and "skills only" sessions
**Status**: Phase 1 and TASK-006 **done**. Discovery and codification skills (TASK-007..021) are **authored but not yet executed**. Next step: validate them against the harness, starting with `discovery-orchestrator`.

> **Approach**: the whole deliverable is a set of **agent skills** (`skills/*/SKILL.md`). There is no Python. See §3 for which tool each phase uses and why.

---

## 1. What this project is

`terraform-vault-vault-codifier` is an agentic, spec-driven toolkit (agent skills plus a small Python foundation library) that surveys a **live HashiCorp Vault Enterprise cluster** through read-only API calls and produces **idiomatic Terraform HCL** that adopts the existing configuration into version control.

The goal is a Terraform baseline for which `terraform plan` shows **no changes** against the live cluster, aligned with HashiCorp Validated Design (HVD) best practices.

**It never writes to Vault.** Every API call is `GET` or `LIST`. Secrets are never read or emitted. All generated files are scrubbed by a guard before writing.

---

## 2. Repository layout

```
terraform-vault-vault-codifier/
├── PROJECT_BRIEF.md
├── openspec/changes/vault-brownfield-research/
│   ├── proposal.md · specs.md · design.md · tasks.md
│   └── task-006-decision.md           ← verified import IDs, namespace style, Enterprise features
├── skills/                            ← 17 agent skills (the deliverable)
│   ├── vault-codifier-conventions/    ← START HERE: tool choice, secret guard, naming, header, providers, layers
│   ├── vault-exporter-setup/          ← TASK-031: provision the read-only exporter identity
│   ├── discovery-{namespaces,root-config,policies,auth-mounts,
│   │             secrets-engines,identity-teams,admin-config,orchestrator}/   ← TASK-007..014
│   └── codification-{namespaces,root-config,policies,auth-mounts,
│                     secrets-engines,teams,admin-config}/                     ← TASK-015..021
├── test/                              ← synthetic brownfield harness (docker-compose + 3 Terraform layers)
├── tmp/                               ← research notes (never commit vault.hclic)
└── discovered_terraform/              ← skill output (raw/ is git-ignored)
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

**Status legend for Phases 2–3**: *Skill authored* = `SKILL.md` written and committed. *Validated* = executed against the harness with its acceptance criteria checked. Nothing in Phases 2–3 is validated yet: `discovered_terraform/raw/` is empty and no HCL has been generated.

### Phase 2 — Discovery Engine (skills authored, not validated)

| Task | Title | Skill (the deliverable) | Skill authored | Validated |
|---|---|---|---|---|
| TASK-006 | Resolve specs open items | — (research task) | n/a | **Done** — see §4 |
| TASK-007 | Namespace discovery | `discovery-namespaces` | Yes | No |
| TASK-008 | Root-config discovery | `discovery-root-config` | Yes | No |
| TASK-009 | Policy discovery | `discovery-policies` | Yes | No |
| TASK-010 | Auth-mount discovery | `discovery-auth-mounts` | Yes | No |
| TASK-011 | Secrets-engine discovery | `discovery-secrets-engines` | Yes | No |
| TASK-012 | Identity/teams discovery | `discovery-identity-teams` | Yes | No |
| TASK-013 | Admin-config discovery | `discovery-admin-config` | Yes | No |
| TASK-014 | Discovery orchestrator | `discovery-orchestrator` | Yes | No |

The orchestrator skill runs the seven discovery skills in dependency order and writes `discovered_terraform/raw/<namespace>/*.json` plus `discovered_terraform/run_report.json`. It requires `EXPORTER_TOKEN` and an enabled audit device, and refuses to run with a root token.

### Phase 3 — Codification Engine (skills authored, not validated)

| Task | Title | Skill | Skill authored | Validated |
|---|---|---|---|---|
| TASK-015 | Namespaces generator | `codification-namespaces` | Yes | No |
| TASK-016 | Root-config generator | `codification-root-config` | Yes | No |
| TASK-017 | Policies generator + correlation matrix | `codification-policies` | Yes | No |
| TASK-018 | Auth-mounts generator | `codification-auth-mounts` | Yes | No |
| TASK-019 | Secrets-engines generator | `codification-secrets-engines` | Yes | No |
| TASK-020 | Teams generator | `codification-teams` | Yes | No |
| TASK-021 | Admin-config generator | `codification-admin-config` | Yes | No |
| TASK-022 | Layer assembly, imports, ownership check | **none yet** | No | No |

TASK-022 has no skill, and neither do TASK-023..027. TASK-028..030 are documentation tasks.

### Phases 4–5 — Not started

Validation (TASK-023..027) and documentation (TASK-028..030) have no deliverables yet. They need generated HCL from Phase 3 to be meaningful.

### Known discrepancies to resolve

- ~~`tasks.md` status stale~~ — fixed. ~~`**Module**:` Python paths~~ — removed. ~~Dangling `discovery-client-setup`~~ — removed.
- `design.md` §6.2 still contains Python pseudocode. It is illustrative; the skills are authoritative.
- The skills have never run. Expect acceptance-criteria failures in the first validation pass.

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
| Docker | `~/.rd/bin/docker` (Rancher Desktop; was `/usr/local/bin/docker` in earlier notes) |
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
| `secret_id_ttl` is integer seconds | Not a duration string in `vault_approle_auth_backend_role` |
| `sys/health` has no `enterprise` key | Vault Enterprise 2.2.2 — do not check for it |
| Stale `~/.config/vault-enterprise/server.hcl` | Always set `VAULT_CONFIG_PATH=/dev/null` |
| `vault_kv_secret_v2` is FORBIDDEN | CAP-004 AC3 — supersedes the design.md resource map |
| Provider `skip_child_token` | Must be `true` in layer 1 (`admin/`) and layer 2 (`namespaces/`) provider blocks |
| Namespace-targeting default | `aliased`, ratified by TASK-006 (resource-level `namespace` breaks `import {}`) |

---

## 9. How to continue

### Recommended start order

1. ~~TASK-006~~ — done (§4).
2. **Validate Phase 2.** Provision the exporter (`vault-exporter-setup`), export `EXPORTER_TOKEN`, run `discovery-orchestrator`. Check TASK-007..014 acceptance criteria in `tasks.md` (4 namespaces, parent-before-child, byte-identical re-runs, run report with no surprises).
3. **Validate Phase 3** against the raw payloads in dependency order: namespaces → root-config → policies → auth-mounts → secrets-engines → teams → admin-config. Fix skills where acceptance criteria fail.
4. **Fill the gaps**: author skills for TASK-022 (assembly, imports, ownership check) and validation TASK-023..027.
5. Documentation TASK-028..030.

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
Commit:  3b84fd0  docs: add HANDOFF.md — Phase 1 complete, Phase 2 ready to start
         1be0e4f  feat: initial commit — Phase 1 foundation complete
Remote:  (none — add with: git remote add origin <url>)
Files:   89 tracked (includes all 16 skills). .gitignore excludes *.hclic, raw/, run-reports, .agents/, .bob/, .claude/, .vscode/
Untracked: .github/, .opencode/, .mcp.json, skills-lock.json (agent tooling and MCP config, not yet committed)
```

To push when ready:

```bash
git remote add origin git@github.com:<org>/terraform-vault-vault-codifier.git
git push -u origin main
```

---

*Generated by vault-brownfield-codifier project — 2026-11-24*
