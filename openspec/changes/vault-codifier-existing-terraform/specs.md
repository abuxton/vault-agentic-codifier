# Specs: vault-codifier-existing-terraform

Capability specs CAP-014 to CAP-016. They extend the stage-1 specs in [`../vault-brownfield-research/specs.md`](../vault-brownfield-research/specs.md), which stay in force. The change is independent of stage 2 ([`../vault-codifier-stage-2/specs.md`](../vault-codifier-stage-2/specs.md)) and of the remote review ([`../vault-codifier-remote-review/specs.md`](../vault-codifier-remote-review/specs.md)).

## Conventions

- The stage-1 conventions apply unchanged: documentation source `git@github.com:hashicorp/web-unified-docs.git` (cited as repository-relative paths), provider `hashicorp/vault` 4.8.0 on the harness, Terraform `>= 1.9`, read-only discovery, no secrets in output, byte-identical re-runs, provenance header on generated files (CAC7).
- **Three sources, one identity key.** Every object is described by its identity key, `<resource type>|<namespace>|<import id>`, with the namespace as a full path from root (`(root)` for root). The import id comes from the verified table in [`../vault-brownfield-research/task-006-decision.md`](../vault-brownfield-research/task-006-decision.md). The sources are:
  - **Code (C)**: top-level resource blocks of the user's `*.tf` files.
  - **State (S)**: the user's state, supplied as `terraform show -json` output of a local copy.
  - **Live (L)**: the objects on the cluster, taken from the `import {}` blocks that the stage-1 generators produce from the same raw payloads (`discovered_terraform/raw/`). Builtin objects are excluded as in stage 1.
- **The user's code and state are read-only input.** Nothing in this change edits them (CAC12).
- **Provider behaviour is to be verified.** The facts below that depend on provider 4.8.0 (what a plan refresh reads, the shape of state `values` per type) are verified by TASK-E02 and TASK-E04 in the same way stage 1 did in TASK-006 and stage 2 does in TASK-S01. Where a task disagrees with this file, the task wins and this file is corrected.
- **Harness only.** Every capability runs against the harness or a throwaway container on `127.0.0.1`. The address guard is the stage-1 guard, unchanged.

### The existing-code fixture

The oracle for CAP-014 to CAP-016 is a fixture that TASK-E01 builds. It starts a throwaway Vault Enterprise container on `127.0.0.1:18202` (the next port after the stage-1 variants), applies the harness layers from `test/terraform/` to it as the user's "existing" Terraform, takes `terraform show -json` of the resulting state, and then diverges code, state and cluster on purpose. The real harness on `:8200` is never written to.

| Case | Divergence | Expected class |
|---|---|---|
| F1 | Resources left unchanged | `matched` |
| F2 | An ACL policy edited on the cluster after apply (out of band) | `drifted` |
| F3 | A live policy and a live KV mount removed from both code and state | `unmanaged` |
| F4 | A resource block in code that was never applied (no state entry), the live object exists | `unimported` |
| F5 | A resource label renamed in code, state still at the old address | `renamed` |
| F6 | A resource block deleted from code, state entry kept, live object exists | `state-only` |
| F7 | A live object deleted on the cluster after apply | `orphan` |
| F8 | A `vault_kv_secret_v2` block and state entry added (synthetic value) | `out-of-policy` |
| F9 | A resource using `for_each` with a non-literal key, never applied | `unresolved` |
| F10 | A resource whose refresh the exporter token cannot read. TASK-E04 confirms which fixture type this is (an AppRole role is the candidate, because the exporter policy denies the role-id path) or, if none, adds a deny on one path of the throwaway container | `unverifiable` |

TASK-E01 writes the expected class per identity to a committed `expected.json`. Fixture values carry the `SYNTHETIC-` marker convention (CAC9 of stage 2 applies if stage 2 is present; otherwise the stage-1 rule in `AGENTS.md`).

### Classification model

Each identity key is placed in exactly one class. The table is evaluated top to bottom; the first row that matches wins.

