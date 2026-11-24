output "admin_namespace_path" {
  description = "Path of the admin/org namespace."
  value       = vault_namespace.admin.path
}

output "approle_root_accessor" {
  description = "Accessor of the root AppRole auth mount."
  value       = vault_auth_backend.approle_root.accessor
}

output "terraform_admin_role_id" {
  description = "RoleID for the terraform-admin AppRole role."
  value       = vault_approle_auth_backend_role.terraform_admin.role_id
}
