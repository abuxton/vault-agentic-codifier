# Tasks: vault-brownfield-research

This artifact breaks the `vault-brownfield-research` change into implementation tasks. It derives from [`proposal.md`](proposal.md), [`specs.md`](specs.md) (CAP-001 to CAP-007 and the common acceptance criteria CAC1 to CAC7) and [`design.md`](design.md) (4-phase pipeline, 3-layer state structure).

## Baseline

| Item | Value |
|---|---|
| Vault | Vault Enterprise 2.2.2+ent (`hashicorp/vault-enterprise:2.2.2-ent`) |
| Provider | `hashicorp/vault` `~> 4` (harness lock files pin `4.8.0`) |
| Terraform | `>= 1.9` (import blocks) |
| Vault CLI | `>= 1.17` |
| Test harness | `test/` — Vault dev-ha at `http://127.0.0.1:8200`, root token `root`; `make -C test all` then `make -C test smoke-test` passes |
| Research artifacts (done) | `tmp/domain-model.md`, `tmp/terraform-resource-map.md`, `tmp/brownfield-discovery-guide.md`, `tmp/hvd-alignment-matrix.md` |
| OpenSpec artifacts (done) | `proposal.md`, `specs.md`, `design.md` |

## Conventions

- **Effort**: S ≤ 0.5 day, M ≈ 1 day, L ≈ 2–3 days, XL > 3 days.
- **Status**: `Ready to start` means all dependencies are already satisfied. `Blocked` means at least one dependency task is incomplete.
- **CAC1–CAC7** are the common acceptance criteria in `specs.md`; **CAP-NNN ACn** refers to a numbered acceptance criterion in that capability's spec.
- The codifier is read-only against Vault (CAC4). No task may add a write call to the cluster under test; only the harness (`test/terraform/*`) and scratch fixtures may write.
- Where `design.md` and `specs.md` differ, `specs.md` is authoritative. Two known differences are resolved in TASK-001: output paths (`root/`, `admin/`, `namespaces/` per spec versus `admin/`, `namespaces/`, `seed/` per design) and `vault_kv_secret_v2` (listed in the design resource map; forbidden by CAP-004 AC3).
- Dependency order of capabilities at run time (from `specs.md`): `namespaces` → `root-config` → `policies` → `auth-mounts` → `secrets-engines` → `teams` → `admin-config`.

## Task index

| Task | Title | Phase | Capability | Type | Effort | Status |
|---|---|---|---|---|---|---|
| TASK-001 | Project scaffolding and output layout | 1 | N/A | implementation | M | **Done** |
| TASK-002 | Provider and version-pin template | 1 | N/A | implementation | S | **Done** |
| TASK-003 | Deterministic naming and label library | 1 | N/A | implementation | M | **Done** |
| TASK-004 | Provenance headers and secret-scrubbing guard | 1 | N/A | implementation | M | **Done** |
| TASK-005 | Read-only Vault API client and run report | 1 | N/A | implementation | M | **Superseded** |
| TASK-006 | Resolve specs open items | 1 | N/A | research | M | **Done** |
| TASK-007 | Namespace discovery | 2 | CAP-005 | implementation | M | Done — validated |
| TASK-008 | Root-config discovery | 2 | CAP-001 | implementation | M | Done — validated |
| TASK-009 | Policy discovery | 2 | CAP-006 | implementation | M | Done — validated |
| TASK-010 | Auth-mount discovery | 2 | CAP-003 | implementation | L | Done — validated |
| TASK-011 | Secrets-engine discovery | 2 | CAP-004 | implementation | L | Done — validated |
| TASK-012 | Identity and teams discovery | 2 | CAP-007 | implementation | L | Done — validated |
| TASK-013 | Admin-namespace discovery | 2 | CAP-002 | implementation | M | Done — validated |
| TASK-014 | Discovery orchestrator and raw payload store | 2 | N/A | implementation | M | Done — validated |
| TASK-015 | Namespaces generator | 3 | CAP-005 | implementation | M | Done — validated |
| TASK-016 | Root-config generator | 3 | CAP-001 | implementation | L | Done — validated |
| TASK-017 | Policies generator and correlation matrix | 3 | CAP-006 | implementation | L | Done — validated |
| TASK-018 | Auth-mounts generator | 3 | CAP-003 | implementation | XL | Done — validated (approle; other types backend-only) |
| TASK-019 | Secrets-engines generator | 3 | CAP-004 | implementation | XL | Done — validated (KV v2 config; other engine types mount-only) |
| TASK-020 | Teams generator | 3 | CAP-007 | implementation | XL | Done — validated (harness; OIDC external group checked on a scratch payload) |
| TASK-021 | Admin-config generator (composition) | 3 | CAP-002 | implementation | L | Done — validated (harness; OIDC and LDAP checked on scratch payloads) |
| TASK-022 | Layer assembly, imports and ownership check | 3 | N/A | implementation | L | Done — validated |
| TASK-023 | Static validation gate (fmt, validate, tflint) | 4 | N/A | test | M | Blocked |
| TASK-024 | Zero-diff import and plan against the harness | 4 | N/A | test | L | Blocked |
| TASK-025 | Read-only and no-secrets verification | 4 | N/A | test | M | Blocked |
| TASK-026 | Variant fixtures for edge-case acceptance criteria | 4 | N/A | test | XL | Blocked |
| TASK-027 | Idempotence check and smoke-test integration | 4 | N/A | test | M | Blocked |
| TASK-028 | Write AGENTS.md | 5 | N/A | documentation | M | Blocked |
| TASK-029 | README and usage guide | 5 | N/A | documentation | M | Blocked |
| TASK-030 | Traceability matrix and handoff review | 5 | N/A | documentation | M | Blocked |
| TASK-031 | Exporter identity: policy, entity, group, and agent skill | 1 | N/A | implementation | M | **Done** |
| TASK-032 | Create GitHub repository and publish | 5 | N/A | delivery | S | Ready to start |
| TASK-033 | Waza review of skills TASK-007..021 and fixes | 4 | N/A | test | L | Baseline captured, fixes pending |
| TASK-034 | Terraform MCP availability or documented fallback | 3 | N/A | implementation | S | Ready to start |

---

## Phase 1: Foundation

Project scaffolding, provider configuration and the shared libraries every capability depends on.

### TASK-001: Project scaffolding and output layout
**Capability**: N/A
**Type**: implementation
**Effort**: M
**Depends on**: none
**Status**: Done — layout and constants now live in `skills/vault-codifier-conventions/SKILL.md` (sections 2, 8); `discovered_terraform/` created
**Description**: Create the codifier source layout (discovery, codification, validation and shared-library directories), choose the implementation language, and define the generated-output layout. Reconcile the two layouts in the OpenSpec artifacts: `specs.md` names per-capability output directories (`root/`, `admin/`, `namespaces/`, `policies/`, `auth-mounts/`, `secrets-engines/`, `teams/`), while `design.md` §7 names three state layers (`admin/`, `namespaces/`, `seed/`). Record the mapping in a short layout note (for example root-config → layer `admin/`; admin-config and org-level resources → layer `namespaces/`; tenant mounts, roles and tenant policies → layer `seed/`) so the 3-layer structure remains the state boundary and capability files land inside it. Record a decision on `vault_kv_secret_v2`: specs CAP-004 AC3 forbids it, so the design resource map row for it is superseded.
**Acceptance Criteria**:
- AC: A layout document lists, for each of the 7 capabilities, the generated files named in `specs.md` and the state layer (`admin/`, `namespaces/` or `seed/`) each file belongs to.
- AC: The implementation language and dependency manager are recorded (`design.md` §6.2 pseudocode assumes Python; a shell + `curl` + `jq` implementation is also acceptable), with the tool versions needed.
- AC: The `vault_kv_secret_v2` conflict is documented and resolved in favour of CAP-004 AC3.
- AC: A generated-output directory (for example `discovered_terraform/`) is created and `.gitignore` excludes raw payloads, run reports containing tokens, state files and `*.hclic`.

