## 6. Reference implementation (validated against the harness)

Harness result: 31 resources and 31 imports in `admin/`, 3 and 3 in `namespaces/`, 18 and 18 in `seed/`;
`0 violations`; all layers pass fmt, init and validate; `terraform plan` shows `31`, `3` and `18 to import`
with 0 add, 0 change, 0 destroy; a second `assemble.sh` run is byte-identical.

Eight injected faults each fail the check (exit 1) with a `VIOLATION:` line: a duplicate `vault_policy`
(two files), a file whose capability header does not own its types, a removed `imports.tf`, a removed
provenance header, a UUID literal in `main.tf`, a `vault_kv_secret_v2` resource, an inline `bindpass`
literal, and an output root with no layer.
