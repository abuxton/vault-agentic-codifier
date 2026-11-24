output "tenant_namespace_paths" {
  description = "Map of tenant name → full namespace path."
  value = {
    for k, ns in vault_namespace.tenant : k => "${var.org_namespace}/${ns.path}"
  }
}

output "tenant_admin_group_ids" {
  description = "Map of tenant name → admin identity group ID."
  value = {
    for k, g in vault_identity_group.tenant_admin : k => g.id
  }
}

output "team_group_ids" {
  description = "Map of tenant-team key → identity group ID."
  value = {
    for k, g in vault_identity_group.team : k => g.id
  }
}

output "team_entity_ids" {
  description = "Map of tenant-team key → synthetic identity entity ID."
  value = {
    for k, e in vault_identity_entity.team_member : k => e.id
  }
}
