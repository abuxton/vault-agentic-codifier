# MFA

Method ids are Vault UUIDs and appear only in `imports_mfa.tf`. A login enforcement rule is imported by name. Duo, Okta and PingID key arguments are sensitive variables with no default and are ignored after import, because Vault never returns them. No TOTP seed or QR code is read.

| Namespace | Kind | Resource | Targets |
|---|---|---|---|
| `admin` | method (totp) | `vault_identity_mfa_totp.admin_totp` | - |
| `admin` | login enforcement | `vault_identity_mfa_login_enforcement.admin_synthetic_platform_admin_totp` | methods: `admin_totp`; groups: `admin_vault_platform_admin`; entities: -; mounts: -; types: - |