### TASK-002: Provider and version-pin template
**Capability**: N/A
**Type**: implementation
**Effort**: S
**Depends on**: none
**Status**: Done — provider template in `skills/vault-codifier-conventions/SKILL.md` section 7; `terraform validate` check in section 9
**Description**: Create the shared `terraform {}` and `provider "vault"` templates emitted at the top of each generated layer. Pin `required_version >= 1.9` and `hashicorp/vault ~> 4`. Per ADR-002, set `skip_child_token = true` in the layer 1 and 2 provider blocks. `address` and `token` are supplied through `VAULT_ADDR` and `VAULT_TOKEN` or sensitive variables, never literals. Provide both namespace-targeting styles required by the specs (aliased provider with `provider = vault.<alias>`, and resource-level `namespace`), selected by a single run option.
**Acceptance Criteria**:
- AC: Rendering the template produces `providers.tf` and `versions.tf` that pass `terraform fmt -check` and `terraform validate` (CAC1) inside a scratch directory.
- AC: No token, address or licence value is embedded in the template output (CAC3); `token` appears only as a sensitive `variable` or environment lookup.
- AC: Switching the run option between aliased-provider and resource-level `namespace` changes only the namespace targeting and never both in one run (specs "Namespace targeting in generated HCL").
- AC: `skip_child_token = true` is present in layer 1 and layer 2 provider blocks.

### TASK-003: Deterministic naming and label library
**Capability**: N/A
**Type**: implementation
**Effort**: M
**Depends on**: none
**Status**: Done — naming rules in `skills/vault-codifier-conventions/SKILL.md` section 5
**Description**: Implement the shared function that derives Terraform resource labels and file names from namespace + path + object name, normalising `/` and `-` to `_`, guaranteeing valid identifiers, uniqueness per directory and stability across runs. Include collision handling for same-named objects in different namespaces (for example `default-readonly` in two namespaces) and policy file paths of the form `policies/<namespace>/<name>.hcl`. Include a reference-address helper (for example `vault_namespace.admin`, `vault_policy.admin_namespace_admin.name`) used by the cross-capability references.
**Acceptance Criteria**:
- AC: Unit tests show identical input produces identical labels on repeated calls and across processes (CAC6, CAC5).
- AC: Labels are valid Terraform identifiers (start with a letter or underscore; only letters, digits, `_`, `-` after normalisation); names beginning with a digit are prefixed.
- AC: Two objects with the same name in different namespaces yield distinct labels and distinct policy file paths (CAP-006 AC6).
- AC: Harness examples map as expected, for example `admin/platform` + `secret` mount → `admin_platform_secret`; entity `synthetic-user-platform-sre` in `admin` → `admin_synthetic_user_platform_sre` (CAP-007 AC2).

### TASK-004: Provenance headers and secret-scrubbing guard
**Capability**: N/A
**Type**: implementation
**Effort**: M
**Depends on**: none
**Status**: Done — header and secret guard in `skills/vault-codifier-conventions/SKILL.md` sections 3, 4; verified by grep checks, not unit tests
**Description**: Implement (a) the header-comment writer that stamps every generated file with the owning capability and the documentation path in `git@github.com:hashicorp/web-unified-docs.git` justifying the mapping (CAC7), and (b) a pre-write guard that refuses to emit values that must never reach disk: root/client tokens, AppRole `secret_id`, KV data, `bindpass`, `client_secret`, `oidc_client_secret`, database passwords, licence text, and any field Vault marks sensitive. Sensitive provider arguments are converted into `variable` references (no default) by the guard (CAC3). The doc-path map for each capability is seeded from `tmp/terraform-resource-map.md` and the two validated-design paths named in `specs.md`.
**Acceptance Criteria**:
- AC: A generated sample file begins with a header naming the capability and a repository-relative documentation path (never a local filesystem path) (CAC7).
- AC: Feeding the guard a payload containing a token, `secret_id`, `bindpass` and a string starting `SYNTHETIC-` causes the value to be dropped or replaced by a sensitive `variable`, and a warning is added to the run report (CAC3; CAP-004 AC3; CAP-003 AC5).
- AC: The guard never logs the rejected value itself, only the field name and file.
- AC: Unit tests cover each forbidden field class listed above.

### TASK-005: Read-only Vault API client and run report
**Capability**: N/A
**Type**: implementation
**Effort**: M
**Depends on**: none
**Status**: Superseded — discovery uses the `vault` CLI, `curl` and `jq` with the exporter token (conventions section 1). The Python client was removed; read-only is enforced by the exporter policy and TASK-025
**Description**: Build the single Vault HTTP client all discovery modules use. It permits only `GET` and `LIST` (and `sys/internal/ui/*` reads), sets `X-Vault-Namespace` per call, reads `VAULT_ADDR`/`VAULT_TOKEN`, and raises on any attempt to issue another method (CAC4). Provide uniform handling of 403/404/empty responses (leaf namespaces, missing endpoints, no permission) and a run report that records endpoint, namespace and HTTP status for every non-200 outcome, per CAP-001 AC7. Include retry/backoff and token-expiry detection during long scans (from `tmp/brownfield-discovery-guide.md` troubleshooting).
**Acceptance Criteria**:
- AC: Calling the client with `POST`, `PUT`, `DELETE` or `PATCH` fails before any network request is made (CAC4).
- AC: Against the harness, `LIST sys/namespaces` returns `admin`, and `LIST sys/namespaces` under `X-Vault-Namespace: admin` returns the three tenant namespaces.
- AC: A 403 on one endpoint is written to the run report with endpoint and status and does not abort the run (CAP-001 AC7).
- AC: An empty or 404 `LIST` is treated as an empty set, not an error (supports empty-set requirements in `specs.md` harness facts).
- AC: Tokens never appear in log output or the run report.

### TASK-006: Resolve specs open items
**Capability**: N/A
**Type**: research
**Effort**: M
**Depends on**: TASK-002, TASK-005
**Status**: Done — [`task-006-decision.md`](task-006-decision.md)
**Description**: Close the three open items listed at the end of `specs.md`: (1) confirm the namespace-qualified `terraform import` ID format for each resource type in provider `4.8.0` (mounts, auth backends, AppRole roles, policies, identity objects, audit, quotas, namespaces), verified experimentally against the harness; (2) decide the default namespace-targeting style (aliased provider or resource-level `namespace`); (3) decide which Enterprise features (EGP/RGP, MFA, Sentinel, replication) get dedicated provider resources versus `vault_generic_endpoint`. Record the results in a decision note and update `tmp/terraform-resource-map.md` where it differs.
**Acceptance Criteria**:
- AC: A table lists every resource type produced by CAP-001 to CAP-007 with its verified import ID syntax, each confirmed with a successful `terraform import` or `import {}` plan against the harness.
- AC: The default namespace-targeting style is recorded with its rationale and wired into TASK-002's run option default.
- AC: Each of EGP, RGP, MFA, Sentinel and replication is assigned a dedicated resource or `vault_generic_endpoint` fallback, with a link to the supporting `content/vault/` path in the documentation repository.
- AC: `specs.md` open items are updated or annotated as resolved.

### TASK-031: Exporter identity — policy, entity, group, and agent skill
**Capability**: N/A (cross-cutting prerequisite)
**Type**: implementation
**Effort**: M
**Depends on**: TASK-002, TASK-003
**Status**: Done — `test/terraform/admin/policies/exporter.hcl`, `skills/vault-exporter-setup/SKILL.md`
**Description**: Before any discovery task interrogates a live Vault cluster, the agent running the export must authenticate as a purpose-built `exporter` identity — not as a root token or an operator. This task provisions that identity and documents it as a reusable agent skill.

**What to provision** (Terraform in `test/terraform/admin/`):

