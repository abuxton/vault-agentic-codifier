## Empty-set handling

- `LIST` returning 404 (Vault's "no keys") is not an error: treat as `[]` and do not log it as a failure beyond an informational run-report entry.
- Missing categories serialize as `[]`, never `null`.
- If a namespace has zero groups, entities, and aliases, **do not create** `identity.json` for it.

---
