## Detailed Steps

1. **Step 1: Authenticate Check**  
   Verify that `${EXPORTER_TOKEN}` is valid and read-only by calling `GET /v1/auth/token/lookup-self`. Confirm policy matches `exporter`.
2. **Step 2: List Root Namespaces**  
   Execute `LIST /v1/sys/namespaces` with no `X-Vault-Namespace` header (or empty header) to retrieve immediate children of root.
3. **Step 3: Read Namespace Metadata**  
   For each discovered namespace path at the current level, issue `GET /v1/sys/namespaces/<path>` under the appropriate parent namespace header to capture `id`, `path`, and `custom_metadata`.
4. **Step 4: Recursive Walk**  
   For each namespace, set `X-Vault-Namespace: <full_parent_path>` and execute `LIST /v1/sys/namespaces`. Repeat depth-first traversal until no further child namespaces exist (empty list, 404, or 403 indicates a leaf node). Track `depth` (e.g., `admin` = 1, `admin/platform` = 2, `admin/platform/sre-team` = 3).
5. **Step 5: Build Ordered Payload**  
   Assemble the collection into a JSON array, excluding root. Sort entries primarily by `depth` ascending and secondarily by `path` ascending. Write the result to `discovered_terraform/raw/namespaces.json` using `jq -S`.
6. **Step 6: Write Run Report**  
   For any encountered HTTP status code other than 200, append a JSON line to `discovered_terraform/raw/run_report.jsonl`:
   `{"endpoint": "sys/namespaces/<path>", "namespace": "<parent>", "http_status": NNN, "skipped": true}`.
