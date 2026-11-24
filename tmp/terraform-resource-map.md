# Vault Object → `hashicorp/vault` Terraform Resource Map

> Provider: `hashicorp/vault` `~> 4` (harness lock: **4.8.0**, `darwin_arm64`).
> API reference: Vault HTTP API (`/v1/...`). Namespace is supplied by the `X-Vault-Namespace` header, which the provider sets from `provider "vault" { namespace = ... }` or the per-resource `namespace` argument.
> Resource names and import ID formats below should be re-verified against the provider docs for the exact provider version in use before generating code; entries marked **(verify)** are the ones with the highest risk of version drift.

Legend — **Scope**: `R` root namespace only · `N` any namespace · `E` Vault Enterprise feature.
**Harness**: ✅ present in `test/terraform/*` · ➖ not present.

---

## 1. Master mapping table

| Vault Object | Vault API Endpoint | Terraform Resource | Scope | Harness | Notes |
|---|---|---|---|---|---|
| **Namespace** | `sys/namespaces/<path>` (LIST/GET/POST/DELETE) | `vault_namespace` | N, E | ✅ `admin`, `platform`, `app-billing`, `app-identity` | `path` is relative to the provider's namespace. Exposes `path_fq` and `namespace_id`. `custom_metadata` supported (used by harness). Deleting a namespace requires it to be empty. |
| **Auth backend (mount)** | `sys/auth/<path>` (GET list, POST enable, DELETE) | `vault_auth_backend` | N | ✅ `approle` ×4 (root, admin, 3 tenants) | `type`, `path`, `description`, `tune {}` block, `accessor` (computed). Import by `path`. Use as the parent for all method-specific resources. |
| **Auth mount tune** | `sys/auth/<path>/tune` | `tune` block on `vault_auth_backend` | N | ➖ | Fields: `default_lease_ttl`, `max_lease_ttl`, `listing_visibility`, `audit_non_hmac_request_keys`, `audit_non_hmac_response_keys`, `passthrough_request_headers`, `allowed_response_headers`, `token_type`. |
| **AppRole role** | `auth/<mount>/role/<name>` | `vault_approle_auth_backend_role` | N | ✅ `terraform-admin`, `namespace-provisioner`, `platform-ci`, `billing-service`, `identity-service` | Uses the `token_*` argument family (`token_policies`, `token_ttl`, `token_max_ttl`). Harness sets `secret_id_num_uses = 1` and short `secret_id_ttl`. `role_id` computed. **Do not codify SecretIDs.** |
| AppRole SecretID | `auth/<mount>/role/<name>/secret-id` | `vault_approle_auth_backend_role_secret_id` | N | ➖ | **Skip.** Ephemeral credential; would persist secret in state. |
| **LDAP auth config** | `auth/<mount>/config` (type `ldap`) | `vault_ldap_auth_backend` | N | ➖ | Mount + config in one resource (does not need `vault_auth_backend`). `url`, `userdn`, `userattr`, `groupdn`, `groupfilter`, `groupattr`, `binddn`, `starttls`, `certificate`. `bindpass` is sensitive and **not returned** by the API → must be supplied from a variable; expect perpetual diff or `ignore_changes` if omitted. Import by mount path. |
| LDAP groups / users | `auth/<mount>/groups/<name>`, `auth/<mount>/users/<name>` | `vault_ldap_auth_backend_group`, `vault_ldap_auth_backend_user` | N | ➖ | Maps LDAP group → policies. |
| **OIDC auth config** | `auth/<mount>/config` (type `oidc`) | `vault_jwt_auth_backend` (`type = "oidc"`) | N | ➖ | One resource for mount + config. `oidc_discovery_url`, `oidc_client_id`, `oidc_client_secret` (sensitive, write-only), `default_role`, `bound_issuer`, `tune {}`. Same resource handles JWT by `type = "jwt"`. |
| OIDC/JWT role | `auth/<mount>/role/<name>` | `vault_jwt_auth_backend_role` | N | ➖ | `role_type`, `bound_audiences`, `user_claim`, `groups_claim`, `allowed_redirect_uris`, `token_policies`. |
| **ACL policy** | `sys/policies/acl/<name>` (legacy alias `sys/policy/<name>`) | `vault_policy` | N | ✅ `operator`, `admin`, `namespace-admin`, 6 tenant policies | Identity is `name`. Harness loads HCL via `file()` for root/admin policies and heredocs for tenant policies. Prefer `data "vault_policy_document"` for generated policies. `default` and `root` are built-in; never manage `root`; manage `default` only deliberately. |
| Sentinel EGP / RGP | `sys/policies/egp/<name>`, `sys/policies/rgp/<name>` | `vault_egp_policy`, `vault_rgp_policy` | N, E | ➖ | Enterprise (Sentinel). See gap analysis. |
| **Secrets mount** | `sys/mounts/<path>` | `vault_mount` | N | ✅ `secret/` KV v2 in 3 tenants | `type`, `path`, `options`, `description`, `default_lease_ttl_seconds`, `max_lease_ttl_seconds`, `seal_wrap`, `listing_visibility`, `audit_non_hmac_*_keys`. Computed `accessor`. Import by `path`. |
| **Mount tune** | `sys/mounts/<path>/tune` | arguments on `vault_mount` (TTL, `listing_visibility`, header lists, `audit_non_hmac_*`) | N | ➖ (defaults only) | There is **no** separate tune resource. Drift appears as in-place changes to `vault_mount`. For auth mounts use the `tune` block (see above). |
| **KV v2 engine config** | `<mount>/config` (GET/POST) | `vault_kv_secret_backend_v2` | N | ➖ | `max_versions`, `cas_required`, `delete_version_after`. Create against an existing `vault_mount` of `type = "kv"`, `options.version = "2"`. Import ID is the mount path (verify). |
| KV v2 secret data | `<mount>/data/<name>`, `<mount>/metadata/<name>` | `vault_kv_secret_v2` (resource), `data "vault_kv_secret_v2"` | N | ✅ 6 synthetic secrets | **Do not codify real secret data.** Harness uses `SYNTHETIC-*` values and `delete_all_versions = true`. Use `data_json_wo` write-only variants where supported by the provider (verify). |
| KV v2 custom metadata | `<mount>/metadata/<name>` | `vault_kv_secret_v2` `custom_metadata` block | N | ➖ | |
| **PKI mount** | `sys/mounts/<path>` (type `pki`) | `vault_mount` (`type = "pki"`) | N | ➖ | Max lease TTL must exceed CA TTL. |
| **PKI role** | `<mount>/roles/<name>` | `vault_pki_secret_backend_role` | N | ➖ | `allowed_domains`, `allow_subdomains`, `max_ttl`, `key_type`, `key_bits`, `require_cn`, … |
| PKI config / URLs | `<mount>/config/urls`, `<mount>/config/crl`, `<mount>/config/issuers` | `vault_pki_secret_backend_config_urls`, `vault_pki_secret_backend_crl_config`, `vault_pki_secret_backend_config_issuers` | N | ➖ | One resource per config endpoint (verify exact names for 4.8.0). |
| PKI CA / issuers | `<mount>/root/generate/*`, `<mount>/intermediate/*`, `<mount>/issuer/*` | `vault_pki_secret_backend_root_cert`, `vault_pki_secret_backend_intermediate_cert_request`, `vault_pki_secret_backend_intermediate_set_signed`, `vault_pki_secret_backend_issuer` | N | ➖ | **Generated key material.** Private keys are never returned by the API. Capture *configuration intent*, not issued certs. Skip issued leaf certs entirely. |
| **Identity entity** | `identity/entity/id/<id>`, `identity/entity/name/<name>` | `vault_identity_entity` | N | ✅ 6 synthetic entities | Identity key is `name`; Terraform ID is the UUID. `policies`, `metadata`, `disabled`, `external_policies`. Set `external_policies = true` if policies are managed elsewhere. |
| **Entity alias** | `identity/entity-alias/id/<id>` | `vault_identity_entity_alias` | N | ➖ | `name`, `canonical_id`, `mount_accessor`. Most aliases are auto-created at first login → usually skip. |
| **Identity group** | `identity/group/id/<id>`, `identity/group/name/<name>` | `vault_identity_group` | N | ✅ 3 tenant-admin + 6 team groups | `type` = `internal` \| `external`; `policies`, `member_entity_ids`, `member_group_ids`, `metadata`, `external_policies`, `external_member_entity_ids`, `external_member_group_ids`. |
| Group membership (split) | `identity/group/id/<id>` | `vault_identity_group_member_entity_ids`, `vault_identity_group_member_group_ids`, `vault_identity_group_policies` | N | ➖ | Use **instead of** inline `member_*` when different states own different members. Combine with `external_member_entity_ids = true` on the group. |
| **Group alias** | `identity/group-alias/id/<id>` | `vault_identity_group_alias` | N | ➖ | `name` (IdP group string), `mount_accessor`, `canonical_id` (external group id). Core of OIDC/LDAP → group → policy mapping in HVD. |
| **Audit device** | `sys/audit/<path>` | `vault_audit` | R (device mounts per namespace in Enterprise; verify behaviour for your version) | ✅ `file` | `type`, `path`, `options = { file_path = ... }`, `local`, `description`. Import by `path`. |
| Audit request header | `sys/config/auditing/request-headers/<name>` | `vault_audit_request_header` | R | ➖ | |
| **Rate-limit quota** | `sys/quotas/rate-limit/<name>` | `vault_quota_rate_limit` | R/N | ✅ `global-rate-limit` (root, `path = ""`) | `path` ("" = global, `ns1/` = namespace, `ns1/mount/` = mount), `rate`, `interval`, `block_interval`. Import by `name`. Harness has **only the root-global** quota. |
| Lease-count quota | `sys/quotas/lease-count/<name>` | `vault_quota_lease_count` | R/N | ➖ | `max_leases`, `path`. |
| Quota config | `sys/quotas/config` | *(no dedicated resource)* — `vault_generic_endpoint` | R | ➖ | `enable_rate_limit_audit_logging`, `enable_rate_limit_response_headers`. |
| Token auth role | `auth/token/roles/<name>` | `vault_token_auth_backend_role` | N | ➖ | Codify **roles**, never tokens. |
| Raft snapshot automation | `sys/storage/raft/snapshot-auto/config/<name>` | `vault_raft_snapshot_agent_config` | R, E | ➖ | Enterprise. Part of HVD backup guidance. |
| MFA methods / enforcement | `identity/mfa/method/*`, `identity/mfa/login-enforcement/*` | `vault_identity_mfa_totp`, `vault_identity_mfa_duo`, `vault_identity_mfa_okta`, `vault_identity_mfa_pingid`, `vault_identity_mfa_login_enforcement` | N, E | ➖ | (verify availability in installed version). |
| Anything else | any | `vault_generic_endpoint` (write-only, idempotent via `ignore_absent_fields`) / `data "vault_generic_secret"` | any | ➖ | Escape hatch. Prefer a typed resource when one exists. |