1. **`vault_policy` — `exporter`** (`test/terraform/admin/policies/exporter.hcl`):
   - `list` capability on every metadata and structural path: `sys/mounts`, `sys/mounts/*`, `sys/auth`, `sys/auth/*`, `sys/policies/acl`, `sys/policies/acl/*`, `sys/namespaces`, `sys/namespaces/*`, `sys/quotas/rate-limit`, `sys/quotas/rate-limit/*`, `identity/group/name`, `identity/group/name/*`, `identity/entity/name`, `identity/entity/name/*`, `identity/group-alias/id`, `identity/group-alias/id/*`, `identity/entity-alias/id`, `identity/entity-alias/id/*`.
   - `read` capability (no `list`) on structural-only paths: `sys/audit`, `sys/health`, `sys/seal-status`, `sys/host-info`, `sys/license/status`, `sys/replication/status`, `sys/config/ui`, `sys/quotas/config`, `sys/internal/ui/feature-flags`, `sys/mounts/*/tune`.
   - **Explicitly deny** `read` on any secret-data path: `secret/data/*`, `+/secret/data/*`, `+/+/secret/data/*`, `+/+/+/secret/data/*`. This prevents the exporter ever reading actual secret values even if granted by inheritance.
   - **No `create`, `update`, `delete`, or `sudo`** anywhere.
   - **No `read` on `auth/<path>/role-id`** or `auth/<path>/role/<name>/secret-id` endpoints.
   - Annotated to cite HVD least-privilege principle and the audit-logging requirement.

2. **`vault_identity_entity` — `exporter-agent`**: a named entity for the exporter identity, with `metadata = { role = "exporter", managed_by = "terraform" }`.

3. **`vault_identity_group` — `exporters`**: an `internal` group, `policies = ["admin", "exporter"]`, `member_entity_ids` referencing the `exporter-agent` entity. Metadata: `{ purpose = "vault-brownfield-codifier export operations" }`.
   - The `admin` policy in the group grants the discovery reads detailed in `design.md`; the `exporter` policy layers the explicit denies on top.

4. **AppRole role `exporter` on the root-namespace AppRole mount** (or `admin` namespace): `token_policies = ["admin", "exporter"]`, `token_ttl = 3600`, `token_max_ttl = 14400`, `token_num_uses = 0` (tokens usable for the duration of a scan run, single use not appropriate), `secret_id_num_uses = 1`, `bind_secret_id = true`.

**Audit trail**: because Vault Enterprise audit logging is enabled in the harness (file audit device at `/vault/logs/audit.log`), every API call made by a token issued to the `exporter` AppRole role will be logged under the `exporter-agent` entity alias. This provides a complete record of what the codifier read during each export run, satisfying the audit requirement.

**Agent skill** (`skills/vault-exporter-setup/SKILL.md`): Document the provisioning steps, the policy rationale, and the per-run workflow (generate secret-id → `vault write auth/approle/login` → export with resulting token → rotate secret-id). The skill is the canonical reference for any agent that needs to authenticate to Vault for discovery.

**Acceptance Criteria**:
- AC: `test/terraform/admin/policies/exporter.hcl` exists and passes `terraform validate` with zero warnings.
- AC: A token issued to the `exporter` AppRole role can `vault auth list` and `vault namespace list` from root but receives a 403 on `vault kv get -mount=secret billing-service/checkout` in `admin/app-billing`.
- AC: The `exporter-agent` entity appears in `vault identity entity list` output.
- AC: The `exporters` group membership includes `exporter-agent` and carries policies `["admin", "exporter"]`.
- AC: Every API call in a discovery run (TASK-007 through TASK-014) using the exporter token appears in the audit log under the `exporter-agent` alias — verified by `vault audit list` and `cat /vault/logs/audit.log | jq 'select(.auth.display_name | contains("exporter"))'`.
- AC: `skills/vault-exporter-setup/SKILL.md` describes the provisioning steps, policy rationale, and per-run workflow; it cites `git@github.com:hashicorp/web-unified-docs.git` for the HVD least-privilege reference.
- AC: The Terraform resources added to `test/terraform/admin/` apply cleanly with zero diff on a second `terraform apply` (idempotent).

---

## Phase 2: Discovery Engine

Per-capability skills that query the live Vault API with the exporter token (`vault` CLI, `curl`, `jq`) and write raw JSON payloads. Discovery never emits HCL.

### TASK-007: Namespace discovery
**Capability**: CAP-005
**Type**: implementation
**Effort**: M
**Skill**: [`skills/discovery-namespaces/SKILL.md`](../../../skills/discovery-namespaces/SKILL.md)
**Depends on**: TASK-005, TASK-003, TASK-031
**Status**: Done — validated against the harness (Vault 2.2.2+ent): 4 namespaces, parent-before-child, IDs match `vault namespace list -detailed`
**Description**: Implement the recursive depth-first namespace walk from `design.md` §6 (`LIST sys/namespaces` at root, then under `X-Vault-Namespace` for each child; leaf detection on empty/404/403) and read `GET sys/namespaces/<path>` for `id`, `path` and `custom_metadata`. Produce the ordered, parent-before-child namespace list that every other discovery module consumes. Handle depth greater than two.
**Acceptance Criteria**:
- AC: Against the harness the discovered set is exactly `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity` (4 namespaces, max depth 2) (CAP-005 AC1).
- AC: The ordered list places every parent before its children (CAP-005 AC3).
- AC: The root namespace `""` is excluded from the namespace list but recorded separately for root-scoped discovery (CAP-005 AC6).
- AC: A scratch-created `admin/platform/sre-team` is discovered with `depth = 3` (CAP-005 AC5); namespace IDs match `vault namespace list -detailed` (CAP-005 AC7).

### TASK-008: Root-config discovery
**Capability**: CAP-001
**Type**: implementation
**Effort**: M
**Skill**: [`skills/discovery-root-config/SKILL.md`](../../../skills/discovery-root-config/SKILL.md)
**Depends on**: TASK-005, TASK-007, TASK-031
**Status**: Done — validated against the harness (Vault 2.2.2+ent): root payloads under `raw/root/`; `sys/config/ui/headers` needs sudo and LIST (exporter policy fixed); empty LIST 404 = empty set
**Description**: Query the root namespace inputs listed in CAP-001: `sys/audit`, root mount tuning (`sys/mounts` and `/tune`), `sys/quotas/rate-limit` (list and per-name read) and `sys/quotas/config`, `sys/seal-status`, `sys/health`, `sys/host-info`, `sys/license/status` (never the licence text), `sys/replication/status`, `sys/config/ui/headers` and `sys/internal/ui/feature-flags`. Store raw payloads and record unreachable endpoints in the run report.
**Acceptance Criteria**:
- AC: Against the harness, raw payloads show one `file` audit device with `file_path = /vault/logs/audit.log` and the `global-rate-limit` quota with `rate = 1000`, `interval = 60`, `block_interval = 60` (CAP-001 AC1, AC2).
- AC: The licence payload stored contains ID, expiry and features only; no licence text (CAP-001 AC4).
- AC: Replication is recorded as disabled for the harness (CAP-001 AC4).
- AC: Against a fresh `make -C test up` without `seed`, an empty `sys/audit` is captured as an empty object (CAP-001 AC6).
- AC: A token without read access to a `sys/` endpoint produces a run-report entry with endpoint and status, and the module continues (CAP-001 AC7).

### TASK-009: Policy discovery
**Capability**: CAP-006
**Type**: implementation
**Effort**: M
**Skill**: [`skills/discovery-policies/SKILL.md`](../../../skills/discovery-policies/SKILL.md)
**Depends on**: TASK-005, TASK-007, TASK-031
**Status**: Done — validated against the harness (Vault 2.2.2+ent): 10 ACL policies byte-identical to the API; `default-ceiling` is a Vault 2.x built-in and is skipped; EGP/RGP empty
**Description**: For the root namespace and every namespace from TASK-007, `LIST sys/policies/acl` and `GET sys/policies/acl/<name>`, excluding `default` and `root`. Also `LIST sys/policies/egp` and `sys/policies/rgp` (Enterprise), recorded for `coverage.md`. Store the policy text byte-for-byte as returned.
**Acceptance Criteria**:
- AC: Against the harness the discovered non-builtin policies are exactly the 9 names in CAP-006 AC1 across root, `admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`.
- AC: `default` and `root` are not present in the stored set (CAP-006 AC1).
- AC: Stored policy text is unchanged from the API response (input to CAP-006 AC2, AC7).
- AC: EGP/RGP discovery returns "none" for the harness without error (CAP-006 AC8).

