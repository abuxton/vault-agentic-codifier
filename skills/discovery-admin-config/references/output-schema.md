## Output schema

`discovered_terraform/raw/admin/admin_config.json`:

```json
{
  "namespace_meta": {"id": "", "path": "admin/", "custom_metadata": {}},
  "human_auth_mounts": [
    {"path": "", "type": "", "accessor": "", "config": {}, "roles_or_groups": []}
  ],
  "machine_auth_mounts": [{"path": "", "type": "", "accessor": ""}],
  "operator_policies": ["admin"],
  "operator_groups": [{"name": "", "policies": []}]
}
```

All arrays sorted by `path` or `name`. `namespace_meta.id` is a Vault-assigned lookup value; do not emit it as a literal in generated HCL (use only in `imports.tf`).

---
