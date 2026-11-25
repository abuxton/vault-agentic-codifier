## 7. Sensitive Field Stripping Table

| Endpoint / Backend | Sensitive Field Name | Handling Strategy |
|---|---|---|
| AppRole (`auth/approle/role/*`) | `role_id` | **NEVER QUERY** endpoint; omit unless user-pinned |
| AppRole (`auth/approle/role/*`) | `secret_id` | **NEVER QUERY** endpoint; never write to disk |
| LDAP (`auth/ldap/config`) | `bindpass` | Strip via `jq 'del(.bindpass)'`; emit variable ref |
| OIDC / JWT (`auth/oidc/config`) | `client_secret` | Strip via `jq 'del(.client_secret)'`; emit variable ref |
| Kubernetes (`auth/kubernetes/config`) | `token_reviewer_jwt` | Strip from raw json; emit variable ref |
