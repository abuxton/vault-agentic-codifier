# admin layer

## Operator policies

| Policy | Namespace | Held by |
|---|---|---|
| `admin` | admin | (no recorded holder) |
| `namespace-admin` | admin | vault-app-billing-admin, vault-app-identity-admin, vault-platform-admin |
| `operator` | root | Out of scope here; owned by root-config / policies |

## Human authentication

No human auth method detected in `admin`.

Machine auth mounts (`approle` (approle)) and their roles are emitted by `auth-mounts` and referenced here, not declared.
