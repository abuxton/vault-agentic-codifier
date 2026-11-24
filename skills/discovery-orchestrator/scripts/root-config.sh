#!/usr/bin/env bash
# discovery-root-config (TASK-008). Writes $RAW/root/*.json. Never reads sys/license (text).
. "$(dirname "$0")/lib.sh"
OUT=$RAW/root; mkdir -p "$OUT"

fetch GET  "" sys/audit '.data // del(.request_id,.lease_id,.renewable,.lease_duration,.wrap_info,.warnings,.auth)' "$OUT/audit.json"
fetch LIST "" sys/quotas/rate-limit '.data' "$OUT/quotas_rate_limit_list.json"
if [ -f "$OUT/quotas_rate_limit_list.json" ]; then
  jq -r '.keys[]' "$OUT/quotas_rate_limit_list.json" | while IFS= read -r n; do
    fetch GET "" "sys/quotas/rate-limit/$(enc "$n")" '.data' "$OUT/quota_rate_limit_${n//-/_}.json"
  done
fi
fetch GET  "" sys/quotas/config '.data' "$OUT/quotas_config.json"
fetch GET  "" sys/seal-status 'del(.nonce,.progress)' "$OUT/seal_status.json"
fetch GET  "" sys/health 'del(.server_time_utc,.last_wal,.echo_duration_ms,.clock_skew_ms,.replication_primary_canary_age_ms)' "$OUT/health.json"
fetch GET  "" sys/license/status '.data' "$OUT/license_status.json"
fetch GET  "" sys/replication/status '.data' "$OUT/replication_status.json"
fetch LIST "" sys/config/ui/headers '.data' "$OUT/ui_headers.json"
fetch GET  "" sys/internal/ui/feature-flags '.' "$OUT/ui_feature_flags.json"
