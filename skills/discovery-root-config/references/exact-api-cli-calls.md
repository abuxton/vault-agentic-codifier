## 5. Exact API & CLI Calls

### 1. Audit Devices
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/audit" | jq -S 'del(.request_id, .lease_id, .renewable, .lease_duration)' \
  > discovered_terraform/raw/root/audit.json
```

### 2. Quotas
```bash
# List rate limit quotas
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/quotas/rate-limit" | jq -S .data \
  > discovered_terraform/raw/root/quotas_rate_limit_list.json

# Read specific rate limit quota (e.g., global-rate-limit)
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/quotas/rate-limit/global-rate-limit" | jq -S .data \
  > discovered_terraform/raw/root/quota_rate_limit_global.json

# Read quota config
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/quotas/config" | jq -S .data \
  > discovered_terraform/raw/root/quotas_config.json
```

### 3. Seal & Health Status
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/seal-status" | jq -S . \
  > discovered_terraform/raw/root/seal_status.json

curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/health" | jq -S . \
  > discovered_terraform/raw/root/health.json
```

### 4. License Status (Metadata Only)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/license/status" | jq -S 'del(.request_id, .lease_id, .renewable, .lease_duration)' \
  > discovered_terraform/raw/root/license_status.json
```

### 5. Replication Status
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/replication/status" | jq -S .data \
  > discovered_terraform/raw/root/replication_status.json
```

### 6. UI Headers & Feature Flags
```bash
curl -s -S --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/config/ui/headers" | jq -S .data \
  > discovered_terraform/raw/root/ui_headers.json   # 404 => write {"keys":[]}

curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/internal/ui/feature-flags" | jq -S .data \
  > discovered_terraform/raw/root/ui_feature_flags.json
```
