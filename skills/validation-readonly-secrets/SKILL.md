---
name: validation-readonly-secrets
description: >
  Verify CAC3 and CAC4. Parse the Vault audit log for the discovery window and require that the exporter
  token made only read and list requests, then scan generated output and raw payloads for secrets.
  Includes a self-test that injects faults and requires each to be caught. Harness. TASK-025.
triggers:
  - "read-only check"
  - "audit log"
  - "no secrets"
  - "CAC3"
  - "CAC4"
  - "TASK-025"
task: TASK-025
depends_on:
  - discovery-orchestrator (TASK-014)
  - codification-layer-assembly (TASK-022)
role: sre
---

# Validation: read-only and no secrets

## 1. Run

```bash
bash skills/validation-readonly-secrets/scripts/verify.sh [out-root] [raw-root] [report-dir]
bash skills/validation-readonly-secrets/scripts/verify.sh --selftest
```

Needs `docker` and the harness container `vault-codifier-dev` (override with `VAULT_CONTAINER`), or
`AUDIT_FILE=<path>` to read a saved log. Report: `discovered_terraform/validation/readonly-secrets.{json,md}`.
Exit 0 all checks pass, 1 a check failed, 2 a missing input.

## 2. Audit-log check (CAC4)

The audit log holds every request since the harness started, including the exporter setup and test runs, so it
is never scanned whole. The window is `start_time` to `end_time` of `discovered_terraform/run_report.json`
(override with `WINDOW_START` and `WINDOW_END`). Inside it, the requests audited are those whose token carries the
`exporter` policy and not `root`.

| Check | Fails when |
|---|---|
| `audit-has-exporter-requests` | the window holds no exporter request (a vacuous pass) |
| `audit-read-only` | any operation other than `read` or `list` |
| `audit-no-secret-reads` | a `/data/`, `/creds/`, `/issue/`, `/sign/`, `secret-id` or `sys/raw` path was read |

Audit lines can be JSON arrays, so every filter starts with `select(type=="object" ...)`.
The window's other requests (the `secret-id` mint and the AppRole login) are listed in the report as setup,
not as codifier activity. A request that Vault denies (403) is still logged as an attempt, so it counts.

`NO_AUDIT_DEVICE=1` reports the three audit checks as `SKIP`. It is for a scenario with no audit device by
definition (an empty cluster) and is used only by `validation-variants`.

## 3. Content scans (CAC3)

Over `terraform/` and `raw/`: no state, plan or tfvars file, no `SYNTHETIC`, no `secret_id` or
`secret_id_accessor` value, no `hvs.`/`hvb.`/`hvr.` token, no `X-Vault-Token`, no literal root token, no KV v2
payload shape (`data.data` with `data.metadata`), and the value of `VAULT_TOKEN` or `EXPORTER_TOKEN` when set.
Over `*.tf` excluding `imports*.tf`: no UUID literal, and no quoted literal on a sensitive argument
(`bindpass`, `client_secret`, `private_key` and similar). Matches are reported by file and line, not by value.
Config keys such as `secret_id_ttl` and `secret_id_num_uses` are not values and do not match.

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
