# Auth mount coverage

| Namespace | Mount | Type | Codified as | Roles | Notes |
|---|---|---|---|---|---|
| root | `approle` | approle | `vault_auth_backend`, `vault_approle_auth_backend_role` | 2 | - |
| `admin` | `approle` | approle | `vault_auth_backend`, `vault_approle_auth_backend_role` | 1 | - |
| `admin/app-billing` | `approle` | approle | `vault_auth_backend`, `vault_approle_auth_backend_role` | 1 | - |
| `admin/app-identity` | `approle` | approle | `vault_auth_backend`, `vault_approle_auth_backend_role` | 1 | - |
| `admin/platform` | `approle` | approle | `vault_auth_backend`, `vault_approle_auth_backend_role` | 1 | - |

Mounts: 5. Roles: 6. Not fully codified: 0.
