## 8. Acceptance criteria (harness)

- `admin/main.tf` declares a provider alias for namespace `admin`; plan shows no
  replacement.
- `README.md` lists `admin` and `namespace-admin`, states `operator` belongs to
  root-config/policies, and shows the three `vault-*-admin` groups as holders of
  `namespace-admin`.
- `human_auth.tf` is absent; README says "no human auth method detected in
  `admin`"; exit code 0.
- `grep -rn 'resource "vault_auth_backend"' admin/` returns 0.
- With an `oidc` mount enabled out of band: one `vault_jwt_auth_backend` with
  `type = "oidc"` and the discovery URL; no client secret literal anywhere.
- fmt and validate pass.
