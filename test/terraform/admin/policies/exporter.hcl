# exporter.hcl
# Least-privilege, read-only policy for the vault-brownfield-codifier exporter.
#
# The exporter token lives in the ROOT namespace. A root-namespace policy
# reaches child namespaces through path prefixes (admin/sys/auth), and `+`
# matches exactly one path segment, so every structural grant is repeated for
# namespace depths 0..3 (root, admin, admin/platform, admin/platform/x).
# Add a depth if the cluster nests deeper.
#
# Design rules
#  1. list/read structural objects only; no create, update, delete.
#  2. Explicit deny on KV data/metadata paths and AppRole credentials. A deny
#     wins over any other policy attached to the same token.
#  3. `sys/audit` is the only sudo path: Vault requires sudo to READ it
#     (https://developer.hashicorp.com/vault/api-docs/system/audit). The grant
#     is `read` + `sudo` on that single path, root namespace only.
#
# Each structural block repeats for depths 0..3. When adding a path, add it at
# all four depths, then run `vault policy fmt` on this file.

# ── Namespace enumeration ─────────────────────────────────────────────────

path "sys/namespaces" {
  capabilities = ["list"]
}

path "sys/namespaces/*" {
  capabilities = ["list", "read"]
}

path "+/sys/namespaces" {
  capabilities = ["list"]
}

path "+/sys/namespaces/*" {
  capabilities = ["list", "read"]
}

path "+/+/sys/namespaces" {
  capabilities = ["list"]
}

path "+/+/sys/namespaces/*" {
  capabilities = ["list", "read"]
}

path "+/+/+/sys/namespaces" {
  capabilities = ["list"]
}

path "+/+/+/sys/namespaces/*" {
  capabilities = ["list", "read"]
}

# ── Auth-mount enumeration ────────────────────────────────────────────────

path "sys/auth" {
  capabilities = ["read"]
}

path "sys/auth/*" {
  capabilities = ["list", "read"]
}

# Reading auth-mount config and tuning requires sudo (read only; no update).
path "sys/auth/+" {
  capabilities = ["read", "sudo"]
}

path "sys/auth/+/tune" {
  capabilities = ["read", "sudo"]
}

path "auth/+/role" {
  capabilities = ["list"]
}

path "auth/+/role/*" {
  capabilities = ["list", "read"]
}

path "auth/+/config" {
  capabilities = ["read"]
}

path "+/sys/auth" {
  capabilities = ["read"]
}

path "+/sys/auth/*" {
  capabilities = ["list", "read"]
}

path "+/sys/auth/+" {
  capabilities = ["read", "sudo"]
}

path "+/sys/auth/+/tune" {
  capabilities = ["read", "sudo"]
}

path "+/auth/+/role" {
  capabilities = ["list"]
}

path "+/auth/+/role/*" {
  capabilities = ["list", "read"]
}

path "+/auth/+/config" {
  capabilities = ["read"]
}

path "+/+/sys/auth" {
  capabilities = ["read"]
}

path "+/+/sys/auth/*" {
  capabilities = ["list", "read"]
}

path "+/+/sys/auth/+" {
  capabilities = ["read", "sudo"]
}

path "+/+/sys/auth/+/tune" {
  capabilities = ["read", "sudo"]
}

path "+/+/auth/+/role" {
  capabilities = ["list"]
}

path "+/+/auth/+/role/*" {
  capabilities = ["list", "read"]
}

path "+/+/auth/+/config" {
  capabilities = ["read"]
}

path "+/+/+/sys/auth" {
  capabilities = ["read"]
}

path "+/+/+/sys/auth/*" {
  capabilities = ["list", "read"]
}

path "+/+/+/sys/auth/+" {
  capabilities = ["read", "sudo"]
}

path "+/+/+/sys/auth/+/tune" {
  capabilities = ["read", "sudo"]
}

path "+/+/+/auth/+/role" {
  capabilities = ["list"]
}

path "+/+/+/auth/+/role/*" {
  capabilities = ["list", "read"]
}

path "+/+/+/auth/+/config" {
  capabilities = ["read"]
}

# ── Secrets-engine mount enumeration ──────────────────────────────────────

path "sys/mounts" {
  capabilities = ["read"]
}

path "sys/mounts/*" {
  capabilities = ["list", "read"]
}

path "+/sys/mounts" {
  capabilities = ["read"]
}

path "+/sys/mounts/*" {
  capabilities = ["list", "read"]
}

path "+/+/sys/mounts" {
  capabilities = ["read"]
}

path "+/+/sys/mounts/*" {
  capabilities = ["list", "read"]
}

path "+/+/+/sys/mounts" {
  capabilities = ["read"]
}

path "+/+/+/sys/mounts/*" {
  capabilities = ["list", "read"]
}

# ── ACL policy enumeration ────────────────────────────────────────────────

path "sys/policies/acl" {
  capabilities = ["list"]
}

