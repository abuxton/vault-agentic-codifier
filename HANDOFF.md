# Handoff Document — terraform-vault-vault-codifier

**Date**: 2026-11-24  
**Commit**: `1be0e4f` (branch `main`, no remote yet)  
**Status**: Phase 1 (Foundation) **complete** — Phase 2 (Discovery Engine) **ready to start**

---

## 1. What this project is

`terraform-vault-vault-codifier` is an agentic, spec-driven Python tool that surveys a **live HashiCorp Vault Enterprise cluster** through read-only API calls and produces **idiomatic Terraform HCL** that adopts the existing configuration into version control.

The goal is a Terraform baseline for which `terraform plan` shows **no changes** against the live cluster, aligned with HashiCorp Validated Design (HVD) best practices.

**It never writes to Vault.** Every API call is `GET` or `LIST`. Secrets are never read or emitted. All generated files are scrubbed by a guard before writing.

---

## 2. Repository layout

```
terraform-vault-vault-codifier/
├── PROJECT_BRIEF.md                   ← one-page overview
├── openspec/changes/vault-brownfield-research/
│   ├── proposal.md                    ← original problem statement
│   ├── specs.md                       ← 7 capability specs (CAP-001..007)
│   ├── design.md                      ← 4-phase pipeline, 3-layer structure
│   └── tasks.md                       ← 31 tasks with status
│
├── tmp/                               ← research artifacts (never commit vault.hclic)
│   ├── domain-model.md                ← Vault concept taxonomy
│   ├── terraform-resource-map.md      ← Vault API path → Terraform resource map
│   ├── brownfield-discovery-guide.md  ← walkthrough + troubleshooting
│   └── hvd-alignment-matrix.md        ← HVD guide → capability alignment
│
├── codifier/                          ← Python package (stdlib only, Python 3.9+)
│   ├── __main__.py                    ← CLI entry point
│   ├── shared/
│   │   ├── constants.py               ← capability slugs, layer map, sensitive fields
│   │   ├── providers.py               ← TASK-002: versions.tf + providers.tf generator
│   │   ├── naming.py                  ← TASK-003: deterministic label/path library
│   │   ├── headers.py                 ← TASK-004a: provenance header writer
│   │   └── guard.py                   ← TASK-004b: secret-scrubbing guard
│   ├── discovery/
│   │   ├── client.py                  ← TASK-005: read-only Vault HTTP client + RunReport
│   │   └── <7 stubs>                  ← TASK-007..013 (namespaces through admin-config)
│   ├── codification/
│   │   └── <8 stubs>                  ← TASK-015..022
│   └── validation/
│       └── <4 stubs>                  ← TASK-023..027
│
├── tests/
│   ├── test_shared.py                 ← 40 tests: providers, naming, guard, headers
│   └── test_client.py                 ← 18 tests: VaultClient + RunReport (offline)
│
├── skills/                            ← 16 agent SKILL.md files
│   ├── vault-exporter-setup/          ← how to provision exporter identity
│   ├── discovery-{namespaces,root-config,policies,auth-mounts,
│   │             secrets-engines,identity-teams,admin-config,orchestrator}/
│   └── codification-{namespaces,root-config,policies,auth-mounts,
│                     secrets-engines,teams,admin-config}/
│
├── test/                              ← synthetic brownfield harness
│   ├── Makefile                       ← make all / make smoke-test
│   ├── docker-compose.yml             ← Vault Enterprise 2.2.2+ent dev-HA
│   └── terraform/{admin,namespaces,seed}/
│
└── discovered_terraform/              ← codifier output (raw/ excluded by .gitignore)
```

---

## 3. Task status

### Phase 1 — Foundation (all done)

| Task | Title | Deliverable |
|---|---|---|
| TASK-001 | Project scaffolding | `codifier/` package, `constants.py`, output layout |
| TASK-002 | Provider template | `shared/providers.py` — `versions.tf` + `providers.tf` |
| TASK-003 | Naming library | `shared/naming.py` — labels, paths, collision registry |
| TASK-004 | Headers + guard | `shared/headers.py` + `shared/guard.py` |
| TASK-005 | Vault API client | `discovery/client.py` — read-only, RunReport, retry/backoff |
| TASK-031 | Exporter identity | `test/terraform/admin/policies/exporter.hcl` + `skills/vault-exporter-setup/SKILL.md` |

**Tests: 58/58 passing.** Run with:

```bash
python3 -m unittest discover -s tests -p "test_*.py" -v
```

### Phase 2 — Discovery Engine (ready to start)

| Task | Title | Module | Skill |
|---|---|---|---|
| TASK-006 | Resolve specs open items | research task | — |
| TASK-007 | Namespace discovery | `discovery/namespaces.py` | `discovery-namespaces` |
| TASK-008 | Root-config discovery | `discovery/root_config.py` | `discovery-root-config` |
| TASK-009 | Policy discovery | `discovery/policies.py` | `discovery-policies` |
| TASK-010 | Auth-mount discovery | `discovery/auth_mounts.py` | `discovery-auth-mounts` |
| TASK-011 | Secrets-engine discovery | `discovery/secrets_engines.py` | `discovery-secrets-engines` |
| TASK-012 | Identity/teams discovery | `discovery/identity_teams.py` | `discovery-identity-teams` |
| TASK-013 | Admin-config discovery | `discovery/admin_config.py` | `discovery-admin-config` |
| TASK-014 | Discovery orchestrator | `discovery/orchestrator.py` | `discovery-orchestrator` |

