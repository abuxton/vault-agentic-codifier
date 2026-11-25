---
name: validation-static-gate
description: >
  Use when you need to run terraform init, validate, fmt -check and tflint in every generated layer and report
  each failure with file, line and owning capability. Use after any generator run or hand edit. Run after
  codification, then read the report. USE FOR: static gate; tflint generated terraform. DO NOT USE FOR: a
  production cluster (harness only), or changing the generated output.
metadata:
  task: "TASK-023"
  role: "sre"
  depends_on: "codification-layer-assembly (TASK-022)"
  version: "1.0"
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

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
