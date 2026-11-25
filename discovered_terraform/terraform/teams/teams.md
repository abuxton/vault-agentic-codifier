# Teams

Recorded policies are on the Vault identity group. Inferred policies are matched by name in the tenant namespace (`policies/correlation.json`) and are never written into Terraform.

| Team | Namespace | Group | Entities | Auth roles | Recorded policies | Inferred policies |
|---|---|---|---|---|---|---|
| (tenant admin) | `admin/app-billing` | `vault-app-billing-admin` |  | - | `namespace-admin` | - |
| developers | `admin/app-billing` | `vault-app-billing-developers` | `synthetic-user-app-billing-developers` | `approle/billing-service` | - | `billing-developers-read` (inferred; access applied at the namespace layer) |
| owners | `admin/app-billing` | `vault-app-billing-owners` | `synthetic-user-app-billing-owners` | - | - | `billing-owners-write` (inferred; access applied at the namespace layer) |
| (tenant admin) | `admin/app-identity` | `vault-app-identity-admin` |  | - | `namespace-admin` | - |
| developers | `admin/app-identity` | `vault-app-identity-developers` | `synthetic-user-app-identity-developers` | `approle/identity-service` | - | `identity-developers-read` (inferred; access applied at the namespace layer) |
| owners | `admin/app-identity` | `vault-app-identity-owners` | `synthetic-user-app-identity-owners` | - | - | `identity-owners-write` (inferred; access applied at the namespace layer) |
| (tenant admin) | `admin/platform` | `vault-platform-admin` |  | - | `namespace-admin` | - |
| devops | `admin/platform` | `vault-platform-devops` | `synthetic-user-platform-devops` | `approle/platform-ci` | - | `platform-devops-write` (inferred; access applied at the namespace layer) |
| sre | `admin/platform` | `vault-platform-sre` | `synthetic-user-platform-sre` | - | - | `platform-sre-read` (inferred; access applied at the namespace layer) |

Aliases found: 1. No aliases found for `admin`.
