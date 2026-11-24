# Namespace hierarchy

```mermaid
graph TD
  admin["admin (depth 1)"]
  admin_app_billing["admin/app-billing (depth 2)"]
  admin_app_identity["admin/app-identity (depth 2)"]
  admin_platform["admin/platform (depth 2)"]
  admin --> admin_app_billing
  admin --> admin_app_identity
  admin --> admin_platform
```

| Full path | Parent | Id | custom_metadata | Depth |
|---|---|---|---|---|
| `admin` | root | `qOOjV` | none | 1 |
| `admin/app-billing` | `admin` | `FJ3lt` | description = Billing application team namespace | 2 |
| `admin/app-identity` | `admin` | `x7ROq` | description = Identity service team namespace | 2 |
| `admin/platform` | `admin` | `CaNRp` | description = Platform engineering team namespace | 2 |
