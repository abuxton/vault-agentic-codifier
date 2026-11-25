## 6. Output Schema

The output file `discovered_terraform/raw/namespaces.json` must adhere to the following schema.
Namespace IDs are short opaque strings (e.g. `qOOjV`), not UUIDs. A namespace with no metadata returns `{}`, not `null`.

```json
[
  {
    "path": "admin",
    "parent": "",
    "id": "qOOjV",
    "custom_metadata": {},
    "depth": 1
  },
  {
    "path": "admin/app-billing",
    "parent": "admin",
    "id": "FJ3lt",
    "custom_metadata": {
      "description": "Billing application team namespace"
    },
    "depth": 2
  },
  {
    "path": "admin/app-identity",
    "parent": "admin",
    "id": "x7ROq",
    "custom_metadata": {
      "description": "Identity service team namespace"
    },
    "depth": 2
  },
  {
    "path": "admin/platform",
    "parent": "admin",
    "id": "CaNRp",
    "custom_metadata": {
      "description": "Platform engineering team namespace"
    },
    "depth": 2
  }
]
```
