## 7. Acceptance criteria (harness)

- 10 `vault_policy` resources (harness drift: includes root `exporter`): root `operator`; `admin` -> `admin`,
  `namespace-admin`; `admin/platform` -> `platform-sre-read`,
  `platform-devops-write`; `admin/app-billing` -> `billing-developers-read`,
  `billing-owners-write`; `admin/app-identity` -> `identity-developers-read`,
  `identity-owners-write`. `default`, `root` and `default-ceiling` not emitted.
- Distribution: 4 in `admin/` (exporter, operator, admin, namespace-admin), 6 in `seed/`.
- Lossless round-trip: the policy text from Vault equals the text rendered from
  the generated file (whitespace-normalised); `terraform plan` shows no change.
- `correlation.md` records `operator` <- `terraform-admin`,
  `namespace-admin` <- `namespace-provisioner` and the three
  `vault-*-admin` groups, `platform-devops-write` <- `platform-ci`,
  `billing-developers-read` <- `billing-service`,
  `identity-developers-read` <- `identity-service`.
- A policy named by a role but absent from its namespace is marked `dangling`.
- `correlation.json` validates as JSON and is non-empty.
- 10 `import {}` blocks.
- Stage 2 (CAP-008): 2 `vault_egp_policy` and 2 `vault_rgp_policy` (root and `admin/platform`), 4 more `import {}`
  blocks in `imports_sentinel.tf`, 4 `.sentinel` files byte-identical to the API, and `coverage.md` with counts per namespace.
