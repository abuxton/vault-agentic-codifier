## Output schema

`discovered_terraform/raw/<namespace>/identity.json`:

```json
{
  "groups": [
    {"name": "", "type": "internal", "policies": [], "member_entity_ids": [],
     "member_group_ids": [], "metadata": {}, "namespace": "admin"}
  ],
  "entities": [
    {"name": "", "policies": [], "metadata": {}, "disabled": false, "namespace": "admin"}
  ],
  "group_aliases": [
    {"id": "", "name": "", "mount_accessor": "", "mount_path": "", "mount_type": "", "canonical_id": ""}
  ],
  "entity_aliases": [
    {"id": "", "name": "", "mount_accessor": "", "mount_path": "", "mount_type": "", "canonical_id": ""}
  ],
  "accessor_map": {"auth_approle_xxxx": {"namespace": "admin", "path": "approle/", "type": "approle"}}
}
```

Arrays are sorted by `name` (aliases by `mount_path`, then `name`). `accessor_map` keys are sorted by `jq -S`.

---
