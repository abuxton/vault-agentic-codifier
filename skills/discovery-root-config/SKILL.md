---
name: discovery-root-config
description: >
  Discover root-namespace structural configuration including audit devices,
  rate-limit quotas, seal and health state, license metadata, replication status,
  and UI settings. TASK-008 — covers CAP-001 (root-config).
triggers:
  - "discover root config"
  - "root config discovery"
  - "root discovery"
  - "TASK-008"
capability: CAP-001
task: TASK-008
depends_on:
  - vault-exporter-setup (TASK-031)
  - discovery-namespaces (TASK-007)
role: vault-expert
---

# Root Configuration Discovery Skill (`discovery-root-config`)

> **Tool choice.** This skill uses the `vault` CLI, `curl` and `jq` with the exporter token.
> The Vault MCP server cannot serve it: it has no namespace, auth, policy, identity,
> quota or `sys/*` read tools, and it exposes write tools. See `vault-codifier-conventions`
> section 1. Optional cross-check: Vault MCP `list_mounts` against `sys/mounts`.

This skill discovers root-namespace structural configurations in a Vault Enterprise cluster. It captures audit devices, rate-limit quotas, health status, replication state, license metadata, and UI configuration, saving raw JSON payloads under `discovered_terraform/raw/root/`.

## 1. Purpose

The root namespace contains global infrastructure constructs that apply cluster-wide and can only be managed from root. This skill queries system endpoints to establish the baseline for Layer 1 (`admin/` / root Terraform configuration), identifying resources that will be codified (e.g. `vault_audit`, `vault_quota_rate_limit`) and unmanaged operational attributes (license, seal state, replication mode) to document in `root/README.md`.

## 2. Governance Rules

The following non-negotiable governance rules apply:
1. **Authentication**: Use ONLY the exporter AppRole token (`${EXPORTER_TOKEN}`) from `vault-exporter-setup` (TASK-031). Never use root or operator tokens.
2. **Read-Only**: Execute ONLY `GET` and `LIST` requests. Never write, mutate, or trigger cluster lifecycle actions.
3. **License Protection**: NEVER read `/v1/sys/license` (which returns raw license text). ONLY read `/v1/sys/license/status` for metadata (features, expiration date, license ID). Never emit license text.
4. **No Secret / Sensitive Data**: Never capture or store tokens, unseal keys, or sensitive backend parameters.
5. **Deterministic Payloads**: Store payloads formatted with sorted keys (`jq -S`). Strip volatile fields (`request_id`, `lease_id`, `lease_duration`, `renewable`). `sys/health` also carries `server_time_utc`, `last_wal`, `echo_duration_ms`, `clock_skew_ms` and `replication_primary_canary_age_ms`; `sys/seal-status` carries `nonce` and `progress`. Delete all of them or re-runs will differ. Prefer `.data` (the envelope is volatile) where the endpoint wraps its response.
6. **Non-Fatal Graceful Degradation**: On HTTP 403 or 404 for optional system endpoints, record a line in `discovered_terraform/raw/run_report.jsonl` and continue.
7. **Provenance**: Cite upstream HashiCorp documentation: `https://developer.hashicorp.com/vault/api-docs/system` and `https://developer.hashicorp.com/vault/docs/configuration`.

## 3. Prerequisites

| Prerequisite | Verification Command / Check | Purpose |
|---|---|---|
| Exporter Token | `test -n "${EXPORTER_TOKEN}"` | Authentication token with root discovery access |
| Vault Address | `test -n "${VAULT_ADDR}"` (default: `http://127.0.0.1:8200`) | Cluster API endpoint |
| CLI Binaries | `/opt/homebrew/bin/vault version`, `jq --version` | Required CLI utilities |
| Raw Root Dir | `mkdir -p discovered_terraform/raw/root` | Output directory for root payloads |
| Config Override | `export VAULT_CONFIG_PATH=/dev/null` | Prevent local config file overrides |

## 4. Discovery Process

