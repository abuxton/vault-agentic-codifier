# TASK-S01 decision note: provider resources and import ids for stage 2

**Date**: 2026-11-26
**Provider**: `hashicorp/vault` `4.8.0` (darwin_arm64), Terraform 1.15.5
**Cluster**: a throwaway Vault Enterprise `2.2.2+ent` container on `127.0.0.1:18200`, not the committed harness. The container was created for this task and removed afterwards.
**Method**: scratch directories outside the repo. Each resource was created with Terraform, then imported into a fresh state with `import {}` and planned with `-detailed-exitcode`. Only throwaway state was written.

Where this note and `specs.md` disagree, this note wins and `specs.md` has been corrected.

## 1. Import ids and plan result (CAP-008, CAP-009)

| Resource | Import `id` | Plan after import | Notes |
|---|---|---|---|
| `vault_egp_policy` | policy name | `6 to import, 0 to add, 0 to change, 0 to destroy` for the six objects below; second plan after apply: no changes | Verified in root and in alias `admin`. `paths` is returned in the order written. `hard-mandatory` also round-trips |
| `vault_rgp_policy` | policy name | as above | Verified in root and in alias `admin` |
| `vault_identity_mfa_totp` | method UUID | as above | Id is the `method_id`. `qr_size`, `skew` and `max_validation_attempts` have provider defaults that equal the Vault defaults, so no diff |
| `vault_identity_mfa_login_enforcement` | enforcement **name** | as above | `mfa_method_ids` and `identity_group_ids` read back as UUID sets |
| `vault_identity_mfa_duo` | method UUID | `2 to import, 0 to add, 1 to change` **unless** `ignore_changes = [secret_key, integration_key]` is set, then `0 to change` | See section 2 |

## 2. Arguments Vault does not return

| Resource | Not returned | Treatment | Evidence |
|---|---|---|---|
| `vault_identity_mfa_duo` | `secret_key`, `integration_key` | Sensitive variables with no default, plus `lifecycle { ignore_changes = [secret_key, integration_key] }` | `GET identity/mfa/method/duo/<id>` returns `null` for both. Without `ignore_changes` the plan shows an in-place update |
| `vault_identity_mfa_okta` | `api_token`, `primary_email` | Sensitive variable with no default and `lifecycle { ignore_changes = [api_token, primary_email] }`; emit `base_url`, which Vault returns | Verified in TASK-S04 on a scratch container: with `primary_email = true` in config the plan shows an update, because Vault never returns it. Omit it from the config and ignore it |
| `vault_identity_mfa_pingid` | `settings_file_base64` | Sensitive variable with no default and `lifecycle { ignore_changes = [settings_file_base64] }` | Verified in TASK-S04: Vault returns `admin_url`, `authenticator_url`, `idp_url`, `org_alias`, `use_signature`, all computed, so none is emitted. `3 to import, 0 to change` with Duo and Okta |
| `vault_identity_mfa_totp` | none (no seed or QR is stored in the method) | No treatment | The seed is created per entity by `generate`/`admin-generate`, which discovery never calls |

## 3. Corrections to `specs.md`

1. **MFA methods are listed per type.** `LIST identity/mfa/method` returns all methods in the namespace; `GET` for a method uses `identity/mfa/method/<type>/<id>`. Both work in a child namespace (`admin`). The spec text is correct; discovery must read the `type` from the list or the `GET identity/mfa/method/<id>` response to build the typed path.
2. **Enforcement import id is the name**, not a UUID. CAP-009 AC5 ("method ids are UUIDs") applies to methods only. The enforcement is imported by `name`.
3. **A namespace-scoped MFA method is not visible from the root path.** A TOTP method created at root and one in `admin` are separate. Discovery must list per namespace, as it does for policies.
4. **EGP and RGP read capability is missing from the exporter policy** (section 4). Stage 1 granted `list` only, so the Sentinel source could not be read.

## 4. Exporter policy additions (read and list only)

Tested with a real exporter token (AppRole, policy `exporter`) against the container:

| Request | Result with the stage-1 policy |
|---|---|
| `LIST sys/policies/egp`, `LIST sys/policies/rgp` | 200 |
| `GET sys/policies/egp/<name>` | **403** |
| `LIST identity/mfa/method`, `LIST identity/mfa/method/totp` | **403** |
| `GET identity/mfa/method/<type>/<id>` | **403** |
| `LIST identity/mfa/login-enforcement`, `GET identity/mfa/login-enforcement/<name>` | **403** |
| `POST sys/policies/egp/<name>`, `POST identity/mfa/method/totp/generate` | 403 (must stay 403) |

Required additions in every namespace depth the policy already covers (`""`, `+/`, `+/+/`, `+/+/+/`):

```hcl
path "sys/policies/egp/*"                { capabilities = ["read"] }
path "sys/policies/rgp/*"                { capabilities = ["read"] }
path "identity/mfa/method"               { capabilities = ["list"] }
path "identity/mfa/method/*"             { capabilities = ["list", "read"] }
path "identity/mfa/login-enforcement"    { capabilities = ["list"] }
path "identity/mfa/login-enforcement/*"  { capabilities = ["read"] }
```

