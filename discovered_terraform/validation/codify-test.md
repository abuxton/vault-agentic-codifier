# codify-test

Run against http://127.0.0.1:8200. Output generated twice into a scratch directory; reports in this folder.

## Per CAC

| CAC | Meaning | Stage | Result |
|---|---|---|---|
| CAC1 | valid HCL | static-gate | PASS |
| CAC2 | zero diff after import | zero-diff | PASS |
| CAC3 | no secrets | readonly-secrets | PASS |
| CAC4 | read-only | readonly-secrets | PASS |
| CAC5 | idempotent | idempotence | PASS |
| CAC6 | naming | ownership | PASS |
| CAC7 | provenance | ownership | PASS |
| CAP-001 to CAP-007 | harness criteria (40 of 52) | spec-check | PASS |

## Per capability

| Capability | Resources | CAC1 (static gate) | CAC2 (zero diff) |
|---|---|---|---|
| admin-config | 0 | pass | none declared |
| auth-mounts | 11 | pass | pass |
| namespaces | 4 | pass | pass |
| policies | 10 | pass | pass |
| root-config | 2 | pass | pass |
| secrets-engines | 8 | pass | pass |
| teams | 17 | pass | pass |

## Stages

| Stage | CAC | Result | What it checks |
|---|---|---|---|
| harness-up | - | PASS | harness reachable at http://127.0.0.1:8200 (starts and seeds it if not) |
| smoke-before | - | PASS | make -C test smoke-test |
| codify-run-1 | - | PASS | discover with a fresh exporter token and generate |
| codify-run-2 | - | PASS | second run against the unchanged cluster |
| idempotence | CAC5 | PASS | two runs give byte-identical output and raw trees |
| ownership | CAC6,CAC7 | PASS | labels unique and deterministic; provenance header on every file |
| spec-check | CAP | PASS | 40 harness criteria of specs.md against the generated output |
| static-gate | CAC1 | PASS | validate, fmt -check and tflint in every layer |
| zero-diff | CAC2 | PASS | import into a scratch state; plan exits 0 in every layer |
| readonly-secrets | CAC3,CAC4 | PASS | audit log read-only and no secrets in output or raw |
| smoke-after | - | PASS | make -C test smoke-test, after the codifier ran |
| harness-unchanged | - | PASS | harness state identical before and after |

Verdict: **PASS**
