## Run report format

`discovered_terraform/run_report.json` (written by `run.sh`; per-skill non-200s go to `raw/run_report.jsonl` and are merged here):

```json
{
  "run_id": "20250101T000000Z",
  "vault_addr": "http://127.0.0.1:8200",
  "start_time": "2025-01-01T00:00:00Z",
  "end_time": "2025-01-01T00:02:10Z",
  "namespaces_discovered": ["admin", "admin/platform", "admin/app-billing", "admin/app-identity"],
  "non_200_responses": [
    {"endpoint": "sys/policies/acl", "namespace": "admin/platform", "http_status": 403, "skipped": true}
  ],
  "exit_code": 0
}
```

`exit_code`: `0` success (non-200s are allowed), `1` a skill failed, `2` a stop condition triggered. The token must never appear in this file.

---