TASK-006 should be done first — it resolves three open items in `specs.md` that inform the discovery modules.

### Phases 3–5 — Blocked on Phase 2

Codification generators (TASK-015..021), assembly (TASK-022), validation (TASK-023..027), and documentation (TASK-028..030) are all blocked until Phase 2 is complete.

---

## 4. Specs open items (TASK-006)

Three questions need answers before writing the discovery modules. They are listed at the bottom of [`specs.md`](openspec/changes/vault-brownfield-research/specs.md):

1. **Import ID formats** — Confirm the `terraform import` ID format for each resource type in provider `4.8.0`. For namespace-scoped resources the format is typically `<namespace>/<path>`. Verify experimentally against the harness with `terraform import` or an `import {}` block.

2. **Namespace-targeting style default** — `aliased` (one `provider "vault" { alias = "admin" }` per namespace) vs `resource` (single provider + `namespace = "..."` per resource). Both are implemented in `shared/providers.py`. Pick one as the default and wire it into `__main__.py`.

3. **EGP / RGP / MFA / Sentinel / replication** — Which Enterprise features get a dedicated `vault_*` Terraform resource vs `vault_generic_endpoint` fallback? None exist in the harness, so a "skip + document" approach is acceptable.

---

## 5. Key constraints (must not be violated)

| Constraint | Enforced by |
|---|---|
| `vault_kv_secret_v2` is **forbidden** — never emit | `guard.assert_resource_allowed()` + `constants.FORBIDDEN_RESOURCES` |
| No secret values on disk | `guard.Guard.scrub()` replaces with `var.*` references |
| Read-only Vault access | `VaultClient._assert_method_allowed()` — POST/PUT/DELETE/PATCH raise `PermissionError` before any network call |
| Never root/operator token for discovery | Use exporter AppRole token only (see `skills/vault-exporter-setup/SKILL.md`) |
| All doc refs must be public HTTPS URLs | Verified live at `developer.hashicorp.com/vault/docs` and `developer.hashicorp.com/validated-designs/vault/` |
| Tokens never logged or in run report | `RunReport` stores only endpoint + namespace + status |
| Builtin objects not codified | `constants.BUILTIN_POLICIES`, `BUILTIN_AUTH_MOUNTS`, `BUILTIN_SECRET_MOUNTS` |

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
| Docker | `/usr/local/bin/docker` |
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
| Namespace-targeting default | `aliased` style (one provider alias per namespace) — not yet wired as default in CLI |

---

## 9. How to continue

### Quick orient

```bash
cd /Users/abuxton/src/github/terraform-vault-vault-codifier

# Confirm tests green
python3 -m unittest discover -s tests -p "test_*.py" -v

# Read task status
grep -A1 "TASK-006\|TASK-007\|TASK-008\|TASK-009" \
  openspec/changes/vault-brownfield-research/tasks.md | head -40

# Review the open items
tail -10 openspec/changes/vault-brownfield-research/specs.md
```

### Recommended start order

1. **TASK-006** — resolve the three open items in `specs.md`; update `tmp/terraform-resource-map.md` where import IDs differ from assumptions; wire namespace-targeting default into `__main__.py`
2. **TASK-007** — implement `codifier/discovery/namespaces.py` using `VaultClient.list("/sys/namespaces")` recursively; use the `discovery-namespaces` skill as the spec
3. **TASK-008..013** — implement the remaining discovery modules in dependency order (see `specs.md §Dependency order`)
4. **TASK-014** — wire all discovery modules into the orchestrator; write raw JSON payloads to `discovered_terraform/raw/`

### Importing the foundation libraries

Every new module starts with:

```python
from codifier.shared.constants import CAPABILITY_ORDER, BUILTIN_POLICIES, ...
from codifier.shared.naming import resource_label, CollisionRegistry
from codifier.shared.headers import prepend_header
from codifier.shared.guard import Guard, assert_resource_allowed
from codifier.discovery.client import VaultClient, RunReport
```

### Running against the harness

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root        # or exporter AppRole token (preferred)

# CLI smoke check
python3 -m codifier --dry-run

# When discovery modules are implemented:
python3 -m codifier --phase discovery --output-dir discovered_terraform
```

---

## 10. Git state

```
Branch:  main
Commit:  1be0e4f  feat: initial commit — Phase 1 foundation complete
Remote:  (none — add with: git remote add origin <url>)
Files:   88 tracked, .gitignore excludes *.hclic, raw/, run-reports, .agents/, .bob/, .claude/
```

To push when ready:

```bash
git remote add origin git@github.com:<org>/terraform-vault-vault-codifier.git
git push -u origin main
```

---

*Generated by vault-brownfield-codifier project — 2026-11-24*