### TASK-010: Auth-mount discovery
**Capability**: CAP-003
**Type**: implementation
**Effort**: L
**Skill**: [`skills/discovery-auth-mounts/SKILL.md`](../../../skills/discovery-auth-mounts/SKILL.md)
**Depends on**: TASK-005, TASK-007, TASK-031
**Status**: Done — validated against the harness (Vault 2.2.2+ent): 5 approle mounts, 6 roles; `sys/auth/<m>/tune` needs sudo at every depth (exporter policy fixed); no role-id or secret-id values
**Description**: Per namespace, read `sys/auth` (type, description, config, options, accessor, local, seal_wrap) and `sys/auth/<path>/tune`, then method-specific reads: AppRole `LIST auth/<path>/role` and `GET .../role/<name>`; `GET auth/<path>/config`; `LIST .../groups` and `.../users` for ldap/okta/github; plus jwt/oidc, kubernetes, aws and cert reads listed in CAP-003 outputs. Skip the builtin `token/` mount. Never read `role-id` or `secret-id` endpoints.
**Acceptance Criteria**:
- AC: Against the harness the raw set contains exactly five `approle` mounts (one per namespace) and five roles with the names and namespaces in CAP-003 AC2.
- AC: Role payloads carry `token_ttl = 3600`, `token_max_ttl = 14400`, `secret_id_num_uses = 1` and the per-role `secret_id_ttl` values in CAP-003 AC3.
- AC: No stored payload contains a `role_id` or `secret_id` value (CAP-003 AC5, CAC3).
- AC: A mount whose type has no dedicated reader (for example `userpass`) is recorded with type and tune data and flagged for the fallback path (CAP-003 AC7).
- AC: Accessor values are retained in raw payloads only for accessor-to-path resolution (used by TASK-012).

### TASK-011: Secrets-engine discovery
**Capability**: CAP-004
**Type**: implementation
**Effort**: L
**Skill**: [`skills/discovery-secrets-engines/SKILL.md`](../../../skills/discovery-secrets-engines/SKILL.md)
**Depends on**: TASK-005, TASK-007, TASK-031
**Status**: Done — validated against the harness (Vault 2.2.2+ent): KV v2 `secret/` in root and 3 tenants, `admin` has none; `agent-registry/` (Vault 2.x built-in) is skipped by mount type
**Description**: Per namespace, read `sys/mounts` and `sys/mounts/<path>/tune`, skipping `sys/`, `identity/` and `cubbyhole/`. Read engine configuration read-only: KV v2 `config`; PKI `config/urls`, `config/crl`, `LIST roles`; database `config/<name>` and roles; AWS/Azure/GCP `config/root` (non-secret fields only); Transit key metadata (no key material). Never read secret data paths.
**Acceptance Criteria**:
- AC: Against the harness the raw set contains exactly three `kv` v2 mounts at `secret` in `admin/platform`, `admin/app-billing` and `admin/app-identity`, with the descriptions in CAP-004 AC1; no mounts for `admin` (CAP-004 AC2).
- AC: A dev-mode root `secret/` mount is captured when present and omitted when absent (CAP-004 AC2).
- AC: The module issues no request to a KV `data/` or `metadata/` path that returns secret values; a `grep -r SYNTHETIC` over stored payloads returns no matches (CAP-004 AC3).
- AC: Mounts with `default_lease_ttl`/`max_lease_ttl` of `0` are captured with the raw value; the omit-on-zero decision belongs to the generator (CAP-004 AC5).
- AC: Database and PKI scratch fixtures are captured without failure and without password fields (CAP-004 AC6).

### TASK-012: Identity and teams discovery
**Capability**: CAP-007
**Type**: implementation
**Effort**: L
**Skill**: [`skills/discovery-identity-teams/SKILL.md`](../../../skills/discovery-identity-teams/SKILL.md)
**Depends on**: TASK-005, TASK-007, TASK-010, TASK-031
**Status**: Done — validated against the harness (Vault 2.2.2+ent): admin: 9 groups, 6 entities; root: exporter-agent + AppRole alias; null member lists normalised
**Description**: Per namespace, `LIST identity/group/name` and `GET identity/group/name/<name>` (type, policies, member_entity_ids, member_group_ids, metadata); `LIST identity/entity/name` and `GET .../<name>`; `LIST identity/group-alias/id` and `identity/entity-alias/id` with per-ID reads; and `sys/auth` accessor-to-mount-path resolution using TASK-010 payloads. Capture group and entity IDs only as lookup keys for reference resolution.
**Acceptance Criteria**:
- AC: Against the harness the raw set contains 9 groups (3 tenant-admin, 6 team) and 6 entities in `admin`, and none in other namespaces (CAP-007 AC1, AC2).
- AC: Empty group-alias and entity-alias lists are captured as empty sets with no error (CAP-007 AC3).
- AC: Group metadata includes `tenant` and, for team groups, `team` (input for CAP-007 AC5).
- AC: A scratch-created group in `admin/platform` is discovered under that namespace (CAP-007 AC8).

### TASK-013: Admin-namespace discovery
**Capability**: CAP-002
**Type**: implementation
**Effort**: M
**Skill**: [`skills/discovery-admin-config/SKILL.md`](../../../skills/discovery-admin-config/SKILL.md)
**Depends on**: TASK-005, TASK-007, TASK-010, TASK-031
**Status**: Done — validated against the harness (Vault 2.2.2+ent): no human auth detected; operator policies admin and namespace-admin; 3 operator groups
**Description**: Query the admin-namespace-specific inputs from CAP-002: `GET sys/namespaces/admin`, and with `X-Vault-Namespace: admin`, `sys/auth` plus `auth/<mount>/config` and role/group endpoints for `oidc`, `jwt`, `ldap` and `approle` mounts. Reuse TASK-009, TASK-010 and TASK-012 payloads for policies and identity rather than re-querying. Detect human auth methods (`oidc`, `jwt`, `ldap`).
**Acceptance Criteria**:
- AC: Against the harness the module reports "no human auth method detected in `admin`" (CAP-002 AC3).
- AC: The `admin` namespace `custom_metadata` is captured as empty (CAP-002 AC6).
- AC: Against a variant with `vault auth enable -namespace=admin oidc`, the OIDC mount and its config are captured without client secret values (CAP-002 AC4, CAC3).

### TASK-014: Discovery orchestrator and raw payload store
**Capability**: N/A
**Type**: implementation
**Effort**: M
**Skill**: [`skills/discovery-orchestrator/SKILL.md`](../../../skills/discovery-orchestrator/SKILL.md)
**Depends on**: TASK-007, TASK-008, TASK-009, TASK-010, TASK-011, TASK-012, TASK-013
**Status**: Done — validated against the harness (Vault 2.2.2+ent): `skills/discovery-orchestrator/scripts/run.sh`: exit 0, no non-200s, byte-identical re-run, 221 exporter requests all read/list, none on data/metadata/role-id/secret-id
**Description**: Implement the Phase 1 (Discovery) driver from `design.md` §2.1: run the discovery modules in the dependency order `namespaces` → `root-config` → `policies` → `auth-mounts` → `secrets-engines` → `teams` → `admin-config`; write raw JSON to a per-namespace directory with stable, sorted keys; emit a single run report (endpoints queried, non-200 outcomes, warnings, exit status). Exit non-zero only where a capability spec says so (for example CAP-001 AC7).
**Acceptance Criteria**:
- AC: One command runs all discovery against `VAULT_ADDR`/`VAULT_TOKEN` and produces a raw payload tree with one directory per namespace plus root.
- AC: Two consecutive runs against an unchanged harness produce byte-identical payload trees (input to CAC5); volatile fields (timestamps, request IDs) are stripped or excluded.
- AC: The run report lists all non-200 responses with endpoint, namespace and status; the exit code is 0 for the harness.
- AC: The orchestrator never writes to Vault (verified in TASK-025).

---

## Phase 3: Codification Engine

Per-capability generators that turn raw payloads into Terraform HCL. Each generator writes the files named in the spec outputs, respects resource ownership, and applies TASK-003 naming and TASK-004 headers and guards.

