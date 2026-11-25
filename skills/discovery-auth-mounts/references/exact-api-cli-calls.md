## 5. Exact API & CLI Calls

> **Validated notes (harness, Vault 2.2.2+ent).**
> - `GET sys/auth/<path>` and `GET sys/auth/<path>/tune` require **`sudo`**
>   ([API docs](https://developer.hashicorp.com/vault/api-docs/system/auth)). The exporter policy grants
>   `read`+`sudo` on `sys/auth/+` and `sys/auth/+/tune` at every namespace depth. Without it the tune read is
>   403 in every namespace. The endpoint accepts no writes with that grant.
> - Fetch `sys/auth` once per namespace; do not re-read it per mount.
> - The tune payload keeps `default_lease_ttl`, `max_lease_ttl`, `token_type`, `listing_visibility`,
>   `audit_non_hmac_*_keys`, `passthrough_request_headers`, `allowed_response_headers`. A mount that was never
>   tuned reports the system default (`2764800`), not `0`.
> - Role payload keeps config keys only (`bind_secret_id`, `secret_id_*`, `token_*`). The key names contain
>   `secret_id` but hold no secret values; a credential check must match values, not key names.

### 1. AppRole Discovery (Harness Oracle)
```bash
# List auth mounts in namespace admin/platform
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/sys/auth" | jq -S .data

# Get mount tuning
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/sys/auth/approle/tune" | jq -S .data

# List AppRole roles
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/auth/approle/role" | jq -S .data.keys

# Read AppRole role definition (NEVER query role-id or secret-id)
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/auth/approle/role/platform-ci" | jq -S .data
```

### 2. OIDC / JWT Discovery
```bash
# Read OIDC configuration
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/auth/oidc/config" | jq -S 'del(.client_secret, .oidc_client_secret)'
```

### 3. LDAP Discovery
```bash
# Read LDAP configuration
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/auth/ldap/config" | jq -S 'del(.bindpass)'
```
