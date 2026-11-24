# TASK-001: Layout Note — Capability Files to State Layers

**Status**: Complete (resolves TASK-001 all acceptance criteria)  
**Date**: 2026-11-24  
**Author**: TASK-001 implementation

---

## 1. Implementation Language Decision

| Item | Decision | Rationale |
|---|---|---|
| Language | **Python 3.9+** | Available on the developer machine at `/usr/bin/python3 3.9.6`; stdlib-only (no hvac, no third-party packages); `design.md` §6.2 pseudocode assumes Python |
| Dependency manager | **None — stdlib only** | `urllib.request`, `http.client`, `pathlib`, `json`, `re`, `hashlib`, `subprocess`. No `pip install` required, no `requirements.txt`. |
| Test framework | **`unittest` (stdlib)** | `python3 -m unittest discover` requires no installation |
| Minimum versions | Python ≥ 3.9, Terraform ≥ 1.9, Vault CLI ≥ 1.17, `hashicorp/vault` provider `~>4` (harness: 4.8.0), `jq` any recent | From harness `Makefile` and `specs.md` baseline |

---

## 2. `vault_kv_secret_v2` Conflict Resolution

`design.md` §5 (Terraform Resource Mapping) includes a row for `vault_kv_secret_v2`
(KV v2 secret data). **This row is superseded.**

**Decision**: `vault_kv_secret_v2` is **forbidden** in all generator output.  
**Authority**: `specs.md` CAP-004 AC3 — "The output contains zero `vault_kv_secret_v2`, `vault_kv_secret` or `vault_generic_secret` resources and no file contains the strings `SYNTHETIC-`."  
**Rationale**: CAC3 (no secrets) and ADR-003 (synthetic data convention) reinforce this. Emitting real secret data to HCL/state files violates basic security hygiene.  
**What the generator does instead**: It captures the KV mount structure and configuration (`vault_mount`, `vault_kv_secret_backend_v2`) but never reads or emits `data/` or `metadata/` paths.

Recorded in `codifier/shared/constants.py` as `FORBIDDEN_RESOURCES["vault_kv_secret_v2"]`.

---

## 3. Capability → State-Layer Mapping

The key reconciliation: `specs.md` names per-capability output directories;
`design.md` §7 names three Terraform state layers. This table is the bridge.
**The 3-layer structure is the Terraform state boundary** (each layer has its
own `terraform.tfstate`). Capability files are subdirectories or files _inside_
the appropriate layer.

### 3.1 State layer overview

| State layer | Directory | Terraform provider context | Lifecycle |
|---|---|---|---|
| **Layer 1** | `discovered_terraform/terraform/admin/` | Root namespace (token from env) | Cluster-wide resources; apply first |
| **Layer 2** | `discovered_terraform/terraform/namespaces/` | `admin` namespace (via alias or `namespace` arg) | Org-level structure; apply second |
| **Layer 3** | `discovered_terraform/terraform/seed/` | Per-tenant namespace (one alias per tenant) | Tenant workloads; apply third |

### 3.2 Per-capability file locations

