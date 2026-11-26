# Tasks: vault-codifier-existing-terraform

Breaks the `vault-codifier-existing-terraform` change into tasks. It derives from [`proposal.md`](proposal.md), [`specs.md`](specs.md) (CAP-014 to CAP-016) and [`design.md`](design.md). Stage 1 is [`../vault-brownfield-research`](../vault-brownfield-research/tasks.md); stage 2 is [`../vault-codifier-stage-2`](../vault-codifier-stage-2/tasks.md); the remote review is [`../vault-codifier-remote-review`](../vault-codifier-remote-review/tasks.md).

Tracking issue: [#27](https://github.com/abuxton/vault-agentic-codifier/issues/27). Each task has an issue, linked from the index below.

## Baseline

| Item | Value |
|---|---|
| Stage 1 | 34 of 34 tasks done; `make codify-test` passes |
| Stage 2 | Not required |
| Remote review | Not required; real clusters stay out of scope |
| Needs | Docker, Terraform `>= 1.9`, Vault CLI, `jq`, the harness licence at `tmp/vault.hclic` (never committed) |

## Conventions

- Commit after each task, conventional commits, one commit per task, stage only that task's files.
- Every task is sized to at most two hours and tagged with one role and one capability, as `openspec/config.yaml` requires.
- Harness only. Every script refuses a `VAULT_ADDR` other than `127.0.0.1` or `localhost` with exit 2 (CAC14).
- The user's code and state are read-only input (CAC12). No task edits them.
- No state, plan or payload value reaches any output (CAC13). Do not write `pass`, `password` or `secret` next to `=` or `:` in scripts; the commit scanner is never bypassed.
- Skills stay within the 1,500-token limit of `.waza.yaml`; detail goes in `references/`. Scripts run on bash 3.2 and `jq`, are idempotent, and use `${arr[@]+"${arr[@]}"}` for arrays that may be empty.
- After every task, `make codify-test` still passes (CAC11).

## Task index

| Task | Title | Capability | Role | Type | Effort | Status |
|---|---|---|---|---|---|---|
| [TASK-E01](https://github.com/abuxton/vault-agentic-codifier/issues/18) | Existing-code fixture and `expected.json` | CAP-014 | SRE | test | M | Ready to start |
| [TASK-E02](https://github.com/abuxton/vault-agentic-codifier/issues/19) | Inventory of code and state | CAP-014 | Vault Expert | implementation | M | Blocked |
| [TASK-E03](https://github.com/abuxton/vault-agentic-codifier/issues/20) | Reconcile: classification model | CAP-015 | Solution Architect | implementation | M | Blocked |
| [TASK-E04](https://github.com/abuxton/vault-agentic-codifier/issues/21) | Plan-only attribute drift and unverifiable types | CAP-015 | SRE | implementation | M | Blocked |
| [TASK-E05](https://github.com/abuxton/vault-agentic-codifier/issues/22) | Reconcile report (md and json) | CAP-015 | Solution Architect | implementation | S | Blocked |
| [TASK-E06](https://github.com/abuxton/vault-agentic-codifier/issues/23) | Adopt proposals: imports and moved | CAP-016 | Solution Architect | implementation | M | Blocked |
| [TASK-E07](https://github.com/abuxton/vault-agentic-codifier/issues/24) | Adopt proposals: new resources overlay | CAP-016 | Solution Architect | implementation | M | Blocked |
| [TASK-E08](https://github.com/abuxton/vault-agentic-codifier/issues/25) | Validation skill, `make` target and `codify-test` stage | CAP-016 | SRE | test | M | Blocked |
| [TASK-E09](https://github.com/abuxton/vault-agentic-codifier/issues/26) | Guide, traceability and pointers | CAP-015 | Technical Writer | documentation | S | Blocked |

### TASK-E01: Existing-code fixture and `expected.json`
**Capability**: CAP-014
**Role**: SRE
**Type**: test
**Effort**: M
**Depends on**: none
**Status**: Ready to start
**Description**: Build the fixture of `specs.md` ("The existing-code fixture"). A script starts a throwaway container on `127.0.0.1:18202`, applies the harness layers as the "existing" code, saves `terraform show -json` of each layer, applies divergences F2 to F10 (F10 is confirmed in TASK-E04), injects the CAC13 marker values, and writes `expected.json`. Choose the location under `test/` and document the `make` target in `test/Makefile`.
**Acceptance Criteria**:
- AC: The container is removed on exit and on failure. A digest of the real harness before and after is equal (the `validation-variants` rule).
- AC: `expected.json` lists the expected class for every identity key of cases F1 to F9. F10 is recorded as pending TASK-E04.
- AC: The generated fixture holds only synthetic values. No licence text is printed or written.
- AC: Two runs of the generator produce byte-identical `expected.json`.
- AC: `make -C test smoke-test` and `make codify-test` still pass (CAC11).

### TASK-E02: Inventory of code and state
**Capability**: CAP-014
**Role**: Vault Expert
**Type**: implementation
**Effort**: M
**Depends on**: TASK-E01
**Status**: Blocked
**Description**: Create the skill `discovery-existing-terraform` with a script that reads a code directory and a `terraform show -json` file and writes `inventory.json` and `inventory.md` as in CAP-014. Verify the "from state" identity rule of `design.md` section 4 for every type in the fixture, and record the result in the skill's `references/`. Add `discovered_terraform/brownfield/` to `discovered_terraform/.gitignore`.
**Acceptance Criteria**:
- AC: CAP-014 AC1 to AC10 pass against the fixture.
- AC: The CAC13 marker value appears nowhere in `discovered_terraform/brownfield/`.
- AC: For a forbidden type, a test that replaces the state `values` with a marker shows the marker is never read.
- AC: The script refuses a non-`terraform show -json` file with exit 2 and writes nothing.
- AC: The input files' hashes are equal before and after (CAC12).
- AC: `SKILL.md` is within 1,500 tokens (`waza check`).

### TASK-E03: Reconcile: classification model
**Capability**: CAP-015
**Role**: Solution Architect
**Type**: implementation
**Effort**: M
**Depends on**: TASK-E02
**Status**: Blocked
**Description**: Create the skill `reconcile-existing-terraform` with a script that reads the inventory and the stage-1 live identities (generated `import {}` blocks plus `vault_generic_endpoint` paths) and applies the classification table of `specs.md`. This task covers every class except `drifted` and `unverifiable`, which need the plan (TASK-E04). The script marks a matched or drift-pending identity as `matched` for now, so the partition check can run.
**Acceptance Criteria**:
- AC: CAP-015 AC1, AC2 and AC4 pass; AC3 passes for F1, F3 to F9.
- AC: A renamed object is reported with both addresses, and is not reported as `orphan` plus `unimported`.
- AC: The partition check fails the run (exit 1) if an identity is in two classes or none.
- AC: The scripts refuse a root token and a non-local address (exit 2).
- AC: A second run is byte-identical (CAC15). `SKILL.md` is within 1,500 tokens.

### TASK-E04: Plan-only attribute drift and unverifiable types
**Capability**: CAP-015
**Role**: SRE
**Type**: implementation
**Effort**: M
**Depends on**: TASK-E03
**Status**: Blocked
**Description**: Add the plan-only run of `design.md` ADR-4: scratch copy, `init -backend=false`, `-lock=false`, exporter token, `TERRAFORM_VAULT_SKIP_CHILD_TOKEN=true`, `plan` then `show -json`, and a `jq` program that lists changed attribute names only. Confirm the variable name against provider 4.8.0. Measure which fixture types the exporter cannot refresh, class them `unverifiable` with the status recorded, re-run the readable set with `-target`, and record the findings in `references/`. Confirm or create fixture case F10, and update `expected.json`.
**Acceptance Criteria**:
- AC: CAP-015 AC3 (including F2 and F10), AC5 and AC6 pass.
- AC: A test shows the provider created no child token and issued no write (the audit log for the window).
- AC: No attribute value appears in the report or in any log; a sensitive attribute is reported as name plus `sensitive` (CAC13 marker scan).
- AC: The exporter policy file is unchanged by this task.
- AC: If a plan error cannot be attributed to a resource, the run exits 1 and says so; it is not folded into `unverifiable`.

### TASK-E05: Reconcile report (md and json)
**Capability**: CAP-015
**Role**: Solution Architect
**Type**: implementation
**Effort**: S
**Depends on**: TASK-E03
**Status**: Blocked
**Description**: Write `discovered_terraform/validation/existing-terraform.{json,md}`: counts per class, identities with addresses, the owning capability, `unresolved` and `unverifiable` lists, the capabilities in scope for the run (ADR-6), and the remedy options per class. Follow the layout and style of `zero-diff.md`.
**Acceptance Criteria**:
- AC: CAP-015 AC7, AC8, AC9 and AC10 pass.
- AC: The report states which stage-1 capabilities were in scope.
- AC: Options are listed and none is chosen.
- AC: No attribute value appears (CAC13); output is sorted and has no timestamps (CAC15).

### TASK-E06: Adopt proposals: imports and moved
**Capability**: CAP-016
**Role**: Solution Architect
**Type**: implementation
**Effort**: M
**Depends on**: TASK-E03
**Status**: Blocked
**Description**: Create the skill `codification-adopt-proposals`. Generate `adopt-existing/imports.tf` for `unimported` identities and `adopt-existing/moved.tf.proposed` for `renamed` identities, with the ids from the task-006 table, no block for `vault_generic_endpoint`, and no duplicate of a block already in the user's code. Add the import gate and the move gate.
**Acceptance Criteria**:
- AC: CAP-016 AC1 to AC4 pass against the fixture (F4 and F5).
- AC: The import gate compares the plan with and without the overlay, and fails the run if the overlay adds a non-import change.
- AC: The user's code and state are byte-identical afterwards (CAC12).
- AC: Generated files carry the provenance header (CAC7). `SKILL.md` is within 1,500 tokens.

### TASK-E07: Adopt proposals: new resources overlay
**Capability**: CAP-016
**Role**: Solution Architect
**Type**: implementation
**Effort**: M
**Depends on**: TASK-E06
**Status**: Blocked
**Description**: Build `adopt-new/<layer>/` by filtering the stage-1 generated output to `unmanaged` identities (block-level extraction of `resource`, its `import {}` and the policy file it references), with its own providers and state. Write the overlay `README.md` with the apply order and the decisions left to the owner. Reuse `check.sh` and `zero-diff.sh`.
**Acceptance Criteria**:
- AC: CAP-016 AC5 to AC10 pass against the fixture (F3 in `adopt-new`; nothing for F2 and F6 to F10).
- AC: `check.sh` passes on `adopt-new`, and `zero-diff.sh` exits 0 for every layer present.
- AC: No `out-of-policy` object and no value from state, plan or payloads is in the overlay (CAC13).
- AC: A second run is byte-identical (CAC15).

### TASK-E08: Validation skill, `make` target and `codify-test` stage
**Capability**: CAP-016
**Role**: SRE
**Type**: test
**Effort**: M
**Depends on**: TASK-E04, TASK-E05, TASK-E07
**Status**: Blocked
**Description**: Create the skill `validation-existing-terraform` and a root `make existing-terraform` target that runs fixture → discovery → inventory → reconcile → overlay → gates. Add the common-criteria checks CAC11 to CAC15 as a verifier with a self-test that injects faults, and add the flow as a stage of `make codify-test` that runs only with `EXISTING=1`, like `VARIANTS=1`.
**Acceptance Criteria**:
- AC: `make existing-terraform` exits 0 on the fixture and its report matches `expected.json`.
- AC: The verifier catches each injected fault: an edited input file, a leaked marker, a write request in the audit log, a non-local address, a class mismatch.
- AC: `make codify-test EXISTING=1` passes. `make codify-test` without the flag is unchanged.
- AC: The audit log for the window shows only `GET` and `LIST` by the exporter token (CAC14).
- AC: `make help` lists the new target.

### TASK-E09: Guide, traceability and pointers
**Capability**: CAP-015
**Role**: Technical Writer
**Type**: documentation
**Effort**: S
**Depends on**: TASK-E08
**Status**: Blocked
**Description**: Write `docs/existing-terraform.md` (inputs, how to produce the state copy, outputs, classes, the human decisions) and extend `docs/traceability.md` with CAP-014 to CAP-016 and CAC11 to CAC15. Add pointers in `AGENTS.md` (skills count and commands) and `HANDOFF.md`.
**Acceptance Criteria**:
- AC: Every CAP-014 to CAP-016 criterion appears in `docs/traceability.md` with its check.
- AC: The guide states that the codifier never edits the user's code, that state copies are sensitive, and that the first version is harness only.
- AC: `AGENTS.md` lists the new skills and the new `make` target, and the skill count is correct.
- AC: Links in the new documents resolve.

## Critical path

`TASK-E01` → `TASK-E02` → `TASK-E03` → (`TASK-E04` and `TASK-E05` and `TASK-E06` → `TASK-E07`) → `TASK-E08` → `TASK-E09`.

## Parallelisation

After `TASK-E03`, `TASK-E04`, `TASK-E05` and `TASK-E06` are independent and can run together. `TASK-E07` follows `TASK-E06`. `TASK-E08` needs `TASK-E04`, `TASK-E05` and `TASK-E07`.