---

## 2. Read-side data sources the codifier can use for discovery verification

| Purpose | Data source |
|---|---|
| Fetch an existing namespace | `data "vault_namespace"` |
| List namespaces | `data "vault_namespaces"` |
| Build policy HCL from structured input | `data "vault_policy_document"` |
| Look up an auth backend accessor | `data "vault_auth_backend"` |
| Look up identity by name | `data "vault_identity_entity"`, `data "vault_identity_group"` |
| Read a KV v2 secret | `data "vault_kv_secret_v2"` |
| Read arbitrary path | `data "vault_generic_secret"` |

---

## 3. Harness resource inventory (what is actually exercised)

| Layer dir | Namespace targeted | Resource types used |
|---|---|---|
| `test/terraform/admin` | root | `vault_audit`, `vault_namespace`, `vault_policy`, `vault_auth_backend`, `vault_approle_auth_backend_role`, `vault_quota_rate_limit` |
| `test/terraform/namespaces` | `admin` | `vault_policy`, `vault_auth_backend`, `vault_approle_auth_backend_role`, `vault_namespace` (`for_each` tenants), `vault_identity_group` (`internal`), `vault_identity_entity` |
| `test/terraform/seed` | `admin/platform`, `admin/app-billing`, `admin/app-identity` | `vault_mount` (KV v2), `vault_policy`, `vault_auth_backend`, `vault_approle_auth_backend_role`, `vault_kv_secret_v2` |