path "sys/policies/acl/*" {
  capabilities = ["list", "read"]
}

path "sys/policies/egp" {
  capabilities = ["list"]
}

path "sys/policies/rgp" {
  capabilities = ["list"]
}

path "+/sys/policies/acl" {
  capabilities = ["list"]
}

path "+/sys/policies/acl/*" {
  capabilities = ["list", "read"]
}

path "+/sys/policies/egp" {
  capabilities = ["list"]
}

path "+/sys/policies/rgp" {
  capabilities = ["list"]
}

path "+/+/sys/policies/acl" {
  capabilities = ["list"]
}

path "+/+/sys/policies/acl/*" {
  capabilities = ["list", "read"]
}

path "+/+/sys/policies/egp" {
  capabilities = ["list"]
}

path "+/+/sys/policies/rgp" {
  capabilities = ["list"]
}

path "+/+/+/sys/policies/acl" {
  capabilities = ["list"]
}

path "+/+/+/sys/policies/acl/*" {
  capabilities = ["list", "read"]
}

path "+/+/+/sys/policies/egp" {
  capabilities = ["list"]
}

path "+/+/+/sys/policies/rgp" {
  capabilities = ["list"]
}

# ── Identity: groups, entities, aliases ───────────────────────────────────

path "identity/group/name" {
  capabilities = ["list"]
}

path "identity/group/name/*" {
  capabilities = ["list", "read"]
}

path "identity/group/id" {
  capabilities = ["list"]
}

path "identity/group/id/*" {
  capabilities = ["read"]
}

path "identity/entity/name" {
  capabilities = ["list"]
}

path "identity/entity/name/*" {
  capabilities = ["list", "read"]
}

path "identity/entity/id" {
  capabilities = ["list"]
}

path "identity/entity/id/*" {
  capabilities = ["read"]
}

path "identity/group-alias/id" {
  capabilities = ["list"]
}

path "identity/group-alias/id/*" {
  capabilities = ["read"]
}

path "identity/entity-alias/id" {
  capabilities = ["list"]
}

path "identity/entity-alias/id/*" {
  capabilities = ["read"]
}

path "+/identity/group/name" {
  capabilities = ["list"]
}

path "+/identity/group/name/*" {
  capabilities = ["list", "read"]
}

path "+/identity/group/id" {
  capabilities = ["list"]
}

path "+/identity/group/id/*" {
  capabilities = ["read"]
}

path "+/identity/entity/name" {
  capabilities = ["list"]
}

path "+/identity/entity/name/*" {
  capabilities = ["list", "read"]
}

path "+/identity/entity/id" {
  capabilities = ["list"]
}

path "+/identity/entity/id/*" {
  capabilities = ["read"]
}

path "+/identity/group-alias/id" {
  capabilities = ["list"]
}

path "+/identity/group-alias/id/*" {
  capabilities = ["read"]
}

path "+/identity/entity-alias/id" {
  capabilities = ["list"]
}

path "+/identity/entity-alias/id/*" {
  capabilities = ["read"]
}

path "+/+/identity/group/name" {
  capabilities = ["list"]
}

path "+/+/identity/group/name/*" {
  capabilities = ["list", "read"]
}

path "+/+/identity/group/id" {
  capabilities = ["list"]
}

path "+/+/identity/group/id/*" {
  capabilities = ["read"]
}

path "+/+/identity/entity/name" {
  capabilities = ["list"]
}

path "+/+/identity/entity/name/*" {
  capabilities = ["list", "read"]
}

path "+/+/identity/entity/id" {
  capabilities = ["list"]
}

path "+/+/identity/entity/id/*" {
  capabilities = ["read"]
}

path "+/+/identity/group-alias/id" {
  capabilities = ["list"]
}

path "+/+/identity/group-alias/id/*" {
  capabilities = ["read"]
}

path "+/+/identity/entity-alias/id" {
  capabilities = ["list"]
}

path "+/+/identity/entity-alias/id/*" {
  capabilities = ["read"]
}

path "+/+/+/identity/group/name" {
  capabilities = ["list"]
}

path "+/+/+/identity/group/name/*" {
  capabilities = ["list", "read"]
}

path "+/+/+/identity/group/id" {
  capabilities = ["list"]
}

path "+/+/+/identity/group/id/*" {
  capabilities = ["read"]
}

path "+/+/+/identity/entity/name" {
  capabilities = ["list"]
}

path "+/+/+/identity/entity/name/*" {
  capabilities = ["list", "read"]
}

path "+/+/+/identity/entity/id" {
  capabilities = ["list"]
}

path "+/+/+/identity/entity/id/*" {
  capabilities = ["read"]
}

path "+/+/+/identity/group-alias/id" {
  capabilities = ["list"]
}

path "+/+/+/identity/group-alias/id/*" {
  capabilities = ["read"]
}

path "+/+/+/identity/entity-alias/id" {
  capabilities = ["list"]
}