| Capability | Spec files (from `specs.md`) | State layer | Generated path |
|---|---|---|---|
| **CAP-001 `root-config`** | `root/audit.tf` | **admin** | `admin/audit.tf` |
| | `root/quotas.tf` | **admin** | `admin/quotas.tf` |
| | `root/sys_config.tf` | **admin** | `admin/sys_config.tf` |
| | `root/replication.tf` | **admin** | `admin/replication.tf` _(only when replication enabled)_ |
| | `root/README.md` | **admin** | `admin/README.md` |
| | `root/imports.tf` | **admin** | `admin/imports.tf` _(merged into layer imports)_ |
| **CAP-002 `admin-config`** | `admin/main.tf` | **admin** | `admin/main.tf` |
| | `admin/human_auth.tf` | **admin** | `admin/human_auth.tf` _(only when OIDC/LDAP detected)_ |
| | `admin/variables.tf`, `outputs.tf` | **admin** | `admin/variables.tf`, `admin/outputs.tf` |
| | `admin/README.md` | **admin** | `admin/README.md` _(merged with root-config README)_ |
| | `admin/imports.tf` | **admin** | `admin/imports.tf` |
| **CAP-003 `auth-mounts`** | One file per namespace+mount | **admin** (root + admin mounts) | `admin/auth_<type>_<ns>.tf` |
| | | **seed** (tenant mounts) | `seed/<ns_label>/auth_<type>.tf` |
| | `auth-mounts/coverage.md` | _(shared)_ | `terraform/auth-mounts/coverage.md` |
| **CAP-004 `secrets-engines`** | `vault_mount` per mount | **seed** | `seed/<ns_label>/mounts.tf` |
| | Engine config resources | **seed** | `seed/<ns_label>/engine_<type>.tf` |
| | `secrets-engines/coverage.md` | _(shared)_ | `terraform/secrets-engines/coverage.md` |
| **CAP-005 `namespaces`** | `vault_namespace "admin"` | **admin** | `admin/namespace_admin.tf` |
| | tenant `vault_namespace` resources | **namespaces** | `namespaces/namespaces.tf` |
| | `namespaces/hierarchy.md` | _(shared)_ | `terraform/namespaces/hierarchy.md` |
| | `namespaces/namespaces.auto.tfvars.json` | **namespaces** | `namespaces/namespaces.auto.tfvars.json` |
| **CAP-006 `policies`** | root + admin `vault_policy` | **admin** | `admin/policies.tf` + `admin/policies/<name>.hcl` |
| | tenant `vault_policy` | **seed** | `seed/<ns_label>/policies.tf` + `seed/<ns_label>/policies/<name>.hcl` |
| | `policies/correlation.md`, `correlation.json` | _(shared)_ | `terraform/policies/correlation.md`, `correlation.json` |
| | `policies/coverage.md` | _(shared)_ | `terraform/policies/coverage.md` |
| **CAP-007 `teams`** | `vault_identity_group`, `vault_identity_entity` | **namespaces** | `namespaces/identity.tf` |
| | `vault_identity_*_alias` | **namespaces** | `namespaces/identity_aliases.tf` _(only when aliases exist)_ |
| | `teams/teams.md`, `teams.json` | _(shared)_ | `terraform/teams/teams.md`, `teams.json` |

> **`<ns_label>`**: the Terraform label derived from the namespace path by the naming library (TASK-003). E.g. `admin/platform` → `admin_platform`.

### 3.3 Directory structure

Coverage reports and documentation live alongside the Terraform layers under
`discovered_terraform/terraform/` using the per-capability path names from
`specs.md` (e.g. `auth-mounts/coverage.md`, `policies/correlation.md`).
They use **no** `docs/` prefix — `terraform init` ignores non-`.tf` files,
and the skill path references in TASK-007 through TASK-021 remain valid as-is.

The table in §3.2 uses `docs/` paths in the "Generated path" column; those
are **superseded** by this section. All skills and the `constants.py` layout
use the paths below.

