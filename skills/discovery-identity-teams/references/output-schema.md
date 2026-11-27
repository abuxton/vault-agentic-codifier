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

## `mfa.json` (CAP-009)

```json
{"methods":[{"config":{"algorithm":"SHA1","digits":6,"issuer":"...","key_size":20,"max_validation_attempts":5,"period":30,"qr_size":200,"skew":1},"id":"<uuid>","namespace":"admin","type":"totp"}],
 "enforcements":[{"auth_method_accessors":[],"auth_method_types":[],"id":"<uuid>","identity_entity_ids":[],"identity_group_ids":["<uuid>"],"mfa_method_ids":["<uuid>"],"name":"...","namespace":"admin"}]}
```