```
[Start Root Discovery]
       │
       ▼
[1. GET /v1/sys/audit] ──(403 & critical)──► [Abort: Audit read denied]
       │
       ▼
[2. LIST & GET /v1/sys/quotas/rate-limit + GET sys/quotas/config]
       │
       ▼
[3. GET /v1/sys/seal-status & GET /v1/sys/health]
       │
       ▼
[4. GET /v1/sys/license/status] (Never /sys/license)
       │
       ▼
[5. GET /v1/sys/replication/status]
       │
       ▼
[6. LIST /v1/sys/config/ui/headers (sudo) & GET sys/internal/ui/feature-flags]
       │
       ▼
[7. Write raw payloads to discovered_terraform/raw/root/*.json via jq -S]
       │
       ▼
[8. Append non-200 responses to discovered_terraform/raw/run_report.jsonl]
```

### Detailed Steps

1. **Step 1: Audit Devices (`GET /v1/sys/audit`)**  
   Read all enabled audit devices. If empty (e.g. unseeded fresh cluster), record an empty object `{}` in `audit.json`.
2. **Step 2: Quotas (`LIST /v1/sys/quotas/rate-limit` & `GET /v1/sys/quotas/config`)**  
   List all rate-limit quota names. For each quota name, call `GET /v1/sys/quotas/rate-limit/<name>` and collect rate, interval, block interval, and path. Query global quota configuration.
3. **Step 3: Seal & Health Status (`GET /v1/sys/seal-status`, `GET /v1/sys/health`)**  
   Capture seal type (shamir, transit, kms), initialization state, HA status, cluster name, and Vault version.
4. **Step 4: License Metadata (`GET /v1/sys/license/status`)**  
   Read license status to capture `license_id`, `start_time`, `expiration_time`, and licensed `features`. Strictly avoid `/v1/sys/license`.
5. **Step 5: Replication Status (`GET /v1/sys/replication/status`)**  
   Check replication mode (disabled, primary, secondary, performance, dr).
6. **Step 6: UI Configuration (`LIST /v1/sys/config/ui/headers`, `GET /v1/sys/internal/ui/feature-flags`)**
   Capture the names of custom UI headers and the UI feature flags. `sys/config/ui/headers` needs `sudo`, and `GET` on the bare path is 405: only `LIST` is valid. A `LIST` that returns 404 means "no headers configured" and is saved as `{"keys": []}`, not logged as a failure (applies to every `LIST` in the discovery skills).
7. **Step 7: Format and Write Payloads**  
   Format each payload with `jq -S` and save under `discovered_terraform/raw/root/`.
8. **Step 8: Log Non-200 Responses**  
   Log any 403/404 response to `discovered_terraform/raw/run_report.jsonl`.

## 5. Exact API & CLI Calls

### 1. Audit Devices
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/audit" | jq -S 'del(.request_id, .lease_id, .renewable, .lease_duration)' \
  > discovered_terraform/raw/root/audit.json
```

### 2. Quotas
```bash
# List rate limit quotas
curl -s -S \
  --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/quotas/rate-limit" | jq -S .data \
  > discovered_terraform/raw/root/quotas_rate_limit_list.json

# Read specific rate limit quota (e.g., global-rate-limit)
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/quotas/rate-limit/global-rate-limit" | jq -S .data \
  > discovered_terraform/raw/root/quota_rate_limit_global.json

# Read quota config
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/quotas/config" | jq -S .data \
  > discovered_terraform/raw/root/quotas_config.json
```

### 3. Seal & Health Status
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/seal-status" | jq -S . \
  > discovered_terraform/raw/root/seal_status.json

curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/health" | jq -S . \
  > discovered_terraform/raw/root/health.json
```

### 4. License Status (Metadata Only)
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/license/status" | jq -S 'del(.request_id, .lease_id, .renewable, .lease_duration)' \
  > discovered_terraform/raw/root/license_status.json
```

### 5. Replication Status
```bash
curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/replication/status" | jq -S .data \
  > discovered_terraform/raw/root/replication_status.json
```

### 6. UI Headers & Feature Flags
```bash
curl -s -S --request LIST \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/config/ui/headers" | jq -S .data \
  > discovered_terraform/raw/root/ui_headers.json   # 404 => write {"keys":[]}

