# Tasks: vault-codifier-remote-review

Breaks the `vault-codifier-remote-review` change into tasks. It derives from [`proposal.md`](proposal.md), [`specs.md`](specs.md) (CAP-013) and [`design.md`](design.md). Stage 1 is [`../vault-brownfield-research`](../vault-brownfield-research/tasks.md); stage 2 is [`../vault-codifier-stage-2`](../vault-codifier-stage-2/tasks.md).

## Baseline

| Item | Value |
|---|---|
| Stage 1 | 34 of 34 tasks done; `make codify-test` passes |
| Stage 2 | Recommended before this change, not required |
| Needs | A cluster owner, a window, written approval, and an exporter identity created by the owner |

## Conventions

- Commit after each task, conventional commits. Push after each.
- **No task issues a request to a cluster before TASK-R01 is done.**
- The repository is public. Nothing from the reviewed cluster is committed: no names, hosts, paths, policy text, ids or generated Terraform (CAP-013 AC5 and AC7).
- The validation scripts keep refusing any address other than `127.0.0.1`.

## Task index

| Task | Title | Capability | Type | Effort | Status |
|---|---|---|---|---|---|
| TASK-R01 | Owner approval and review plan | CAP-013 | delivery | S | Ready to start |
| TASK-R02 | Guarded remote mode | CAP-013 | implementation | M | Ready to start |
| TASK-R03 | Run the review on the approved cluster | CAP-013 | test | L | Blocked |
| TASK-R04 | Sanitised report and harness-reproducible follow-ups | CAP-013 | documentation | M | Blocked |
| TASK-R05 | Optional: plan against a scratch state | CAP-013 | test | S | Blocked |

### TASK-R01: Owner approval and review plan
**Capability**: CAP-013
**Type**: delivery
**Effort**: S
**Depends on**: none
**Status**: Ready to start
**Description**: Agree the cluster, the window, the namespaces in scope, the request-rate limit and who holds the exporter token. Get the approval in writing. The cluster owner provisions the exporter identity with the stage-1 policy using `vault-exporter-setup`.
**Acceptance Criteria**:
- AC: A written approval exists (CAP-013 AC1) and is kept outside the repository if it names internal hosts.
- AC: The exporter policy on the cluster is the stage-1 policy and has no write capability or `sudo` beyond what stage 1 documents.
- AC: The cluster has an audit device whose log the owner can share for the window (AC6).
- AC: Stop here if any item is missing.

### TASK-R02: Guarded remote mode
**Capability**: CAP-013
**Type**: implementation
**Effort**: M
**Depends on**: none
**Status**: Ready to start
**Description**: Add the remote mode from `design.md` section 1 to discovery and codification: `VAULT_CODIFIER_REMOTE=1`, an untracked allow-list, TLS verification on, `VAULT_CACERT` support, `VAULT_SKIP_VERIFY` refused, and an output directory outside the repository with a `git status` guard.
**Acceptance Criteria**:
- AC: Without `VAULT_CODIFIER_REMOTE=1` and an allow-list entry, a non-`127.0.0.1` address is refused as before (AC3).
- AC: `VAULT_SKIP_VERIFY` set to any value is refused (AC4).
- AC: A test shows `zero-diff.sh`, `run-variants.sh` and the harness seeding still refuse a remote address with the mode enabled.
- AC: The guard fails the run when a tracked file would change (AC5).
- AC: The allow-list file is git-ignored and is not committed.
- AC: `make codify-test` still passes and skills stay within 1,500 tokens.

### TASK-R03: Run the review on the approved cluster
**Capability**: CAP-013
**Type**: test
**Effort**: L
**Depends on**: TASK-R01, TASK-R02
**Status**: Blocked
**Description**: Follow the procedure in `design.md` section 2: discovery, codification and the static gate into a directory outside the repository, then the audit-log check for the window.
**Acceptance Criteria**:
- AC: The run uses the exporter identity, never a root or operator token (AC2).
- AC: The audit log shows only read and list requests by the exporter token and none on a secret data path (AC6).
- AC: Output stays outside the repository and `git status` is unchanged.
- AC: Failures at any stage are recorded by stage and error class, not hidden.

### TASK-R04: Sanitised report and harness-reproducible follow-ups
**Capability**: CAP-013
**Type**: documentation
**Effort**: M
**Depends on**: TASK-R03
**Status**: Blocked
**Description**: Write `docs/remote-review.md` with counts only, and open one follow-up per gap with a reproduction on the harness or a scratch variant.
**Acceptance Criteria**:
- AC: The report holds counts, resource types, failed criteria, generator gaps and time taken, and no name, host, path, policy text, id or value from the cluster (AC7). A scan of the file for the cluster's names, which the reviewer keeps outside the repository, finds none.
- AC: Each gap has a follow-up task with a harness reproduction, or is marked unreproduced (AC8).
- AC: The whole-history secret scan reports no credential, and `origin/main` equals local `main`.

### TASK-R05: Optional plan against a scratch state
**Capability**: CAP-013
**Type**: test
**Effort**: S
**Depends on**: TASK-R04
**Status**: Blocked
**Description**: Only if the owner approves separately. Run `terraform plan` on the generated code against a scratch state to measure the zero-diff result on a real cluster. Never `apply`.
**Acceptance Criteria**:
- AC: A separate written approval exists (AC9).
- AC: The plan uses a scratch state and no `apply` is run.
- AC: The result is added to the sanitised report as counts (resources to add, change and destroy).

## Critical path

`TASK-R01` + `TASK-R02` → `TASK-R03` → `TASK-R04` → `TASK-R05` (optional).

## Parallelisation

`TASK-R01` and `TASK-R02` are independent and can run together. Everything after them is sequential.
