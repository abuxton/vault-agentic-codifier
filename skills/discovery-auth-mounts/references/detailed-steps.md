## Detailed Steps

1. **Step 1: Iterate Namespaces**  
   Load root (`""`) and all tenant namespaces from `namespaces.json`.
2. **Step 2: List Auth Mounts (`GET /v1/sys/auth`)**  
   Fetch all auth backends. Filter out the default `token/` mount.
3. **Step 3: Capture Mount Tuning (`GET /v1/sys/auth/<path>/tune`)**  
   Fetch default and max lease TTLs for each mount.
4. **Step 4: Method-Specific Role/Config Extraction**  
   - **AppRole**: Call `LIST /v1/auth/<path>/role`. For each role name, call `GET /v1/auth/<path>/role/<name>` to retrieve `token_policies`, `token_ttl`, `token_max_ttl`, `secret_id_num_uses`, and `secret_id_ttl`. DO NOT query `role-id` or `secret-id`.
   - **OIDC/JWT**: Read `GET /v1/auth/<path>/config` and list/read roles. Strip any client secrets.
   - **LDAP**: Read `GET /v1/auth/<path>/config` (strip `bindpass`), list groups and users.
   - **Kubernetes / AWS / Cert**: Read respective config and roles.
   - **Other/Generic**: Capture mount metadata and tuning; mark role management as generic fallback.
5. **Step 5: Write Per-Namespace Payloads**  
   Output structured JSON to `discovered_terraform/raw/<namespace>/auth_mounts.json`.