```
discovered_terraform/
├── raw/                        # Discovery phase: raw JSON payloads (gitignored)
└── terraform/                  # Codification phase: generated HCL + documentation
    ├── admin/                  # Layer 1: root + admin namespace resources
    │   ├── providers.tf
    │   ├── versions.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── audit.tf
    │   ├── quotas.tf
    │   ├── sys_config.tf
    │   ├── namespace_admin.tf
    │   ├── policies.tf
    │   ├── policies/
    │   │   └── <name>.hcl
    │   ├── auth_approle_root.tf
    │   ├── auth_approle_admin.tf
    │   ├── main.tf             # admin-config composition
    │   ├── human_auth.tf       # only when OIDC/LDAP in admin
    │   ├── README.md
    │   └── imports.tf
    ├── namespaces/             # Layer 2: org-level structure
    │   ├── providers.tf
    │   ├── versions.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── namespaces.tf       # tenant vault_namespace resources
    │   ├── namespaces.auto.tfvars.json
    │   ├── identity.tf         # groups + entities
    │   ├── identity_aliases.tf # only when aliases exist
    │   └── imports.tf
    └── seed/                   # Layer 3: tenant workloads
        ├── providers.tf
        ├── versions.tf
        ├── variables.tf
        ├── outputs.tf
        ├── <ns_label>/
        │   ├── mounts.tf
        │   ├── engine_kv.tf    # vault_kv_secret_backend_v2
        │   ├── auth_approle.tf
        │   ├── policies.tf
        │   └── policies/
        │       └── <name>.hcl
        └── imports.tf

    # Shared documentation — alongside the layers, not in a separate docs/ dir
    # (paths match specs.md references; not .tf files so terraform init ignores them)
    ├── namespaces/hierarchy.md
    ├── policies/correlation.md
    ├── policies/correlation.json
    ├── policies/coverage.md
    ├── auth-mounts/coverage.md
    ├── secrets-engines/coverage.md
    └── teams/
        ├── teams.md
        └── teams.json
```

---

## 4. Source-code layout

```
codifier/                        # Python package root
├── __init__.py
├── shared/
│   ├── __init__.py
│   ├── constants.py             # all slugs, layer map, ownership, sensitive fields
│   ├── naming.py                # TASK-003: label derivation and reference helper
│   ├── headers.py               # TASK-004a: provenance header writer
│   └── guard.py                 # TASK-004b: secret-scrubbing guard
├── discovery/
│   ├── __init__.py
│   ├── client.py                # TASK-005: read-only Vault HTTP client + run report
│   ├── namespaces.py            # TASK-007: recursive namespace walk
│   ├── root_config.py           # TASK-008
│   ├── policies.py              # TASK-009
│   ├── auth_mounts.py           # TASK-010
│   ├── secrets_engines.py       # TASK-011
│   ├── identity_teams.py        # TASK-012
│   ├── admin_config.py          # TASK-013
│   └── orchestrator.py          # TASK-014
├── codification/
│   ├── __init__.py
│   ├── namespaces.py            # TASK-015
│   ├── root_config.py           # TASK-016
│   ├── policies.py              # TASK-017
│   ├── auth_mounts.py           # TASK-018
│   ├── secrets_engines.py       # TASK-019
│   ├── teams.py                 # TASK-020
│   ├── admin_config.py          # TASK-021
│   └── assembler.py             # TASK-022: layer assembly + ownership check
└── validation/
    ├── __init__.py
    ├── static_gate.py           # TASK-023: fmt + validate + tflint
    ├── import_plan.py           # TASK-024: zero-diff import and plan
    ├── readonly_check.py        # TASK-025: audit log verification
    └── idempotence.py           # TASK-027
```

---

## 5. Namespace targeting style

Both styles permitted by `specs.md` ("Namespace targeting in generated HCL") are supported.
One style is chosen per run via a `--namespace-style` flag on the CLI entry point:

| Flag value | Mechanism | When to use |
|---|---|---|
| `aliased` (default) | `provider = vault.<alias>` on each resource | Matches the test harness pattern; cleaner plan output |
| `namespace` | Resource-level `namespace = "<path>"` argument | Useful when provider aliases become unwieldy (many namespaces) |

Default is `aliased` — matches the test harness in `test/terraform/`.
This decision feeds TASK-002's run option default.

---

## 6. Acceptance criteria checklist

- [x] Layout document lists all 7 capabilities with generated files and state layer (§3.2 above)
- [x] Implementation language and dependency manager recorded with tool versions (§1 above)
- [x] `vault_kv_secret_v2` conflict documented and resolved in favour of CAP-004 AC3 (§2 above)
- [x] `discovered_terraform/` directory created; `.gitignore` excludes raw payloads, run reports, state files, `*.hclic`
- [x] Source layout defined in `codifier/` package (§4 above)
