# Zero-diff import report

Imports applied in a scratch state (Vault is not modified), followed by `terraform plan -detailed-exitcode`. The "reimport" pass deletes the scratch state and imports again.

| Capability | Resources | Result |
|---|---|---|
| admin-config | 0 | none declared |
| auth-mounts | 11 | pass |
| namespaces | 4 | pass |
| policies | 10 | pass |
| root-config | 2 | pass |
| secrets-engines | 8 | pass |
| teams | 17 | pass |

| Layer | Resources | Result |
|---|---|---|
| admin | 31 | pass |
| namespaces | 3 | pass |
| seed | 18 | pass |

## ignore_changes entries

| Layer | File | Resource | Attributes | Reason |
|---|---|---|---|---|
| admin | `admin_auth_mounts.tf` | `vault_auth_backend.admin_approle` | `disable_remount,tune` | provider 4.8.0 imports disable_remount (and an untuned tune) as unset; ignoring them avoids a no-op diff |
| admin | `root_auth_mounts.tf` | `vault_auth_backend.approle` | `disable_remount,tune` | provider 4.8.0 imports disable_remount (and an untuned tune) as unset; ignoring them avoids a no-op diff |
| admin | `root_identity_aliases.tf` | `vault_identity_entity_alias.exporter_agent_approle` | `name` | a sensitive name is imported unmarked; ignoring it avoids a no-op in-place change |
| seed | `admin_app_billing_auth_mounts.tf` | `vault_auth_backend.admin_app_billing_approle` | `disable_remount,tune` | provider 4.8.0 imports disable_remount (and an untuned tune) as unset; ignoring them avoids a no-op diff |
| seed | `admin_app_identity_auth_mounts.tf` | `vault_auth_backend.admin_app_identity_approle` | `disable_remount,tune` | provider 4.8.0 imports disable_remount (and an untuned tune) as unset; ignoring them avoids a no-op diff |
| seed | `admin_platform_auth_mounts.tf` | `vault_auth_backend.admin_platform_approle` | `disable_remount,tune` | provider 4.8.0 imports disable_remount (and an untuned tune) as unset; ignoring them avoids a no-op diff |
