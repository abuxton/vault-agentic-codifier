## Exact curl commands

```bash
STRIP='del(.request_id,.lease_id,.renewable,.lease_duration)'

# Namespace metadata: NO X-Vault-Namespace header
curl -sS -o /tmp/ns_admin.raw -w '%{http_code}' \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/namespaces/admin"
jq -S "$STRIP" /tmp/ns_admin.raw > /tmp/ns_admin.json

# Auth mount list inside admin
curl -sS -o /tmp/auth.raw -w '%{http_code}' \
  -H "X-Vault-Token: ${VAULT_TOKEN}" -H "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/auth"
jq -S "$STRIP" /tmp/auth.raw > /tmp/auth.json

# Human mount config (example: an OIDC mount at oidc/), then redact
curl -sS -o /tmp/oidc_cfg.raw -w '%{http_code}' \
  -H "X-Vault-Token: ${VAULT_TOKEN}" -H "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/auth/oidc/config"
jq -S "$STRIP | (.data | select(.) | .. | objects) |= with_entries(
  if (.key|test(\"client_secret|bindpass\")) then .value=\"REDACTED\" else . end)" \
  /tmp/oidc_cfg.raw > /tmp/oidc_cfg.json
```

---
