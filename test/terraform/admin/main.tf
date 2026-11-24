# ──────────────────────────────────────────────────────────────────────────────
# Audit device
# Enable a file audit device so the cluster has an audit trail.
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_audit" "file" {
  type = "file"
  options = {
    file_path = "/vault/logs/audit.log"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Admin / org-level namespace (HVD "admin" layer)
# Root namespace is kept only for cluster operators; all other work lives here.
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_namespace" "admin" {
  path = var.org_namespace
}

# ──────────────────────────────────────────────────────────────────────────────
# Root-namespace policies
# Applied in the root namespace so cluster operators can administer the cluster.
# ──────────────────────────────────────────────────────────────────────────────

# Operator policy — full access, used by root-namespace admins only.
resource "vault_policy" "operator" {
  name   = "operator"
  policy = file("${path.module}/policies/operator.hcl")
}

# ──────────────────────────────────────────────────────────────────────────────
# Root-namespace AppRole auth (for Terraform / CI pipeline authentication)
# A minimal AppRole used by the seed Terraform itself to avoid hardcoding tokens.
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_auth_backend" "approle_root" {
  type        = "approle"
  path        = "approle"
  description = "AppRole auth — root namespace (CI / Terraform pipelines)"
}

resource "vault_approle_auth_backend_role" "terraform_admin" {
  backend        = vault_auth_backend.approle_root.path
  role_name      = "terraform-admin"
  token_policies = [vault_policy.operator.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
  # Single-use SecretIDs reduce exposure window
  secret_id_num_uses = 1
  secret_id_ttl      = 900 # 15 minutes in seconds
}

# ──────────────────────────────────────────────────────────────────────────────
# Rate-limit quota (global — good operational practice)
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_quota_rate_limit" "global" {
  name           = "global-rate-limit"
  path           = ""
  rate           = 1000
  interval       = 60
  block_interval = 60
}
