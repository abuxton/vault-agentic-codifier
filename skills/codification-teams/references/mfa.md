# MFA (CAP-009)

Input: `<raw>/<ns>/mfa.json` (`methods`, `enforcements`). Output in the layer of the namespace: `<ns>_mfa.tf`,
`imports_mfa.tf`, and `teams/mfa.md`. A namespace with no MFA objects gets no file.

| Resource | Import id | Emitted arguments |
|---|---|---|
| `vault_identity_mfa_totp` | method UUID | `issuer`, `period`, `key_size`, `algorithm`, `digits`, `skew`, `qr_size`, `max_validation_attempts` |
| `vault_identity_mfa_duo` | method UUID | `api_hostname`, `push_info`, `use_passcode`, `username_format`; `integration_key` and `secret_key` from variables |
| `vault_identity_mfa_okta` | method UUID | `org_name`, `base_url`, `username_format`; `api_token` from a variable |
| `vault_identity_mfa_pingid` | method UUID | `settings_file_base64` from a variable |
| `vault_identity_mfa_login_enforcement` | rule **name** | `name`; `mfa_method_ids`, `identity_group_ids`, `identity_entity_ids`, `auth_method_accessors` as references; `auth_method_types` |

Rules:

- Key arguments are `sensitive` variables with no default, named `<label>_<argument>`, and the resource has
  `lifecycle { ignore_changes }` on them, because Vault never returns them. Okta also ignores `primary_email`
  (not returned), PingID emits no computed field. Verified on a scratch container (`task-s01-decision.md` section 5).
- Method ids, group ids, entity ids and accessors are references; UUIDs are only in `imports_mfa.tf`.
- A method label is `<ns>_<type>`, with a numeric suffix for a second method of one type. A method not found in its
  own namespace, or a group or entity not in `identity.json`, stops the run (exit 2).
- A `mfa.json` with a credential-named field stops the run. Discovery filters each type to an allowlist.
- Discovery never calls `generate` or `admin-generate`; no TOTP seed or QR code is read.
