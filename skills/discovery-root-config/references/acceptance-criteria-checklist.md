## 9. Acceptance Criteria Checklist

- [ ] **AC-1 (CAP-001 AC1)**: Raw payload shows exactly one `file` audit device at path `file_path = "/vault/logs/audit.log"`.
- [ ] **AC-2 (CAP-001 AC2)**: Rate limit quota `global-rate-limit` captured with `rate = 1000`, `interval = 60`, `block_interval = 60`, `path = ""`.
- [ ] **AC-3 (CAP-001 AC3)**: No policy, mount, or namespace resources are captured by this root skill (ownership boundaries respected).
- [ ] **AC-4 (CAP-001 AC4)**: `license_status.json` contains license ID, expiry, and features only, with zero raw license text. Replication is captured as disabled.
- [ ] **AC-5 (CAP-001 AC6)**: If `sys/audit` is empty on a clean cluster, an empty JSON object is saved without error.
- [ ] **AC-6 (CAP-001 AC7)**: Unauthorized `sys/` endpoints record a run report entry and allow the process to proceed.
