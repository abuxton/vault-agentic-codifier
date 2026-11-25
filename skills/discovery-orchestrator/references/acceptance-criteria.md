## Acceptance criteria

- [ ] One command runs all discovery end to end against the harness.
- [ ] `run_report.json` shows `non_200_responses: []` and `exit_code: 0` for the harness.
- [ ] Output tree matches the expected tree above.
- [ ] Two runs produce byte-identical `raw/` trees (`diff -r` clean).
- [ ] `grep -r SYNTHETIC discovered_terraform/raw/` is empty; no tokens in any file.
- [ ] Audit log shows only `GET`/`LIST` by the exporter alias and no `/data/` or `/metadata/` paths.

---
