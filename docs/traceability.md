# Traceability

Maps every acceptance criterion in [`specs.md`](../openspec/changes/vault-brownfield-research/specs.md) (52 capability criteria CAP-001 to CAP-007 and 7 common criteria CAC1 to CAC7, 59 in all) to the task that implements it and the check that verifies it. Gaps are listed explicitly in section 4.

## How the criteria are verified

| Check | Command | What it covers |
|---|---|---|
| `spec-check` | `make spec-check` (`make spec-check-selftest` injects 12 faults) | 40 harness criteria, one result per criterion, against the generated output. Report: `discovered_terraform/validation/spec-check.md` |
| `variants` | `make variants` | 10 criteria that need a fixture the harness lacks (OIDC, userpass, PKI, a nested namespace, a 403 token, an empty cluster) |
| `zero-diff` | `make zero-diff` | CAC2 and the plan-based criteria: import into a scratch state, `plan -detailed-exitcode` is 0 in every layer |
| `static-gate` | `make static-gate` | CAC1: `fmt -check`, `validate`, `tflint` |
| `verify` | `make verify` | CAC3 and CAC4: content scans and the audit log of the run |
| `codify-test` | `make codify-test` | All of the above plus idempotence and ownership, in one verdict |

Implementing task per capability: each capability has a discovery task and a generator task.

| Capability | Discovery | Generator |
|---|---|---|
| CAP-001 root-config | TASK-008 | TASK-016 |
| CAP-002 admin-config | TASK-013 | TASK-021 |
| CAP-003 auth-mounts | TASK-010 | TASK-018 |
| CAP-004 secrets-engines | TASK-011 | TASK-019 |
| CAP-005 namespaces | TASK-007 | TASK-015 |
| CAP-006 policies | TASK-009 | TASK-017 |
| CAP-007 teams | TASK-012 | TASK-020 |

## 1. Common criteria

| Criterion | Implemented by | Verified by |
|---|---|---|
| CAC1 valid HCL | TASK-002, TASK-022 | `static-gate` (TASK-023); every variant scenario |
| CAC2 zero diff | TASK-006 (import ids), TASK-015 to TASK-022 | `zero-diff` (TASK-024); `variants` |
| CAC3 no secrets | TASK-004, all generators | `verify` (TASK-025); `variants` |
| CAC4 read-only | TASK-031 (exporter policy) | `verify` (TASK-025): the audit log has only read and list for the exporter token |
| CAC5 idempotent | TASK-014, TASK-022 | `codify-test` idempotence stage (TASK-027) |
| CAC6 naming | TASK-003 | `codify-test` ownership stage (TASK-022, TASK-027) |
| CAC7 provenance | TASK-004 | `codify-test` ownership stage (TASK-022, TASK-027) |

## 2. Criteria checked by `spec-check` (40)

Implementing tasks are in the table above. The result for each criterion is in the generated `spec-check.md`; all 40 pass.

| Capability | Criteria |
|---|---|
| CAP-001 | AC1, AC2, AC3, AC4, AC5 |
| CAP-002 | AC1, AC2, AC3, AC5, AC6 |
| CAP-003 | AC1, AC2, AC3, AC4, AC5, AC6 |
| CAP-004 | AC1, AC2, AC3, AC4, AC5, AC7, AC8 |
| CAP-005 | AC1, AC2, AC3, AC4, AC6, AC7 |
| CAP-006 | AC1, AC3, AC4, AC7, AC8 |
| CAP-007 | AC1, AC2, AC3, AC5, AC6, AC7 |

## 3. Criteria verified by another check (12)

| Criterion | Verified by | Scenario or phase |
|---|---|---|
| CAP-001 AC6 empty `sys/audit` | `variants` (TASK-026) | `empty-cluster` CAP-001-AC6 |
| CAP-001 AC7 403 on a `sys/` endpoint | `variants` (TASK-026) | `restricted-403` CAP-001-AC7a, AC7b, AC7c |
| CAP-002 AC4 OIDC mount in `admin` | `variants` (TASK-026) | `variant` CAP-002-AC4, CAP-002-AC4-secret |
| CAP-003 AC7 mount type without a dedicated resource | `variants` (TASK-026) | `variant` CAP-003-AC7 |
| CAP-003 AC8 re-import gives zero diff | `zero-diff` (TASK-024) | every layer |
| CAP-004 AC6 engine configuration for PKI and database | `variants` (TASK-026) | `variant` CAP-004-AC6 |
| CAP-005 AC5 namespace nested deeper than two levels | `variants` (TASK-026) | `variant` CAP-005-AC5 |
| CAP-006 AC2 lossless policy round trip | `zero-diff` (TASK-024); TASK-009 compared 10 policies byte for byte with the API | policies layer |
| CAP-006 AC5 dangling policy reference | `variants` (TASK-026) | `variant` CAP-006-AC5 |
| CAP-006 AC6 same policy name in two namespaces | `variants` (TASK-026) | `variant` CAP-006-AC6 |
| CAP-007 AC4 external group and group alias | `variants` (TASK-026) | `variant` CAP-007-AC4 |
| CAP-007 AC8 group in a non-admin namespace | `variants` (TASK-026) | `variant` CAP-007-AC8 |

