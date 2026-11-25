# Usage guide: from a live cluster to reviewed Terraform

This guide takes you from a running Vault Enterprise cluster to reviewed HCL with a zero-diff plan. Every command was run as written against the harness on 2026-11-25. Commands that need a real cluster say so.

**The rules.** Discovery is read-only: only `GET` and `LIST`, using the `exporter` identity, never a root or operator token. Generated files never contain secrets. The harness root token `root` and `127.0.0.1:8200` are for local testing only. See [`AGENTS.md`](../AGENTS.md).

Vault documentation is cited as repository-relative paths in `git@github.com:hashicorp/web-unified-docs.git`, for example `content/validated-designs/docs/docs/vault/administration-guide/authentication-for-people.mdx`.

## 1. Prerequisites

| Tool | Minimum | Check |
|---|---|---|
| Docker with Compose (harness only) | 25, 2.24 | `docker version` |
| `terraform` | 1.9 | `terraform version` |
| `vault` CLI | 1.17 | `vault version` |
| `jq`, `curl`, `make` | any | `jq --version` |
| `tflint` (static gate only) | 0.66 | `tflint --version` |
| Vault Enterprise licence (harness only) | none | `ls tmp/vault.hclic` |

Put the licence at `tmp/vault.hclic`. It is git-ignored; never commit it ([`test/PREREQUISITES.md`](../test/PREREQUISITES.md)).

```bash
export PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin:$HOME/.rd/bin
export VAULT_CONFIG_PATH=/dev/null       # ignore a stray local Vault config
export VAULT_ADDR=http://127.0.0.1:8200  # your cluster address in real use
```

## 2. Start the harness (skip for a real cluster)

```bash
make -C test all          # start Vault Enterprise, seed synthetic data
make -C test smoke-test   # every namespace and secret is reachable
```

The harness has four namespaces (`admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`), AppRole auth, KV v2 mounts, 10 policies and identity groups.

## 3. Create the exporter identity

The exporter is a read-only AppRole with the `exporter` policy ([`test/terraform/admin/policies/exporter.hcl`](../test/terraform/admin/policies/exporter.hcl)). It can read and list structure. It is explicitly denied KV data and metadata and AppRole `role-id` and `secret-id` paths, and has no grant on `sys/license` or `sys/raw`. Tokens last one hour (`token_ttl` 3600, maximum four hours). The secret-id is single use.

On the harness, `make -C test all` has already created it. On a real cluster, apply the policy and role from [`test/terraform/admin/`](../test/terraform/admin/) with an administrator, following [`vault-exporter-setup`](../skills/vault-exporter-setup/SKILL.md). Also review the policy against section 1.2 of [`tmp/brownfield-discovery-guide.md`](../tmp/brownfield-discovery-guide.md). The audit log must have at least one enabled device; discovery refuses to run without one.

Log in. The bootstrap token is used only to mint a one-time secret-id, in a subshell:

```bash
export EXPORTER_TOKEN=$(
  SECRET_ID=$(VAULT_TOKEN=root vault write -f -field=secret_id auth/approle/role/exporter/secret-id)
  ROLE_ID=$(VAULT_TOKEN=root vault read -field=role_id auth/approle/role/exporter/role-id)
  vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID"
)
```

Replace `root` with an administrator token on a real cluster. The shell now holds only the exporter token.

## 4. Run discovery

```bash
bash skills/discovery-orchestrator/scripts/run.sh
unset EXPORTER_TOKEN
```

It runs the seven discovery steps in dependency order (about six seconds on the harness) and writes `discovered_terraform/raw/` (git-ignored; raw payloads may hold sensitive fields) and `discovered_terraform/run_report.json`. It refuses a token that carries the `root` policy and refuses to start without an audit device. Resume a failed run with `FROM=discovery-auth-mounts` (any step name).

Read the run report:

```bash
jq . discovered_terraform/run_report.json
```

| Field | Meaning |
|---|---|
| `exit_code` | 0 ok, 1 a step failed, 2 a stop condition |
| `namespaces_discovered` | the tree, parents first |
| `non_200_responses` | paths that returned 403, 404 or another status; empty on the harness |
| `start_time`, `end_time` | the window `make verify` audits |

## 5. Generate Terraform

```bash
make assemble
```

This runs the seven generators in order (namespaces, root-config, policies, auth-mounts, secrets-engines, teams, admin-config), then the ownership check, then `fmt`, `init` and `validate` in every layer. It is idempotent. Run it again and the output is byte-identical.

| Layer | Directory | Holds | Provider auth |
|---|---|---|---|
| 1 | `discovered_terraform/terraform/admin/` | root namespace: audit, quotas, the `admin` namespace, root and admin policies, identity, auth and secrets mounts | root-namespace token |
| 2 | `discovered_terraform/terraform/namespaces/` | tenant namespaces under `admin` | token with rights on `admin` |
| 3 | `discovered_terraform/terraform/seed/` | tenant mounts, policies, roles, identity, via provider aliases | token with rights on each tenant |

Each layer is independent state. Apply order is `admin`, then `namespaces`, then `seed`. Every Vault object has one owning file and one `import {}` block. Every file starts with a header naming its capability. The folders `auth-mounts/`, `policies/`, `secrets-engines/` and `teams/` hold reports: coverage lists, the policy correlation matrix and the team-to-access matrix.

