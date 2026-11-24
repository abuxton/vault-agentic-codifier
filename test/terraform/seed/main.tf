# ──────────────────────────────────────────────────────────────────────────────
# PLATFORM namespace — SRE / DevOps tooling secrets
# Pattern: nhsy-hcp/terraform-vault-onboarding namespace-tn001/main.tf
# Ref: https://developer.hashicorp.com/validated-designs/vault/administration-guide/static-secrets-management
# ──────────────────────────────────────────────────────────────────────────────

# KV v2 — shared secrets engine (single mount, path-based separation per HVD)
resource "vault_mount" "platform_secret" {
  provider    = vault.platform
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "Platform KV v2 secrets engine"
}

# Team-scoped ACL policies
resource "vault_policy" "platform_sre_read" {
  provider = vault.platform
  name     = "platform-sre-read"
  policy   = <<-EOT
    path "secret/data/platform/sre/*" {
      capabilities = ["read", "list"]
    }
    path "secret/metadata/platform/sre/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_policy" "platform_devops_write" {
  provider = vault.platform
  name     = "platform-devops-write"
  policy   = <<-EOT
    path "secret/data/platform/devops/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "secret/metadata/platform/devops/*" {
      capabilities = ["read", "list", "update", "delete"]
    }
  EOT
}

# AppRole for a CI pipeline in platform namespace
resource "vault_auth_backend" "platform_approle" {
  provider    = vault.platform
  type        = "approle"
  path        = "approle"
  description = "AppRole auth — platform namespace"
}

resource "vault_approle_auth_backend_role" "platform_ci" {
  provider           = vault.platform
  backend            = vault_auth_backend.platform_approle.path
  role_name          = "platform-ci"
  token_policies     = [vault_policy.platform_devops_write.name]
  token_ttl          = 3600
  token_max_ttl      = 14400
  secret_id_num_uses = 1
  secret_id_ttl      = 1800 # 30 minutes in seconds
}

# Synthetic KV secrets — representative but NOT real credentials
resource "vault_kv_secret_v2" "platform_sre_config" {
  provider            = vault.platform
  mount               = vault_mount.platform_secret.path
  name                = "platform/sre/config"
  delete_all_versions = true
  data_json = jsonencode({
    alert_webhook_url   = "https://alertmanager.example.internal/webhook"
    pagerduty_service   = "SYNTHETIC-PD-SVC-001"
    grafana_api_key     = "SYNTHETIC-GRAFANA-KEY-REPLACE-IN-PRODUCTION"
    prometheus_endpoint = "http://prometheus.example.internal:9090"
  })
}

resource "vault_kv_secret_v2" "platform_devops_cicd" {
  provider            = vault.platform
  mount               = vault_mount.platform_secret.path
  name                = "platform/devops/ci-cd"
  delete_all_versions = true
  data_json = jsonencode({
    github_actions_token = "SYNTHETIC-GHA-TOKEN-REPLACE-IN-PRODUCTION"
    docker_registry_url  = "registry.example.internal:5000"
    docker_registry_user = "ci-service-account"
    docker_registry_pass = "SYNTHETIC-REGISTRY-PASS-REPLACE-IN-PRODUCTION"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# APP-BILLING namespace — billing service secrets
# ──────────────────────────────────────────────────────────────────────────────

resource "vault_mount" "billing_secret" {
  provider    = vault.app_billing
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "Billing app KV v2 secrets engine"
}

resource "vault_policy" "billing_dev_read" {
  provider = vault.app_billing
  name     = "billing-developers-read"
  policy   = <<-EOT
    path "secret/data/billing-service/*" {
      capabilities = ["read", "list"]
    }
    path "secret/metadata/billing-service/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_policy" "billing_owners_write" {
  provider = vault.app_billing
  name     = "billing-owners-write"
  policy   = <<-EOT
    path "secret/data/billing-service/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "secret/metadata/billing-service/*" {
      capabilities = ["read", "list", "update", "delete"]
    }
  EOT
}

resource "vault_auth_backend" "billing_approle" {
  provider    = vault.app_billing
  type        = "approle"
  path        = "approle"
  description = "AppRole auth — app-billing namespace"
}

resource "vault_approle_auth_backend_role" "billing_app" {
  provider           = vault.app_billing
  backend            = vault_auth_backend.billing_approle.path
  role_name          = "billing-service"
  token_policies     = [vault_policy.billing_dev_read.name]
  token_ttl          = 3600
  token_max_ttl      = 14400
  secret_id_num_uses = 1
  secret_id_ttl      = 900 # 15 minutes in seconds
}

resource "vault_kv_secret_v2" "billing_checkout" {
  provider            = vault.app_billing
  mount               = vault_mount.billing_secret.path
  name                = "billing-service/checkout"
  delete_all_versions = true
  data_json = jsonencode({
    stripe_api_key        = "SYNTHETIC-STRIPE-KEY-REPLACE-IN-PRODUCTION"
    stripe_webhook_secret = "SYNTHETIC-STRIPE-WH-REPLACE-IN-PRODUCTION"
    database_url          = "postgresql://billing_svc:SYNTHETIC-PASS@db.billing.internal:5432/billing"
  })
}

resource "vault_kv_secret_v2" "billing_payment_processor" {
  provider            = vault.app_billing
  mount               = vault_mount.billing_secret.path
  name                = "billing-service/payment-processor"
  delete_all_versions = true
  data_json = jsonencode({
    processor_endpoint = "https://payments.example.internal/v2"
    processor_api_key  = "SYNTHETIC-PAYMENT-KEY-REPLACE-IN-PRODUCTION"
    hmac_secret        = "SYNTHETIC-HMAC-SECRET-REPLACE-IN-PRODUCTION"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# APP-IDENTITY namespace — identity service secrets
# ──────────────────────────────────────────────────────────────────────────────

resource "vault_mount" "identity_secret" {
  provider    = vault.app_identity
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "Identity service KV v2 secrets engine"
}

resource "vault_policy" "identity_dev_read" {
  provider = vault.app_identity
  name     = "identity-developers-read"
  policy   = <<-EOT
    path "secret/data/identity-service/*" {
      capabilities = ["read", "list"]
    }
    path "secret/metadata/identity-service/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_policy" "identity_owners_write" {
  provider = vault.app_identity
  name     = "identity-owners-write"
  policy   = <<-EOT
    path "secret/data/identity-service/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "secret/metadata/identity-service/*" {
      capabilities = ["read", "list", "update", "delete"]
    }
  EOT
}

resource "vault_auth_backend" "identity_approle" {
  provider    = vault.app_identity
  type        = "approle"
  path        = "approle"
  description = "AppRole auth — app-identity namespace"
}

resource "vault_approle_auth_backend_role" "identity_app" {
  provider           = vault.app_identity
  backend            = vault_auth_backend.identity_approle.path
  role_name          = "identity-service"
  token_policies     = [vault_policy.identity_dev_read.name]
  token_ttl          = 3600
  token_max_ttl      = 14400
  secret_id_num_uses = 1
  secret_id_ttl      = 900 # 15 minutes in seconds
}

resource "vault_kv_secret_v2" "identity_ldap" {
  provider            = vault.app_identity
  mount               = vault_mount.identity_secret.path
  name                = "identity-service/ldap"
  delete_all_versions = true
  data_json = jsonencode({
    ldap_bind_dn       = "cn=vault,ou=service-accounts,dc=example,dc=com"
    ldap_bind_password = "SYNTHETIC-LDAP-PASS-REPLACE-IN-PRODUCTION"
    ldap_url           = "ldaps://ldap.example.internal:636"
  })
}

resource "vault_kv_secret_v2" "identity_mfa" {
  provider            = vault.app_identity
  mount               = vault_mount.identity_secret.path
  name                = "identity-service/mfa"
  delete_all_versions = true
  data_json = jsonencode({
    totp_issuer = "ExampleCorp"
    totp_period = "30"
    smtp_host   = "smtp.example.internal"
    smtp_port   = "587"
    smtp_user   = "noreply@example.internal"
    smtp_pass   = "SYNTHETIC-SMTP-PASS-REPLACE-IN-PRODUCTION"
  })
}