`identity/mfa/method/*` also matches `.../generate` and `.../admin-generate`, which are `update` operations. Granting `read` and `list` only does not allow them.

**Tested** with the six paths above added to the stage-1 policy on the container, using an AppRole exporter token:

| Request | Result |
|---|---|
| `LIST identity/mfa/method`, `GET identity/mfa/method/duo/<id>`, `GET sys/policies/egp/<name>`, `LIST sys/policies/rgp` | 200 |
| `LIST identity/mfa/login-enforcement` at root | 404 (none exists at root; they live in `admin`) |
| `POST sys/policies/egp/<name>`, `POST .../totp/generate`, `POST .../totp/admin-generate`, `DELETE .../duo/<id>`, `POST .../totp`, `POST .../login-enforcement/<name>` | 403 |

TASK-S02 repeats the write attempts against the committed harness (its acceptance criterion).

## 5. Open items carried to later tasks

- Okta and PingID have no fixture. TASK-S04 adds scratch variants for them and updates section 2.
- CAP-010 and CAP-011 resource names are not verified here. TASK-S05 and TASK-S06 each begin by verifying their own resources the same way and append to this note.

## 5. Duo, Okta and PingID on a scratch container (TASK-S04)

Created on a throwaway Vault 2.2.2+ent dev container in namespace `admin`, with a marker string in every secret field.

- `LIST identity/mfa/method` returns `key_info` per method with `type`; `GET identity/mfa/method/<type>/<id>` returns the same fields. The marker appeared in neither response, so the keys are never returned.
- A method's `name` is empty unless set at creation; a `name` argument is then not emitted.
- Duo returns `api_hostname`, `use_passcode`, `pushinfo`, `username_format`. Okta returns `org_name`, `base_url`, `username_format`. PingID returns only computed fields.
- Combined plan with `ignore_changes` on the key arguments and `primary_email` left out: `3 to import, 0 to add, 0 to change, 0 to destroy`.

## 6. CAP-010 auth method configuration (TASK-S05)

Verified on a throwaway Vault 2.2.2+ent container in `admin/platform` (fixture: `skills/validation-variants/scripts/fixture-auth-config.sh`). One configuration with 15 `import {}` blocks planned `15 to import, 0 to change`, applied as 15 imported, and re-planned with exit 0.

| Resource | Import id | Sensitive or unreadable | Handling |
|---|---|---|---|
| `vault_ldap_auth_backend` | mount path | `bindpass` never returned | Variable, `ignore_changes = [bindpass, disable_remount]`. It owns the mount, so no `vault_auth_backend` is emitted. Vault returns `max_page_size = 0` and the provider default is -1, so `max_page_size` is always emitted |
| `vault_ldap_auth_backend_group` | `auth/<p>/groups/<name>` | none | `policies` |
| `vault_ldap_auth_backend_user` | `auth/<p>/users/<name>` | none | `groups`, `policies` |
| `vault_kubernetes_auth_backend_config` | `auth/<p>/config` | `token_reviewer_jwt` (Vault returns only `token_reviewer_jwt_set`) | Variable and `ignore_changes`. `kubernetes_ca_cert` is public and is emitted |
| `vault_kubernetes_auth_backend_role` | `auth/<p>/role/<name>` | none | |
| `vault_aws_auth_backend_client` | `auth/<p>/config/client` | `secret_key` never returned. **`access_key` is returned in clear** | Both are variables when `access_key` is set, both ignored after import. The raw payload keeps neither |
| `vault_aws_auth_backend_role` | `auth/<p>/role/<name>` | none | Vault returns singular names (`bound_iam_principal_arn`); the provider takes plurals. `resolve_aws_unique_ids = false` is emitted when it is false |
| `vault_cert_auth_backend_role` | **none: "doesn't support import"** | none | **Not emitted.** An import-less resource plans as a create, which breaks the zero-diff claim (a `vault_generic_endpoint` stand-in also plans as a create). The cert mount is emitted as `vault_auth_backend`; the cert roles are listed in `coverage.md` as "review manually: provider 4.8.0 cannot import cert roles". CAP-010 AC1 is amended accordingly |
| `vault_token_auth_backend_role` | `auth/token/roles/<name>` | none | The `token/` mount is not listed in `sys/auth`; roles are read from `auth/token/roles` |
| `vault_jwt_auth_backend` (oidc, jwt) | mount path | `oidc_client_secret` never returned | As in `admin-config`; static `jwt_validation_pubkeys` is public |
| `vault_jwt_auth_backend_role` | `auth/<p>/role/<name>` | none | |

The exporter policy had `auth/+/role`, `auth/+/role/*` and `auth/+/config` only. LDAP groups and users, cert roles, token roles and the AWS client need extra read and list grants (TASK-S05).

