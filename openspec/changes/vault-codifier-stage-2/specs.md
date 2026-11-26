# Specs: vault-codifier-stage-2

Capability specs CAP-008 to CAP-012 for stage 2. They extend the stage-1 specs in [`../vault-brownfield-research/specs.md`](../vault-brownfield-research/specs.md), which stay in force. Where stage 2 changes a stage-1 criterion, the change is stated under "Modified criteria".

## Conventions

- The stage-1 conventions apply unchanged: documentation source `git@github.com:hashicorp/web-unified-docs.git`, provider `hashicorp/vault` 4.8.0, Terraform `>= 1.9`, aliased providers (never the resource-level `namespace` argument), read-only discovery, no secrets in output, byte-identical re-runs.
- Provider resource names and import ids in this file are **to be verified** against 4.8.0 by TASK-S01, the same way stage 1 did in TASK-006. Where TASK-S01 disagrees with this file, TASK-S01 wins and this file is corrected.
- The harness is the oracle for CAP-008 to CAP-011. A fixture added to the harness is committed and documented, and `make -C test smoke-test` still passes.
- Every capability here runs against the harness or throwaway containers on `127.0.0.1`. The review of a non-harness cluster is a separate change, [`vault-codifier-remote-review`](../vault-codifier-remote-review/proposal.md).

### Common acceptance criteria (stage 2)

- **CAC8 (no regression)**: after every stage-2 task, `make codify-test` still passes: CAC1 to CAC7 and the 40 `spec-check` criteria. Counts that change because a fixture was added are updated in `spec-check.sh` and `docs/traceability.md` in the same commit.
- **CAC9 (fixture isolation)**: new harness fixtures are synthetic, named with the existing `SYNTHETIC-` convention where they carry a value, and need no network access beyond `127.0.0.1`.
- **CAC10 (secrets)**: no new payload or generated file contains a Duo or Okta key, a TOTP seed or QR code, a database connection password, a cloud access key, or private key material. Sensitive provider arguments become variables with no default.

## CAP-008: Sentinel policies (EGP and RGP)

**Capability**: `sentinel-policies`
**Description**: Discover Sentinel endpoint governing policies and role governing policies in every namespace and emit them as `vault_egp_policy` and `vault_rgp_policy`. The Sentinel source is part of the policy and is emitted verbatim.
**Inputs**: `LIST /v1/sys/policies/egp`, `LIST /v1/sys/policies/rgp`, `GET /v1/sys/policies/egp/<name>`, `GET /v1/sys/policies/rgp/<name>`, per namespace.
**Outputs**: `<ns>_sentinel.tf` and `imports_sentinel.tf` in the `policies` layer; `policies/sentinel/<ns>/<name>.sentinel` for each source; the EGP and RGP section of `coverage.md` and `correlation.md`.
**Fixture** (TASK-S02): in root, one EGP on `sys/*` with `enforcement_level = "advisory"` and one RGP on a role with `soft-mandatory`; in `admin/platform`, one EGP and one RGP. Sources are small and synthetic.
**Acceptance Criteria**:
- AC1: Against the extended harness, the output contains exactly the fixture's EGP and RGP resources, each under the provider alias for its namespace, with `name`, `enforcement_level` and `policy` matching the API.
- AC2: A Sentinel source in the output is byte-identical to `GET sys/policies/<kind>/<name>` `.data.policy`.
- AC3: An EGP's `paths` list is emitted in the order Vault returns it, and `enforcement_level` is one of `advisory`, `soft-mandatory`, `hard-mandatory`.
- AC4: `coverage.md` states the number of EGP and RGP policies found per namespace, and "none" for a namespace without any.
- AC5: Policies of the same name in different namespaces do not collide (CAC6).
- AC6: On a cluster without Sentinel (a 404 or 403 on the list endpoints), the codifier records the status in the run report, emits nothing, and exits 0. The stage-1 `empty-cluster` variant still passes.
- AC7: `terraform plan` after import is zero-diff in every layer (CAC2). If the provider cannot read a field back, the generator applies the same `lifecycle { ignore_changes }` treatment as stage 1 and records it in `coverage.md`.
- AC8: The exporter token reads these paths and cannot write to them (CAC4).

## CAP-009: MFA

**Capability**: `mfa`
**Description**: Discover MFA methods and login enforcement rules and emit them. A method's secret material is never read or emitted.
**Inputs**: `LIST /v1/identity/mfa/method`, `GET /v1/identity/mfa/method/<type>/<id>`, `LIST /v1/identity/mfa/login-enforcement`, `GET /v1/identity/mfa/login-enforcement/<name>`.
**Outputs**: `<ns>_mfa.tf`, `imports_mfa.tf` and `mfa.md` in the `teams` layer, next to the identity objects they reference.
**Fixture** (TASK-S02): in `admin`, one TOTP method and one login-enforcement rule that requires it for the `vault-platform-admin` group.
**Acceptance Criteria**:
- AC1: The output contains one `vault_identity_mfa_totp` and one `vault_identity_mfa_login_enforcement` for the fixture, in provider alias `admin`.
- AC2: The enforcement rule references the method and the group through resource references, never UUID literals (as CAP-007 AC7).
- AC3: Duo, Okta and PingID methods, when present, are emitted with their key arguments as variables with no default, and the value never appears in a payload, file, report or log (CAC10).
- AC4: No TOTP seed, QR code or barcode value is read. The discovery stage does not call the generate or admin-generate endpoints.
- AC5: Method ids are UUIDs; they are used only in `imports_mfa.tf`.
- AC6: `mfa.md` lists every method and enforcement rule with its namespace and the groups, entities and mounts it targets.
- AC7: A namespace with no MFA objects produces no empty file.
- AC8: Zero-diff after import (CAC2); import id shapes are recorded by TASK-S01.