### TASK-015: Namespaces generator
**Capability**: CAP-005
**Type**: implementation
**Effort**: M
**Skill**: [`skills/codification-namespaces/SKILL.md`](../../../skills/codification-namespaces/SKILL.md)
**Depends on**: TASK-007, TASK-003, TASK-004, TASK-002
**Status**: Done — validated (generate.sh; zero-diff import plan)
**Description**: Generate `namespaces/namespaces.tf` (`vault_namespace`, children referencing the parent by resource reference or aliased provider rather than string concatenation), `namespaces/hierarchy.md` (Mermaid tree and a table of full path, parent, namespace ID, custom metadata and depth), `namespaces/namespaces.auto.tfvars.json` or a `locals` map consumed as the ordered namespace list, and `import {}` blocks.
**Acceptance Criteria**:
- AC: Four `vault_namespace` resources are produced; the three tenants carry the `custom_metadata.description` values in CAP-005 AC2; `admin` has no `custom_metadata`.
- AC: Each child refers to its parent by reference (`vault_namespace.admin`); a grep for `"admin/` literals inside `vault_namespace` blocks returns zero matches (CAP-005 AC4).
- AC: No `vault_namespace` is emitted for the root namespace (CAP-005 AC6).
- AC: `hierarchy.md` shows `admin` as parent of the three tenants and the nested scratch namespace at `depth = 3` (CAP-005 AC1, AC5).
- AC: `terraform validate` reports no dependency cycles (CAP-005 AC3, CAC1).

### TASK-016: Root-config generator
**Capability**: CAP-001
**Type**: implementation
**Effort**: L
**Skill**: [`skills/codification-root-config/SKILL.md`](../../../skills/codification-root-config/SKILL.md)
**Depends on**: TASK-008, TASK-003, TASK-004, TASK-002, TASK-006
**Status**: Done — validated (generate.sh; zero-diff import plan)
**Description**: Generate `root/audit.tf` (`vault_audit`), `root/quotas.tf` (`vault_quota_rate_limit`, and `vault_quota_lease_count` when present), `root/sys_config.tf` and `root/replication.tf` (`vault_generic_endpoint` only where no dedicated resource exists and, for replication, only when enabled), `root/README.md` with the "not managed by Terraform" table (seal type, licence ID/expiry, replication mode, each with the reason it cannot be codified), and `root/imports.tf`. Emit no `vault_policy`, `vault_auth_backend`, `vault_mount` or `vault_namespace` (ownership table).
**Acceptance Criteria**:
- AC: Exactly one `vault_audit` with `type = "file"` and `options = { file_path = "/vault/logs/audit.log" }` and an import ID of `file` (CAP-001 AC1).
- AC: Exactly one `vault_quota_rate_limit` named `global-rate-limit` with `path = ""`, `rate = 1000`, `interval = 60`, `block_interval = 60` (CAP-001 AC2).
- AC: No resource types owned by other capabilities appear in `root/` (CAP-001 AC3).
- AC: `root/README.md` records seal type, licence ID/expiry and replication mode; no `root/replication.tf` for the harness (CAP-001 AC4).
- AC: Masked or omitted audit options are not fabricated (CAP-001 AC5); an empty `sys/audit` yields no `vault_audit` and the README states "no audit devices" (CAP-001 AC6).

### TASK-017: Policies generator and correlation matrix
**Capability**: CAP-006
**Type**: implementation
**Effort**: L
**Skill**: [`skills/codification-policies/SKILL.md`](../../../skills/codification-policies/SKILL.md)
**Depends on**: TASK-009, TASK-010, TASK-012, TASK-003, TASK-004, TASK-006
**Status**: Done — validated (generate.sh; zero-diff import plan)
**Description**: Generate `vault_policy` for every ACL policy except `default` and `root`, with documents under `policies/<namespace>/<name>.hcl` loaded via `file("${path.module}/policies/<namespace>/<name>.hcl")` for policies over 10 lines and heredocs for shorter ones; `vault_egp_policy` and `vault_rgp_policy` when present; `policies/correlation.md` (policy × auth mount/role, identity group, identity entity, per namespace, with dangling references flagged); `policies/correlation.json` for the teams generator; `policies/coverage.md`; and `import {}` blocks with `id = "<name>"`.
**Acceptance Criteria**:
- AC: Nine `vault_policy` resources with the exact per-namespace names in CAP-006 AC1.
- AC: Generated policy documents compare equal to `vault policy read -namespace=<ns> <name>` after trailing-newline normalisation (CAP-006 AC2); namespace-relative `path` stanzas such as `secret/data/platform/sre/*` are unchanged (CAP-006 AC7).
- AC: `correlation.md` records `operator` ← `terraform-admin`, `namespace-admin` ← `namespace-provisioner` and the three tenant-admin groups, `platform-devops-write` ← `platform-ci`, `billing-developers-read` ← `billing-service`, `identity-developers-read` ← `identity-service` (CAP-006 AC3, AC4).
- AC: A role or group naming a policy absent from its namespace is marked "dangling" and no `vault_policy` is fabricated (CAP-006 AC5).
- AC: Two same-named policies in different namespaces yield distinct file paths and labels (CAP-006 AC6); `coverage.md` records EGP/RGP as "none" for the harness (CAP-006 AC8).

### TASK-018: Auth-mounts generator
**Capability**: CAP-003
**Type**: implementation
**Effort**: XL
**Skill**: [`skills/codification-auth-mounts/SKILL.md`](../../../skills/codification-auth-mounts/SKILL.md)
**Depends on**: TASK-010, TASK-017, TASK-003, TASK-004, TASK-002, TASK-006
**Status**: Done — validated for approle; other method types are backend-only until TASK-026 variants
**Description**: Generate `vault_auth_backend` (with `tune {}`) per non-builtin mount and the method-specific resources by type (AppRole, jwt/oidc, ldap, kubernetes, aws, cert), one file per namespace and mount (for example `namespaces/admin_platform/auth_approle.tf`). Use `vault_generic_endpoint` for unsupported types with a documented fallback and never emit credentials. `token_policies` cross-reference `vault_policy` resources owned by TASK-017 when the policy exists in the same namespace, otherwise keep the literal and warn. Generate `auth-mounts/coverage.md` and `import {}` blocks. Top-level OIDC/LDAP in the `admin` namespace is left to TASK-021 (ownership table).
**Acceptance Criteria**:
- AC: Exactly five `vault_auth_backend` (`type = "approle"`, `path = "approle"`), one per namespace, and no `token/` mount (CAP-003 AC1).
- AC: Exactly five `vault_approle_auth_backend_role` with the names and namespaces in CAP-003 AC2 and the TTL and `secret_id_num_uses` values in CAP-003 AC3, as integers in seconds.
- AC: `token_policies` use `vault_policy.<label>.name` references where the policy exists, and a warning is written otherwise (CAP-003 AC4).
- AC: No `role_id` (unless explicitly set) or `secret_id` appears in any file (CAP-003 AC5, CAC3).
- AC: `coverage.md` lists all five mounts and five roles with none "unsupported" (CAP-003 AC6); a scratch `userpass` mount produces `vault_auth_backend` plus a documented `vault_generic_endpoint` fallback (CAP-003 AC7).