path "+/+/+/identity/entity-alias/id/*" {
  capabilities = ["read"]
}

# ── Rate-limit quotas (root namespace objects, listed from any depth) ─────

path "sys/quotas/rate-limit" {
  capabilities = ["list"]
}

path "sys/quotas/rate-limit/*" {
  capabilities = ["read"]
}

path "sys/quotas/config" {
  capabilities = ["read"]
}

# ── Structural health and config endpoints (no secret values) ─────────────

path "sys/health" {
  capabilities = ["read"]
}

path "sys/seal-status" {
  capabilities = ["read"]
}

path "sys/host-info" {
  capabilities = ["read"]
}

path "sys/license/status" {
  capabilities = ["read"]
}

path "sys/replication/status" {
  capabilities = ["read"]
}

path "sys/config/ui" {
  capabilities = ["read"]
}

path "sys/config/ui/headers" {
  capabilities = ["list", "read", "sudo"]
}

path "sys/config/ui/headers/*" {
  capabilities = ["list", "read", "sudo"]
}

path "sys/internal/ui/feature-flags" {
  capabilities = ["read"]
}

# ── Secrets-engine configuration (metadata only, no secret values) ──────────
# Used by discovery-secrets-engines. KV v2 `<mount>/config` carries only
# max_versions, cas_required and delete_version_after. The `data/` and
# `metadata/` paths stay denied below; `config/root` (cloud credentials) and
# key material paths are deliberately NOT granted.

path "+/config" {
  capabilities = ["read"]
}

path "+/config/urls" {
  capabilities = ["read"]
}

path "+/config/crl" {
  capabilities = ["read"]
}

path "+/roles" {
  capabilities = ["list"]
}

path "+/roles/*" {
  capabilities = ["read"]
}

path "+/+/config" {
  capabilities = ["read"]
}

path "+/+/config/urls" {
  capabilities = ["read"]
}

path "+/+/config/crl" {
  capabilities = ["read"]
}

path "+/+/roles" {
  capabilities = ["list"]
}

path "+/+/roles/*" {
  capabilities = ["read"]
}

path "+/+/+/config" {
  capabilities = ["read"]
}

path "+/+/+/config/urls" {
  capabilities = ["read"]
}

path "+/+/+/config/crl" {
  capabilities = ["read"]
}

path "+/+/+/roles" {
  capabilities = ["list"]
}

path "+/+/+/roles/*" {
  capabilities = ["read"]
}

path "+/+/+/+/config" {
  capabilities = ["read"]
}

path "+/+/+/+/config/urls" {
  capabilities = ["read"]
}

path "+/+/+/+/config/crl" {
  capabilities = ["read"]
}

path "+/+/+/+/roles" {
  capabilities = ["list"]
}

path "+/+/+/+/roles/*" {
  capabilities = ["read"]
}

# ── Audit devices (sudo required by Vault for GET sys/audit) ──────────────

path "sys/audit" {
  capabilities = ["read", "sudo"]
}

# ── Explicit deny: AppRole credentials ──────────────────────────────────

path "auth/+/role/+/role-id" {
  capabilities = ["deny"]
}

path "auth/+/role/+/secret-id" {
  capabilities = ["deny"]
}

path "auth/+/role/+/secret-id/*" {
  capabilities = ["deny"]
}

path "+/auth/+/role/+/role-id" {
  capabilities = ["deny"]
}

path "+/auth/+/role/+/secret-id" {
  capabilities = ["deny"]
}

path "+/auth/+/role/+/secret-id/*" {
  capabilities = ["deny"]
}

path "+/+/auth/+/role/+/role-id" {
  capabilities = ["deny"]
}

path "+/+/auth/+/role/+/secret-id" {
  capabilities = ["deny"]
}

path "+/+/auth/+/role/+/secret-id/*" {
  capabilities = ["deny"]
}

path "+/+/+/auth/+/role/+/role-id" {
  capabilities = ["deny"]
}

path "+/+/+/auth/+/role/+/secret-id" {
  capabilities = ["deny"]
}

path "+/+/+/auth/+/role/+/secret-id/*" {
  capabilities = ["deny"]
}

# ── Explicit deny: KV data and metadata, any mount name, depths 0..3 ─────
# Matches <mount>/data/*, <mount>/metadata/*, and the same under a namespace.

path "+/data/*" {
  capabilities = ["deny"]
}

path "+/metadata/*" {
  capabilities = ["deny"]
}

path "+/+/data/*" {
  capabilities = ["deny"]
}

path "+/+/metadata/*" {
  capabilities = ["deny"]
}

path "+/+/+/data/*" {
  capabilities = ["deny"]
}

path "+/+/+/metadata/*" {
  capabilities = ["deny"]
}

path "+/+/+/+/data/*" {
  capabilities = ["deny"]
}

path "+/+/+/+/metadata/*" {
  capabilities = ["deny"]
}
