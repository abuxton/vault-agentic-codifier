## Re-run / resume

- Each skill is idempotent and overwrites only its own files, so re-running is always safe.
- The orchestrator keeps `discovered_terraform/.state.json` (`{"completed": ["discovery-namespaces", ...]}`), excluded from the idempotency comparison.
- Resume from a step: `FROM=discovery-auth-mounts` skips every step recorded as completed and before `FROM`. Already-collected payloads are never deleted.
- Force a step to re-run: remove it from `completed` (never `rm -rf raw/`).
- Dependencies are re-checked on resume: if `FROM=discovery-identity-teams` and `auth_mounts.json` is absent, stop.
- If the token expired, re-issue via `vault-exporter-setup` (new secret-id), then resume.

---