| Order | Condition | Class |
|---|---|---|
| 1 | The type is in the forbidden list (`vault_kv_secret_v2`, `vault_kv_secret`, `vault_generic_secret`, `vault_approle_auth_backend_role_secret_id`) | `out-of-policy` |
| 2 | The identity of a code or state object cannot be resolved (non-literal arguments, unsupported type) | `unresolved` |
| 3 | In L, with the same address in C and S, refresh readable, plan shows no change | `matched` |
| 4 | In L, with the same address in C and S, refresh readable, plan shows an update | `drifted` |
| 5 | In L, with the same address in C and S, refresh not readable by the exporter | `unverifiable` |
| 6 | In L, in C at address A, in S at a different address B, and B has no block in C | `renamed` |
| 7 | In L and C, not in S | `unimported` |
| 8 | In L and S, not in C | `state-only` |
| 9 | In L only | `unmanaged` |
| 10 | In C or S, not in L | `orphan` |

### Common acceptance criteria (this change)

- **CAC11 (no regression)**: after every task here, `make codify-test` still passes the stage-1 criteria CAC1 to CAC7 and the 40 `spec-check` criteria. If stage 2 is merged, CAC8 to CAC10 pass too. Counts that change because a fixture was added are updated in the same commit.
- **CAC12 (inputs untouched)**: the code directory and the state file supplied by the user are byte-identical before and after every run (a hash comparison). The codifier reads copies in a `mktemp` directory and deletes them on exit.
- **CAC13 (no state or plan values in output)**: no attribute value from the state, the plan, the live payloads or the fixture appears in any report, inventory, overlay file or log. Records hold types, addresses, identity keys, file names and attribute **names** only. The check injects a marker value into a fixture state attribute and a fixture cluster attribute and finds it nowhere in the output tree. For out-of-policy types, only the type and address are read.
- **CAC14 (read-only against Vault)**: the audit log for the run window shows only `GET` and `LIST` requests by the exporter token, and no request on a secret data path. The plan-only runs set `TERRAFORM_VAULT_SKIP_CHILD_TOKEN=true`, so the provider does not create a child token. The scripts refuse a `VAULT_ADDR` other than `127.0.0.1` or `localhost` with exit 2. The inventory, reconcile and plan-only scripts also refuse a token that carries the `root` policy. The only uses of the harness root token are the fixture builder and the stage-1 `zero-diff` gate on `adopt-new` (CAP-016 AC6), both harness-only.
- **CAC15 (deterministic)**: a second run on the same inputs gives a byte-identical inventory, report and overlay. Output is sorted, and no timestamps are written into generated files.

## CAP-014: Code and state inventory

