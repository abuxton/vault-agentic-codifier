---
name: validation-zero-diff
description: >
  Use when you need to import the generated resources into a scratch Terraform state against the harness, then
  require terraform plan -detailed-exitcode to exit 0 for every layer, with a per-capability result and a list of
  ignore_changes entries. Harness only. Run after codification, then read the report. USE FOR: zero diff; import
  and plan. DO NOT USE FOR: a production cluster (harness only), or changing the generated output.
metadata:
  task: "TASK-024"
  role: "sre"
  depends_on: "codification-layer-assembly (TASK-022), validation-static-gate (TASK-023)"
  version: "1.0"
---

# Validation: zero-diff import

## 1. Purpose

Prove CAC2: after the generated `import {}` blocks run, the generated code describes the live harness exactly.

## 2. Run

```bash
export VAULT_TOKEN=root          # harness root token; the script refuses a non-local VAULT_ADDR
bash skills/validation-zero-diff/scripts/zero-diff.sh [out-root] [report-dir]
```

Report: `discovered_terraform/validation/zero-diff.md` and `zero-diff.json`. Exit 0 only when every layer and
every capability passes. Exit 2 if `VAULT_ADDR` is not `127.0.0.1` or `localhost`.

## 3. Process per layer (apply order: `admin`, `namespaces`, `seed`)

1. Copy the layer to a `mktemp` directory, so no state file reaches the repo. `terraform init`.
2. `terraform plan -out`. **If the plan holds any add, update or destroy, stop the layer: it is not applied.**
   Only a plan made entirely of imports is applied, so this step cannot change Vault.
3. `terraform apply` of that plan imports into the scratch state.
4. `terraform plan -detailed-exitcode` must exit 0 (no changes). Resources are mapped to their capability
   through the file's `# Capability:` header.
5. Delete the scratch state and repeat 2 to 4 (the destroy-and-reimport cycle). It is state-only; Vault is
   never destroyed.
6. A blanket `ignore_changes = all` anywhere in the output fails the run before anything starts.

The report lists every `ignore_changes` entry with its resource, attributes and the comment above it.
A capability that declares no resources (`admin-config` on the harness) shows "none declared".

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