curl -s -S \
  --header "X-Vault-Token: ${EXPORTER_TOKEN}" \
  "${VAULT_ADDR}/v1/sys/internal/ui/feature-flags" | jq -S .data \
  > discovered_terraform/raw/root/ui_feature_flags.json
```

## 6. Output File Schema

Output payloads are saved under `discovered_terraform/raw/root/`:

| Filename | Source Endpoint | Kept Fields | Stripped Fields |
|---|---|---|---|
| `audit.json` | `GET /v1/sys/audit` | `type`, `description`, `options`, `path` | `request_id`, `lease_id`, `renewable` |
| `quotas_rate_limit.json` | `GET /v1/sys/quotas/rate-limit/<name>` | `name`, `type`, `rate`, `interval`, `block_interval`, `path` | `request_id`, `lease_id` |
| `seal_status.json` | `GET /v1/sys/seal-status` | `type`, `initialized`, `sealed`, `t`, `n`, `version`, `cluster_name` | `nonce`, `migration` |
| `license_status.json` | `GET /v1/sys/license/status` | `license_id`, `start_time`, `expiration_time`, `features` | `license_text`, `request_id` |
| `replication_status.json` | `GET /v1/sys/replication/status` | `mode`, `dr`, `performance` | `request_id`, `lease_id` |
| `ui_headers.json` | `LIST /v1/sys/config/ui/headers` | `keys` (names only) | `request_id`, `lease_id` |

## 7. What NOT to Capture

The following items are server configuration file concerns and must **NEVER** be codified into Terraform:
- **Raw License File / Text (`/sys/license`)**: Managed via auto-load or server env vars.
- **Storage Backend Configuration**: Managed in server HCL (Raft, Consul, etc.).
- **Listener Stanzas**: IP, port, TLS certificate files on the host filesystem.
- **Entropy & HSM Pin Settings**: Physical or cloud KMS host credentials.
- **Unseal Keys and Master Keys**: Handled exclusively via unseal ceremonies.

## 8. Coding & Naming Standards

- Resource labels for root constructs:
  - Audit device: `file` → `file` (`vault_audit.file`)
  - Quota: `global-rate-limit` → `global_rate_limit` (`vault_quota_rate_limit.global_rate_limit`)
- All JSON outputs must be generated with `jq -S` for consistent key ordering.

## 9. Acceptance Criteria Checklist

- [ ] **AC-1 (CAP-001 AC1)**: Raw payload shows exactly one `file` audit device at path `file_path = "/vault/logs/audit.log"`.
- [ ] **AC-2 (CAP-001 AC2)**: Rate limit quota `global-rate-limit` captured with `rate = 1000`, `interval = 60`, `block_interval = 60`, `path = ""`.
- [ ] **AC-3 (CAP-001 AC3)**: No policy, mount, or namespace resources are captured by this root skill (ownership boundaries respected).
- [ ] **AC-4 (CAP-001 AC4)**: `license_status.json` contains license ID, expiry, and features only, with zero raw license text. Replication is captured as disabled.
- [ ] **AC-5 (CAP-001 AC6)**: If `sys/audit` is empty on a clean cluster, an empty JSON object is saved without error.
- [ ] **AC-6 (CAP-001 AC7)**: Unauthorized `sys/` endpoints record a run report entry and allow the process to proceed.

## 10. Stop Conditions & Failure Recovery

- **Fatal - Audit Read Denied at Root**: If `GET /v1/sys/audit` fails with HTTP 403 when authenticated as the exporter token, abort with: `ERROR: Exporter AppRole lacks read capability on sys/audit. Verify TASK-031 exporter policy.`
- **Non-Fatal - Replication / Quotas 404/403**: Quota endpoints returning 404 (e.g. feature not enabled) or 403 are logged to `run_report.jsonl` and skipped.

## 11. Related Skills

- [`vault-exporter-setup`](../vault-exporter-setup/SKILL.md) (TASK-031) — Grants read permissions on `sys/audit`, `sys/quotas`, `sys/license/status`.
- [`discovery-namespaces`](../discovery-namespaces/SKILL.md) (TASK-007) — Traverses tenant namespaces.
- [`discovery-policies`](../discovery-policies/SKILL.md) (TASK-009) — Discovers root-level operator policy.
