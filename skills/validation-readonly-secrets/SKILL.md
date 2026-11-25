---
name: validation-readonly-secrets
description: >
  Use when you need to verify CAC3 and CAC4. Parse the Vault audit log for the discovery window and require that
  the exporter token made only read and list requests, then scan generated output and raw payloads for secrets.
  Includes a self-test that injects faults and requires each to be caught. Harness. Run after codification, then
  read the report. USE FOR: read-only check; audit log. DO NOT USE FOR: a production cluster (harness only), or
  changing the generated output.
metadata:
  task: "TASK-025"
  role: "sre"
  depends_on: "discovery-orchestrator (TASK-014), codification-layer-assembly (TASK-022)"
  version: "1.0"
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

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
