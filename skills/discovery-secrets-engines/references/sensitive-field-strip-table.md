## Sensitive field strip table

| Field | Where it appears | Replacement in stored JSON |
|---|---|---|
| `password` | database `config/<name>`, `connection_details` | `"REDACTED-sensitive-variable-required"` |
| `secret_key` | aws `config/root` | `"REDACTED-sensitive-variable-required"` |
| `credentials` | gcp `config/root` | `"REDACTED-sensitive-variable-required"` |
| `private_key` | any engine config | `"REDACTED-sensitive-variable-required"` |
| `client_secret` | azure `config/root` | `"REDACTED-sensitive-variable-required"` |

The generator turns each redacted field into a `variable` with no default (rule 9).

---
