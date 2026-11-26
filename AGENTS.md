# AGENTS.md

Guidance for people and coding agents working in this repository. Read [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) for the goal, and [`HANDOFF.md`](HANDOFF.md) for the current state.

The deliverable is a set of agent skills under [`skills/`](skills/). Each skill has a `SKILL.md` and, where it runs code, bash and `jq` scripts in `scripts/`. The skills contain no Python and no compiled code; the one Python file, `scripts/waza-restructure.py`, is a record of the TASK-033 restructure.

## Constraints (not negotiable)

1. **Read-only.** The codifier sends only `GET` and `LIST` requests to the Vault cluster it surveys. Discovery authenticates as the `exporter` identity (policy [`exporter.hcl`](test/terraform/admin/policies/exporter.hcl)), never as a root or operator token. `discovery-orchestrator/scripts/run.sh` refuses a token that carries the `root` policy. `make verify` proves the rule from the audit log.
2. **No secrets in output.** Generated files never contain tokens, AppRole `secret_id` values, KV data or other sensitive values. Sensitive arguments become `variable` blocks with `sensitive = true` and no default. The generators exit 2 when a payload holds a credential field. Never emit `vault_kv_secret_v2`, `vault_kv_secret`, `vault_generic_secret` or `vault_approle_auth_backend_role_secret_id`.
3. **Licence.** A Vault Enterprise licence is needed to start the harness. The harness reads it from `tmp/vault.hclic` (`VAULT_LICENSE_SRC` overrides the path; see [`test/PREREQUISITES.md`](test/PREREQUISITES.md)). Never commit a licence. `*.hclic` is git-ignored. Never print licence text.
4. **Harness only.** The harness runs Vault at `http://127.0.0.1:8200`, with TLS off and root token `root`. Every validation script refuses any other address. Never bind a service to `0.0.0.0` in new code.
5. **Do not bypass the commit scanner.** A secret scanner runs on every commit. Fix the code that it flags. Avoid `pass`, `password` or `secret` next to `=` or `:` in scripts.
6. **Synthetic data.** Harness secret values are marked `SYNTHETIC-*-REPLACE-IN-PRODUCTION`. They must not appear in generated output.

## Roles

From [`design.md`](openspec/changes/vault-brownfield-research/design.md) §3.

| Role | Does | Deliverables |
|---|---|---|
| Vault Expert | Reads Vault endpoints, walks namespaces, extracts raw payloads | `discovery-*` skills, raw payloads in `discovered_terraform/raw/` |
| Solution Architect | Maps Vault objects to `hashicorp/vault` resources, defines layers and state boundaries | `codification-*` skills, [`tmp/terraform-resource-map.md`](tmp/terraform-resource-map.md), `admin/` `namespaces/` `seed/` layers |
| SRE | Runs the harness, linting, validate and plan, proves zero drift | `validation-*` skills, reports in `discovered_terraform/validation/` |
| Technical Writer | Documents findings, structure and HVD alignment | [`tmp/domain-model.md`](tmp/domain-model.md), [`tmp/brownfield-discovery-guide.md`](tmp/brownfield-discovery-guide.md), [`tmp/hvd-alignment-matrix.md`](tmp/hvd-alignment-matrix.md), `docs/` |

## Commands

Set the environment first. Run from the repository root.

```bash
export PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin:$HOME/.rd/bin
export VAULT_CONFIG_PATH=/dev/null VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root     # harness only
```

| Command | Purpose |
|---|---|
| `make -C test all` | Start the harness Vault, write `.vault-env`, apply the seed layers |
| `make -C test smoke-test` | Check Vault is up and every namespace and secret is reachable |
| `make -C test fmt validate` | Format and validate the harness Terraform |
| `make -C test reset` | Tear down and rebuild the harness |
| `make help` | List the root targets |
| `make assemble` | Run the seven generators in order, then ownership check, fmt, init and validate |
| `make ownership` | Check ownership, labels, imports and provenance headers |
| `make static-gate` | `terraform validate`, `fmt -check` and `tflint` per layer |
| `make zero-diff` | Import into a scratch state; the plan must exit 0 in every layer |
| `make verify` | Audit log is read-only for the discovery window; no secret in the output |
| `make verify-selftest` | Inject faults; the verifier must catch every one |
| `make variants` | Edge-case fixtures on throwaway containers (ports 18200 and 18201) |
| `make codify-test` | One command, stages 1 to 11 (CAC1 to CAC7). `VARIANTS=1` adds the fixtures |

