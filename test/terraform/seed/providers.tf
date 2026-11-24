terraform {
  required_version = ">= 1.9"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4"
    }
  }
}

# Provider aliases — one per tenant namespace (scoped via namespace attribute).
# In production each tenant workspace would have its own provider configuration.
# Here we stack them all to seed a single test instance.

provider "vault" {
  alias            = "platform"
  address          = var.vault_address
  token            = var.vault_token
  namespace        = "${var.org_namespace}/platform"
  skip_child_token = true
}

provider "vault" {
  alias            = "app_billing"
  address          = var.vault_address
  token            = var.vault_token
  namespace        = "${var.org_namespace}/app-billing"
  skip_child_token = true
}

provider "vault" {
  alias            = "app_identity"
  address          = var.vault_address
  token            = var.vault_token
  namespace        = "${var.org_namespace}/app-identity"
  skip_child_token = true
}
