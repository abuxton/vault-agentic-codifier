## 10. Reference implementation (validated against the harness)

Run `skills/codification-namespaces/scripts/generate.sh [namespaces.json] [out-root]`.
It calls `vault-codifier-conventions/scripts/scaffold-layer.sh` for `versions.tf` and
`providers.tf`, writes `admin/` and `namespaces/`, runs `terraform fmt`, and stops
(exit 2) on an orphan parent or a duplicate label.

Validated: 4 `vault_namespace` resources; `fmt -check` and `validate` pass in both layers;
a second run is byte-identical; no `namespace =` argument and no `"admin/` literal in any
`vault_namespace` block; a depth-3 fixture (`admin/platform/sre-team`) gets
`provider = vault.admin_platform` plus `depends_on`; an orphan fixture exits 2;
`terraform plan` shows `4 to import, 0 to add, 0 to change, 0 to destroy` (1 in `admin/`, 3 in `namespaces/`).
Import blocks omit `provider =`, so they use the provider of the target resource.
