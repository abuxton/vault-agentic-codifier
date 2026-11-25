## 7. Coding & Naming Standards

- **Terraform Resource Label Helper**: Normalise full namespace paths by replacing `/` and `-` with underscores `_`:
  - `admin` → `admin`
  - `admin/platform` → `admin_platform`
  - `admin/app-billing` → `admin_app_billing`
  - `admin/app-identity` → `admin_app_identity`
- **JSON Formatting**: Always use `jq -S` to format JSON with deterministically sorted object keys.
- **Parent Referencing**: Do not hardcode string paths in downstream generators; use the `parent` and `path` structure to establish hierarchical references.
