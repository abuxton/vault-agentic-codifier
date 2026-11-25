---
name: vault-exporter-setup
description: >
  Provision the vault-brownfield-codifier exporter identity in a target Vault Enterprise cluster and authenticate
  as the exporter before any discovery run. Use this skill as the mandatory first step before any task that reads
  live Vault state ( The exporter identity is a purpose-built, least-privilege, audit-traced identity — never use
  a root token or an operator token for discovery. USE FOR: set up exporter; provision exporter identity. DO NOT
  USE FOR: a production cluster without review, or anything but creating the read-only exporter.
metadata:
  version: "1.0"
---

# Vault Exporter Setup Skill

## Purpose

Every discovery run against a live Vault cluster **must** authenticate as the
`exporter` identity, not as a root token or an operator.  This skill:

1. Provisions the required Terraform resources in the target cluster.
2. Issues a short-lived AppRole token scoped to the `exporter` identity.
3. Exports `VAULT_TOKEN` for the duration of the discovery run.
4. Rotates the secret-id after the run completes.

This satisfies three requirements:

- **Least privilege** — the exporter can list all structural objects and read
  health/config endpoints, but is explicitly denied access to any secret value.
- **Auditability** — every API call is logged under the `exporter-agent` entity
  alias, giving a complete, immutable record of what the codifier read.
- **Separation of concerns** — the exporter identity is managed by Terraform
  and is distinct from human operator identities.

HVD reference:  
`https://developer.hashicorp.com/validated-designs/vault/administration-guide/authentication-for-people`

---

## Prerequisites

| Requirement | Check |
|---|---|
| Vault Enterprise ≥ 1.17 | `vault version` |
| Vault CLI at `vault` | `ls vault` |
| Terraform ≥ 1.9 at `terraform` | `terraform version` |
| `VAULT_ADDR` set to target cluster | `echo $VAULT_ADDR` |
| Initial `VAULT_TOKEN` with admin rights (bootstrap only) | `vault token lookup` |
| `test/terraform/admin/` Terraform layer already initialised | `ls test/terraform/admin/.terraform` |
| Vault audit logging enabled (file or syslog device) | `vault audit list` |

---

## Security Notes

| Concern | Mitigation |
|---|---|
| Root token exposure | Never set `VAULT_TOKEN=root` for discovery; use exporter AppRole token only |
| Secret-id leakage | `secret_id_num_uses = 1`; rotate or destroy after each login |
| Token scope creep | `exporter` policy explicit denies override any broader policy in the group |
| Long-lived tokens | `token_max_ttl = 14400`; tokens cannot be renewed past 4 hours |
| Audit bypass | File audit device at `/vault/logs/audit.log` is mandatory in the harness; discovery will not start without it |
| Secret values in payloads | TASK-025 `grep -r SYNTHETIC` check and CAC3 (no-write) are verified in CI |

---

## Related Tasks

- **TASK-031** — provisions this identity; this skill IS the documentation for TASK-031.
- **TASK-005** — superseded. Discovery runs with the `vault` CLI, `curl` and `jq`, so read-only is enforced here by the exporter policy, not by client code.
- **TASK-007 through TASK-013** — all depend on TASK-031 being complete before they run against a live cluster.
- **TASK-025** — read-only and no-secrets verification; uses the exporter token to confirm zero writes and zero secret-data reads.
- **TASK-028** (`AGENTS.md`) — will reference this skill as the standard authentication bootstrap for any agent that connects to Vault.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Terraform Resources](references/terraform-resources.md)
- [Per-Run Workflow](references/per-run-workflow.md)
- [Acceptance Criteria Checklist](references/acceptance-criteria-checklist.md)
