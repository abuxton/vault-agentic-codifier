---
name: validation-static-gate
description: >
  Run terraform init, validate, fmt -check and tflint in every generated layer
  and report each failure with file, line and owning capability. Use after any
  generator run or hand edit. TASK-023.
triggers:
  - "static gate"
  - "tflint generated terraform"
  - "validate generated layers"
  - "TASK-023"
task: TASK-023
depends_on:
  - codification-layer-assembly (TASK-022)
role: sre
---

# Validation: static gate

## 1. Purpose

Prove CAC1: every generated layer is valid, formatted HCL that passes lint.

## 2. Run

```bash
make static-gate                                   # from the repo root
bash skills/validation-static-gate/scripts/gate.sh [out-root]
```

Exit 0 only when every layer passes every step. Exit 2 if `tflint` is missing.

## 3. Steps per layer

A layer is a directory under the output root that holds `providers.tf`.

1. `terraform init -backend=false` and `terraform validate -json`. A parse or reference error stops
   the layer here and is reported once.
2. `terraform fmt -check -recursive -list=true`: lists each file that would change.
3. `tflint --format json` with default rules (`terraform_unused_declarations` and the bundled `terraform`
   ruleset). No `.tflint.hcl` is used and no rule is suppressed.

Each failure prints `FAIL <layer>/<file>:<line> [<capability>] <message>`. The capability comes from the
file's `# Capability:` header, so the owner of a bad file is known. `[unknown]` means the header is missing,
which `codification-layer-assembly` also reports.

## 4. Installing tflint

`tflint` 0.66.0 on macOS arm64, no root needed:

```bash
curl -sLO https://github.com/terraform-linters/tflint/releases/download/v0.66.0/tflint_darwin_arm64.zip
curl -sL  https://github.com/terraform-linters/tflint/releases/download/v0.66.0/checksums.txt | grep tflint_darwin_arm64.zip
shasum -a 256 tflint_darwin_arm64.zip      # must match the line above
unzip tflint_darwin_arm64.zip && install -m 0755 tflint ~/.local/bin/tflint
```

The Makefile adds `~/.local/bin` to `PATH`.

## 5. Reference implementation (validated against the harness)

Harness: `static gate: ok` for `admin/`, `namespaces/` and `seed/`; `make static-gate` exits 0.

The first run found one real issue: `local.operator_groups` in the admin-config output was declared and never
used (`terraform_unused_declarations`). The generator now exposes it as `output "operator_group_names"`;
nothing is suppressed.

Injected faults, each exit 1 with the owner named: a syntax error (`seed/admin_platform_policies.tf:33
[policies]`), an unformatted file (`admin/root_policies.tf [policies]`), a reference to an undeclared policy
(`admin/root_auth_mounts.tf:20 [auth-mounts]`), and an unused variable (`admin/audit.tf:15 [root-config]`).
