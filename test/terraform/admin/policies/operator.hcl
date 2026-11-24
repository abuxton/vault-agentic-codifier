# operator.hcl
# Full cluster access for root-namespace Vault operators.
# Source: HVD Vault Administration Guide — Authentication for People
# Ref: https://developer.hashicorp.com/validated-designs/vault/administration-guide/authentication-for-people

path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