## CAP-010: Auth method configuration

**Capability**: `auth-method-config`
**Description**: Emit configuration, not only the mount, for the auth methods that stage 1 left as mounts: LDAP, Kubernetes, AWS, cert, token roles, and JWT/OIDC outside `admin`. Methods outside the slice stay mount-only and are listed for review.
**Fixture** (TASK-S03): a scratch variant, as in TASK-026, that enables each method in a tenant namespace with synthetic configuration. They run on throwaway containers; the committed harness is not touched unless the fixture is small and stable.
**Acceptance Criteria**:
- AC1: For each method in the slice, the output contains the method's configuration resource and its role or group resources, in the owning namespace's alias.
- AC2: `bindpass`, `client_secret`, `token_reviewer_jwt`, `secret_key` and similar fields are sensitive variables with no default, and the fixture value appears in no file (CAC10).
- AC3: A method outside the slice is emitted as `vault_auth_backend` and listed in `coverage.md` as "review manually", as in stage 1.
- AC4: Roles that name a policy not present in the namespace are flagged dangling, as in CAP-006 AC5.
- AC5: `token/` roles are emitted as `vault_token_auth_backend_role`; no token is read or emitted.
- AC6: Ownership: one resource, one file. The `auth-mounts` and `admin-config` ownership split of stage 1 is unchanged (CAP-002 AC5).
- AC7: Zero-diff after import for every emitted resource, or a documented `ignore_changes` for a field the provider cannot read back.

**Modified criteria**: CAP-003 AC1 and AC2 count AppRole mounts and roles only; they stay as written.

## CAP-011: Secrets engine configuration

**Capability**: `engine-config`
**Description**: Emit engine configuration for PKI, database, AWS, transit and SSH. Key material, credentials, issued certificates and generated keys are never read or emitted.
**Fixture** (TASK-S04): a scratch variant with one engine of each type and synthetic configuration.
**Acceptance Criteria**:
- AC1: PKI emits roles, URL configuration and issuer configuration. No private key, no issued certificate and no CA bundle is emitted.
- AC2: Database emits the connection and roles; the connection password and URL userinfo are sensitive variables with no default.
- AC3: AWS emits the backend and roles; access key and secret key are sensitive variables with no default.
- AC4: Transit emits key metadata only (name, type, `deletion_allowed`, `min_decryption_version`); no key version or key bytes.
- AC5: SSH emits roles and no CA private key.
- AC6: An engine type outside the list is emitted as `vault_mount` and listed as "review manually" (CAP-004 AC6 unchanged).
- AC7: Zero-diff after import, or a documented `ignore_changes`.
- AC8: The exporter policy needs read on the engine configuration paths and no new write, no `sudo` beyond stage 1.

**Modified criteria**: CAP-004 AC3 (no secret data) is extended: no engine credential or key either.

## CAP-012: Skill evaluation suite

**Capability**: `skill-evals`
**Description**: A behavioural eval suite for the 23 skills with waza, run against a real executor, with an A/B baseline. It measures whether an agent follows the skills; it does not replace `make codify-test`, which measures the generated output.
**Acceptance Criteria**:
- AC1: Every skill has an `eval.yaml` with at least two tasks: one happy path and one stop condition (for example a root token, a non-`127.0.0.1` address, a missing exporter).
- AC2: Graders are deterministic where possible (file exists, exit code, no forbidden string). Prompt graders are used only where a deterministic check cannot decide, and name their judge model.
- AC3: Evals run against copies in a scratch directory, never against the working tree, and the harness digest is unchanged afterwards.
- AC4: The suite is run with `config.executor` set to a real model. A `mock` executor result is labelled "harness only" and is never reported as agent quality.
- AC5: A baseline run without skills (`--baseline`) is recorded for the same tasks, with pass rates for both.
- AC6: The cost, model, number of trials and date are recorded in `docs/eval-results.md`. The run needs the owner's approval before it spends money.
- AC7: Any skill whose with-skills result is worse than the baseline is listed as a follow-up with a reason.
- AC8: `make evals` runs the suite and exits non-zero on a failed deterministic grader. It is not part of `make codify-test`.

## Traceability

| Spec | Stage-1 capability extended | Harness layer for fixtures | Primary provider resources |
|---|---|---|---|
| CAP-008 `sentinel-policies` | `policies` (CAP-006) | `test/terraform/admin`, `test/terraform/seed` | `vault_egp_policy`, `vault_rgp_policy` |
| CAP-009 `mfa` | `teams` (CAP-007) | `test/terraform/namespaces` | `vault_identity_mfa_totp`, `vault_identity_mfa_duo`, `vault_identity_mfa_okta`, `vault_identity_mfa_pingid`, `vault_identity_mfa_login_enforcement` |
| CAP-010 `auth-method-config` | `auth-mounts` (CAP-003) | scratch variant | `vault_ldap_auth_backend`, `vault_kubernetes_auth_backend_config`, `vault_aws_auth_backend_client`, `vault_cert_auth_backend_role`, `vault_token_auth_backend_role` |
| CAP-011 `engine-config` | `secrets-engines` (CAP-004) | scratch variant | `vault_pki_secret_backend_role`, `vault_database_secret_backend_connection`, `vault_aws_secret_backend`, `vault_transit_secret_backend_key`, `vault_ssh_secret_backend_role` |
| CAP-012 `skill-evals` | none (new) | none | none |

## Dependency order

CAP-008, CAP-009, CAP-010 and CAP-011 are independent of each other and depend on TASK-S01. CAP-012 depends on stable skills, so it runs after the four generators change them.
