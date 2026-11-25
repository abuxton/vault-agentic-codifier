---
name: validation-variants
description: >
  Use when you need to run the edge-case fixtures the base harness cannot reach (oidc in admin, userpass, pki and
  database, a nested namespace, duplicate policy names, a dangling policy, a 403 token, an empty cluster) on
  throwaway Vault containers, assert the expected output, and run CAC1 to CAC4 on each. Harness only. Run after
  codification, then read the report. USE FOR: variant fixtures; edge cases. DO NOT USE FOR: a production cluster
  (harness only), or changing the generated output.
metadata:
  task: "TASK-026"
  role: "sre"
  depends_on: "codification-layer-assembly (TASK-022), validation-zero-diff (TASK-024), validation-readonly-secrets (TASK-025)"
  version: "1.0"
---

# Validation: variant fixtures

## 1. Run

```bash
bash skills/validation-variants/scripts/run-variants.sh [report-dir]     # or: make variants
```

Needs `docker`, `terraform`, `vault`, `jq`, `tflint` and `tmp/vault.hclic`. About three minutes. Report:
`discovered_terraform/validation/variants.{json,md}`. Exit 0 only when every check passes.

## 2. Isolation

The committed harness on `:8200` is never written to. The script starts two **throwaway** dev containers on
`127.0.0.1`: `vault-codifier-variant` (`:18200`) and `vault-codifier-empty` (`:18201`). Both are removed on exit,
including on failure. A digest of the real harness (namespaces, policies, auth and secrets mounts, entity names)
is taken before and after, and the run fails if it differs. `make -C test clean` is therefore not needed.
`zero-diff.sh` refuses non-local addresses, so the throwaway ports are accepted and nothing else is.

## 3. Scenarios and assertions

| Scenario | Fixture | Acceptance criteria asserted |
|---|---|---|
| `variant` | harness layers copied and applied, then `oidc` with a client secret, two roles, an external group and alias in `admin`; `userpass` in `app-billing`; `pki` and `database` in `platform`; `admin/platform/sre-team`; a group in `platform`; `default-readonly` in `platform` and `app-billing`; an AppRole naming a missing policy | CAP-002 AC4; CAP-003 AC4, AC7; CAP-004 AC6; CAP-005 AC3, AC5; CAP-006 AC5, AC6; CAP-007 AC4, AC8; CAC1 to CAC4 |
| `restricted-403` | child token with the `exporter` policy plus a deny on `sys/quotas/config` and `sys/config/ui/headers`; a second token with a deny on `sys/audit` | CAP-001 AC7 (run continues, both endpoints and 403 in `run_report.json`; an audit 403 stops root-config codification); token not in any output; CAC3, CAC4 |
| `empty-cluster` | fresh dev cluster, no seed | CAP-001 AC6; CAP-002 AC3; CAP-005 AC6; CAC1 to CAC3; the orchestrator's own stop conditions refuse a root token and a cluster with no audit device |

The oidc client secret is a random marker written to Vault. The scenario asserts that it appears in no generated file
or raw payload, and that the generated code takes it from a sensitive variable with no default.

Two scenario details. The empty cluster has no audit device by definition, so the read-only check runs with
`NO_AUDIT_DEVICE=1`: the three audit checks report `SKIP` and every content scan still runs. The empty cluster is
collected with the dev root token because the orchestrator, correctly, refuses it; this is fixture-only.

## References

Load these when you need the detail; each is moved verbatim from this file.

- [Reference implementation (validated against the harness)](references/reference-implementation-validated-against-the-harness.md)
