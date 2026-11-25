---
name: codification-layer-assembly
description: >
  Use when you need to run the seven codification generators in dependency order, then check ownership, labels,
  imports and provenance across the admin, namespaces and seed layers, then fmt, init and validate each layer. Run
  after discovery, then validate. USE FOR: assemble layers; ownership check. DO NOT USE FOR: reading Vault (use
  the matching discovery-* skill), or applying the generated Terraform.
metadata:
  task: "TASK-022"
  role: "solution-architect"
  depends_on: "codification-namespaces (TASK-015), codification-root-config (TASK-016), codification-policies (TASK-017), codification-auth-mounts (TASK-018), codification-secrets-engines (TASK-019), codification-teams (TASK-020), codification-admin-config (TASK-021), vault-codifier-conventions (TASK-002, TASK-003, TASK-004)"
  version: "1.0"
---

# Codification: Layer assembly

## 1. Purpose

Turn the output of seven generators into three independent Terraform state
layers (`admin/`, `namespaces/`, `seed/`) and prove that no resource is declared
twice, owned by the wrong capability, or left without an import.

Input: `discovered_terraform/raw/`. Output: `discovered_terraform/terraform/<layer>/`.

## 2. Process

```bash
bash skills/codification-layer-assembly/scripts/assemble.sh [raw-dir] [out-root]
bash skills/codification-layer-assembly/scripts/check.sh    [out-root]      # check only
```

`assemble.sh` runs the generators in this order, because later ones reference
labels and files made by earlier ones: namespaces, root-config, policies,
auth-mounts, secrets-engines, teams, admin-config. It then runs `check.sh` and
`terraform fmt -check`, `init -backend=false` and `validate` in every layer.
It stops at the first failure. Generators are idempotent, so a re-run is safe.

## 4. Layer layout

| Layer | Holds | Files |
|---|---|---|
| `admin/` | root and `admin` objects, depth-1 namespaces, `root-config`, `admin-config` | `providers.tf`, `versions.tf` (provider pin and the `vault_address`, `vault_token` variables), `outputs.tf`, generator files, `imports*.tf` |
| `namespaces/` | namespaces of depth 2 and deeper | `providers.tf`, `versions.tf`, `namespaces.tf`, `imports.tf`, `hierarchy.md` |
| `seed/` | tenant namespace policies, auth mounts, secrets engines | `providers.tf`, `versions.tf`, generator files, `imports*.tf` |

Deviation from the TASK-022 description: imports stay in one `imports*.tf` per capability (`imports.tf` for
namespaces, `imports_<capability>.tf` for the rest) instead of being merged into one file, so each generator owns
its file and can be re-run alone; the check counts them across the layer. Variables live in `versions.tf` (written by `scaffold-layer.sh`), not
a separate `variables.tf`, and only `admin/` has `outputs.tf`. The other layers export nothing that another
layer reads, so an empty `outputs.tf` would add no value.

## 5. Stop conditions

- A generator exits non-zero (the run stops; do not continue to later generators).
- `check.sh` reports a violation.
- `fmt -check`, `init` or `validate` fails in any layer.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [What `check.sh` verifies](references/what-check-sh-verifies.md)
- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
