# Policy correlation matrix

Which auth roles, identity groups and entities reference each policy. Generated from discovery payloads.

## root

| Policy | Auth roles | Groups | Entities |
|---|---|---|---|
| `exporter` | `approle/exporter` | - | `exporter-agent` |
| `operator` | `approle/terraform-admin` | - | - |

## admin

| Policy | Auth roles | Groups | Entities |
|---|---|---|---|
| `admin` | - | - | - |
| `namespace-admin` | `approle/namespace-provisioner` | `vault-app-billing-admin`, `vault-app-identity-admin`, `vault-platform-admin` | - |

## admin/app-billing

| Policy | Auth roles | Groups | Entities |
|---|---|---|---|
| `billing-developers-read` | `approle/billing-service` | - | - |
| `billing-owners-write` | - | - | - |

## admin/app-identity

| Policy | Auth roles | Groups | Entities |
|---|---|---|---|
| `identity-developers-read` | `approle/identity-service` | - | - |
| `identity-owners-write` | - | - | - |

## admin/platform

| Policy | Auth roles | Groups | Entities |
|---|---|---|---|
| `platform-devops-write` | `approle/platform-ci` | - | - |
| `platform-sre-read` | - | - | - |

