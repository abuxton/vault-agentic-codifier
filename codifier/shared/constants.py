"""
Shared constants for the vault-brownfield-codifier.

Capability slugs, layer assignments, resource ownership, and sensitive-field
lists are defined here so every other module imports from one place.

Doc ref: https://developer.hashicorp.com/vault/docs
"""

# ---------------------------------------------------------------------------
# Implementation metadata
# ---------------------------------------------------------------------------
IMPLEMENTATION_LANGUAGE = "Python"
PYTHON_MIN_VERSION = (3, 9)
DEPENDENCY_MANAGER = "stdlib-only (no third-party packages required)"
TOOL_VERSIONS = {
    "python": ">=3.9",
    "terraform": ">=1.9",
    "vault_cli": ">=1.17",
    "vault_provider": "~>4 (harness pin: 4.8.0)",
    "jq": "any recent",
}

# ---------------------------------------------------------------------------
# Capability slugs (from specs.md)
# ---------------------------------------------------------------------------
CAP_ROOT_CONFIG = "root-config"       # CAP-001
CAP_ADMIN_CONFIG = "admin-config"     # CAP-002
CAP_AUTH_MOUNTS = "auth-mounts"       # CAP-003
CAP_SECRETS_ENGINES = "secrets-engines"  # CAP-004
CAP_NAMESPACES = "namespaces"         # CAP-005
CAP_POLICIES = "policies"             # CAP-006
CAP_TEAMS = "teams"                   # CAP-007

# Execution order from specs.md "Dependency order" section
CAPABILITY_ORDER = [
    CAP_NAMESPACES,
    CAP_ROOT_CONFIG,
    CAP_POLICIES,
    CAP_AUTH_MOUNTS,
    CAP_SECRETS_ENGINES,
    CAP_TEAMS,
    CAP_ADMIN_CONFIG,
]

# ---------------------------------------------------------------------------
# State-layer mapping
#
# Design.md §7 uses three Terraform state layers (admin/, namespaces/, seed/).
# Specs.md names per-capability output directories (root/, admin/, teams/ etc.)
# This table is the TASK-001 reconciliation: specs dirs live *inside* a layer.
#
# Resolution rule (specs.md is authoritative for acceptance criteria):
#   - The 3-layer structure is the Terraform state boundary.
#   - Per-capability output files land in a subdirectory inside that layer.
#   - Layer is determined by the namespace scope of the resources produced.
# ---------------------------------------------------------------------------

# Mapping: capability slug → Terraform state layer
CAPABILITY_TO_LAYER = {
    # CAP-001: audit devices, quotas — root namespace only → admin/ layer
    CAP_ROOT_CONFIG: "admin",

    # CAP-002: admin ns composition (references others) → admin/ layer
    CAP_ADMIN_CONFIG: "admin",

    # CAP-003: auth backends span all namespaces.
    #   root + admin mounts → admin/ layer
    #   tenant (admin/platform etc.) mounts → seed/ layer
    # NOTE: the generator distributes files; this entry is the *default* layer.
    CAP_AUTH_MOUNTS: "seed",   # tenant mounts; root/admin handled by admin/

    # CAP-004: secrets engines are all in tenant namespaces → seed/ layer
    CAP_SECRETS_ENGINES: "seed",

    # CAP-005: namespaces
    #   vault_namespace "admin" → admin/ layer
    #   tenant vault_namespace resources → namespaces/ layer
    CAP_NAMESPACES: "namespaces",  # tenant namespaces; admin ns in admin/

    # CAP-006: policies are in every namespace layer
    #   root + admin policies → admin/ layer
    #   tenant policies → seed/ layer
    CAP_POLICIES: "admin",   # default; generator distributes by namespace

    # CAP-007: identity resources live in admin namespace → namespaces/ layer
    CAP_TEAMS: "namespaces",
}

