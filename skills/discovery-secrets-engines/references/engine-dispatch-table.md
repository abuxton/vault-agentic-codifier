## Engine dispatch table

| Engine type | Requests | Notes |
|---|---|---|
| `kv` (version 2) | `GET /v1/<M>/config` | Keep `max_versions`, `cas_required`, `delete_version_after`. Never touch `data/` or `metadata/`. |
| `pki` | `GET /v1/<M>/config/urls`, `GET /v1/<M>/config/crl`, `LIST /v1/<M>/roles` then `GET /v1/<M>/roles/<name>` | No `/cert/*`, no `/issuer/*/pem`, no key export. |
| `database` | `LIST /v1/<M>/config` then `GET /v1/<M>/config/<name>`; `LIST /v1/<M>/roles` then `GET /v1/<M>/roles/<name>` | Strip `password`, and any password inside `connection_details`. |
| `aws`, `azure`, `gcp` | `GET /v1/<M>/config/root` | Non-secret fields only; strip `secret_key`, `credentials`, `client_secret`. |
| `transit` | `LIST /v1/<M>/keys` then `GET /v1/<M>/keys/<name>` | Metadata only. Drop the `keys` map (key material/public keys). |
| `ssh` | `LIST /v1/<M>/roles` then `GET /v1/<M>/roles/<name>` | No `/config/ca` private key (only public key exists, still skip). |
| other | none | Capture mount metadata + tune only. Add to `coverage` with `resource_type: null` and a `fallback` note. |