**Capability**: `code-inventory`
**Description**: Read an existing Terraform code directory and a state copy, read-only, and write a normalised inventory with an identity key per object. State values are never written.
**Inputs**: a code directory (`*.tf` files, not recursive into module sources); a state copy in `terraform show -json` format (`.values.root_module` and `.child_modules`).
**Outputs**: `discovered_terraform/brownfield/inventory.json` and `inventory.md` (git-ignored run state).
**Terraform resource types**: the types the stage-1 generators own (see the ownership table in [`vault-codifier-conventions`](../../../skills/vault-codifier-conventions/SKILL.md)); any other type is recorded and classified `unresolved`.
**Discovery commands** (read-only, local): `terraform show -json <state>` (supplied by the user), static extraction of `resource`, `import`, `moved` and `lifecycle { ignore_changes }` blocks from the code files. No request is sent to Vault.
**Acceptance Criteria**:
- AC1: The tool accepts a state file only in `terraform show -json` shape (`format_version` present and `.values` present). Anything else exits 2 with a message that names the expected format, and no file is written.
- AC2: Each inventory record holds: `type`, `address`, `namespace`, `import_id` (or `null`), `identity_key`, `provider_alias` or the `namespace` argument when set, `file` (for code records), `source` (`code`, `state` or `both`), `ignore_changes` attribute names, and `flags`. No attribute value is recorded (CAC13).
- AC3: Every state instance becomes one record, including instances with an index key (`count`, `for_each`) and instances inside child modules. The module path is part of the address.
- AC4: A code resource whose `name`, `path` or equivalent identity argument is a string literal gets an identity from the code. A code resource with a non-literal argument and no state entry is recorded with `import_id` `null` and flag `unresolved`. It is never dropped.
- AC5: The identity for a state instance is derived from the state `values` using the per-type rule of the task-006 table. TASK-E02 verifies the rule for every type present in the fixture. An unknown type gets `import_id` `null` and flag `unresolved`.
- AC6: Resources of a forbidden type are recorded with `type`, `address` and flag `out-of-policy` only. The state `values` for such an instance are not read by the program (verified by a test that replaces them with a marker).
- AC7: Existing `import {}` and `moved {}` blocks in the user's code are recorded (target address and id), so later capabilities do not propose a duplicate.
- AC8: Existing `ignore_changes` entries are recorded by attribute name. A blanket `ignore_changes = all` is recorded with a warning and does not stop the run (the user's code is not ours to reject).
- AC9: A second run on the same inputs is byte-identical (CAC15). The inputs are unchanged (CAC12).
- AC10: Against the fixture, the inventory holds exactly the identities of cases F1 to F9 that appear in code or state, with the flags that `expected.json` lists.

## CAP-015: Reconcile with the live cluster

**Capability**: `reconcile`
**Description**: Place every identity from code, state and the live cluster in exactly one class, and report attribute drift from a plan-only run on a scratch copy. The report states findings; it does not choose a remedy.
**Inputs**: the CAP-014 inventory; the stage-1 raw payloads of the same cluster (`discovered_terraform/raw/`, produced by `discovery-orchestrator` with the exporter identity); the stage-1 generated `import {}` blocks for those payloads (live identities).
**Outputs**: `discovered_terraform/validation/existing-terraform.json` and `.md`.
**Terraform resource types**: as CAP-014. Plan-only runs use the user's own provider configuration, with the token overridden by environment.
**Discovery commands** (read-only): `GET` and `LIST` requests made by stage-1 discovery; `terraform init -backend=false`, `terraform plan -lock=false -input=false -out=<scratch>` and `terraform show -json <scratch plan>` on a scratch copy.
**Acceptance Criteria**:
- AC1: Every identity key from C, S and L is in exactly one class of the classification model. The sum of the class counts equals the number of distinct identity keys (a partition check in the report).
- AC2: Live identities are those of the stage-1 generated `import {}` blocks. An identity of `vault_generic_endpoint`, which has no import, is taken from its `path` argument. Builtin objects are excluded as in stage 1.
- AC3: Against the fixture, the class of each identity equals `expected.json` for cases F1 to F10, and the report's class counts equal the expected counts.
- AC4: A rename (case F5) is reported as `renamed` with both addresses. It is never reported as a pair of `orphan` and `unimported`, and no destroy-and-create is proposed for it.
- AC5: Attribute drift (case F2) comes from a plan-only run in a scratch directory: the user's code and state copy, `terraform init -backend=false`, `-lock=false`, the exporter token, `TERRAFORM_VAULT_SKIP_CHILD_TOKEN=true`. The run never applies, imports, or edits state. The report records the attribute **names** whose before and after differ, and for a sensitive attribute only the name and the word `sensitive` (CAC13).
- AC6: A resource the exporter cannot refresh (case F10) is classed `unverifiable` with the HTTP status class recorded (for example 403). The run continues for the other resources (for example by targeting the readable set). The exporter policy is not widened. TASK-E04 records which fixture types are unreadable and why.
- AC7: The report lists, per class, the count, the identity keys with their addresses, and the owning capability from the ownership table. It lists `unresolved` and `unverifiable` identities explicitly and never folds them into another class.
- AC8: The report lists remedy **options** per class and no more (for example `state-only`: restore the block or add a `removed {}` block with `destroy = false`; `drifted`: update the code or let the next apply revert the cluster). It does not choose.
- AC9: The script exits 0 when the report is complete, whatever the findings. It exits 1 on a tool error and 2 on a guard refusal (non-local address, root token, input in the wrong format).
- AC10: A second run on the same inputs is byte-identical (CAC15), the inputs are unchanged (CAC12), and the audit log is read-only (CAC14).

## CAP-016: Adopt proposals (additive overlay)

**Capability**: `adopt-proposals`
**Description**: Write an overlay that, if the user chooses to apply it, brings gaps under management with the smallest change. The overlay is additive: it lives in its own directory and never edits the user's files. A plan-only check proves it adds nothing except imports.
**Inputs**: the CAP-015 report; the stage-1 generated code for the live objects.
**Outputs** under `discovered_terraform/brownfield/overlay/` (git-ignored run state):
- `adopt-existing/imports.tf`: one `import {}` block per `unimported` identity, with `to` set to the user's address.
- `adopt-existing/moved.tf.proposed`: `moved {}` blocks for each `renamed` identity. The `.proposed` extension keeps Terraform from reading it until the user renames the file.
- `adopt-new/<layer>/`: the stage-1 resource blocks, filtered to `unmanaged` identities, as a **separate root module with its own providers and its own state**.
- `README.md`: what each file is, the order to apply it, and the options that need a human decision.
**Terraform resource types**: those of the stage-1 owners. The overlay introduces no new owner and no new type.
**Acceptance Criteria**:
- AC1: The user's code directory and state copy are byte-identical before and after the run (CAC12). The overlay is written only under `discovered_terraform/brownfield/overlay/`.
- AC2: `imports.tf` has exactly one `import {}` block per `unimported` identity, with the id from the task-006 table. There is no block for `vault_generic_endpoint`. A block already present in the user's code (CAP-014 AC7) is not proposed again.
- AC3: **Import gate.** In a scratch copy of the user's code plus `imports.tf` plus the state copy, the plan contains the same non-import changes as the plan without the overlay, and exactly as many imports as proposals. An overlay that adds a create, update or destroy fails the gate, and the report marks nothing as adoptable.
- AC4: **Move gate.** In a scratch copy where `moved.tf.proposed` is renamed to a `.tf` file, the plan shows each renamed identity as a move and shows no destroy or create for it.
- AC5: `adopt-new` holds only blocks of `unmanaged` identities, copied from the stage-1 generated output with their provenance header (CAC7). The stage-1 ownership check (`make ownership` logic) passes on it: labels unique per type per layer, one import per resource, owner matches type, no forbidden type.
- AC6: **New-resource gate.** The stage-1 `zero-diff` logic, run on `adopt-new` against the fixture container, imports into a scratch state and then `terraform plan -detailed-exitcode` exits 0 in every layer present. This is the only `apply` in the change, it is import-only, and it never targets the user's state.
- AC7: No `out-of-policy` object is proposed in any file, and no value from state, plan or payloads is written (CAC13).
- AC8: `orphan`, `state-only`, `drifted`, `out-of-policy`, `unresolved` and `unverifiable` identities produce no overlay file. The `README.md` lists them with the options from CAP-015 AC8.
- AC9: A second run on the same inputs is byte-identical (CAC15).
- AC10: Against the fixture, the overlay holds exactly the identities of F3 (in `adopt-new`), F4 (in `imports.tf`) and F5 (in `moved.tf.proposed`), and nothing for F2 and F6 to F10.

## Traceability

| Spec | Stage-1 capability extended | Harness layer for fixtures | Primary provider resources |
|---|---|---|---|
| CAP-014 `code-inventory` | none (new input side) | `test/terraform/` applied on a throwaway container | all stage-1 owner types, as found in the user's code |
| CAP-015 `reconcile` | CAP-001 to CAP-007 (live identities come from their generators) | same container, diverged | all stage-1 owner types |
| CAP-016 `adopt-proposals` | CAP-001 to CAP-007 (generators reused, no new owner) | same container, diverged | those of the stage-1 owners; `import {}` and `moved {}` blocks |

## Dependency order

`code-inventory` → `reconcile` → `adopt-proposals`. The change runs after stage 1 and does not depend on stage 2 or on the remote review.