### TASK-019: Secrets-engines generator
**Capability**: CAP-004
**Type**: implementation
**Effort**: XL
**Skill**: [`skills/codification-secrets-engines/SKILL.md`](../../../skills/codification-secrets-engines/SKILL.md)
**Depends on**: TASK-011, TASK-003, TASK-004, TASK-002, TASK-006
**Status**: Done — validated for KV v2; PKI, database, AWS, transit and SSH engine resources are mount-only until TASK-026 variants
**Description**: Generate `vault_mount` for each non-builtin mount (retaining `options = { version = "2" }` for KV v2), omitting zero-valued lease TTLs and unpinned `plugin_version`, plus engine-specific resources (`vault_kv_secret_backend_v2`, PKI, database, AWS/Azure/GCP, Transit, SSH) where Vault returns configuration. Engine resources reference the mount (for example `mount = vault_mount.admin_platform_secret.path`). Never emit `vault_kv_secret_v2`, `vault_kv_secret`, `vault_generic_secret` or database connection passwords. Generate `secrets-engines/coverage.md` and `import {}` blocks.
**Acceptance Criteria**:
- AC: Exactly three `vault_mount` resources for `admin/platform`, `admin/app-billing` and `admin/app-identity`, with the types, options and descriptions in CAP-004 AC1; none for `admin` (CAP-004 AC2).
- AC: Zero `vault_kv_secret_v2`, `vault_kv_secret` or `vault_generic_secret` resources and no `SYNTHETIC-` strings in output (CAP-004 AC3).
- AC: `sys/`, `identity/` and `cubbyhole/` are never emitted (CAP-004 AC4); zero TTLs are omitted (CAP-004 AC5); `plugin_version` only when pinned (CAP-004 AC7).
- AC: A scratch `database` or `pki` mount produces an engine-specific resource with secret fields as sensitive variables with no default (CAP-004 AC6).
- AC: Engine resources reference `vault_mount` implicitly and `terraform validate` passes (CAP-004 AC8, CAC1).

### TASK-020: Teams generator
**Capability**: CAP-007
**Type**: implementation
**Effort**: XL
**Skill**: [`skills/codification-teams/SKILL.md`](../../../skills/codification-teams/SKILL.md)
**Depends on**: TASK-012, TASK-017, TASK-018, TASK-003, TASK-004, TASK-002, TASK-006
**Status**: Done — validated; alias id added to discovery payloads (import ID)
**Description**: Generate `vault_identity_group`, `vault_identity_entity`, `vault_identity_group_alias` and `vault_identity_entity_alias`, with `member_entity_ids` expressed as resource references and `mount_accessor` as `vault_auth_backend.<label>.accessor`. Choose the exclusive versus non-exclusive membership pattern and record it in the README. Generate `teams/teams.md` (team → namespace → group → entities → auth roles → policies), `teams/teams.json`, and `import {}` blocks. Inferred policy links (for example `platform-sre-read` for `vault-platform-sre`) are marked "inferred" versus Vault-recorded. Create no empty files when no aliases exist.
**Acceptance Criteria**:
- AC: Nine `vault_identity_group` resources in `admin`, all `type = "internal"`, with the policies and metadata in CAP-007 AC1.
- AC: Six `vault_identity_entity` resources named `synthetic-user-<tenant>-<team>` with `metadata = { tenant, team, type = "synthetic" }`, each referenced exactly once from the matching group's `member_entity_ids` via resource reference (CAP-007 AC2).
- AC: No alias resources or empty files for the harness; `teams.md` states "no aliases found" for `admin` (CAP-007 AC3).
- AC: `teams.md` lists the team-to-tenant relationships and namespaces in CAP-007 AC5 and marks inferred policy links for `policies = []` groups (CAP-007 AC6).
- AC: A grep for UUID patterns in `*.tf` other than `imports.tf` returns zero matches (CAP-007 AC7); the OIDC external-group variant emits `type = "external"` and a group alias whose accessor is a reference (CAP-007 AC4).

### TASK-021: Admin-config generator (composition)
**Capability**: CAP-002
**Type**: implementation
**Effort**: L
**Skill**: [`skills/codification-admin-config/SKILL.md`](../../../skills/codification-admin-config/SKILL.md)
**Depends on**: TASK-013, TASK-015, TASK-017, TASK-018, TASK-020, TASK-003, TASK-004, TASK-002
**Status**: Done — validated; ownership split with auth-mounts and teams for human auth mounts
**Description**: Generate the `admin/` composition: `main.tf` with the provider alias for namespace `admin` and references to resources owned by `namespaces`, `policies`, `auth-mounts` and `teams`; `human_auth.tf` only when an `oidc`/`jwt` (`vault_jwt_auth_backend`, `vault_jwt_auth_backend_role`) or `ldap` (`vault_ldap_auth_backend`, `vault_ldap_auth_backend_group`) mount exists, with `bindpass`, `client_secret` and `oidc_client_secret` as sensitive variables with no default; `variables.tf`, `outputs.tf`, `README.md` and `imports.tf`.
**Acceptance Criteria**:
- AC: A provider alias for `admin` is declared and every resource resolves to namespace `admin` (CAP-002 AC1).
- AC: `README.md` lists operator policies `admin` and `namespace-admin`, states that root `operator` belongs to `root-config`/`policies`, and lists the three tenant-admin groups as holders of `namespace-admin` (CAP-002 AC2).
- AC: For the harness `human_auth.tf` is not created and the README states "no human auth method detected in `admin`" (CAP-002 AC3).
- AC: A grep for `resource "vault_auth_backend"` in `admin/` returns zero matches (CAP-002 AC5); the `admin` `vault_namespace` has no `custom_metadata` block (CAP-002 AC6).
- AC: With an `oidc` variant, one `vault_jwt_auth_backend` with `type = "oidc"` and the matching `oidc_discovery_url` is emitted, with no client secret literal (CAP-002 AC4, CAC3).

### TASK-022: Layer assembly, imports and ownership check
**Skill**: [`skills/codification-layer-assembly/SKILL.md`](../../../skills/codification-layer-assembly/SKILL.md)
**Capability**: N/A
**Type**: implementation
**Effort**: L
**Depends on**: TASK-015, TASK-016, TASK-017, TASK-018, TASK-019, TASK-020, TASK-021
**Status**: Done — validated; variables stay in `versions.tf`, `outputs.tf` only in `admin/`
**Description**: Assemble generator output into the three state layers decided in TASK-001 (`admin/`, `namespaces/`, `seed/`), each with `providers.tf`, `versions.tf`, `variables.tf` and `outputs.tf`. Consolidate `import {}` blocks into per-layer `imports.tf` using the import ID formats from TASK-006. Add an ownership checker that fails the run if a resource type appears outside its owning capability (ownership table in `specs.md`) or if two resources in a directory share a label (CAC6). Run in the dependency order from `specs.md`.
**Acceptance Criteria**:
- AC: Output tree follows the layout note from TASK-001; each layer is independently `terraform init`-able.
- AC: The ownership checker reports zero violations for the harness and fails (non-zero exit) on an injected duplicate `vault_policy`.
- AC: Every generated resource has exactly one matching `import {}` block with the verified ID format.
- AC: Every generated file carries the provenance header (CAC7).

---

## Phase 4: Validation & Testing

Verification against the synthetic harness in `test/` and scratch variant fixtures. Phase 4 maps to the SRE role in `design.md` §2.4 and §11.

### TASK-023: Static validation gate (fmt, validate, tflint)
**Capability**: N/A
**Type**: test
**Effort**: M
**Depends on**: TASK-022
**Status**: Blocked
**Description**: Add a validation script/target that runs `terraform fmt -check -recursive`, `terraform init -backend=false`, `terraform validate` and `tflint` in every generated layer directory, mirroring `make -C test fmt validate`. Failures surface file, line and capability owner.
**Acceptance Criteria**:
- AC: All generated layers pass `terraform fmt -check -recursive` and `terraform validate` (CAC1).
- AC: `tflint` reports no errors on generated code, or each suppression is documented in the layout note.
- AC: A deliberately malformed generated file makes the gate fail with a message naming the file and owning capability.
- AC: The gate is invokable with one `make` target and returns a non-zero exit code on failure.

### TASK-024: Zero-diff import and plan against the harness
**Capability**: N/A
**Type**: test
**Effort**: L
**Depends on**: TASK-022, TASK-023, TASK-006
**Status**: Blocked
**Description**: Run `make -C test all`, run the codifier against the harness, then, in a scratch state for each layer in apply order (`admin/`, `namespaces/`, `seed/`), run `terraform init`, apply the generated `import {}` blocks with `terraform apply` (imports only, no resource changes), and follow with `terraform plan -detailed-exitcode`. Record every attribute that needs `lifecycle { ignore_changes = [...] }` (for example values Vault does not return) in the run report.
**Acceptance Criteria**:
- AC: After import, `terraform plan -detailed-exitcode` exits `0` for each layer (CAC2; CAP-003 AC8).
- AC: Every `ignore_changes` entry is listed in the run report with reason; no blanket ignore is used.
- AC: Every namespaced resource resolves to the correct namespace with no replacement in the plan (CAP-002 AC1, CAP-003 AC8).
- AC: The result for each of the seven capabilities is reported separately (pass/fail per capability).
- AC: A destroy-and-reimport cycle in a scratch state yields zero diff (CAP-003 AC8).

