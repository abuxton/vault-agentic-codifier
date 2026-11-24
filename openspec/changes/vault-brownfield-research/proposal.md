## Why

Organizations running HashiCorp Vault Enterprise in brownfield deployments (Vault already running, not greenfield) need a way to capture their existing cluster configuration as Terraform code — producing an auditable, version-controlled IaC baseline that follows HashiCorp Validated Design (HVD) best practices. No automated, spec-driven tool exists today that can survey a live Vault cluster, reason about its organisational hierarchy (namespaces, auth mounts, secrets engines, policies, teams), and emit idiomatic Terraform HCL.

## What Changes

- Introduce an agentic, spec-driven workflow that interrogates a live Vault cluster and produces structured research artifacts describing current state.
- Implement a Terraform codification pipeline that translates those research artifacts into best-practice Terraform HCL using the `hashicorp/vault` provider.
- Produce a brownfield discovery guide covering what to capture, how to reason about namespace hierarchies, and how to map Vault primitives to Terraform resources.
- Establish roles: Terraform/Vault expert, Solution Architect, SRE, and Technical Writer — each contributing specialised artifacts via orchestrated sub-agents.

## Capabilities

### New Capabilities

- `root-config`: Capture and codify root-namespace configuration: audit devices, system backend tuning, cluster seals, license, replication configuration, and UI settings.
- `admin-config`: Capture and codify the admin/org-level namespace: initial operator policies, identity store (entities, groups, group-aliases), and the top-level OIDC/LDAP auth method for human operators.
- `auth-mounts`: Enumerate all auth method mounts across all namespaces, their paths, types, options, and associated roles/groups; produce `vault_auth_backend` and related Terraform resources.
- `secrets-engines`: Enumerate all secrets engine mounts (KV v1/v2, PKI, database, AWS, Azure, Transit, etc.) across all namespaces; capture mount config, tuning, and engine-specific configuration; produce `vault_mount` and engine-specific Terraform resources.
- `namespaces`: Discover the full namespace hierarchy rooted at the admin namespace; map parent–child relationships; produce `vault_namespace` resources.
- `policies`: Enumerate all ACL policies in every namespace; capture policy documents; produce `vault_policy` resources and correlate with auth roles and identity groups.
- `teams`: Map organisational units (teams, application owners, service consumers) to Vault constructs: identity groups, group aliases, and auth roles; produce `vault_identity_group`, `vault_identity_group_alias`, `vault_identity_entity`, and auth-role resources.

### Modified Capabilities

_(None — this is a greenfield project.)_

## Impact

- **New files**: `openspec/specs/<capability>/spec.md` for each capability above; `tmp/` research artifacts (domain model, Terraform resource map, brownfield discovery guide, HVD alignment matrix); `PROJECT_BRIEF.md`.
- **Dependencies**: Vault Enterprise cluster accessible via `VAULT_ADDR` + `VAULT_TOKEN`; `hashicorp/vault` Terraform provider ≥ 4.x; Vault CLI ≥ 1.17; Vault documentation sourced from [`git@github.com:hashicorp/web-unified-docs.git`](git@github.com:hashicorp/web-unified-docs.git).
- **No breaking changes** — purely additive; no existing Vault infrastructure is modified during the research phase.
