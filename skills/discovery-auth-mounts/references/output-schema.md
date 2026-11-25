## 6. Output Schema

The output payload is written to `discovered_terraform/raw/<namespace>/auth_mounts.json`:

```json
{
  "mounts": [
    {
      "path": "approle",
      "type": "approle",
      "accessor": "auth_approle_d1a2b3c4",
      "description": "AppRole auth backend for platform namespace",
      "local": false,
      "seal_wrap": false,
      "tune": {
        "default_lease_ttl": 0,
        "max_lease_ttl": 0
      },
      "roles": [
        {
          "name": "platform-ci",
          "token_policies": ["platform-devops-write"],
          "token_ttl": 3600,
          "token_max_ttl": 14400,
          "secret_id_num_uses": 1,
          "secret_id_ttl": 1800,
          "token_type": "default"
        }
      ]
    }
  ],
  "coverage": [
    {
      "path": "approle",
      "type": "approle",
      "resource_type": "vault_auth_backend",
      "role_resource_type": "vault_approle_auth_backend_role"
    }
  ]
}
```
