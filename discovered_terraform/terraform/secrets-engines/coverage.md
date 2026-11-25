# Secrets engine coverage

| Namespace | Mount | Type | Codified as | Notes |
|---|---|---|---|---|
| root | `secret` | kv (v2) | `vault_mount`, `vault_kv_secret_backend_v2` | secret data is never read; preloaded root mount (Vault dev mode) is imported, not created |
| `admin/app-billing` | `secret` | kv (v2) | `vault_mount`, `vault_kv_secret_backend_v2` | secret data is never read |
| `admin/app-identity` | `secret` | kv (v2) | `vault_mount`, `vault_kv_secret_backend_v2` | secret data is never read |
| `admin/platform` | `secret` | kv (v2) | `vault_mount`, `vault_kv_secret_backend_v2` | secret data is never read |

Mounts: 4. Not fully codified: 0.
