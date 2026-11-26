# Design: vault-codifier-remote-review

Decisions for CAP-013. Stage-1 design and the skills under `skills/` remain authoritative for everything not named here.

## 1. Remote mode without weakening the guard

The repository's safety rule is that every script refuses an address other than `127.0.0.1`. Remote review needs an exception without weakening the rule for the rest:

- Only discovery and codification may run remotely, and only with `VAULT_CODIFIER_REMOTE=1` plus an address listed in an untracked allow-list file.
- The scripts that apply, plan or mutate (`zero-diff`, `run-variants`, harness seeding) never accept a remote address.
- TLS verification stays on.
- Output goes outside the repository. A guard compares `git status` before and after.
- Because the repository is public, the committed report is counts only.

A plan against the real cluster is a separate step with a separate approval, `plan` only.

## 2. Procedure

1. Owner approval is recorded (CAP-013 AC1). Stop here if it is missing.
2. Provision the exporter identity on the cluster with `vault-exporter-setup`. The owner, not the agent, creates it.
3. Run discovery with `VAULT_CODIFIER_REMOTE=1`, `VAULT_ADDR`, `VAULT_CACERT` and the exporter token, into an output directory outside the repository.
4. Run codification and the static gate on the output. These need no cluster access.
5. Check the cluster's audit log for the run window (AC6).
6. Write the sanitised report (AC7). Turn each gap into a harness-reproducible follow-up (AC8).
7. Only if the owner approves separately, run `terraform plan` against a scratch state (AC9).

## 3. What the report may contain

Counts per resource type, criteria that failed, generator errors by stage, time taken, and the stage-1 or stage-2 version. It may not contain a namespace name, mount path, policy name or text, host, id, role name or any value read from the cluster.

## 4. Risks

| Risk | Mitigation |
|---|---|
| Real-cluster data reaches a public repository | CAP-013 AC5 and AC7; `git status` guard before and after; the report holds counts only |
| The remote exception spreads to the validation scripts | The allow-list applies to discovery and codification only; a test asserts `zero-diff` and `run-variants` still refuse a remote address |
| The exporter token is over-privileged on the real cluster | `vault-exporter-setup` creates the stage-1 policy; the audit check (AC6) fails the review on any write |
| Load on a production cluster | The stage-1 run issued 221 read requests on the harness; the window and a request-rate limit are agreed in the approval |
| A finding cannot be reproduced on the harness | Recorded as unreproduced with the stage and error class, still counted in the report |