**Not exercised by the harness but required for a general-purpose codifier:** LDAP, OIDC/JWT, group alias, entity alias, PKI, KV v2 config, mount tuning, lease-count quotas, per-namespace quotas, Sentinel, MFA, Transit/Database/AWS/etc. engines.

---

## 4. Provider-behaviour notes that affect generated code

1. **Namespace targeting.** Either `provider "vault" { alias = "x"; namespace = "admin/platform" }` and `provider = vault.x` on each resource, or the resource-level `namespace` argument. The harness uses provider aliases with `skip_child_token = true`.
2. **Child token.** By default the provider creates a short-lived child token for each run; `skip_child_token = true` is required when the supplied token lacks `auth/token/create` or when targeting multiple aliases with one token (harness does this).
3. **Sensitive write-only attributes.** `oidc_client_secret`, `bindpass`, AppRole SecretIDs, KV values are not readable back from Vault; expect "no drift detected" even if the live value differs, or a persistent diff depending on the resource. Handle with variables, not literals.
4. **Computed IDs.** Groups/entities/aliases are keyed by UUID in Terraform state but by name in Vault; imports must supply the UUID.
5. **Policy rename.** `vault_policy.name` forces replacement; a replaced policy briefly disappears and tokens that reference it lose access.
6. **State exposure.** Every attribute read from Vault is stored in state. KV v2 `data_json` values and sensitive config become state contents; state storage must be encrypted and access-controlled.

---

## 5. Verified import IDs (TASK-006, provider 4.8.0)

Verified by `terraform plan` with `import {}` against the harness. Full table and evidence: `openspec/changes/vault-brownfield-research/task-006-decision.md`. Where this differs from the table in section 1, this section wins.

- IDs are relative to the provider's namespace. Never prefix the namespace.
- `vault_auth_backend`: bare mount path (`approle`). `auth/approle` fails.
- `vault_namespace`: leaf name under the parent's provider alias (`platform`). `admin/platform` fails with HTTP 400.
- `vault_approle_auth_backend_role`: `auth/<mount>/role/<name>`.
- `vault_kv_secret_backend_v2`: `<mount>/config`.
- `vault_identity_group` / `vault_identity_entity`: UUID.
- `vault_generic_endpoint`: import not supported.
- Resource-level `namespace` breaks `import {}` (plan shows replacement); use aliased providers.
