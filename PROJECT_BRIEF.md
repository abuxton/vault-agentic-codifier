# Project Brief: terraform-vault-vault-codifier

## 1. Overview

`terraform-vault-vault-codifier` is an agentic, spec-driven workflow that surveys a **live, running HashiCorp Vault Enterprise cluster** and turns what it finds into **Terraform HCL** using the `hashicorp/vault` provider. It walks the namespace tree, reads mounts, policies, identities and system settings through read-only Vault API calls, writes research notes that explain what exists and why, and then generates Terraform code (with `import {}` blocks) that adopts the existing configuration under version control. The goal is a reviewed Terraform baseline for which `terraform plan` shows **no changes** against the live cluster, aligned with HashiCorp Validated Design (HVD) practice.

## 2. Problem

Most Vault Enterprise clusters existed before anyone wrote Terraform for them. They were configured by hand, by scripts, or by several teams over several years. That leaves:

- **No auditable source of truth.** Nobody can say what the cluster should look like, so drift is invisible.
- **Hidden structure.** Namespaces, auth mounts, policies and identity groups reference each other, but the relationships exist only in people's heads.
- **Risky manual migration.** Hand-writing HCL for dozens of namespaces is slow, error-prone, and easy to get subtly wrong (wrong import ID, missed attribute, leaked secret).
- **No HVD baseline.** Without a codified view, it is hard to check against least privilege, namespace isolation and identity-centric access.

No automated tool today surveys a live Vault cluster, reasons about its organisational hierarchy, and emits idiomatic Terraform. This project fills that gap, and it does so **read-only**: it never writes to the cluster being surveyed.

## 3. Capabilities

Seven capabilities, specified in [`specs.md`](openspec/changes/vault-brownfield-research/specs.md):

- **CAP-001 `root-config`** — Root-namespace configuration: audit devices, rate-limit quotas, system tuning, and a documented "not managed by Terraform" table for seal, licence and replication state.
- **CAP-002 `admin-config`** — The admin/org namespace: composition of the admin layer, operator policies, and the top-level human OIDC/LDAP auth method when one exists.
- **CAP-003 `auth-mounts`** — Every auth method mount in every namespace (`vault_auth_backend`) plus method-specific roles and config, such as AppRole roles.
- **CAP-004 `secrets-engines`** — Every secrets engine mount (`vault_mount`) and engine configuration (KV v2, PKI, database, cloud, Transit). Secret data is never read or emitted.
- **CAP-005 `namespaces`** — The full namespace hierarchy as `vault_namespace` resources, with parent–child references and custom metadata. This is the namespace source of truth for the other capabilities.
- **CAP-006 `policies`** — All ACL policies in every namespace, stored faithfully as `.hcl` files, with a matrix correlating each policy to the auth roles, groups and entities that use it.
- **CAP-007 `teams`** — Organisational units mapped to Vault identity groups, entities and aliases, with a team-to-access matrix.

Specs run in dependency order: `namespaces` → `root-config` → `policies` → `auth-mounts` → `secrets-engines` → `teams` → `admin-config`.

## 4. Architecture

### Four-phase pipeline

A set of role-specific sub-agents moves the cluster state through four sequential phases ([`design.md`](openspec/changes/vault-brownfield-research/design.md)):

1. **Discovery** — The Vault Expert recursively walks namespaces via the REST API (`X-Vault-Namespace`) and stores raw JSON payloads.
2. **Research** — The Architect and Technical Writer correlate the payloads and write the research artifacts in `tmp/`.
3. **Codification** — The Architect generates Terraform HCL from those artifacts.
4. **Validation** — The SRE runs `terraform fmt`, `validate` and `plan` against the test harness. Any drift sends the work back to discovery.

### Three-layer Terraform structure

Generated code is split by lifecycle and blast radius, mirroring `test/terraform/`:

| Layer | Directory | Scope | Authenticates as |
|---|---|---|---|
| 1 | `admin/` | Root namespace: audit device, quotas, the `admin` namespace, bootstrap AppRole | Root-namespace token |
| 2 | `namespaces/` | Org layer: tenant namespaces, admin policies, identity groups and entities | Provisioner AppRole in `admin` |
| 3 | `seed/` | Tenant layer: KV v2 mounts, tenant policies, AppRoles | Per-tenant AppRoles via provider aliases |

Each Vault resource type has exactly one owning capability, so the generated output contains no duplicate resources.

## 5. Quick Start

The harness in [`test/`](test/) runs Vault Enterprise 2.2.2+ent in dev-ha mode at `http://127.0.0.1:8200` and seeds it with synthetic brownfield data. It is also the oracle for the acceptance criteria in `specs.md`.

**Prerequisites** (full list in [`test/PREREQUISITES.md`](test/PREREQUISITES.md)):

- Docker ≥ 25 with Compose ≥ 2.24
- Terraform ≥ 1.9
- Vault CLI ≥ 1.17
- `jq` and `make`
- A valid Vault Enterprise licence at `/tmp/vault.hclic` (never commit it)

**Run:**

```bash
cd test
make all          # start Vault, initialise, unseal, seed synthetic data
make smoke-test   # verify Vault is up and all namespaces and secrets are accessible
source .vault-env # load VAULT_ADDR and VAULT_TOKEN into your shell
```

