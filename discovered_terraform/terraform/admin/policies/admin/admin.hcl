# admin.hcl
# Admin-namespace administrator — full access within the org namespace and below.
# Source: nhsy-hcp/terraform-vault-onboarding policies/vault_admin_policy.hcl
# Ref: git@github.com:hashicorp/web-unified-docs.git
#      content/validated-designs/docs/docs/vault/administration-guide/authentication-for-people.mdx

# List existing policies
path "sys/policies/acl" {
  capabilities = ["list"]
}

# Create and manage ACL policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage auth methods broadly
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create, update, and delete auth methods
path "sys/auth/*" {
  capabilities = ["create", "update", "delete", "sudo"]
}

# List auth methods
path "sys/auth" {
  capabilities = ["read"]
}

# Managing identity
path "identity/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow managing leases
path "sys/leases/*" {
  capabilities = ["read", "update", "list"]
}

# Manage namespaces
path "sys/namespaces" {
  capabilities = ["list", "read"]
}

path "sys/namespaces/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage secrets engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# List existing secrets engines
path "sys/mounts" {
  capabilities = ["read"]
}

# Configure License
path "sys/license" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Configure Vault UI
path "sys/config/ui" {
  capabilities = ["read", "update", "delete", "list"]
}
