## 8. State layers

| Layer | Holds |
|---|---|
| `admin/` | root namespace objects, the `admin` namespace itself, root and `admin` policies, root and `admin` auth mounts, `root-config`, `admin-config` |
| `namespaces/` | child `vault_namespace` resources, identity objects in `admin` |
| `seed/<ns>/` | tenant namespace policies, auth mounts and secrets engines |

Output root: `discovered_terraform/terraform/<layer>/`. Raw payloads:
`discovered_terraform/raw/<namespace>/` (git-ignored). Run report:
`discovered_terraform/run-report.json` (endpoint, namespace, status only, never
tokens).
