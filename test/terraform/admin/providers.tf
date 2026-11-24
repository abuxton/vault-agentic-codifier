terraform {
  required_version = ">= 1.9"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4"
    }
  }
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
  # skip_child_token avoids creating a child token for each provider operation,
  # which is correct when seeding via a root/admin token.
  skip_child_token = true
}
