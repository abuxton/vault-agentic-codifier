variable "vault_address" {
  description = "Vault API address."
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Root or admin Vault token. Set via VAULT_TOKEN env var; do not hardcode."
  type        = string
  sensitive   = true
  default     = null
}

variable "org_namespace" {
  description = "Top-level organisational namespace (must exist — created by admin layer)."
  type        = string
  default     = "admin"
}

variable "tenants" {
  description = "Map of tenant namespaces to create under the org namespace."
  type = map(object({
    description = string
    teams       = list(string)
  }))
  default = {
    "platform" = {
      description = "Platform engineering team namespace"
      teams       = ["sre", "devops"]
    }
    "app-billing" = {
      description = "Billing application team namespace"
      teams       = ["developers", "owners"]
    }
    "app-identity" = {
      description = "Identity service team namespace"
      teams       = ["developers", "owners"]
    }
  }
}