### TASK-025: Read-only and no-secrets verification
**Capability**: N/A
**Type**: test
**Effort**: M
**Depends on**: TASK-014, TASK-022
**Status**: Blocked
**Description**: Verify CAC3 and CAC4. Run the codifier with its own dedicated token, then parse the Vault audit log (`/vault/logs/audit.log` in the harness container) and assert no request attributable to that token has an operation other than `read` or `list`. Scan all generated output and stored raw payloads for forbidden content: the root token, AppRole `secret_id`, KV data, `SYNTHETIC-` markers, UUID literals in `*.tf` outside `imports.tf`, and sensitive provider arguments.
**Acceptance Criteria**:
- AC: The audit-log check reports zero non-`read`/`list` operations for the codifier token (CAC4).
- AC: `grep -r SYNTHETIC` and a scan for the root token and `secret_id` over output and raw payloads return no matches (CAC3; CAP-004 AC3; CAP-003 AC5).
- AC: A UUID-pattern grep over `*.tf` excluding `imports.tf` returns zero matches (CAP-007 AC7).
- AC: The check fails when a test write call is injected into the client, confirming the verifier is effective.

### TASK-026: Variant fixtures for edge-case acceptance criteria
**Capability**: N/A
**Type**: test
**Effort**: XL
**Depends on**: TASK-022, TASK-024
**Status**: Blocked
**Description**: Create scratch fixtures that exercise the acceptance criteria the base harness cannot reach, applied out of band (CLI/Terraform in a throwaway harness copy, never modifying the committed `test/terraform/*` layers without review): `oidc` mount in `admin` with an external group and group alias; `userpass` in `admin/app-billing`; `database` or `pki` in `admin/platform`; nested namespace `admin/platform/sre-team`; a group in `admin/platform`; `default-readonly` policy in two namespaces; a role naming a policy missing from its namespace; an empty cluster (`make -C test up` without `seed`); and a restricted token that receives 403 on a `sys/` endpoint.
**Acceptance Criteria**:
- AC: Each scenario above has a documented fixture, an expected-output assertion, and a pass/fail result in a test report.
- AC: The scenarios cover CAP-001 AC6/AC7, CAP-002 AC4, CAP-003 AC7, CAP-004 AC6, CAP-005 AC5, CAP-006 AC5/AC6, and CAP-007 AC4/AC8.
- AC: Each variant run also passes CAC1, CAC3 and CAC4.
- AC: Fixtures are teardown-safe (`make -C test clean` returns the harness to its baseline).

### TASK-027: Idempotence check and smoke-test integration
**Capability**: N/A
**Type**: test
**Effort**: M
**Depends on**: TASK-023, TASK-024, TASK-025, TASK-026
**Status**: Blocked
**Description**: Add the CAC5 check (run the codifier twice against an unchanged cluster and diff output byte-for-byte) and wire all Phase 4 checks into a single repeatable target (for example `make codify-test`) alongside the existing `make smoke-test`. Confirm `make smoke-test` still passes after the codifier runs, since the codifier must leave the harness unchanged.
**Acceptance Criteria**:
- AC: Two consecutive runs produce byte-identical output trees (CAC5).
- AC: One command runs: harness up → codify → static gate → import/plan zero-diff → read-only and secrets checks, and exits `0` only if every stage passes.
- AC: `make -C test smoke-test` passes before and after the codifier run.
- AC: The target prints a per-capability and per-CAC pass/fail summary.

---

## Phase 5: Documentation & Handoff

### TASK-028: Write AGENTS.md
**Capability**: N/A
**Type**: documentation
**Effort**: M
**Depends on**: TASK-022, TASK-027
**Status**: Blocked
**Description**: Author the repository `AGENTS.md` (referenced as "not yet written" in `PROJECT_BRIEF.md`). Cover the four roles (Vault Expert, Solution Architect, SRE, Technical Writer) and their deliverables from `design.md` §3; build and test commands (`make -C test all`, `smoke-test`, the Phase 4 target); the read-only rule; the secrets rule and synthetic-data convention (`SYNTHETIC-*-REPLACE-IN-PRODUCTION`); the capability dependency order; resource ownership table; documentation source repository convention; the licence rule (`/tmp/vault.hclic`, never committed); and where research artifacts live.
**Acceptance Criteria**:
- AC: `AGENTS.md` exists at repo root and lists commands verified to run as written.
- AC: It states the read-only rule, no-secrets rule and licence rule as explicit constraints.
- AC: It references `openspec/changes/vault-brownfield-research/` artifacts and `tmp/` research files by relative path.
- AC: `PROJECT_BRIEF.md` Contributing section is updated to link to the real `AGENTS.md`.

### TASK-029: README and usage guide
**Capability**: N/A
**Type**: documentation
**Effort**: M
**Depends on**: TASK-022, TASK-027
**Status**: Blocked
**Description**: Write the top-level `README.md` and a usage guide that takes an engineer from a live cluster to reviewed HCL: prerequisites and token permissions (from `tmp/brownfield-discovery-guide.md`), running discovery and codification, reading the run report, the layer layout, applying imports against a real cluster, handling the "not managed by Terraform" items, and troubleshooting (403, leaf namespaces, token expiry). Keep the secret-handling guidance (sensitive variables, replacing synthetic values).
**Acceptance Criteria**:
- AC: A reader following the guide on a clean machine can reproduce a harness run and zero-diff plan.
- AC: Every command in the guide has been executed once and works as written.
- AC: Documentation citations use repository-relative paths in `git@github.com:hashicorp/web-unified-docs.git`, not local paths (specs "Documentation source").
- AC: The guide states the required token policy (read/list only) and links to `tmp/brownfield-discovery-guide.md`.

### TASK-030: Traceability matrix and handoff review
**Capability**: N/A
**Type**: documentation
**Effort**: M
**Depends on**: TASK-027, TASK-028, TASK-029
**Status**: Blocked
**Description**: Produce a traceability matrix mapping each CAP-001 to CAP-007 acceptance criterion and each CAC to the task that implements it and the test that verifies it, and reconcile `tmp/` research artifacts (`domain-model.md`, `terraform-resource-map.md`, `brownfield-discovery-guide.md`, `hvd-alignment-matrix.md`) with what was actually built (resolved import IDs from TASK-006, the resolved layout from TASK-001). Run an OpenSpec verification pass and list any acceptance criteria not met as follow-up items.
**Acceptance Criteria**:
- AC: Every acceptance criterion in `specs.md` (CAP-001 AC1–AC7, CAP-002 AC1–AC6, CAP-003 AC1–AC8, CAP-004 AC1–AC8, CAP-005 AC1–AC7, CAP-006 AC1–AC8, CAP-007 AC1–AC8, CAC1–CAC7) maps to at least one task and one verifying test, or is listed as an explicit gap.
- AC: `tmp/*.md` research artifacts are updated where they disagree with the implemented behaviour, or annotated with the divergence.
- AC: A final `make codify-test` run result is attached to the handoff note.
- AC: Remaining risks and deferred items (for example Enterprise features routed to `vault_generic_endpoint`) are listed with an owner role.

---

