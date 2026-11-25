## Output schema

`discovered_terraform/raw/<namespace>/secrets_engines.json`:

```json
{
  "mounts": [
    {
      "path": "secret/",
      "type": "kv",
      "description": "",
      "options": {"version": "2"},
      "tune": {"default_lease_ttl": 0, "max_lease_ttl": 0},
      "engine_config": {"max_versions": 0, "cas_required": false, "delete_version_after": "0s"}
    }
  ],
  "coverage": [
    {"path": "secret/", "type": "kv", "resource_type": "vault_mount + vault_kv_secret_backend_v2", "fallback": null}
  ]
}
```

Unknown engine types appear in `coverage` with `resource_type: null` and `fallback: "mount metadata only"`.

---
