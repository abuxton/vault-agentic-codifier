# namespace_admin.hcl
# Namespace-scoped admin — manages resources within a single tenant namespace.
# Source: nhsy-hcp/terraform-vault-onboarding policies/tfc_namespace_admin_policy.hcl
# Ref: git@github.com:hashicorp/web-unified-docs.git
#      content/validated-designs/docs/docs/vault/administration-guide/vault-organizational-concepts.mdx

# Full access to secrets in this namespace
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage ACL policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies/acl" {
  capabilities = ["list"]
}

# Manage auth methods
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/auth/*" {
  capabilities = ["create", "update", "delete", "sudo"]
}

path "sys/auth" {
  capabilities = ["read"]
}

# Manage secrets engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/mounts" {
  capabilities = ["read"]
}

# Manage identity
path "identity/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage leases
path "sys/leases/*" {
  capabilities = ["read", "update", "list"]
}