### TASK-032: Create GitHub repository and publish
**Capability**: N/A
**Type**: delivery
**Effort**: S
**Depends on**: TASK-033 (so the first push carries the reviewed skills); TASK-025 for the final read-only and no-secrets sign-off
**Status**: Ready to start (`gh` was not authenticated in the session that wrote this task; run `gh auth login` first)
**Description**: Create the GitHub repository for `terraform-vault-vault-codifier`, add it as `origin`, and push `main`. Decide the owner (`abuxton` or an organisation) and visibility before creating it. Before the first push, confirm that nothing sensitive is tracked: `*.hclic`, `discovered_terraform/raw/`, `.state.json`, `run_report.json`, any `terraform.tfstate*` under `test/terraform/`, and the untracked agent tooling (`.github/`, `.mcp.json`, `.opencode/`, `skills-lock.json`). Decide for each whether it is committed or ignored.
**Acceptance Criteria**:
- AC: `git remote -v` shows `origin`; `git ls-remote origin main` equals local `main`.
- AC: `git ls-files | grep -E '\.hclic$|terraform\.tfstate|/raw/|\.state\.json|run_report\.json'` returns nothing (the harness `terraform.tfstate` files are ignored or removed from the index).
- AC: A secret scan of the pushed history (for example `gitleaks detect`) reports no findings; the harness root token `root` is documented as harness-only.
- AC: The repository has a description, topics (`vault`, `terraform`, `agent-skills`), and a licence decision recorded in the README.
- AC: `HANDOFF.md` §10 records the remote URL.

### TASK-033: Waza review of skills TASK-007..021 and fixes
**Capability**: N/A
**Type**: test
**Effort**: L
**Depends on**: TASK-007..018 (validated); TASK-019..021 for their three skills
**Status**: Baseline captured (waza 0.38.7, `waza check`, 2026-11-24); fixes pending
**Tool**: [microsoft/waza](https://github.com/microsoft/waza) (`waza check`, `waza tokens`, `waza suggest`, `waza spec verify`). Installed at `~/bin/waza`, version 0.38.7; the current published release is v0.42.0, so run `waza update` first. Disable the update check and product telemetry in scripted runs: `WAZA_NO_UPDATE_CHECK=1 WAZA_TELEMETRY_OPTOUT=1`. Waza is a Go CLI and is a review tool only; it adds no runtime dependency to the skills.
**Scope**: the 17 skills under `skills/`: `vault-codifier-conventions`, `vault-exporter-setup`, the 8 `discovery-*` skills (TASK-007..014), and the 7 `codification-*` skills (TASK-015..021). TASK-022 and TASK-023..027 skills are reviewed when authored.
**Baseline (`waza check`, 17 skills)**:

| Finding | Count | Meaning |
|---|---|---|
| Token budget exceeded | 17 of 17 | Every `SKILL.md` is 1,909 to 3,391 tokens against a default 500 limit; the total is 45,367 tokens |
| `spec-allowed-fields` | 17 of 17 | Frontmatter fields `triggers`, `capability`, `task`, `depends_on`, `role` are not in the agentskills.io spec (`name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility`) |
| `body-structure` | 17 of 17 | No examples section and no troubleshooting section as waza defines them |
| `complexity` | 17 of 17 | Rated "comprehensive" |
| `over-specificity` | 16 of 17 | Absolute paths such as `/opt/homebrew/bin/...` and hard-coded URLs |
| `procedural-content` | 11 of 17 | The description lacks procedural lead words |
| `negative-delta-risk` | 9 of 17 | Patterns that can make an agent perform worse than without the skill |
| Compliance level | 16 Low, 1 Medium (`vault-exporter-setup`) | |
| Eval suite | none | No `eval.yaml` for any skill |

**Description**: Review every skill with waza, decide each finding, and fix the real ones. Work in this order:
1. **Config.** Add `.waza.yaml` with `tokens.limits` set deliberately. Reference-heavy operational skills are not 500-token skills; set a limit per glob (for example `skills/discovery-*/SKILL.md` and `skills/codification-*/SKILL.md`) from the measured sizes and record the reason. Do not raise it to hide the problem.
2. **Frontmatter.** Move `triggers`, `capability`, `task`, `depends_on`, `role` under `metadata:` (the spec permits it), keep `name` and `description`, and fold the trigger phrases into the description as "USE FOR" and "DO NOT USE FOR" text. Confirm Bob and Claude Code still load the skills.
3. **Token reduction.** Move the long "Example HCL output", "Reference implementation" and acceptance-criteria tables into `references/*.md` beside each `SKILL.md` and link them (progressive disclosure). Keep process, governance and stop conditions in `SKILL.md`. `waza tokens suggest skills/` gives candidates.
4. **Over-specificity.** Replace absolute tool paths with a prerequisite check (`command -v vault terraform jq`), and keep harness-only values (token `root`, `127.0.0.1:8200`) in a clearly marked harness section.
5. **Negative-delta risks.** Read each flagged skill's finding, and fix or record why it is kept.
6. **Evals.** Create `waza new eval` scaffolds for the validated skills. Use `executor: mock` for the offline harness check only; a mock pass is not evidence of agent quality. Real executor runs may incur provider cost and need explicit approval.
7. **Spec coverage.** Run `waza spec verify` for each skill that has an eval.
**Acceptance Criteria**:
- AC: `waza check --format json` reports `ready: true` for all 17 skills, or each remaining finding is recorded in `docs/waza-review.md` with a reason and an owner.
- AC: Frontmatter reports no `spec-allowed-fields` warning for any of the 17 skills.
- AC: Every `SKILL.md` is within its configured token limit, and moving content into `references/` loses no acceptance criterion (a diff of the section headings and the acceptance-criteria lists shows only moves).
- AC: The generator scripts still pass their validation: re-run `generate.sh` for TASK-015..018 and confirm `terraform plan` shows `0 to add, 0 to change, 0 to destroy` and the output is byte-identical.
- AC: `docs/waza-review.md` records the waza version, the command lines, the before and after table, and any deviation.
- AC: No secret, token or licence content appears in any eval fixture.

### TASK-034: Terraform MCP availability or documented fallback
**Capability**: N/A
**Type**: implementation
**Effort**: S
**Depends on**: none
**Status**: Ready to start. Partly mitigated: every codification `SKILL.md` for TASK-015..018 now carries a docs-URL fallback note
**Description**: The codification skills tell the agent to call the Terraform MCP (`search_providers`, `get_provider_details`) for schema and import syntax. `.mcp.json` and `.bob/mcp.json` configure `terraform-mcp-server`, but the binary is not installed on the development machine, so TASK-015..018 used `terraform providers schema -json` and the provider docs at `raw.githubusercontent.com/hashicorp/terraform-provider-vault/v4.8.0/website/docs/r/<resource>.html.md`. Either install the server (and record the version) or make the fallback the documented primary path.
**Acceptance Criteria**:
- AC: `terraform-mcp-server` is installed and a `get_provider_details` call for `vault_namespace` agrees with `task-006-decision.md`, or `vault-codifier-conventions` documents the schema and docs fallback and the remaining codification skills (TASK-019..021) carry the same note.
- AC: Any MCP lookup that disagrees with `task-006-decision.md` is reported and stops the run.

## Critical path

`TASK-031` → `TASK-005` → `TASK-007` → `TASK-009`/`TASK-010` → `TASK-012` → `TASK-014` → `TASK-017` → `TASK-018` → `TASK-020` → `TASK-021` → `TASK-022` → `TASK-024` → `TASK-027` → `TASK-030`.

`TASK-031` gates all discovery: no Phase 2 task may run against a live cluster until the exporter identity, policy, and AppRole are provisioned and the agent is authenticated with the resulting token.

## Parallelisation

- Start `TASK-001`, `TASK-002`, `TASK-003`, `TASK-004`, `TASK-005`, and `TASK-031` in parallel (no dependencies between them).
- **All Phase 2 tasks (TASK-007 through TASK-013) are blocked on `TASK-031`** — this is the prerequisite gate for any live-cluster discovery.
- After `TASK-031` and `TASK-007` are complete, discovery tasks `TASK-008`, `TASK-009`, `TASK-010` and `TASK-011` run in parallel.
- After their discovery inputs, generators `TASK-015`, `TASK-016` and `TASK-019` run in parallel; `TASK-017`, `TASK-018`, `TASK-020`, `TASK-021` follow the ownership order.
- `TASK-023` and `TASK-025` run in parallel once `TASK-022` completes.
- `TASK-033` (waza review) can start on the 14 validated skills now, but rerun it on `codification-secrets-engines`, `codification-teams` and `codification-admin-config` after TASK-019..021. `TASK-034` has no dependencies. `TASK-032` follows `TASK-033`.
