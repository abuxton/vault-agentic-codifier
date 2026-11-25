---
name: validation-codify-test
description: >
  Use when you need to run the whole codifier test in one command: harness up, smoke test, discover and codify
  twice, check idempotence (CAC5), ownership (CAC6, CAC7), static gate (CAC1), zero-diff (CAC2), read-only and
  secrets (CAC3, CAC4), smoke test again, and confirm the harness is unchanged. Prints per-CAC and per-capability
  results. Harness only. Run after codification, then read the report. USE FOR: codify-test; idempotence. DO NOT
  USE FOR: a production cluster (harness only), or changing the generated output.
metadata:
  task: "TASK-027"
  role: "sre"
  depends_on: "validation-static-gate (TASK-023), validation-zero-diff (TASK-024), validation-readonly-secrets (TASK-025), validation-variants (TASK-026)"
  version: "1.0"
---

# Validation: codify-test

## 1. Run

```bash
make codify-test                    # about 90 seconds
VARIANTS=1 make codify-test         # adds the TASK-026 edge-case fixtures, about 3 more minutes
bash skills/validation-codify-test/scripts/codify-test.sh --selftest
```

Reports: `discovered_terraform/validation/codify-test.{json,md}`, plus the zero-diff and read-only reports the
stages write. Exit 0 only when every stage passes. A failing stage prints the last lines of its own log.

## 2. Stages

| Stage | CAC | What it does |
|---|---|---|
| `harness-up` | | uses `127.0.0.1:8200`; runs `make -C test up seed` if it is not reachable |
| `smoke-before` | | `make -C test smoke-test` |
| `codify-run-1`, `codify-run-2` | | each mints a fresh exporter token (AppRole, one-time secret-id), runs the orchestrator, then `assemble.sh`, into its own scratch directory |
| `idempotence` | CAC5 | the two output trees and the two raw trees hash identically; regenerating over an existing tree changes nothing |
| `ownership` | CAC6, CAC7 | `check.sh`: unique deterministic labels, provenance headers, one import per resource |
| `static-gate` | CAC1 | `gate.sh`: validate, `fmt -check`, tflint per layer |
| `zero-diff` | CAC2 | `zero-diff.sh`: scratch-state import, `plan -detailed-exitcode` 0 |
| `readonly-secrets` | CAC3, CAC4 | `verify.sh` on both runs, over a window spanning both |
| `smoke-after` | | `make -C test smoke-test` again |
| `harness-unchanged` | | a digest of namespaces, policies, mounts and entities is equal before and after |

Both runs write to a scratch directory, so the committed `discovered_terraform/terraform` tree is not rewritten by
the test. Hashing ignores `.terraform/`, the lock file, `run_report*` (timestamps) and `.state.json`. Everything
else, including the raw payloads, must match.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
