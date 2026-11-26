## Why

Stage 1 (`vault-brownfield-research`, 34 of 34 tasks done) codifies the harness cluster with zero diff. Its own report lists what it did not prove:

- EGP, RGP and MFA are mapped but never exercised against a live cluster.
- Auth methods other than AppRole and engines other than KV v2 are emitted as mounts only.
- The 23 skills have structure checks (waza `ready`) but no behavioural eval suite.

Stage 2 closes these three gaps. The first two raise what the codifier can capture. The third measures whether agents follow the skills.

A further gap, that no real cluster has been reviewed, is a separate change: [`vault-codifier-remote-review`](../vault-codifier-remote-review/proposal.md).

## What Changes

- Add Sentinel (EGP and RGP) and MFA fixtures to the harness, and extend discovery and codification to read and emit them.
- Extend discovery and codification from mount-only to configuration for a first slice of auth methods and secrets engines.
- Add a waza eval suite for the skills, with an A/B baseline, and report the results honestly (a mock executor proves the harness only).

## Capabilities

### New Capabilities

- `sentinel-policies` (CAP-008): discover and emit `vault_egp_policy` and `vault_rgp_policy` in every namespace.
- `mfa` (CAP-009): discover and emit MFA methods and login enforcement.
- `auth-method-config` (CAP-010): method and role configuration for LDAP, Kubernetes, AWS, cert, token roles, and JWT/OIDC outside `admin`.
- `engine-config` (CAP-011): engine configuration for PKI, database, AWS, transit and SSH, never key material.
- `skill-evals` (CAP-012): a behavioural eval suite for the skills.

### Modified Capabilities

- `policies` (CAP-006): the EGP and RGP coverage line changes from "none" to a count, and the generator emits resources when present.
- `auth-mounts` (CAP-003) and `secrets-engines` (CAP-004): the "mount-only, review manually" rows for the types above become emitted resources.
- `vault-exporter-setup`: the exporter policy gains read and list on MFA paths. It stays read-only.

## Impact

- **Dependencies**: stage 1 complete (`make codify-test` passes); Vault Enterprise licence with Sentinel and MFA (the harness licence lists both); provider `hashicorp/vault` 4.8.0; waza 0.42.0; for CAP-012 a model executor and cost approval.
- **No breaking changes** to stage-1 output. Stage-1 criteria CAC1 to CAC7 and CAP-001 to CAP-007 keep passing after every task (CAC8).
