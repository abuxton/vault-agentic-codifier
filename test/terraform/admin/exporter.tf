# ──────────────────────────────────────────────────────────────────────────────
# Exporter identity (TASK-031)
# Read-only identity used by the discovery-* skills. See
# skills/vault-exporter-setup/SKILL.md.
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_policy" "exporter" {
  name   = "exporter"
  policy = file("${path.module}/policies/exporter.hcl")
}

resource "vault_identity_entity" "exporter_agent" {
  name     = "exporter-agent"
  policies = [vault_policy.exporter.name]

  metadata = {
    role       = "exporter"
    managed_by = "terraform"
  }
}

resource "vault_approle_auth_backend_role" "exporter" {
  backend            = vault_auth_backend.approle_root.path
  role_name          = "exporter"
  token_policies     = [vault_policy.exporter.name]
  token_ttl          = 3600
  token_max_ttl      = 14400
  token_num_uses     = 0
  secret_id_num_uses = 1
  secret_id_ttl      = 900
  bind_secret_id     = true
}

# AppRole entity aliases are keyed on the role ID, not the role name.
resource "vault_identity_entity_alias" "exporter_approle" {
  name           = vault_approle_auth_backend_role.exporter.role_id
  mount_accessor = vault_auth_backend.approle_root.accessor
  canonical_id   = vault_identity_entity.exporter_agent.id
}
