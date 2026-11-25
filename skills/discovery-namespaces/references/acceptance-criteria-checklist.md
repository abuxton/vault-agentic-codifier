## 8. Acceptance Criteria Checklist

- [ ] **AC-1 (CAP-005 AC1)**: Against the harness, exactly 4 namespaces are discovered: `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`.
- [ ] **AC-2 (CAP-005 AC2)**: Custom metadata descriptions match harness configuration for tenant namespaces (`platform`, `app-billing`, `app-identity`), while `admin` has `{}` custom metadata.
- [ ] **AC-3 (CAP-005 AC3)**: Topologically ordered such that every parent namespace precedes its child namespaces.
- [ ] **AC-4 (CAP-005 AC5)**: Handles arbitrary depth (`depth >= 3`) correctly without hardcoded level limits.
- [ ] **AC-5 (CAP-005 AC6)**: Root namespace `""` is excluded from the output list.
- [ ] **AC-6 (CAP-005 AC7)**: Namespace IDs in output match `vault namespace list -detailed` on the cluster.
- [ ] **AC-7 (CAC5)**: Two consecutive executions produce byte-identical `namespaces.json`.
