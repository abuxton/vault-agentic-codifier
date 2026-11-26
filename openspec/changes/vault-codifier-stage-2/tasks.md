# Tasks: vault-codifier-stage-2

Breaks the `vault-codifier-stage-2` change into tasks. It derives from [`proposal.md`](proposal.md), [`specs.md`](specs.md) (CAP-008 to CAP-012, CAC8 to CAC10) and [`design.md`](design.md). Stage 1 is [`../vault-brownfield-research`](../vault-brownfield-research/tasks.md); the review on a non-harness cluster is [`../vault-codifier-remote-review`](../vault-codifier-remote-review/tasks.md).

Tracking issue: [#16](https://github.com/abuxton/vault-agentic-codifier/issues/16). Each task has an issue, linked from the index below.

## Baseline

| Item | Value |
|---|---|
| Stage 1 | 34 of 34 tasks done; `make codify-test` passes; `make spec-check` passes 40 of 40 |
| Vault | Vault Enterprise 2.2.2+ent at `http://127.0.0.1:8200`. The harness licence lists Sentinel, MFA, Lease Count Quotas and several engines |
| Provider | `hashicorp/vault` 4.8.0 |
| waza | 0.42.0 at `~/bin/waza` |

## Conventions

- Effort, status and the CAC1 to CAC7 references follow stage 1. CAC8 to CAC10 are defined in `specs.md`.
- **Commit after each task**, conventional commits, one task per commit. Push to `origin/main` after each.
- After every task `make codify-test` must pass (CAC8). A task that adds a fixture updates the expected counts in `spec-check.sh` and `docs/traceability.md` in the same commit.
- Skills stay within the 1,500-token limit in `.waza.yaml`; detail goes in `references/`.
- No task writes to a cluster other than the harness or throwaway containers on `127.0.0.1`.

## Task index

| Task | Title | Phase | Capability | Type | Effort | Status |
|---|---|---|---|---|---|---|
| [TASK-S01](https://github.com/abuxton/vault-agentic-codifier/issues/1) | Verify provider resources and import ids for stage 2 | A | all | research | M | **Done** for CAP-008 and CAP-009; CAP-010 and CAP-011 are verified inside TASK-S05 and TASK-S06 |
| [TASK-S02](https://github.com/abuxton/vault-agentic-codifier/issues/2) | Harness fixtures for EGP, RGP and MFA | A | CAP-008, CAP-009 | implementation | M | **Done** |
| [TASK-S03](https://github.com/abuxton/vault-agentic-codifier/issues/3) | Sentinel discovery and generator | B | CAP-008 | implementation | L | **Done** |
| [TASK-S04](https://github.com/abuxton/vault-agentic-codifier/issues/4) | MFA discovery and generator | B | CAP-009 | implementation | L | Ready to start |
| [TASK-S05](https://github.com/abuxton/vault-agentic-codifier/issues/5) | Auth method configuration: variant fixture, discovery, generator | C | CAP-010 | implementation | XL | Ready to start |
| [TASK-S06](https://github.com/abuxton/vault-agentic-codifier/issues/6) | Engine configuration: variant fixture, discovery, generator | C | CAP-011 | implementation | XL | Ready to start |
| [TASK-S07](https://github.com/abuxton/vault-agentic-codifier/issues/7) | Verification extensions (spec-check, verify, variants) | D | CAC8 to CAC10 | test | L | Blocked |
| [TASK-S08](https://github.com/abuxton/vault-agentic-codifier/issues/8) | Eval suite scaffolding and deterministic graders | E | CAP-012 | test | L | Blocked |
| [TASK-S09](https://github.com/abuxton/vault-agentic-codifier/issues/9) | Eval run with a real executor and baseline | E | CAP-012 | test | M | Blocked |
| [TASK-S10](https://github.com/abuxton/vault-agentic-codifier/issues/10) | Stage-2 docs, traceability and publish | F | N/A | documentation | M | Blocked |

Phases: A foundation, B Enterprise policy and identity, C breadth, D verification, E evals, F docs.

## Phase A: Foundation

### TASK-S01: Verify provider resources and import ids for stage 2
**Capability**: CAP-008 to CAP-011
**Type**: research
**Effort**: M
**Depends on**: none
**Status**: **Done** for CAP-008 and CAP-009 ([`task-s01-decision.md`](task-s01-decision.md)). CAP-010 and CAP-011 are verified at the start of TASK-S05 and TASK-S06.
**Description**: Do for stage 2 what TASK-006 did for stage 1. For every resource in the `specs.md` traceability table, confirm the resource name exists in `hashicorp/vault` 4.8.0, its required arguments, which arguments are write-only (not read back), and the import id shape, by running `terraform plan` with `import {}` against the harness or a scratch container. Record the result in `task-s01-decision.md`. Use the Terraform MCP or the documented fallback.
**Acceptance Criteria**:
- AC: A table lists each resource with its import id shape, the arguments Vault does not return, and whether the plan is zero-diff after import.
- AC: Each resource that needs `lifecycle { ignore_changes }` is listed with the fields.
- AC: Any name or id in `specs.md` that disagrees with the result is corrected in `specs.md`.
- AC: The exporter policy additions needed for MFA and the CAP-010 and CAP-011 config paths are listed (read and list only).

### TASK-S02: Harness fixtures for EGP, RGP and MFA
**Capability**: CAP-008, CAP-009
**Type**: implementation
**Effort**: M
**Depends on**: TASK-S01
**Status**: Done
**Description**: Add the synthetic fixtures from CAP-008 and CAP-009 to `test/terraform`: a root EGP and RGP, a tenant EGP and RGP, and a TOTP method with a login-enforcement rule in `admin`. Extend `exporter.hcl` with the six read and list paths from `task-s01-decision.md` section 4, at every namespace depth the policy already covers, and nothing else. Update the harness counts everywhere they appear.
**Acceptance Criteria**:
- AC: `make -C test all` and `make -C test smoke-test` pass with the fixtures applied.
- AC: `terraform plan` in each harness layer shows no changes after apply.
- AC: The exporter token reads the new paths (200) and each write in `task-s01-decision.md` section 4 returns 403, tested against the committed harness.
- AC: `make codify-test` still passes with updated counts (CAC8).
- AC: Fixture values carry the `SYNTHETIC-` convention and no real seed or key (CAC9, CAC10).

## Phase B: Enterprise policy and identity

### TASK-S03: Sentinel discovery and generator
**Capability**: CAP-008
**Type**: implementation
**Effort**: L
**Skill**: `skills/discovery-policies`, `skills/codification-policies`
**Depends on**: TASK-S02
**Status**: Done
**Description**: Extend discovery to store per-namespace EGP and RGP payloads and the generator to emit `vault_egp_policy`, `vault_rgp_policy`, the Sentinel sources under `policies/sentinel/<ns>/`, imports, and the coverage and correlation sections.
**Acceptance Criteria**:
- AC: CAP-008 AC1 to AC8 hold against the extended harness.
- AC: Re-running discovery and the generator is byte-identical (CAC5).
- AC: The static gate and zero-diff pass for the `policies` layer (CAC1, CAC2).
- AC: The skills stay within 1,500 tokens and `waza check` reports them `ready`.

### TASK-S04: MFA discovery and generator
**Capability**: CAP-009
**Type**: implementation
**Effort**: L
**Skill**: `skills/discovery-identity-teams`, `skills/codification-teams`
**Depends on**: TASK-S02
**Status**: Ready to start
**Description**: Extend discovery to read MFA methods and login enforcement without calling any generate endpoint, and the generator to emit the method and enforcement resources, `imports_mfa.tf` and `mfa.md`. Secret-bearing method types use sensitive variables with no default.
**Acceptance Criteria**:
- AC: CAP-009 AC1 to AC8 hold against the extended harness.
- AC: A scratch Duo or Okta method fixture (not committed) proves its key never reaches a file (CAC10).
- AC: Re-run is byte-identical; static gate and zero-diff pass for the `teams` layer.
- AC: The skills stay within 1,500 tokens and `waza check` reports them `ready`.

## Phase C: Breadth

### TASK-S05: Auth method configuration
**Capability**: CAP-010
**Type**: implementation
**Effort**: XL
**Skill**: `skills/discovery-auth-mounts`, `skills/codification-auth-mounts`
**Depends on**: TASK-S01
**Status**: Ready to start
**Description**: First verify the CAP-010 resources and import ids as TASK-S01 did, and append them to `task-s01-decision.md`. Then build the scratch variant fixture for LDAP, Kubernetes, AWS, cert, token roles and JWT/OIDC outside `admin`, extend discovery to read the method config and roles with secrets masked, and extend the generator to emit per-method resources. One method at a time, each with its own zero-diff check.
**Acceptance Criteria**:
- AC: CAP-010 AC1 to AC7 hold in the variant run.
- AC: No fixture secret appears in any file, report or log (CAC10).
- AC: `coverage.md` lists the types still outside the slice as "review manually".
- AC: The ownership check still passes (CAP-002 AC5).

### TASK-S06: Engine configuration
**Capability**: CAP-011
**Type**: implementation
**Effort**: XL
**Skill**: `skills/discovery-secrets-engines`, `skills/codification-secrets-engines`
**Depends on**: TASK-S01
**Status**: Ready to start
**Description**: First verify the CAP-011 resources and import ids as TASK-S01 did, and append them to `task-s01-decision.md`. Then build the scratch variant fixture for PKI, database, AWS, transit and SSH, extend discovery to read engine config without key material, and extend the generator to emit per-engine resources. One engine at a time, each with its own zero-diff check.
**Acceptance Criteria**:
- AC: CAP-011 AC1 to AC8 hold in the variant run.
- AC: No private key, issued certificate, transit key bytes or credential appears anywhere (CAC10).
- AC: `coverage.md` lists the types still outside the list as "review manually".

## Phase D: Verification

### TASK-S07: Verification extensions
**Capability**: CAC8 to CAC10
**Type**: test
**Effort**: L
**Depends on**: TASK-S03, TASK-S04, TASK-S05, TASK-S06
**Status**: Blocked
**Description**: Extend `spec-check.sh` with the harness-verifiable stage-2 criteria (CAP-008 and CAP-009), `run-variants.sh` with the CAP-010 and CAP-011 scenarios, and `verify.sh` with a marker for every new fixture secret. Extend the self-test to inject a fault per new criterion.
**Acceptance Criteria**:
- AC: `make spec-check` reports each new harness criterion; the self-test catches every injected fault.
- AC: `make variants` passes with the new scenarios on throwaway containers and the real harness digest unchanged.
- AC: `make codify-test` passes with the new stages (CAC8).
- AC: `docs/traceability.md` maps CAP-008 to CAP-012 to tasks and checks with explicit gaps.

## Phase E: Evals

### TASK-S08: Eval suite scaffolding and deterministic graders
**Capability**: CAP-012
**Type**: test
**Effort**: L
**Depends on**: TASK-S07
**Status**: Blocked
**Description**: Create `waza new eval` suites for the 23 skills, with two tasks each (happy path and stop condition), deterministic graders, scratch working copies, and `make evals`. Validate the suite with the mock executor and label that result "harness only".
**Acceptance Criteria**:
- AC: Every skill has an `eval.yaml` with at least one happy-path and one stop-condition task (CAP-012 AC1).
- AC: Graders are deterministic except where a prompt grader names its judge model (AC2).
- AC: Evals run on copies; the harness digest is unchanged (AC3).
- AC: `make evals` runs under the mock executor and exits non-zero on a failed grader (AC8). It is not part of `make codify-test`.
- AC: No secret, token or licence content appears in any fixture.

### TASK-S09: Eval run with a real executor and baseline
**Capability**: CAP-012
**Type**: test
**Effort**: M
**Depends on**: TASK-S08
**Status**: Blocked
**Description**: Run the suite with a real model and with `--baseline`, record the results, and list skills that do worse than the baseline.
**Acceptance Criteria**:
- AC: **Owner approval for the model, number of trials and expected cost is recorded before the run** (AC6). Stop here if it is missing.
- AC: `docs/eval-results.md` records model, judge model, trials, date, cost, and pass rates with and without skills (AC4, AC5, AC6).
- AC: Each skill that is worse than the baseline is listed as a follow-up with a reason (AC7).
- AC: No secret or licence content is in the committed results.

## Phase F: Docs

### TASK-S10: Stage-2 docs, traceability and publish
**Capability**: N/A
**Type**: documentation
**Effort**: M
**Depends on**: TASK-S07, TASK-S09
**Status**: Blocked
**Description**: Update `README.md`, `AGENTS.md`, `docs/usage-guide.md`, `HANDOFF.md`, `STATUS_REPORT.md`, `tmp/terraform-resource-map.md` and the stage-2 traceability. Remove the "not exercised" lines for EGP, RGP and MFA from the README limits. Run a whole-history secret scan, commit and push.
**Acceptance Criteria**:
- AC: Every CAP-008 to CAP-012 criterion maps to a task and a check, or is an explicit gap.
- AC: The README "Limits" section matches what was built.
- AC: `make codify-test` and `make spec-check` pass; `waza check` reports 23 of 23 skills `ready`.
- AC: `vault-radar scan repo --clone-dir . --skip-activeness` reports no finding that is a credential; any low finding is listed and accepted.
- AC: `git ls-remote origin main` equals the local `main`.

## Critical path

`TASK-S01` → `TASK-S02` → `TASK-S03`/`TASK-S04` → `TASK-S07` → `TASK-S08` → `TASK-S09` → `TASK-S10`.

## Parallelisation

- After `TASK-S01`, `TASK-S02`, `TASK-S05` and `TASK-S06` can start in parallel.
- `TASK-S03` and `TASK-S04` run in parallel once `TASK-S02` is done.
- `TASK-S07` waits for all four generators. `TASK-S08` can start its scaffolding earlier on skills that no generator task changes, but the final run waits for `TASK-S07` so the skills are stable.
- `TASK-S09` is gated by owner approval of the cost.

## Deferred beyond stage 2

Azure, GCP, Consul, Nomad, Okta, SPIFFE, KMIP and secrets-sync resources; Kubernetes and Terraform Cloud deployment of the generated code; remote-state layout. The review on a real cluster is [`vault-codifier-remote-review`](../vault-codifier-remote-review/tasks.md).