## 4. Gaps and partial coverage

No criterion is unmet. These are limits of the checks.

| Criterion | Limit | Owner |
|---|---|---|
| CAP-005 AC7 | `spec-check` compares namespace ids with the live cluster only when `VAULT_TOKEN` is set; otherwise the criterion is reported SKIP | Test owner |
| CAP-004 AC7 | Checks only that `plugin_version` is absent. No fixture pins a plugin version, so the pinned case is untested | Test owner |
| CAP-001 AC7 | Covers a 403 on two optional endpoints and on the audit endpoint. Other `sys/` endpoints share the same code path but are not each tried | Test owner |
| CAP-002 AC4 | Covers OIDC. LDAP was checked by hand on a scratch payload (TASK-021), not by a repeatable check | Test owner |

## 5. Harness drift from the spec

The harness holds more than `specs.md` assumed. The checks accept the real counts and `spec-check` names each as "harness drift".

| Spec says | Harness has | Cause |
|---|---|---|
| 9 policies | 10 | root `exporter` policy (TASK-031) |
| 5 AppRole roles | 6 | root `exporter` role |
| 3 KV mounts | 4 | preloaded root `secret/` |
| 6 entities, 0 aliases | 7 entities, 1 alias | root `exporter-agent` entity and alias |

## 6. Remaining risks and deferred items

| Item | Risk | Owner |
|---|---|---|
| Sentinel EGP and RGP | Mapped, never exercised: no harness fixture, so import and `file()` emission are untested | Vault platform owner |
| MFA methods and login enforcement | Not discovered or emitted; no fixture | Vault platform owner |
| Auth methods other than AppRole | The backend is emitted as a mount; method configuration is only checked for OIDC (variant) and LDAP (scratch payload) | Generator owner |
| Engines other than KV v2 | Emitted as `vault_mount` only; engine configuration is listed in `coverage.md` for manual review | Generator owner |
| Replication and DR | Recorded in the root README only; not codified | Vault platform owner |
| Waza eval suite | Skipped; the 23 skills pass the structure checks only (see [`waza-review.md`](waza-review.md)) | Skill owner |
| Findings in git history | `vault-radar scan repo` reports 13 low-severity findings: 6 `pass` phase keys in `zero-diff.json` (renamed), 4 synthetic placeholders in `test/terraform/seed/main.tf`, 2 test values in a deleted test file, and 1 sentence in `HANDOFF.md` that reads like an assignment (reworded). None is a credential. Accepted; the history stays unchanged | Repository owner |
| Real-cluster use | Verified on the harness only. A first run on a production cluster needs a review of every `coverage.md` | Vault platform owner |

## 7. OpenSpec verification pass (2026-11-26)

The `openspec` CLI is not installed, so the pass was done by hand against `proposal.md`, `design.md`, `specs.md` and `tasks.md`.

| Dimension | Result |
|---|---|
| Completeness | 32 of 34 tasks are done before TASK-030; TASK-005 is superseded; TASK-032 is the last open task. All 59 criteria map to a task and a check (sections 1 to 3). |
| Correctness | `make codify-test` passes: 11 stages, CAC1 to CAC7 and the CAP row. No criterion is unmet. Sections 4 and 5 list the limits and the harness drift. |
| Coherence | Three differences from `design.md`, all recorded in the task statuses: (1) discovery uses the `vault` CLI, `curl` and `jq` with a read-only exporter token, not a Python client with a root token (TASK-005 superseded, TASK-031); (2) the output has seven capability layers assembled under `discovered_terraform/terraform/`, not the three harness layers `admin`, `namespaces` and `seed`; (3) the `design.md` section 6.2 pseudocode is illustrative and was not implemented. |

Suggested follow-up, in priority order: an Enterprise fixture for EGP, RGP and MFA; method and engine resources beyond AppRole and KV v2; a waza eval suite; a first review on a non-harness cluster.