# Full layout note — per capability, generated files and their state layer.
# This is the authoritative reconciliation required by TASK-001 AC1.
LAYOUT_NOTE = {
    CAP_ROOT_CONFIG: {
        "layer": "admin",
        "files": [
            "admin/audit.tf",
            "admin/quotas.tf",
            "admin/sys_config.tf",
            "admin/replication.tf",    # only when replication is enabled
            "admin/README.md",
            "admin/imports.tf",
        ],
        "note": "root/ in specs.md maps to admin/ state layer",
    },
    CAP_ADMIN_CONFIG: {
        "layer": "admin",
        "files": [
            "admin/main.tf",
            "admin/human_auth.tf",     # only when OIDC/LDAP detected
            "admin/variables.tf",
            "admin/outputs.tf",
            "admin/README.md",
            "admin/imports.tf",
        ],
        "note": "composition layer; references resources from other capabilities",
    },
    CAP_AUTH_MOUNTS: {
        "layer": "admin (root+admin mounts) / seed (tenant mounts)",
        "files": [
            "admin/auth_approle.tf",               # root approle
            "namespaces/admin/auth_approle.tf",    # admin approle
            "seed/<ns>/auth_approle.tf",           # one per tenant namespace
            "auth-mounts/coverage.md",
            "imports.tf",                           # per layer
        ],
        "note": (
            "root and admin namespace mounts go in admin/ layer; "
            "tenant namespace mounts go in seed/ layer"
        ),
    },
    CAP_SECRETS_ENGINES: {
        "layer": "seed",
        "files": [
            "seed/<ns>/mounts.tf",                 # one per tenant namespace
            "secrets-engines/coverage.md",
            "imports.tf",
        ],
        "note": "all secrets-engine mounts are in tenant namespaces → seed/ layer",
    },
    CAP_NAMESPACES: {
        "layer": "admin (admin ns) / namespaces (tenants)",
        "files": [
            "admin/namespace_admin.tf",            # vault_namespace "admin"
            "namespaces/namespaces.tf",            # tenant vault_namespace resources
            "namespaces/hierarchy.md",
            "namespaces/namespaces.auto.tfvars.json",
            "imports.tf",
        ],
        "note": (
            "vault_namespace for admin itself goes in admin/ layer; "
            "child namespaces go in namespaces/ layer"
        ),
    },
    CAP_POLICIES: {
        "layer": "admin (root+admin) / seed (tenant)",
        "files": [
            "admin/policies/<name>.hcl",           # root and admin policies
            "admin/policies.tf",
            "seed/<ns>/policies.tf",               # one per tenant namespace
            "seed/<ns>/policies/<name>.hcl",
            "policies/correlation.md",
            "policies/correlation.json",
            "policies/coverage.md",
            "imports.tf",
        ],
        "note": (
            "root and admin namespace policies go in admin/ layer; "
            "tenant policies go in seed/ layer"
        ),
    },
    CAP_TEAMS: {
        "layer": "namespaces",
        "files": [
            "namespaces/identity.tf",              # groups, entities
            "namespaces/identity_aliases.tf",      # only when aliases exist
            "teams/teams.md",
            "teams/teams.json",
            "imports.tf",
        ],
        "note": "identity resources live in admin namespace → namespaces/ layer",
    },
}

# ---------------------------------------------------------------------------
# Resource ownership (from specs.md "Resource ownership" table)
# A resource type must only appear in files owned by its capability.
# ---------------------------------------------------------------------------
RESOURCE_OWNERSHIP = {
    "vault_namespace": CAP_NAMESPACES,
    "vault_policy": CAP_POLICIES,
    "vault_egp_policy": CAP_POLICIES,
    "vault_rgp_policy": CAP_POLICIES,
    "vault_auth_backend": CAP_AUTH_MOUNTS,
    "vault_approle_auth_backend_role": CAP_AUTH_MOUNTS,
    "vault_jwt_auth_backend": CAP_AUTH_MOUNTS,       # except admin top-level OIDC → CAP_ADMIN_CONFIG
    "vault_jwt_auth_backend_role": CAP_AUTH_MOUNTS,
    "vault_ldap_auth_backend": CAP_AUTH_MOUNTS,      # except admin top-level LDAP → CAP_ADMIN_CONFIG
    "vault_ldap_auth_backend_group": CAP_AUTH_MOUNTS,
    "vault_ldap_auth_backend_user": CAP_AUTH_MOUNTS,
    "vault_kubernetes_auth_backend_config": CAP_AUTH_MOUNTS,
    "vault_kubernetes_auth_backend_role": CAP_AUTH_MOUNTS,
    "vault_aws_auth_backend_client": CAP_AUTH_MOUNTS,
    "vault_aws_auth_backend_role": CAP_AUTH_MOUNTS,
    "vault_cert_auth_backend_role": CAP_AUTH_MOUNTS,
    "vault_mount": CAP_SECRETS_ENGINES,
    "vault_kv_secret_backend_v2": CAP_SECRETS_ENGINES,
    "vault_pki_secret_backend_role": CAP_SECRETS_ENGINES,
    "vault_pki_secret_backend_config_urls": CAP_SECRETS_ENGINES,
    "vault_database_secret_backend_connection": CAP_SECRETS_ENGINES,
    "vault_database_secret_backend_role": CAP_SECRETS_ENGINES,
    "vault_aws_secret_backend": CAP_SECRETS_ENGINES,
    "vault_aws_secret_backend_role": CAP_SECRETS_ENGINES,
    "vault_transit_secret_backend_key": CAP_SECRETS_ENGINES,
    "vault_ssh_secret_backend_role": CAP_SECRETS_ENGINES,
    "vault_identity_entity": CAP_TEAMS,
    "vault_identity_entity_alias": CAP_TEAMS,
    "vault_identity_group": CAP_TEAMS,
    "vault_identity_group_alias": CAP_TEAMS,
    "vault_identity_group_member_entity_ids": CAP_TEAMS,
    "vault_identity_group_member_group_ids": CAP_TEAMS,
    "vault_identity_group_policies": CAP_TEAMS,
    "vault_audit": CAP_ROOT_CONFIG,
    "vault_quota_rate_limit": CAP_ROOT_CONFIG,
    "vault_quota_lease_count": CAP_ROOT_CONFIG,
}

