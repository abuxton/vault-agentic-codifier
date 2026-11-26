## Why

Stage 1 (`vault-brownfield-research`) turns a live Vault cluster into **new** Terraform. Many clusters are not in that position. Someone has already written Terraform for part of the cluster, and a state file exists. For those teams a second, parallel code base is the wrong result. They need to know:

- which live objects the existing code does not manage (gaps),
- which objects the code or state manages that no longer exist (orphans),
- which objects are managed under an address that does not match their identity (renames),
- which managed objects have drifted from the code,
- and what is the smallest safe change that brings the gaps under management.

Nothing in the repository reads existing Terraform. Stage 1 assumes it owns the output, so it cannot be pointed at a code base that already has owners, labels and state. The only related notes are the `moved {}` and `terraform show -json` hints in `tmp/brownfield-discovery-guide.md`.

This change adds that capability. It is kept apart from stage 2 (more resource coverage) and from `vault-codifier-remote-review` (a real cluster) because it differs in kind: its input is someone else's code and state, and its output is a set of proposals that never edit that code.

## What Changes

- Read an existing Terraform code directory and a local copy of its state (`terraform show -json`), read-only, into a normalised inventory that holds addresses, types and identity keys and no secret values.
- Compare that inventory with the live cluster, using the stage-1 discovery output as the source of live identities, and classify every object: matching, drifted, unmanaged, orphaned, renamed, out of policy or unverifiable.
- Detect attribute drift with a plan-only run on a scratch copy of the user's code and state. Only attribute names are recorded, never values.
- Write an additive overlay in a separate directory: `import {}` blocks for objects that are in code but not in state, the stage-1 generated code for unmanaged objects (as its own root module with its own state), and `moved {}` suggestions for renames. The user's files are never edited.
- Add a fixture generator that builds an "existing code and state" scenario from the harness layers on a throwaway container, and a `make` target that runs the whole flow.

## Capabilities

### New Capabilities

- `code-inventory` (CAP-014): read existing code and a state copy into a secret-free inventory with an identity key per object.
- `reconcile` (CAP-015): classify every live and every inventoried object, and report attribute drift from a plan-only run.
- `adopt-proposals` (CAP-016): an additive overlay of imports, new resources and `moved {}` suggestions, proven by a plan-only check that adds nothing but imports.

### Modified Capabilities

_(None. Stage-1 and stage-2 criteria are unchanged. `vault-exporter-setup` and the exporter policy are not widened: an object the exporter cannot refresh is reported as unverifiable, not made readable.)_

## Impact

- **New skills** (created by the tasks): `discovery-existing-terraform`, `reconcile-existing-terraform`, `codification-adopt-proposals`, `validation-existing-terraform`. They own no Vault resource type; the overlay reuses the stage-1 generators and the ownership table in `vault-codifier-conventions`.
- **Dependencies**: stage 1 complete (`make codify-test` passes); Terraform `>= 1.9`; `hashicorp/vault` provider 4.8.0 on the harness; Vault Enterprise licence for the harness. Stage 2 and `vault-codifier-remote-review` are **not required**. Real clusters stay out of scope until the remote-review guard exists.
- **Risk**: a state file holds secret values. State is read from a copy in a scratch directory, deleted on exit, and no value from it reaches a report, a log or the repository (CAC13).
- **No breaking changes** to stage-1 output or to the validation guards.

## Non-goals

- Rewriting, reformatting or restructuring the user's code, or applying anything to the user's state.
- Remote backends (HCP Terraform, S3) and state pulled by the tool. The user supplies a local state copy.
- Non-Vault providers and Vault Community Edition clusters.
- Running against any cluster except the harness and throwaway containers on `127.0.0.1`. Relaxing that guard belongs to `vault-codifier-remote-review`.
- Choosing a remedy for drift. The report lists the options; the owner of the code decides.
- Documentation references follow the stage-1 rule: Vault documentation is cited as repository-relative paths in `git@github.com:hashicorp/web-unified-docs.git`.
