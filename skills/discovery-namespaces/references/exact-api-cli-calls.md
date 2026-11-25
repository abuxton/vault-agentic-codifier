## 5. Exact API & CLI Calls

### Check Token
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/auth/token/lookup-self" | jq -S .data
```

### List Root Namespaces
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/namespaces" | jq -S .
```

### Read Namespace Details (at Root)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/namespaces/admin" | jq -S .data
```

### List Child Namespaces (under `admin`)
```bash
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/namespaces" | jq -S .
```

### Read Child Namespace Details (e.g., `platform` under `admin`)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  --header "X-Vault-Namespace: admin" \
  "${VAULT_ADDR}/v1/sys/namespaces/platform" | jq -S .data
```

### Reference implementation (validated against the harness)

Runs under macOS `/bin/bash` 3.2: `${h[@]+"${h[@]}"}` is required because an empty array is "unbound" under `set -u`.
Under zsh do not rely on word-splitting of `$keys`; use `while read`.

```bash
set -euo pipefail
walk() {
  local parent="$1" h=()
  [ -n "$parent" ] && h=(--header "X-Vault-Namespace: $parent")
  curl -sS --request LIST --header "X-Vault-Token: ${EXPORTER_TOKEN}" ${h[@]+"${h[@]}"} "${VAULT_ADDR}/v1/sys/namespaces" \
    | jq -r '.data.keys[]?' | LC_ALL=C sort | while read -r k; do
      k=${k%/}
      curl -sS --header "X-Vault-Token: ${EXPORTER_TOKEN}" ${h[@]+"${h[@]}"} "${VAULT_ADDR}/v1/sys/namespaces/$k" \
        | jq -c --arg p "${parent:+$parent/}$k" --arg par "$parent" \
          '.data | {path:$p,parent:$par,id:.id,custom_metadata:(.custom_metadata // null),depth:($p|split("/")|length)}'
      walk "${parent:+$parent/}$k"
    done
}
walk "" | jq -s -S 'sort_by([.depth,.path])' > discovered_terraform/raw/namespaces.json
```
