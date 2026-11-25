## 9. Acceptance Criteria Checklist

- [ ] **AC-1 (CAP-003 AC1)**: Discovers exactly 5 `approle` mounts (one per namespace: root, `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`). `token/` is skipped.
- [ ] **AC-2 (CAP-003 AC2)**: Discovers exactly 6 roles: `terraform-admin` and `exporter` (root), `namespace-provisioner` (`admin`), `platform-ci` (`admin/platform`), `billing-service` (`admin/app-billing`), `identity-service` (`admin/app-identity`). `exporter` is the discovery identity itself; it is present once `vault-exporter-setup` has run.
- [ ] **AC-3 (CAP-003 AC3)**: Roles capture `token_ttl = 3600`, `token_max_ttl = 14400`, `secret_id_num_uses = 1`, and correct `secret_id_ttl` (900s for root/admin/billing/identity, 1800s for platform-ci). The `exporter` role has `secret_id_ttl = 900`, `secret_id_num_uses = 1`.
- [ ] **AC-4 (CAP-003 AC5)**: Zero `role_id` or `secret_id` values appear in raw payloads.
- [ ] **AC-5 (CAP-003 AC6)**: `coverage` records all 5 mounts with `vault_auth_backend` and roles with `vault_approle_auth_backend_role`.
- [ ] **AC-6 (CAP-003 AC7)**: Unhandled auth types (e.g. `userpass`) are captured with mount metadata and flagged for fallback.
