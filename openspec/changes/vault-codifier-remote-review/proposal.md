## Why

Stage 1 (`vault-brownfield-research`) was verified only on the local harness at `127.0.0.1:8200`, which the authors built. No real cluster has been reviewed. The harness cannot show what a production cluster holds that the authors did not think of: unusual mount types, large namespace trees, policies that reference missing objects, tuned mounts, and settings that return an unexpected status.

This change runs the codifier read-only against a real Vault Enterprise cluster, with the owner's approval, and turns what it finds into harness-reproducible follow-ups.

It is kept apart from stage 2 (`vault-codifier-stage-2`) because it differs in kind. Stage 2 adds capability and is tested on the harness. This change needs a real cluster, an owner's written approval, and a relaxed address guard, and its outcome depends on someone else's system.

Related: [`vault-codifier-existing-terraform`](../vault-codifier-existing-terraform/proposal.md) handles clusters that already have Terraform. It is harness-only until the guarded remote mode of this change exists.

## What Changes

- Add a guarded remote mode to discovery and codification, so they can run against an address other than `127.0.0.1` when explicitly allowed.
- Run a first review on one approved cluster and record a sanitised report.
- Turn each gap found into a follow-up task with a reproduction on the harness.

## Capabilities

### New Capabilities

- `remote-review` (CAP-013): a guarded, read-only review of a non-harness cluster. The spec is in [`specs.md`](specs.md).

### Modified Capabilities

_(None. Stage-1 and stage-2 criteria are unchanged. The `127.0.0.1` guard in the validation scripts is not relaxed.)_

## Impact

- **Dependencies**: stage 1 complete (`make codify-test` passes). Stage 2 (`vault-codifier-stage-2`) is **recommended first**, so the review tests the finished codifier, but it is not required: the review can run on stage 1 alone and then report which stage-2 capabilities it would have needed. A cluster owner, a window and written approval. An exporter identity on that cluster (`vault-exporter-setup`).
- **Risk**: the repository is public. Output from a real cluster must never be committed. See CAP-013 AC5 and AC7.
- **No breaking changes** to stage-1 output or to the validation guards.
