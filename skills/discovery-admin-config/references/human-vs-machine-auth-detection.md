## Human vs machine auth detection

| Mount `type` | Class | Config/read endpoint | Secret fields to strip |
|---|---|---|---|
| `oidc` | human | `auth/<p>/config`, `LIST auth/<p>/role` | `oidc_client_secret`, `client_secret` |
| `jwt` | human | `auth/<p>/config`, `LIST auth/<p>/role` | `jwt_validation_pubkeys` kept; `oidc_client_secret` stripped |
| `ldap` | human | `auth/<p>/config`, `LIST auth/<p>/groups` | `bindpass` |
| `github` | human | `auth/<p>/config`, `LIST auth/<p>/map/teams` | none expected |
| `okta` | human | `auth/<p>/config`, `LIST auth/<p>/groups` | `api_token` |
| `approle` | machine | none (roles covered by TASK-010) | - |
| `kubernetes` | machine | none | - |
| `aws` | machine | none | - |
| `cert` | machine | none | - |
| `token`, other | skipped / `unknown` | mount metadata only | - |

---
