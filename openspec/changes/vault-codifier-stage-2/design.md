# Design: vault-codifier-stage-2

Decisions for the stage-2 specs (CAP-008 to CAP-012). The review on a non-harness cluster is a separate change: [`vault-codifier-remote-review`](../vault-codifier-remote-review/design.md). Stage-1 design ([`../vault-brownfield-research/design.md`](../vault-brownfield-research/design.md)) and the skills under `skills/` remain authoritative for everything not named here.

## 1. Extend, do not fork

Each new capability extends an existing skill pair rather than adding a parallel pipeline.

| Capability | Discovery change | Codification change | Layer |
|---|---|---|---|
| CAP-008 | `discovery-policies`: add per-namespace EGP and RGP payloads (the list calls already exist) | `codification-policies`: emit `vault_egp_policy`, `vault_rgp_policy`, sources under `policies/sentinel/` | `policies` |
| CAP-009 | `discovery-identity-teams`: add `identity/mfa/*` payloads | `codification-teams`: emit methods and enforcement | `teams` |
| CAP-010 | `discovery-auth-mounts`: read method config and roles for the slice | `codification-auth-mounts`: emit per-method resources | `auth-mounts` |
| CAP-011 | `discovery-secrets-engines`: read engine config for the slice | `codification-secrets-engines`: emit per-engine resources | `secrets-engines` |

The ownership map in `vault-codifier-conventions` gets the new resource types, and `codification-layer-assembly/scripts/check.sh` already routes `vault_egp_policy` and `vault_rgp_policy` to `policies`.

## 2. Slice, not everything

CAP-010 and CAP-011 cover a named slice. A type outside the slice keeps the stage-1 behaviour (mount plus a "review manually" line). The slice is chosen by what real clusters most often hold and what the provider can read back:

- Auth: LDAP, Kubernetes, AWS, cert, token roles, JWT/OIDC outside `admin`.
- Engines: PKI, database, AWS, transit, SSH.

Everything else (Azure, GCP, Consul, Nomad, Okta, SPIFFE, KMIP, secrets sync) is a later stage and is listed in `docs/traceability.md` as deferred.

## 3. Secrets rule for new types

The stage-1 rule holds: no secret value is read into a payload, written to a file, or put in a report. For the new types:

- **Never read**: TOTP seeds and QR codes, private keys, issued certificates, transit key bytes, SSH CA private keys.
- **Read but masked at discovery** (as `admin-config.sh` does for OIDC and LDAP): `client_secret`, `bindpass`, `api_token`, `password`, `secret_key`, `token_reviewer_jwt`, Duo and Okta keys.
- **Emitted as sensitive variables with no default**: every argument the provider needs but Vault does not return.

`verify.sh` gains a marker for each new fixture secret. A fixture value that reaches any file fails CAC3.

## 4. Fixtures

- **Committed harness** (CAP-008, CAP-009): small and stable, so the committed `test/terraform` layers get them. This changes the harness counts, so `spec-check.sh` and the traceability drift table are updated in the same task.
- **Scratch variants** (CAP-010, CAP-011): throwaway containers on `127.0.0.1:18200`, as TASK-026 does. They need several services' worth of synthetic config and would bloat the harness.

## 5. Evals (CAP-012)

waza 0.42.0 supports `waza new eval`, `waza run` with `--baseline`, `--model`, `--judge-model` and `executor: mock`. The mock executor tests the harness, not an agent. So:

- Deterministic graders do most of the work: file checks, exit codes, forbidden strings.
- A real executor is needed for AC4 and AC5. That spends money and needs the owner's approval first (TASK-S10).
- Evals are separate from `make codify-test`, which stays free and offline. Hence `make evals`.

## 6. Risks

| Risk | Mitigation |
|---|---|
| A provider resource cannot read a field back, so a plan never reaches zero diff | TASK-S01 finds this first; `ignore_changes` with a note in `coverage.md`, as stage 1 did for `vault_auth_backend` |
| Fixtures change harness counts and break `spec-check` | Update the counts in the same commit (CAC8) |
| MFA secret handling leaks a seed | CAP-009 AC4 forbids the generate endpoints; `verify.sh` marker check |
| Eval cost | Approval gate in TASK-S10; record cost in `docs/eval-results.md` |
| Scope grows into every engine and method | Named slice in section 2; the rest is deferred in writing |
