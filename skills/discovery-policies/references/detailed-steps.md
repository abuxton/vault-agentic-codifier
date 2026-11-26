## Detailed Steps

1. **Step 1: Iterate Namespaces**  
   Load root (`""`) and all namespace paths from `discovered_terraform/raw/namespaces.json` (`admin`, `admin/platform`, `admin/app-billing`, `admin/app-identity`).
2. **Step 2: List ACL Policies**  
   Issue `LIST /v1/sys/policies/acl` with `X-Vault-Namespace` set to the current namespace.
3. **Step 3: Fetch Policy Contents**  
   For each policy name returned, check if it is `default`, `root` or `default-ceiling`. If so, skip. Otherwise, execute `GET /v1/sys/policies/acl/<name>` and retrieve the raw `policy` string.
4. **Step 4: Check Sentinel Policies (Enterprise)**  
   Execute `LIST /v1/sys/policies/egp` and `LIST /v1/sys/policies/rgp`. If empty or 403, record status as "none" or "unavailable". Otherwise `GET /v1/sys/policies/<egp|rgp>/<name>` for each name and keep `enforcement_level`, `paths` (EGP) and `policy`.
5. **Step 5: Write Per-Namespace Payloads**  
   Write `discovered_terraform/raw/<namespace_path>/policies.json` and `sentinel.json` with sorted keys. (For root, write to `discovered_terraform/raw/root/policies.json`).
6. **Step 6: Update Coverage & Run Report**  
   Log any Sentinel capabilities to `discovered_terraform/raw/coverage.json` and non-200 responses to `discovered_terraform/raw/run_report.jsonl`.
