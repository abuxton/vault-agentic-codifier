## Terraform Resources

All resources live in `test/terraform/admin/exporter.tf`, with the policy in
`test/terraform/admin/policies/exporter.hcl`:

### 1. Policy — `exporter`

```hcl
resource "vault_policy" "exporter" {
  name   = "exporter"
  policy = file("${path.module}/policies/exporter.hcl")
}
```

The policy file is at `test/terraform/admin/policies/exporter.hcl`.  
Key design points (verified against the harness, Vault Enterprise 2.2.2):
- The token lives in the **root** namespace and reaches children through path
  prefixes (`admin/sys/auth`). `+` matches exactly one segment, so every
  structural grant is repeated for namespace depths 0..3. Add a depth if the
  cluster nests deeper.
- `list` / `read` on structural paths (namespaces, auth, mounts, policies,
  identity, quotas) and `read` on health/config paths with no secret values.
- Secrets-engine config reads are granted as `<mount>/config`, `config/urls`,
  `config/crl`, `roles`, `roles/*`. `config/root` (cloud credentials) and key
  material paths are **not** granted.
- **`sys/audit` needs `sudo`.** Vault requires sudo to *read* it
  ([API docs](https://developer.hashicorp.com/vault/api-docs/system/audit)).
  The grant is `read` + `sudo` on that one root path only. Without it,
  `discovery-root-config` gets a 403 on its mandatory audit-device read.
- **`sys/auth/<path>` and `sys/auth/<path>/tune` also need `sudo`**
  ([API docs](https://developer.hashicorp.com/vault/api-docs/system/auth)). Grant `read`+`sudo` on
  `sys/auth/+` and `sys/auth/+/tune` at every depth. `discovery-auth-mounts` gets a 403 on tuning without it.
- **`sys/config/ui/headers` also needs `sudo`**
  ([API docs](https://developer.hashicorp.com/vault/api-docs/system/config-ui-headers)),
  and only `LIST` is valid on the bare path. Grant `list`, `read`, `sudo` on
  `sys/config/ui/headers` and `sys/config/ui/headers/*`. Without `sudo` the
  exporter gets 403 even though `vault token capabilities` reports `list, read`.
- **Explicit `deny`** on `<mount>/data/*` and `<mount>/metadata/*` at every
  depth, and on AppRole `role-id` / `secret-id` endpoints.
- No `create`, `update` or `delete` anywhere.

### 2. Identity Entity — `exporter-agent`

```hcl
resource "vault_identity_entity" "exporter_agent" {
  name     = "exporter-agent"
  policies = ["exporter"]

  metadata = {
    role       = "exporter"
    managed_by = "terraform"
  }
}
```

### 3. Identity Group — not used

An earlier draft attached an `exporters` group carrying the `admin` policy. The
harness has no root-namespace `admin` policy, and the exporter must not hold
broader access than its own policy, so the identity is entity + policy only.

### 3. AppRole Role — `exporter`

```hcl
resource "vault_approle_auth_backend_role" "exporter" {
  backend            = vault_auth_backend.approle_root.path
  role_name          = "exporter"
  token_policies     = [vault_policy.exporter.name]
  token_ttl          = 3600   # 1 hour — enough for a full scan run
  token_max_ttl      = 14400  # 4 hours hard cap
  token_num_uses     = 0      # unlimited uses within TTL
  secret_id_num_uses = 1      # one-time secret-id
  secret_id_ttl      = 900    # 15 minutes
  bind_secret_id     = true
}
```

> **Note:** `token_num_uses = 0` means the token is usable for the full TTL.
> This is correct for a scan that makes many sequential API calls.  
> `secret_id_num_uses = 1` means each secret-id can only be used to log in once
> (must rotate before the next run).

### 4. Entity Alias — bind entity to AppRole accessor

```hcl
resource "vault_identity_entity_alias" "exporter_approle" {
  # AppRole aliases are keyed on the role ID, not the role name.
  name           = vault_approle_auth_backend_role.exporter.role_id
  mount_accessor = vault_auth_backend.approle_root.accessor
  canonical_id   = vault_identity_entity.exporter_agent.id
}
```

This alias is what causes audit log entries to show `exporter-agent` as the
display name when the AppRole token is used.

---
