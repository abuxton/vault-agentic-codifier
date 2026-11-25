## 8. Coding & Naming Standards

- **File Naming**: When codified into HCL files, policies over 10 lines will be emitted to `policies/<namespace>/<name>.hcl`.
- **String Handling**: Preserve literal newlines `\n` in JSON payloads; do not strip or trim document formatting.
- **Sorted Output**: Ensure all JSON files use sorted keys via `jq -S`.
