## 4. Reference implementation (validated against the harness)

Discovery window `08:40:42` to `08:40:48`: 121 exporter requests (47 list, 74 read), 0 other, no secret path.
All 12 checks PASS. The only other requests in the window were the `secret-id` mint and the AppRole login.

`--selftest` copies the inputs to a scratch directory, confirms they pass, then injects 10 faults, each of which
must fail on the named check: a write, a delete and a KV data read by the exporter token (rewritten audit
lines), an empty window, a `secret_id` value, a `SYNTHETIC` marker and a KV v2 payload in raw, a UUID literal,
a token literal and a sensitive literal in `.tf`, and a state file. All are caught.

Live check, with the harness changed in no way: a real exporter token (AppRole login) listed namespaces, read a
policy, then tried `vault write sys/policies/acl/zz-injected`. Vault returned 403 and the policy list was
identical before and after. With `WINDOW_START` and `WINDOW_END` set round those three calls, `audit-read-only`
reported `FAIL: 1 non-read operations ... update sys/policies/acl/zz-injected`.
