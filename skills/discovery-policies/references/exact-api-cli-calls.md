## 5. Exact API & CLI Calls

### List Policies at Root
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/policies/acl" | jq -S .data.keys
```

### Read Policy at Root (e.g., `operator`)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/policies/acl/operator" | jq -S .data
```

### List Policies in Namespace (e.g., `admin`)
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/policies/acl" | jq -S .data.keys
```

### Read Policy in Namespace (e.g., `platform-sre-read` in `admin/platform`)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/sys/policies/acl/platform-sre-read" | jq -S .data
```

### List Sentinel EGP/RGP Policies
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/policies/egp" | jq -S .

curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/policies/rgp" | jq -S .
```

### Read One Sentinel Policy (read only)
```bash
curl -s -S --header "X-Vault-Token: ${EXPORTER_TOKEN}" --header "X-Vault-Namespace: admin/platform" \
  "${VAULT_ADDR}/v1/sys/policies/egp/synthetic-egp-platform-advisory" | jq -S .data
```
The exporter policy needs `read` on `sys/policies/egp/*` and `sys/policies/rgp/*`.
