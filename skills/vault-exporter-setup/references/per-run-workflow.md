## Per-Run Workflow

Run these steps **before** starting any Phase 2 discovery task.

### Step 1 — Apply the Terraform resources (first time, or after changes)

```bash
cd test/terraform/admin
VAULT_ADDR=http://127.0.0.1:8200 \
VAULT_TOKEN=root \
VAULT_CONFIG_PATH=/dev/null \
  terraform apply -auto-approve
```

### Step 2 — Generate a one-time secret-id

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root   # bootstrap token for secret-id generation only

SECRET_ID=$(vault write -f -field=secret_id \
  auth/approle/role/exporter/secret-id)
```

### Step 3 — Read the role-id

```bash
ROLE_ID=$(vault read -field=role_id \
  auth/approle/role/exporter/role-id)
```

### Step 4 — Log in as the exporter

```bash
EXPORTER_TOKEN=$(vault write -field=token \
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
vault namespace list -format=json
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
  vault write -f auth/approle/role/exporter/secret-id-accessor/destroy \
  secret_id_accessor="<accessor from step 2 if stored>"
```

Or simply let the used secret-id expire naturally (it has `num_uses=1`).

---