Other useful targets: `make help`, `make fmt`, `make validate`, `make reset` (teardown and fresh start) and `make clean` (destroy seed data and the container).

## 6. Research Artifacts

Research output lives in [`tmp/`](tmp/):

| File | Covers |
|---|---|
| [`tmp/domain-model.md`](tmp/domain-model.md) | Core Vault entities, relationships (ER diagram), namespace hierarchy, Vault ↔ Terraform glossary, HVD layering, and modelling rules for the codifier |
| [`tmp/terraform-resource-map.md`](tmp/terraform-resource-map.md) | Master mapping from Vault objects to `hashicorp/vault` resources, read-side data sources, the harness inventory, and provider-behaviour notes |
| [`tmp/brownfield-discovery-guide.md`](tmp/brownfield-discovery-guide.md) | Discovery prerequisites and a read-only token policy, discovery order, per-capability commands, what to capture versus skip, namespace traversal, pitfalls, import strategy, and a validation checklist |
| [`tmp/hvd-alignment-matrix.md`](tmp/hvd-alignment-matrix.md) | How the harness aligns with HVD principles, gap analysis, and a summary scorecard |

## 7. OpenSpec Pipeline

Change: [`openspec/changes/vault-brownfield-research/`](openspec/changes/vault-brownfield-research/)

| Artifact | Status | Purpose |
|---|---|---|
| [`proposal.md`](openspec/changes/vault-brownfield-research/proposal.md) | ✅ Done | Why, what changes, capabilities, impact |
| [`specs.md`](openspec/changes/vault-brownfield-research/specs.md) | ✅ Done | Seven capability specs with measurable acceptance criteria |
| [`design.md`](openspec/changes/vault-brownfield-research/design.md) | ✅ Done | Pipeline, discovery protocol, resource mapping, state layering, ADRs |
| [`tasks.md`](openspec/changes/vault-brownfield-research/tasks.md) | ✅ Done | 30 implementation tasks in five phases: Foundation, Discovery Engine, Codification Engine, Validation & Testing, Documentation & Handoff |

Implementation is in progress; see [`HANDOFF.md`](HANDOFF.md) and [`STATUS_REPORT.md`](STATUS_REPORT.md) for the current state.

## 8. Roles

| Role | Responsibility | Main deliverables |
|---|---|---|
| **Vault Expert** | Interrogates Vault endpoints, walks the namespace tree, extracts raw payloads | Raw API payloads, API-to-CLI mappings |
| **Solution Architect** | Defines code hierarchy, maps Vault concepts to Terraform resources, plans state boundaries | `terraform-resource-map.md`, `admin/` / `namespaces/` / `seed/` structure |
| **SRE** | Runs the harness, linting, validate and plan, verifies zero drift | Plan logs, lint reports, zero-drift checklist |
| **Technical Writer** | Documents findings, maps structure to owners, checks HVD alignment | `domain-model.md`, `brownfield-discovery-guide.md`, `hvd-alignment-matrix.md` |

## 9. Key Constraints

- **Vault Enterprise licence required.** The harness will not start without one. Place it at `/tmp/vault.hclic` (outside the repo). It must never be committed; `test/.gitignore` excludes `*.hclic`.
- **Provider and tool versions.** `hashicorp/vault` provider `>= 4.x` (pinned `~> 4`, harness lock files at `4.8.0`), Terraform `>= 1.9`, Vault CLI `>= 1.17`, Vault Enterprise 2.2.2+ent.
- **Read-only against Vault.** The codifier issues only `GET` and `LIST` requests. No spec may cause a write to the surveyed cluster.
- **No secrets in output.** Generated files never contain tokens, AppRole `secret_id` values, KV data, or other sensitive values; sensitive arguments become variables with no default.
- **Provider tool paths.** Namespaced resources are emitted either with an aliased provider (`provider = vault.<alias>`) or the resource-level `namespace` argument, chosen once per run. Namespace paths are always full paths from root (for example `admin/platform`).
- **Synthetic data convention.** All harness secret values are marked `SYNTHETIC-*-REPLACE-IN-PRODUCTION`. They are safe to commit and never real credentials.
- **Documentation source.** Vault documentation is cited as repository-relative paths in `git@github.com:hashicorp/web-unified-docs.git`, never as local paths.
- **Harness only.** TLS is disabled and the root token is `root` in the test harness; this is for local development only.

## 10. Contributing

- **[`AGENTS.md`](AGENTS.md)** — contributor and agent guidelines: constraints, commands, ownership and where things are.
- **Test harness** — use [`test/`](test/) (`make all`, `make smoke-test`, `make validate`) to verify any change; see [`test/PREREQUISITES.md`](test/PREREQUISITES.md).
- **Documentation source** — Vault docs and validated designs come from `git@github.com:hashicorp/web-unified-docs.git` (for example `content/validated-designs/docs/docs/vault/administration-guide/authentication-for-people.mdx` and the `content/vault/` tree).
- **Work tracking** — pick a task from [`tasks.md`](openspec/changes/vault-brownfield-research/tasks.md); acceptance criteria come from [`specs.md`](openspec/changes/vault-brownfield-research/specs.md).