`make codify-test` is the acceptance run. Run it before you commit a change to a generator or a discovery script.

## Capability order

`namespaces` → `root-config` → `policies` → `auth-mounts` → `secrets-engines` → `teams` → `admin-config`. A generator may reference only resources owned by an earlier capability. [`assemble.sh`](skills/codification-layer-assembly/scripts/assemble.sh) runs them in this order.

## Resource ownership

One resource type has exactly one owning skill. The rule lives in [`vault-codifier-conventions`](skills/vault-codifier-conventions/SKILL.md); `make ownership` enforces it.

| Resource type | Owner |
|---|---|
| `vault_namespace` | `codification-namespaces` |
| `vault_policy`, `vault_egp_policy`, `vault_rgp_policy` | `codification-policies` |
| `vault_auth_backend`, auth roles and config | `codification-auth-mounts` (human OIDC, JWT and LDAP in `admin`: `codification-admin-config`) |
| `vault_mount`, engine config | `codification-secrets-engines` |
| `vault_identity_*` | `codification-teams` |
| `vault_audit`, `vault_quota_*`, system `vault_generic_endpoint` | `codification-root-config` |

`vault_generic_endpoint` has no import support. Do not emit an `import {}` block for it.

## Working on a skill

- Start from [`vault-codifier-conventions`](skills/vault-codifier-conventions/SKILL.md): tool choice, secret guard, naming, provenance header, providers, layers. If a skill disagrees with it, the conventions win.
- Keep `SKILL.md` within the 1,500-token limit in [`.waza.yaml`](.waza.yaml). Put examples, schemas and acceptance criteria in `references/`. Check with `WAZA_NO_UPDATE_CHECK=1 WAZA_TELEMETRY_OPTOUT=1 waza check`. Findings are explained in [`docs/waza-review.md`](docs/waza-review.md).
- Scripts must run on bash 3.2: no `mapfile`; use `${arr[@]+"${arr[@]}"}` for arrays that may be empty under `set -u`. Keep `jq` programs in single-quoted heredocs and pass values with `--arg`. Generators must be idempotent: a second run is byte-identical.
- On macOS zsh, `GID` is read-only and `PIPESTATUS` does not exist.
- Provider `hashicorp/vault` is pinned at 4.8.0 in the harness lock files. Look up schemas with the Terraform MCP when available; otherwise use `terraform providers schema -json` (the documented fallback).
- Use conventional commit messages, one commit per task, and stage only that task's files.

## Where things are

| Path | Contents |
|---|---|
| [`skills/`](skills/) | The 23 skills: `vault-*` (2), `discovery-*` (8), `codification-*` (8), `validation-*` (5) |
| [`Makefile`](Makefile) | Root targets that call the validation scripts |
| [`test/`](test/) | The synthetic brownfield harness (docker compose and three Terraform layers) |
| [`discovered_terraform/`](discovered_terraform/) | `raw/`, `run_report.json` and `.state.json` (all git-ignored run state), `terraform/` (generated), `validation/` (reports) |
| [`openspec/changes/vault-brownfield-research/`](openspec/changes/vault-brownfield-research/) | `proposal.md`, `specs.md`, `design.md`, `tasks.md`, `task-006-decision.md` |
| [`tmp/`](tmp/) | Research notes. `tmp/vault.hclic` is the licence and is never committed |
| [`docs/`](docs/) | [Usage guide](docs/usage-guide.md), [traceability](docs/traceability.md), [waza review](docs/waza-review.md) |
| [`HANDOFF.md`](HANDOFF.md), [`STATUS_REPORT.md`](STATUS_REPORT.md) | Current state, evidence, risks |

## Documentation source

Cite Vault documentation as repository-relative paths in `git@github.com:hashicorp/web-unified-docs.git`, for example `content/validated-designs/docs/docs/vault/administration-guide/authentication-for-people.mdx`. Do not cite local paths. Every generated file starts with a provenance header naming its capability and the documentation path (CAC7).
