terraform {
  required_version = ">= 1.9"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4"
    }
  }
}

# Two provider aliases:
#   default  → root namespace (for reading admin namespace path)
#   admin    → admin/org namespace (all namespace work happens here)

provider "vault" {
  address          = var.vault_address
  token            = var.vault_token
  skip_child_token = true
}

provider "vault" {
  alias            = "admin"
  address          = var.vault_address
  token            = var.vault_token
  namespace        = var.org_namespace
  skip_child_token = true
}
