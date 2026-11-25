## Exact curl commands (KV v2, the harness type)

```bash
export VAULT_CONFIG_PATH=/dev/null
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN="${EXPORTER_TOKEN}"
NS="admin/app-billing"; M="secret"
STRIP='del(.request_id,.lease_id,.renewable,.lease_duration)'

vget() {  # usage: vget <namespace> <path> <outfile>; echoes HTTP status
  curl -sS -o "$3.raw" -w '%{http_code}' \
    -H "X-Vault-Token: ${VAULT_TOKEN}" -H "X-Vault-Namespace: $1" \
    "${VAULT_ADDR}/v1/$2"
}

# 1. List mounts
vget "$NS" "sys/mounts" /tmp/mounts
jq -S "$STRIP" /tmp/mounts.raw > /tmp/mounts.json

# 2. Per-mount tune
vget "$NS" "sys/mounts/${M}/tune" /tmp/tune
jq -S "$STRIP" /tmp/tune.raw > /tmp/tune.json

# 3. KV v2 engine config (ONLY config; never data/ or metadata/)
vget "$NS" "${M}/config" /tmp/kvconfig
jq -S "$STRIP" /tmp/kvconfig.raw > /tmp/kvconfig.json
```

Never place the token in a URL or in a logged command line; the header is read from the environment.

---
