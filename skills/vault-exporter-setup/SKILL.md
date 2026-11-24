---
name: vault-exporter-setup
description: >
  Provision the vault-brownfield-codifier exporter identity in a target Vault
  Enterprise cluster and authenticate as the exporter before any discovery run.
  Use this skill as the mandatory first step before any task that reads live
  Vault state (TASK-007 through TASK-014).  The exporter identity is a
  purpose-built, least-privilege, audit-traced identity — never use a root
  token or an operator token for discovery.
triggers:
  - "set up exporter"
  - "provision exporter identity"
  - "authenticate for discovery"
  - "before running discovery"
  - "TASK-031"
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
| Vault CLI at `/opt/homebrew/bin/vault` | `ls /opt/homebrew/bin/vault` |
| Terraform ≥ 1.9 at `/opt/homebrew/bin/terraform` | `/opt/homebrew/bin/terraform version` |
| `VAULT_ADDR` set to target cluster | `echo $VAULT_ADDR` |
| Initial `VAULT_TOKEN` with admin rights (bootstrap only) | `vault token lookup` |
| `test/terraform/admin/` Terraform layer already initialised | `ls test/terraform/admin/.terraform` |
| Vault audit logging enabled (file or syslog device) | `vault audit list` |

---

## Terraform Resources

All resources live in `test/terraform/admin/` alongside the existing admin-layer
configuration.  Add the following blocks to `test/terraform/admin/main.tf` (or a
dedicated `exporter.tf` within that module):

### 1. Policy — `exporter`

```hcl
resource "vault_policy" "exporter" {
  name   = "exporter"
  policy = file("${path.module}/policies/exporter.hcl")
}
```

The policy file is at `test/terraform/admin/policies/exporter.hcl`.  
Key design points:
- `list` on all structural paths (namespaces, auth, mounts, policies, identity, quotas).
- `read` on health/config paths that carry no secret values.
- **Explicit `deny`** on `secret/data/*`, `+/secret/data/*`, `+/+/secret/data/*`,
  `+/+/+/secret/data/*` and all `+/.../data/*` wildcard depths — these override
  any `read` capability the `admin` group policy grants.
- No `create`, `update`, `delete`, or `sudo` anywhere.
- AppRole `role-id` and `secret-id` endpoints explicitly denied.

### 2. Identity Entity — `exporter-agent`

```hcl
resource "vault_identity_entity" "exporter_agent" {
  name     = "exporter-agent"
  policies = ["exporter"]

  metadata = {
    role       = "exporter"
    managed_by = "terraform"
  }
}
```

### 3. Identity Group — `exporters`

```hcl
resource "vault_identity_group" "exporters" {
  name     = "exporters"
  type     = "internal"
  policies = ["admin", "exporter"]

  member_entity_ids = [vault_identity_entity.exporter_agent.id]

  metadata = {
    purpose = "vault-brownfield-codifier export operations"
  }
}
```

The group carries both `admin` (for broad list/read access) and `exporter`
(for the explicit secret-data denies on top).  Policy union means both apply;
deny always wins.

### 4. AppRole Role — `exporter`

```hcl
resource "vault_approle_auth_backend_role" "exporter" {
  backend        = vault_auth_backend.approle.path   # existing root AppRole mount
  role_name      = "exporter"
  token_policies = ["admin", "exporter"]

  token_ttl         = 3600   # 1 hour — enough for a full scan run
  token_max_ttl     = 14400  # 4 hours hard cap
  token_num_uses    = 0      # unlimited uses within TTL (scan may make 100s of calls)
  secret_id_num_uses = 1     # one-time secret-id; rotate after each login
  bind_secret_id    = true
}
```

> **Note:** `token_num_uses = 0` means the token is usable for the full TTL.
> This is correct for a scan that makes many sequential API calls.  
> `secret_id_num_uses = 1` means each secret-id can only be used to log in once
> (must rotate before the next run).

### 5. Entity Alias — bind entity to AppRole accessor

```hcl
resource "vault_identity_entity_alias" "exporter_approle" {
  name           = vault_approle_auth_backend_role.exporter.role_name
  mount_accessor = vault_auth_backend.approle.accessor
  canonical_id   = vault_identity_entity.exporter_agent.id
}
```