## 6. Validate (harness)

```bash
export VAULT_TOKEN=root     # harness only
make static-gate            # validate, fmt -check, tflint per layer (CAC1)
make zero-diff              # scratch-state import, plan exits 0 per layer (CAC2)
make verify                 # audit log read-only, no secret in the output (CAC3, CAC4)
```

Or run all of it, twice over, with the harness checks around it:

```bash
make codify-test            # about 90 seconds; stages and per-CAC verdicts, exit 0 only if all pass
```

Reports go to `discovered_terraform/validation/`. Re-running them rewrites the timestamps in the committed reports, so review `git diff` before you commit.

To see a zero-diff plan yourself, in the layer directory:

```bash
cd discovered_terraform/terraform/seed
terraform init -backend=false -input=false
TF_VAR_vault_address=$VAULT_ADDR TF_VAR_vault_token=$VAULT_TOKEN terraform plan -input=false
# Plan: 18 to import, 0 to add, 0 to change, 0 to destroy.
```

`0 to add, 0 to change, 0 to destroy` means the HCL describes the cluster exactly. The `admin` layer also needs `TF_VAR_exporter_agent_approle_name`. It is the alias name, which is sensitive: `vault read -field=role_id auth/approle/role/exporter/role-id`.

## 7. Apply the imports to a real cluster

1. Copy the layer directories to your own repository. Configure a remote backend with encrypted state; the generated `versions.tf` sets none.
2. Replace nothing by hand in generated `.tf` files. Re-run the generators instead, so the output stays reproducible.
3. Supply credentials as sensitive variables or `VAULT_TOKEN`, never in the files. Use a token that can read the objects being imported. A plan made only of `import` blocks reads Vault and does not change it.
4. Run `terraform plan` in `admin/`, then `namespaces/`, then `seed/`. Require no `add`, `change` or `destroy`. Investigate any difference before you apply; do not "fix" it with a config edit you cannot explain.
5. Run `terraform apply`. With a plan of only imports, this writes the imports into state and does not change Vault.

Harness values (`root`, `127.0.0.1`) never belong in a real cluster's configuration.

## 8. Items not managed by Terraform

Each run states what it did not codify.

| Item | Where it is reported | Why |
|---|---|---|
| Seal type, licence, replication mode | `terraform/admin/root_config_README.md` | set in server config or by operator workflow; licence text is never recorded |
| Auth methods other than AppRole, and engines other than KV v2 | `auth-mounts/coverage.md`, `secrets-engines/coverage.md` | mount only; review by hand |
| Enterprise policies (EGP, RGP) | `policies/coverage.md` | covered when present |
| `vault_generic_endpoint` resources | the README of the owning layer | the provider cannot import them; they are adopted by apply |
| Dangling policy references | `policies/correlation.md` | the role names a policy that does not exist |
| Machine identities and human auth | `admin_config_README.md` | human auth in `admin` is owned by admin-config |

## 9. Secrets

- Sensitive provider arguments become `variable` blocks with `sensitive = true` and no default (for example `oidc_client_secret`). Supply them at plan time.
- When Vault does not return a value, the generator adds `lifecycle { ignore_changes = [...] }` with a comment. `make zero-diff` lists each one in its report.
- Harness secret values read `SYNTHETIC-*-REPLACE-IN-PRODUCTION`. They must not appear in any output; `make verify` checks this.
- `discovered_terraform/raw/` and any `terraform.tfstate` stay out of version control.

## 10. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `STOP: exporter token invalid or expired (HTTP 403)` | The token lasts one hour. Repeat section 3. |
| `STOP: token carries the root policy` | Discovery refuses a root token. Use the exporter. |
| `STOP: no audit device enabled` | Enable a file or syslog audit device first. The audit trail is what proves read-only. |
| `non_200_responses` lists a path with 403 | The exporter policy lacks that path (for `sys/audit`, `sys/config/ui/headers` and `sys/auth/+/tune` it needs `sudo`). Optional payloads are skipped; a failed `sys/audit` read stops root-config. |
| A namespace returns 403 or 404 when listing children | It is a leaf or a permission boundary. It is logged and the walk continues. |
| `make zero-diff` refuses to run | It only runs against `127.0.0.1` or `localhost`. |
| `make verify` reports no exporter requests | The audit window is empty. Run discovery first, then verify. |
| `admin` plan asks for `exporter_agent_approle_name` | See section 6. |
| No `admin` namespace | Admin-config is skipped with a note; nothing else changes. |
| Plan wants to replace a namespace or policy | A Vault-side rename is destructive. Do not apply; compare the label with the discovered name. |

Background and further pitfalls: [`tmp/brownfield-discovery-guide.md`](../tmp/brownfield-discovery-guide.md) section 6. The required token policy is in section 1.2 of that guide.

## 11. Edge cases

`make variants` runs the cases the base harness lacks on throwaway containers (ports 18200 and 18201): an OIDC mount in `admin`, userpass, PKI and database mounts, a depth-3 namespace, duplicate policy names, a dangling policy, a restricted 403 token and an empty cluster. The real harness is not touched.
