---
name: validation-zero-diff
description: >
  Import the generated resources into a scratch Terraform state against the
  harness, then require terraform plan -detailed-exitcode to exit 0 for every
  layer, with a per-capability result and a list of ignore_changes entries.
  Harness only. TASK-024.
triggers:
  - "zero diff"
  - "import and plan"
  - "CAC2"
  - "TASK-024"
task: TASK-024
depends_on:
  - codification-layer-assembly (TASK-022)
  - validation-static-gate (TASK-023)
role: sre
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

## 4. Reference implementation (validated against the harness)

Harness: all three layers exit 0 in both passes, 31, 3 and 18 resources; capabilities `auth-mounts`,
`namespaces`, `policies`, `root-config`, `secrets-engines` and `teams` pass; `admin-config` declares none.
Six `ignore_changes` entries, each with a reason: `disable_remount` and `tune` on five `vault_auth_backend`
resources, and `name` on the sensitive exporter alias.

**A failure of the script itself, and its fix.** The first version flagged a non-import change but still ran
`apply`. The drift fixture (renaming the entity `exporter-agent` in the generated code) therefore renamed the
live entity to `exporter-agentx`. It was restored by hand and the script now returns before `apply`. The
fixture was re-run: it exits 1, names `vault_identity_entity.exporter_agent update`, and the entity is
unchanged before and after. Keep a before-and-after snapshot in any new destructive-looking fixture.

Faults checked: blanket `ignore_changes = all` (exit 1 before any work), drifted generated code (exit 1, Vault
unchanged).
