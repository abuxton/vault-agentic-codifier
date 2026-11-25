## 9. Acceptance Criteria Checklist

- [ ] **AC-1 (CAP-006 AC1)**: Discovers exactly the 10 non-builtin ACL policies across namespaces:
  - Root: `operator`, `exporter` (2)
  - `admin`: `admin`, `namespace-admin` (2)
  - `admin/platform`: `platform-sre-read`, `platform-devops-write` (2)
  - `admin/app-billing`: `billing-developers-read`, `billing-owners-write` (2)
  - `admin/app-identity`: `identity-developers-read`, `identity-owners-write` (2)
- [ ] **AC-2 (CAP-006 AC1)**: Built-in policies `default`, `root` and `default-ceiling` are excluded from all output payloads.
- [ ] **AC-3 (CAP-006 AC2)**: Stored `policy_text` matches the live cluster API output byte-for-byte.
- [ ] **AC-4 (CAP-006 AC7)**: Path stanzas with namespace-relative paths (e.g. `secret/data/*`) are preserved without alterations.
- [ ] **AC-5 (CAP-006 AC8)**: EGP/RGP checks return "none" for the harness without causing errors.
- [ ] **AC-6 (CAC5)**: Two consecutive discovery runs produce byte-identical JSON payloads.
