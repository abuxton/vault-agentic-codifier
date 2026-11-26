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
| `vault_identity_mfa_okta` | `api_token` | Same as Duo | Expected from the provider schema; not run here, no Okta fixture. Treat as unverified until a variant covers it |
| `vault_identity_mfa_pingid` | `settings_file_base64` | Same as Duo | Unverified, as for Okta |
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
