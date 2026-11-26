## 9. Reference implementation (validated against the harness)

Run `skills/codification-policies/scripts/generate.sh [raw] [out-root]`.

- Layout: `admin/<ns>_policies.tf` and `admin/imports_policies.tf` (root and `admin`),
  `seed/...` (tenants, one provider alias per namespace via `scaffold-layer.sh`),
  `<layer>/policies/<root|ns__path>/<name>.hcl`, `policies/correlation.{md,json}`, `policies/coverage.md`.
- Bodies over 10 lines, bodies with tabs, CR, `${`, `%{` or an `EOT` line, and bodies without a
  trailing newline go to `.hcl` files written byte-for-byte. Others become `<<-EOT` heredocs.
- The harness now has **10** non-built-in ACL policies, not 9: the `exporter` policy is part of
  the cluster (root `exporter` and `operator`; `admin` x2; 6 tenant policies). Distribution is
  4 in `admin/` and 6 in `seed/`. Skills must tolerate this drift.
- Exit 2 on a missing or unreadable `policies.json`, an unsafe policy name, or a duplicate label.
- A policy named by a role, group or entity but absent from its namespace is `dangling` in
  `correlation.{md,json}`; nothing is fabricated for it.
- EGP/RGP (CAP-008): emitted as `vault_egp_policy` and `vault_rgp_policy` in `<ns>_sentinel.tf` with
  `imports_sentinel.tf` and sources under `<layer>/policies/sentinel/<root|ns__path>/<kind>-<name>.sentinel`.
  The harness has 2 EGP and 2 RGP (root and `admin/platform`).

Validated: `fmt -check` and `validate` pass in `admin/` and `seed/`; `terraform plan` shows
`7 to import` in `admin/` (policies, audit, quota, namespace) and `6 to import` in `seed/`, all with
0 add, 0 change, 0 destroy (lossless round-trip); a second run is byte-identical; a `ghost` fixture
is reported as dangling; tab-bearing and newline-less fixtures are written verbatim.
