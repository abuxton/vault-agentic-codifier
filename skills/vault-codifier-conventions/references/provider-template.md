## 7. Provider template

`versions.tf` per layer:

```hcl
terraform {
  required_version = ">= 1.9"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4"
    }
  }
}

variable "vault_address" {
  description = "Vault cluster address. Falls back to VAULT_ADDR."
  type        = string
  default     = null
}

variable "vault_token" {
  description = "Vault token for this layer. Falls back to VAULT_TOKEN."
  type        = string
  sensitive   = true
  default     = null
}
```

`providers.tf` per layer: one block per namespace alias, each with
`skip_child_token = true` (layers `admin` and `namespaces`; layer `seed` leaves
it unset), `address = var.vault_address`, `token = var.vault_token`. Credentials
are never literals.
