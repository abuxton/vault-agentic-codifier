# MFA discovery (CAP-009)

Per namespace, with `X-Vault-Namespace` set. Writes `<ns>/mfa.json` only when something exists.

```bash
curl -s --request LIST --header "X-Vault-Token: ${EXPORTER_TOKEN}" --header "X-Vault-Namespace: admin" "${VAULT_ADDR}/v1/identity/mfa/method"
curl -s --header "X-Vault-Token: ${EXPORTER_TOKEN}" --header "X-Vault-Namespace: admin" "${VAULT_ADDR}/v1/identity/mfa/method/<type>/<id>"
curl -s --request LIST --header "X-Vault-Token: ${EXPORTER_TOKEN}" --header "X-Vault-Namespace: admin" "${VAULT_ADDR}/v1/identity/mfa/login-enforcement"
curl -s --header "X-Vault-Token: ${EXPORTER_TOKEN}" --header "X-Vault-Namespace: admin" "${VAULT_ADDR}/v1/identity/mfa/login-enforcement/<name>"
```

- Root answers 404 when it has no methods; a 404 on a LIST means an empty set.
- A child namespace also lists the methods of its ancestors. Keep a method only when its `namespace_path` equals the
  namespace being scanned (`admin/` for `admin`, empty for root).
- The `type` comes from the LIST `key_info`. Only `totp`, `duo`, `okta` and `pingid` are read.
- Each type is cut to an allowlist, so a secret field cannot reach `mfa.json`: TOTP `algorithm, digits, issuer, key_size,
  max_validation_attempts, period, qr_size, skew`; Duo `api_hostname, pushinfo, use_passcode, username_format`; Okta
  `org_name, base_url, username_format`; PingID nothing.
- Enforcement keeps `name, id, mfa_method_ids, identity_group_ids, identity_entity_ids, auth_method_accessors, auth_method_types`.
- The exporter policy needs read and list on `identity/mfa/method`, `identity/mfa/method/*`, `identity/mfa/login-enforcement` and `.../*`
  at every namespace depth (TASK-S02).
