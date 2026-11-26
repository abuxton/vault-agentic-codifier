## 6. Output Schema

### Per-Namespace `policies.json`
Saved to `discovered_terraform/raw/<namespace>/policies.json` (or `root/policies.json` for root):

```json
[
  {
    "name": "platform-sre-read",
    "namespace": "admin/platform",
    "policy_text": "path \"secret/data/platform/sre/*\" {\n  capabilities = [\"read\", \"list\"]\n}\n",
    "type": "acl"
  },
  {
    "name": "platform-devops-write",
    "namespace": "admin/platform",
    "policy_text": "path \"secret/data/platform/*\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]\n}\n",
    "type": "acl"
  }
]
```

### Per-Namespace `sentinel.json` (CAP-008)
Saved next to `policies.json`. `paths` is `null` for an RGP. `policy_text` is `.data.policy` verbatim.
```json
{"egp":[{"enforcement_level":"advisory","name":"synthetic-egp-platform-advisory","namespace":"admin/platform","paths":["secret/*"],"policy_text":"...","type":"egp"}],
 "rgp":[]}
```

### Coverage Record (`coverage.json`)
`LIST` on an empty EGP/RGP set returns 404, which is recorded as an empty list, not a failure.
```json
{
  "policies": {
    "acl_total": 10,
    "egp_policies": [],
    "rgp_policies": []
  }
}
```

### Reference implementation (validated against the harness)
Per namespace: `LIST sys/policies/acl`, drop built-ins, `GET` each, emit `{name, namespace, policy_text: .data.policy, type}`
sorted by name. Compare with `jq -j` (no trailing newline) when checking byte-for-byte against the API.
```bash
vget LIST "$ns" sys/policies/acl | jq -r '.data.keys[]? | select(. != "default" and . != "root" and . != "default-ceiling")' | LC_ALL=C sort
vget GET  "$ns" "sys/policies/acl/$n" | jq -c --arg ns "$ns" '.data | {name:.name,namespace:$ns,policy_text:.policy,type:"acl"}'
```
