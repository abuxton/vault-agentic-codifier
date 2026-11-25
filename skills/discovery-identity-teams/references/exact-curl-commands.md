## Exact curl commands

```bash
NS="admin"
STRIP='del(.request_id,.lease_id,.renewable,.lease_duration)'

vreq() {  # usage: vreq <GET|LIST> <namespace> <path> <outfile>; echoes HTTP status
  curl -sS -X "$1" -o "$4" -w '%{http_code}' \
    -H "X-Vault-Token: ${VAULT_TOKEN}" -H "X-Vault-Namespace: $2" \
    "${VAULT_ADDR}/v1/$3"
}

# Groups
vreq LIST "$NS" identity/group/name /tmp/groups.raw
for g in $(jq -r '.data.keys[]?' /tmp/groups.raw); do
  vreq GET "$NS" "identity/group/name/${g}" "/tmp/group_${g}.raw"
  jq -S "$STRIP" "/tmp/group_${g}.raw" > "/tmp/group_${g}.json"
done

# Entities
vreq LIST "$NS" identity/entity/name /tmp/entities.raw
for e in $(jq -r '.data.keys[]?' /tmp/entities.raw); do
  vreq GET "$NS" "identity/entity/name/${e}" "/tmp/entity_${e}.raw"
  jq -S "$STRIP" "/tmp/entity_${e}.raw" > "/tmp/entity_${e}.json"
done
```

Never echo `VAULT_TOKEN`. Names containing spaces or `/` must be URL-encoded (`jq -rn --arg n "$g" '$n|@uri'`).

---
