# Sentinel policy coverage (EGP / RGP)

ACL policies discovered: 10

- EGP: synthetic-egp-platform-advisory, synthetic-egp-root-advisory
- RGP: synthetic-rgp-platform-soft, synthetic-rgp-root-soft

Emitted as `vault_egp_policy` and `vault_rgp_policy`; the Sentinel source is copied byte-for-byte to `policies/sentinel/<namespace>/<kind>-<name>.sentinel`.

| Namespace | EGP | RGP |
|---|---|---|
| root | 1 | 1 |
| admin | none | none |
| admin/app-billing | none | none |
| admin/app-identity | none | none |
| admin/platform | 1 | 1 |

| Policy | Namespace | Kind | Enforcement | Paths |
|---|---|---|---|---|
| `synthetic-egp-root-advisory` | root | EGP | advisory | `secret/*`, `auth/approle/*` |
| `synthetic-rgp-root-soft` | root | RGP | soft-mandatory | n/a |
| `synthetic-egp-platform-advisory` | admin/platform | EGP | advisory | `secret/*` |
| `synthetic-rgp-platform-soft` | admin/platform | RGP | soft-mandatory | n/a |