# Resources that must NEVER be emitted (superseded or forbidden)
FORBIDDEN_RESOURCES = {
    # CAP-004 AC3: vault_kv_secret_v2 is forbidden.
    # design.md resource map listed it; specs.md is authoritative.
    "vault_kv_secret_v2": (
        "Forbidden by CAP-004 AC3. Never emit real secret data. "
        "Design.md resource map entry superseded by specs.md."
    ),
    "vault_kv_secret": "Forbidden by CAP-004 AC3.",
    "vault_generic_secret": "Forbidden by CAP-004 AC3.",
    # Ephemeral credentials must never be persisted
    "vault_approle_auth_backend_role_secret_id": (
        "Ephemeral credential. Would persist secret_id in state. Skip."
    ),
}

# ---------------------------------------------------------------------------
# Sensitive fields — values that must NEVER be written to disk
# The secret-scrubbing guard (TASK-004) uses this list.
# ---------------------------------------------------------------------------
SENSITIVE_FIELDS = frozenset({
    # Auth credentials
    "secret_id",
    "role_id",          # only when auto-generated; not when explicitly set
    "bindpass",
    "client_secret",
    "oidc_client_secret",
    # Token values
    "token",
    "root_token",
    "client_token",
    # Database and cloud credentials
    "password",
    "connection_url",   # may contain password
    "secret_key",
    "access_key",       # only when it is a secret, not an ID
    "credentials",
    "private_key",
    # Vault licence
    "license",
    "license_text",
    # KV secret data (never read; guard as belt-and-suspenders)
    "data",             # KV v2 data_json contents
})

# Field name prefixes that are always sensitive (guard checks startswith)
SENSITIVE_FIELD_PREFIXES = ("secret_", "password_", "token_value")

# Strings that indicate a SYNTHETIC placeholder — still must not reach disk
SYNTHETIC_PREFIX = "SYNTHETIC-"

# ---------------------------------------------------------------------------
# Builtin Vault objects — never codify these
# ---------------------------------------------------------------------------
BUILTIN_POLICIES = frozenset({"default", "root"})
BUILTIN_AUTH_MOUNTS = frozenset({"token/"})
BUILTIN_SECRET_MOUNTS = frozenset({"sys/", "identity/", "cubbyhole/"})

# ---------------------------------------------------------------------------
# Output directory
# ---------------------------------------------------------------------------
OUTPUT_DIR = "discovered_terraform"
RAW_PAYLOAD_DIR = f"{OUTPUT_DIR}/raw"
TERRAFORM_OUTPUT_DIR = f"{OUTPUT_DIR}/terraform"
RUN_REPORT_FILE = f"{OUTPUT_DIR}/run-report.json"

# State layer subdirectories inside TERRAFORM_OUTPUT_DIR
LAYER_ADMIN = "admin"
LAYER_NAMESPACES = "namespaces"
LAYER_SEED = "seed"
ALL_LAYERS = (LAYER_ADMIN, LAYER_NAMESPACES, LAYER_SEED)
