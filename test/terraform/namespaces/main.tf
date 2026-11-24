# ──────────────────────────────────────────────────────────────────────────────
# Admin-namespace policies (applied inside the org namespace via "admin" provider)
# Source: nhsy-hcp/terraform-vault-onboarding policies/vault_admin_policy.hcl
# Ref: https://developer.hashicorp.com/validated-designs/vault/administration-guide/authentication-for-people
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_policy" "admin" {
  provider = vault.admin
  name     = "admin"
  policy   = file("${path.module}/policies/admin.hcl")
}

resource "vault_policy" "namespace_admin" {
  provider = vault.admin
  name     = "namespace-admin"
  policy   = file("${path.module}/policies/namespace_admin.hcl")
}

# ──────────────────────────────────────────────────────────────────────────────
# AppRole auth in the admin namespace (for Terraform workspace authentication)
# Pattern: tfo-apj-demos/terraform-vault-tfo-apj-demo-admin — 12-auth_approle.tf
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_auth_backend" "approle_admin" {
  provider    = vault.admin
  type        = "approle"
  path        = "approle"
  description = "AppRole auth — admin namespace (Terraform workspace auth)"
}

resource "vault_approle_auth_backend_role" "namespace_provisioner" {
  provider           = vault.admin
  backend            = vault_auth_backend.approle_admin.path
  role_name          = "namespace-provisioner"
  token_policies     = [vault_policy.namespace_admin.name]
  token_ttl          = 3600
  token_max_ttl      = 14400
  secret_id_num_uses = 1
  secret_id_ttl      = 900 # 15 minutes in seconds
}

# ──────────────────────────────────────────────────────────────────────────────
# Tenant namespaces (HVD: admin → tenant → app/env hierarchy)
# Pattern: nhsy-hcp/terraform-vault-onboarding — namespace-vending/tn001.tf
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_namespace" "tenant" {
  provider = vault.admin
  for_each = var.tenants
  path     = each.key
  custom_metadata = {
    description = each.value.description
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Per-tenant admin identity groups
# Each tenant gets a dedicated admin group so tenant admins can manage
# their own sub-namespace without root or org-admin privileges.
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_identity_group" "tenant_admin" {
  provider = vault.admin
  for_each = var.tenants
  name     = "vault-${each.key}-admin"
  type     = "internal"
  policies = [vault_policy.namespace_admin.name]
  metadata = {
    tenant = each.key
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Synthetic identity entities (stand-in for OIDC-federated users)
# In production these would be created automatically on first OIDC login.
# Here we create them explicitly to have a complete brownfield dataset.
# Pattern: tfo-apj-demos — 20-identity_entities.tf
# ──────────────────────────────────────────────────────────────────────────────
locals {
  # Flatten tenants × teams → list of {tenant, team} maps
  team_members = flatten([
    for tenant_key, tenant_val in var.tenants : [
      for team in tenant_val.teams : {
        key    = "${tenant_key}-${team}"
        tenant = tenant_key
        team   = team
        name   = "synthetic-user-${tenant_key}-${team}"
      }
    ]
  ])

  team_members_map = { for m in local.team_members : m.key => m }
}

resource "vault_identity_entity" "team_member" {
  provider = vault.admin
  for_each = local.team_members_map
  name     = each.value.name
  metadata = {
    tenant = each.value.tenant
    team   = each.value.team
    type   = "synthetic"
  }
}

# Team-scoped internal groups — one per tenant × team combination
resource "vault_identity_group" "team" {
  provider          = vault.admin
  for_each          = local.team_members_map
  name              = "vault-${each.value.tenant}-${each.value.team}"
  type              = "internal"
  policies          = [] # policies applied at the namespace layer
  member_entity_ids = [vault_identity_entity.team_member[each.key].id]
  metadata = {
    tenant = each.value.tenant
    team   = each.value.team
  }
}
