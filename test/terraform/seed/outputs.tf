output "platform_kv_mount_path" {
  description = "Platform KV v2 mount path."
  value       = vault_mount.platform_secret.path
}

output "billing_kv_mount_path" {
  description = "Billing KV v2 mount path."
  value       = vault_mount.billing_secret.path
}

output "identity_kv_mount_path" {
  description = "Identity KV v2 mount path."
  value       = vault_mount.identity_secret.path
}

output "billing_approle_role_id" {
  description = "RoleID for the billing-service AppRole."
  value       = vault_approle_auth_backend_role.billing_app.role_id
}

output "identity_approle_role_id" {
  description = "RoleID for the identity-service AppRole."
  value       = vault_approle_auth_backend_role.identity_app.role_id
}
