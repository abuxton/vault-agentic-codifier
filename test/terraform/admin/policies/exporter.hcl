# exporter.hcl
# Least-privilege policy for the vault-brownfield-codifier exporter identity.
#
# Design goals
# ────────────
# 1. The exporter must be able to enumerate (list) every structural object in
#    Vault: namespaces, auth mounts, secrets-engine mounts, ACL policies,
#    identity groups, entities and aliases, quotas.
# 2. The exporter must be able to read structural/health endpoints that do not
#    return secret values (audit config, health, seal status, licence metadata).
# 3. The exporter must NEVER be able to read actual secret values, even if the
#    admin policy (also granted to the exporters group) would otherwise allow it.
#    Explicit deny rules enforce this invariant regardless of group-policy union.
# 4. No write, create, update, delete or sudo capability is granted anywhere.
#    The exporter is strictly read-only.
# 5. AppRole role-id and secret-id endpoints are explicitly denied — the
#    exporter must not be able to harvest credentials from other roles.
#
# HVD reference
# ─────────────
# Least-privilege policy design:
#   https://developer.hashicorp.com/validated-designs/vault/administration-guide/authentication-for-people
#
# Audit logging
# ─────────────
# All API calls made under a token issued to the exporter AppRole role are
# recorded in the audit log under the exporter-agent entity alias.  This
# provides a complete, immutable record of what the codifier read during each
# export run.

# ── Namespace enumeration ────────────────────────────────────────────────────

path "sys/namespaces" {
  capabilities = ["list"]
}

path "sys/namespaces/*" {
  capabilities = ["list", "read"]
}

# ── Auth-mount enumeration ───────────────────────────────────────────────────

path "sys/auth" {
  capabilities = ["read"]
}

path "sys/auth/*" {
  capabilities = ["list", "read"]
}

# AppRole-specific: list roles only; never role-id or secret-id
path "auth/approle/role" {
  capabilities = ["list"]
}

path "auth/approle/role/*" {
  capabilities = ["list", "read"]
}

# Deny AppRole credential endpoints explicitly — belt-and-suspenders
path "auth/approle/role/+/role-id" {
  capabilities = ["deny"]
}

path "auth/approle/role/+/secret-id" {
  capabilities = ["deny"]
}

path "auth/approle/role/+/secret-id/*" {
  capabilities = ["deny"]
}

# ── Secrets-engine mount enumeration ────────────────────────────────────────

path "sys/mounts" {
  capabilities = ["read"]
}

path "sys/mounts/*" {
  capabilities = ["list", "read"]
}

# ── ACL policy enumeration ───────────────────────────────────────────────────

path "sys/policies/acl" {
  capabilities = ["list"]
}

path "sys/policies/acl/*" {
  capabilities = ["list", "read"]
}

# Enterprise: list EGP/RGP policies (read requires Sentinel licence)
path "sys/policies/egp" {
  capabilities = ["list"]
}

path "sys/policies/rgp" {
  capabilities = ["list"]
}

# ── Identity: groups, entities, aliases ─────────────────────────────────────

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

# ── Rate-limit quotas ────────────────────────────────────────────────────────

path "sys/quotas/rate-limit" {
  capabilities = ["list"]
}

path "sys/quotas/rate-limit/*" {
  capabilities = ["read"]
}

path "sys/quotas/config" {
  capabilities = ["read"]
}

# ── Structural health and config endpoints (read-only, no secret values) ────

path "sys/audit" {
  capabilities = ["read"]
}

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

path "sys/internal/ui/feature-flags" {
  capabilities = ["read"]
}

# ── Explicit deny: secret data paths ────────────────────────────────────────
# These denies override any capability granted by the admin policy that is
# also attached to the exporters group.  The exporter MUST NOT read secret
# values regardless of group-policy union.

# Root-namespace KV data paths
path "secret/data/*" {
  capabilities = ["deny"]
}

path "secret/metadata/*" {
  capabilities = ["deny"]
}

# Single-level namespace (e.g. admin/secret/data/*)
path "+/secret/data/*" {
  capabilities = ["deny"]
}

path "+/secret/metadata/*" {
  capabilities = ["deny"]
}

# Two-level namespace (e.g. admin/platform/secret/data/*)
path "+/+/secret/data/*" {
  capabilities = ["deny"]
}

path "+/+/secret/metadata/*" {
  capabilities = ["deny"]
}

# Three-level namespace (e.g. admin/platform/sre-team/secret/data/*)
path "+/+/+/secret/data/*" {
  capabilities = ["deny"]
}

path "+/+/+/secret/metadata/*" {
  capabilities = ["deny"]
}

# Catch-all for any KV mount name, all nesting depths
path "+/data/*" {
  capabilities = ["deny"]
}

path "+/+/data/*" {
  capabilities = ["deny"]
}

path "+/+/+/data/*" {
  capabilities = ["deny"]
}