This alias is what causes audit log entries to show `exporter-agent` as the
display name when the AppRole token is used.

---

## Per-Run Workflow

Run these steps **before** starting any Phase 2 discovery task.

### Step 1 — Apply the Terraform resources (first time, or after changes)

```bash
cd test/terraform/admin
VAULT_ADDR=http://127.0.0.1:8200 \
VAULT_TOKEN=root \
VAULT_CONFIG_PATH=/dev/null \
  /opt/homebrew/bin/terraform apply -auto-approve
```

### Step 2 — Generate a one-time secret-id

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root   # bootstrap token for secret-id generation only

SECRET_ID=$(/opt/homebrew/bin/vault write -field=secret_id \
  auth/approle/role/exporter/secret-id)
```

### Step 3 — Read the role-id

```bash
ROLE_ID=$(/opt/homebrew/bin/vault read -field=role_id \
  auth/approle/role/exporter/role-id)
```

### Step 4 — Log in as the exporter

```bash
EXPORTER_TOKEN=$(/opt/homebrew/bin/vault write -field=token \
  auth/approle/login \
  role_id="${ROLE_ID}" \
  secret_id="${SECRET_ID}")

export VAULT_TOKEN="${EXPORTER_TOKEN}"
unset ROLE_ID SECRET_ID   # do not leave credentials in environment
```

The `root` token is now **out of scope**.  All subsequent discovery calls use
`VAULT_TOKEN` set to the exporter token.

### Step 5 — Run discovery

```bash
# Example: list namespaces with the exporter token
/opt/homebrew/bin/vault namespace list -format=json
```

### Step 6 — Verify audit trail (optional but recommended)

```bash
# Requires docker exec or volume mount access to the audit log
docker exec vault-enterprise \
  sh -c "cat /vault/logs/audit.log | jq -c 'select(.auth.display_name | strings | contains(\"exporter\"))' | tail -20"
```

Each line is one API call.  Confirm the `exporter-agent` alias appears as
`auth.display_name` and that no `secret/data/` paths appear in `request.path`.

### Step 7 — Rotate secret-id after the run

```bash
# Using a fresh admin token (or the exporter token cannot rotate its own secret-id)
VAULT_TOKEN=root \
  /opt/homebrew/bin/vault write -f auth/approle/role/exporter/secret-id-accessor/destroy \
  secret_id_accessor="<accessor from step 2 if stored>"
```

Or simply let the used secret-id expire naturally (it has `num_uses=1`).

---

## Acceptance Criteria Checklist

Before marking TASK-031 complete, verify all of the following against the test
harness (`make -C test up && make -C test seed`):

- [ ] `test/terraform/admin/policies/exporter.hcl` exists and `terraform validate` returns no errors.
- [ ] `terraform apply` in `test/terraform/admin/` succeeds with zero diff on a second run (idempotent).
- [ ] The exporter AppRole token can run `vault auth list` and `vault namespace list` from root (exit 0).
- [ ] The exporter AppRole token receives HTTP 403 on `vault kv get -mount=secret billing-service/checkout -namespace=admin/app-billing`.
- [ ] `vault identity entity list` shows `exporter-agent`.
- [ ] `vault identity group list` shows `exporters`; `vault identity group lookup -format=json` shows `policies: ["admin","exporter"]` and `member_entity_ids` containing the `exporter-agent` ID.
- [ ] After a scan run, the audit log contains entries with `auth.display_name` matching `exporter-agent`.
- [ ] No `secret/data/` path appears in the audit log `request.path` for the exporter token's calls.

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
- **TASK-005** — the read-only Vault API client must accept `VAULT_TOKEN` from the environment and must refuse `POST`/`PUT`/`DELETE`.  It does not manage authentication; this skill does.
- **TASK-007 through TASK-013** — all depend on TASK-031 being complete before they run against a live cluster.
- **TASK-025** — read-only and no-secrets verification; uses the exporter token to confirm zero writes and zero secret-data reads.
- **TASK-028** (`AGENTS.md`) — will reference this skill as the standard authentication bootstrap for any agent that connects to Vault.
