# Specs: vault-codifier-remote-review

One capability spec, CAP-013. It extends the stage-1 specs in [`../vault-brownfield-research/specs.md`](../vault-brownfield-research/specs.md), which stay in force, and is independent of the stage-2 specs in [`../vault-codifier-stage-2/specs.md`](../vault-codifier-stage-2/specs.md).

## Conventions

- The stage-1 conventions apply unchanged: read-only discovery, no secrets in output, aliased providers, byte-identical re-runs.
- This is the only capability that touches a cluster outside `127.0.0.1`.
- The stage-1 common criteria CAC1 to CAC7 apply to the generated output of the reviewed cluster, but the output stays outside the repository. Only the results are reported (AC7).

## CAP-013: Review on a non-harness cluster

**Capability**: `remote-review`
**Description**: Run the stage-1 pipeline against a real Vault Enterprise cluster, read-only, with the owner's written approval, and record what the codifier got right and wrong. The generated Terraform and raw payloads of a real cluster stay out of the repository.
**Acceptance Criteria**:
- AC1: A written approval from the cluster owner exists before the first request. It records the cluster name, the window, the namespaces in scope and who holds the exporter token. The approval is not committed if it names internal hosts.
- AC2: The run uses a purpose-built exporter identity (`vault-exporter-setup`), never a root token and never an operator token. The existing stop conditions for root tokens and a missing audit device apply.
- AC3: A remote mode relaxes only the `127.0.0.1` guard in discovery and codification, and only when `VAULT_CODIFIER_REMOTE=1` and an explicit allow-list entry for the address are set. The validation scripts that apply or plan against the harness keep refusing any other address.
- AC4: TLS verification is on. `VAULT_SKIP_VERIFY` is refused. A private CA is passed with `VAULT_CACERT`.
- AC5: Output goes to a directory outside the repository, or one that is git-ignored. A check fails the run if any file under a tracked path would change.
- AC6: The cluster's audit log shows only read and list requests by the exporter token, and no request on a secret data path (CAC4).
- AC7: The run's findings are recorded in a sanitised report in the repository: counts, resource types, criteria that failed, generator gaps, and time taken. No names, hosts, paths, policy text or ids from the cluster.
- AC8: Each gap found becomes a follow-up task with a reproduction on the harness, so the fix is tested without the real cluster.
- AC9: A plan of the generated code against the real cluster is run only if the owner approves it separately. It uses a scratch state and `terraform plan` only, never `apply`.

## Traceability

| Spec | Stage-1 capability extended | Harness layer for fixtures | Primary provider resources |
|---|---|---|---|
| CAP-013 `remote-review` | all (CAP-001 to CAP-007) | none (a real cluster); follow-up gaps get harness fixtures (AC8) | none |

## Dependency order

Runs after stage 2 where possible, so the review tests the finished codifier. It does not depend on it.
