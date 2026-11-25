## 1. Tool selection

| Phase | Primary tool | Why |
|---|---|---|
| Discovery | `vault` CLI, `curl`, `jq` with the exporter token | The Vault MCP server only exposes mount, KV and PKI tools. It has none for namespaces, auth mounts, policies, identity, quotas, audit or other `sys/*` reads. |
| Discovery (optional cross-check) | Vault MCP `list_mounts` | Compare against `sys/mounts`. Use only on a harness or with the exporter token. |
| Codification | Terraform MCP (`search_providers`, `get_provider_details`, `search_provider_docs`) | Look up the resource schema and import syntax for the pinned provider before writing HCL. Do not rely on memory. |
| Validation | `terraform` CLI (`fmt`, `validate`, `plan`) | The Terraform MCP does not run these. |

Vault MCP rules:

- It exposes write and delete tools (`create_mount`, `delete_mount`,
  `write_secret`, `delete_secret`, `create_pki_*`, `issue_pki_certificate`).
  Never call them. Discovery is `GET` / `LIST` only.
- Never call `read_secret`. Secret values must not reach the model.
- Point it at the harness only, never production.

Terraform MCP rules:

- Pin lookups to provider `hashicorp/vault` version `4.8.0`, the version the
  import IDs were verified against (`task-006-decision.md`).
- Record the doc URL returned by the lookup in the file header (section 4).
- If a lookup disagrees with `task-006-decision.md`, stop and report it. Do not
  silently pick one.

Fallback when `terraform-mcp-server` is not installed (the state on the harness machine, TASK-034). This is
a supported path, not an error:

1. Read the resource page at
   `https://raw.githubusercontent.com/hashicorp/terraform-provider-vault/v4.8.0/website/docs/r/<resource>.html.md`
   for arguments and the import syntax. Use the registry URL
   `https://registry.terraform.io/providers/hashicorp/vault/4.8.0/docs/resources/<resource>` in the file header.
2. Confirm argument names against the installed provider:
   `terraform -chdir=<layer> providers schema -json | jq '.provider_schemas | to_entries[0].value.resource_schemas.<type>.block.attributes | keys'`.
3. If either source disagrees with `task-006-decision.md`, stop and report it, exactly as for an MCP lookup.
4. Record "Terraform MCP not installed; docs and schema fallback used" in the run notes.

Checked on the harness: the docs URL for `vault_namespace` returns 200 and the provider schema lists `path`,
`path_fq`, `custom_metadata`, which agrees with the import ID in `task-006-decision.md`.
