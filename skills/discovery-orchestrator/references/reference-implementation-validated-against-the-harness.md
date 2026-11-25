## Reference implementation (validated against the harness)

The runnable implementation lives in [`scripts/`](../scripts/run.sh): `lib.sh` (shared `vget`/`fetch` helpers), one script
per discovery skill, and `run.sh` (the orchestrator). One command runs everything:

```bash
export VAULT_CONFIG_PATH=/dev/null VAULT_ADDR=http://127.0.0.1:8200
export EXPORTER_TOKEN=...            # from vault-exporter-setup; never a root token, never printed
bash skills/discovery-orchestrator/scripts/run.sh          # FROM=discovery-auth-mounts to resume
```

Validated results (Vault 2.2.2+ent harness, 4 namespaces): a clean run takes about 6 s, exits 0 with
`non_200_responses: []`; a second run produces a byte-identical `raw/` tree; the audit log for both runs shows
221 exporter requests, all `read` or `list`, none under `data/`, `metadata/`, `role-id`, `secret-id`, `sys/license`
(text) or `config/root`, and no error responses. Needs macOS `/bin/bash` 3.2 or newer, `curl` and `jq`; no Python.

`run.sh` also enforces the stop conditions itself: invalid or expired token, a token carrying the `root` policy and
a missing audit device all exit 2 before any discovery call.

```bash
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"; START="$(date -u +%FT%TZ)"
for step in discovery-namespaces discovery-root-config discovery-policies \
            discovery-auth-mounts discovery-secrets-engines \
            discovery-identity-teams discovery-admin-config; do
  vault token lookup >/dev/null 2>&1 || { echo "token expired"; exit 2; }
  run_skill "$step" || mark_failed "$step"      # see Re-run / resume
done
```

`run_id`, `start_time`, `end_time` appear **only** in the run report, never in raw payloads.

---
