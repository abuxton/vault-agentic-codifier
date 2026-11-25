## 6. Example `admin/README.md` (harness)

```markdown
# admin layer

## Operator policies
| Policy | Namespace | Held by |
|---|---|---|
| `admin` | admin | (no recorded holder) |
| `namespace-admin` | admin | vault-platform-admin, vault-app-billing-admin, vault-app-identity-admin |
| `operator` | root | Out of scope here; owned by root-config / policies |

## Human authentication
No human auth method detected in `admin`.
The `approle/` mount and `namespace-provisioner` role are emitted by
`auth-mounts` and referenced here, not declared.
```

**Ownership check reminder.** Before writing any `resource` block, ask: does
this resource type belong to `admin-config`? If not, reference it, never
declare it.
