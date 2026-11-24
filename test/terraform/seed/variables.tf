variable "vault_address" {
  description = "Vault API address."
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Root or admin Vault token."
  type        = string
  sensitive   = true
  default     = null
}

variable "org_namespace" {
  description = "Top-level organisational namespace."
  type        = string
  default     = "admin"
}
