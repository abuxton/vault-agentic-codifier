# Test harness — Prerequisites

This directory contains everything needed to run a local Vault Enterprise
instance and seed it with synthetic brownfield data for use by the
`terraform-vault-vault-codifier` tool.

---

## ⚠ Licence requirement (NEVER commit)

A valid **Vault Enterprise licence** is required to start the instance.

| Item | Detail |
|------|--------|
| **Where to get it** | <https://www.hashicorp.com/products/vault/trial> or your HashiCorp account portal |
| **Where to place it** | `/tmp/vault.hclic` on the host running Docker |
| **Why `/tmp/`?** | It is bind-mounted read-only into the container at runtime and is **outside** this repository tree |
| **What happens if missing** | `make start` / `make up` will fail with a clear error before Docker starts |

> **The licence file must NEVER be committed to this repository.**
> `test/.gitignore` explicitly excludes `*.hclic` and `vault.hclic`.
> CI pre-commit hooks and secret-scanning should enforce this independently.

---

## Software requirements

| Tool | Minimum version | Install |
|------|----------------|---------|
| Docker + Docker Compose | Docker ≥ 25, Compose ≥ 2.24 | <https://docs.docker.com/get-docker/> |
| Vault CLI | ≥ 1.17 | <https://releases.hashicorp.com/vault/> |
| Terraform | ≥ 1.9 | <https://releases.hashicorp.com/terraform/> |
| `jq` | any | `brew install jq` / `apt install jq` |
| `make` | any | pre-installed on macOS/Linux |

---

## Quick start

```bash
# 1. Place your licence (once per machine)
cp /path/to/your/vault.hclic /tmp/vault.hclic

# 2. From the test/ directory
cd test/

# 3. Start Vault, initialise, unseal, login, and seed all synthetic data
make all

# 4. Source the generated credentials file into your shell
source .vault-env

# 5. Verify
vault status
vault secrets list
```

---

## Makefile targets

Run `make help` from `test/` for the full list. Key targets:

| Target | Description |
|--------|-------------|
| `make all` | Full workflow: start → init → unseal → seed |
| `make up` | Start container, init, unseal, write `.vault-env` |
| `make start` | Start the Docker container only |
| `make vault-init` | Initialise Vault (writes `.vault-init-state.json`) |
| `make vault-unseal` | Unseal using stored key |
| `make vault-login` | Write root token to `.vault-env` |
| `make seed` | Apply all Terraform layers (admin → namespaces → seed) |
| `make seed-destroy` | Destroy all Terraform seed data |
| `make fmt` | Format all Terraform |
| `make validate` | Validate all Terraform |
| `make stop` | Stop container (data persisted) |
| `make destroy` | Remove container + volumes (destructive) |
| `make clean` | Full clean: seed-destroy + destroy |
| `make reset` | Full teardown then fresh `make all` |

---

## Directory structure

```
test/
├── Makefile                      # All lifecycle targets
├── docker-compose.yml            # Vault Enterprise container definition
├── PREREQUISITES.md              # This file
├── .gitignore                    # Excludes *.hclic, state, .terraform/, tfstate
├── vault/
│   └── config.hcl                # Vault server config (Raft, Enterprise licence path)
└── terraform/
    ├── admin/                    # Layer 1: root-namespace config (audit, namespace, AppRole)
    │   ├── providers.tf
    │   ├── variables.tf
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── policies/
    │       └── operator.hcl
    ├── namespaces/               # Layer 2: org-namespace config (tenants, identity, policies)
    │   ├── providers.tf
    │   ├── variables.tf
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── policies/
    │       ├── admin.hcl
    │       └── namespace_admin.hcl
    └── seed/                     # Layer 3: per-tenant secrets engines, AppRoles, KV data
        ├── providers.tf
        ├── variables.tf
        ├── main.tf
        └── outputs.tf
```

---

## Synthetic data inventory

All secret **values** are clearly marked `SYNTHETIC-*-REPLACE-IN-PRODUCTION`.
They are safe to commit and are never real credentials.

| Namespace | Auth mounts | Secrets engine | Key paths |
|-----------|-------------|----------------|-----------|
| `admin/platform` | `approle` (platform-ci) | `secret` (KV v2) | `platform/sre/config`, `platform/devops/ci-cd` |
| `admin/app-billing` | `approle` (billing-service) | `secret` (KV v2) | `billing-service/checkout`, `billing-service/payment-processor` |
| `admin/app-identity` | `approle` (identity-service) | `secret` (KV v2) | `identity-service/ldap`, `identity-service/mfa` |

Root namespace contains: audit device, `admin` namespace, `approle` auth (terraform-admin role), rate-limit quota, `operator` policy.

---

## Vault Enterprise image

Image: `hashicorp/vault-enterprise:2.2.2-ent`
Release page: <https://releases.hashicorp.com/vault/2.2.2+ent/>

The image is pulled automatically by `docker compose up`.
No binary download is needed.

---

## Security notes

- TLS is **disabled** in `vault/config.hcl` — intentional for local dev only.
  Production deployments must enable TLS.
- The root token is written to `.vault-init-state.json` and `.vault-env` — both are
  in `.gitignore`. Treat them as secrets on disk.
- After seeding, revoke the root token and authenticate via AppRole/OIDC per HVD guidance.
  See: `git@github.com:hashicorp/web-unified-docs.git`
  → `content/validated-designs/docs/docs/vault/administration-guide/authentication-for-people.mdx`
