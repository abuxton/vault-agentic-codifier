variable "vault_address" {
  description = "Vault API address."
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Root or admin Vault token. Set via VAULT_TOKEN env var; do not hardcode."
  type        = string
  sensitive   = true
  default     = null # resolved from TF_VAR_vault_token or VAULT_TOKEN
}

variable "org_namespace" {
  description = "Top-level organisational namespace (HVD 'admin' layer)."
  type        = string
  default     = "admin"
}
