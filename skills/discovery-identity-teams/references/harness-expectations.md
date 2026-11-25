## Harness expectations

| Namespace | Groups | Entities | Group aliases | Entity aliases |
|---|---|---|---|---|
| root | 0 | 1 (`exporter-agent`) | 0 | 1 (approle, keyed on `role_id`) |
| `admin` | 9 | 6 | 0 | 0 |
| `admin/platform`, `admin/app-billing`, `admin/app-identity` | 0 | 0 | 0 | 0 (no file written) |

The root entity and alias exist once `vault-exporter-setup` has run. The alias `name` is the AppRole
`role_id` (a UUID that identifies the role, not a credential), so it is kept in the raw payload;
codification must emit it as a variable or `data` reference, not a literal.

Validated notes (harness, Vault 2.2.2+ent):
- `member_group_ids` and `metadata` come back as `null` when empty; normalise to `[]` / `{}` so downstream
  `length` checks do not fail.
- The group/entity `id` is kept in the raw payload (needed by `imports.tf`) but arrays of member names are
  resolved from it, so a codification skill never needs to print a UUID outside `imports.tf`.
- The exporter reads `identity/*` at root and in `admin` with no 403s, including entity and alias reads.

---
