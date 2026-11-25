## Harness expectation

- `human_auth_mounts = []`; run report entry: `no human auth method detected`.
- `machine_auth_mounts` contains the `approle` mount(s) of `admin` (the harness has 5 approle mounts overall; only those in `admin` appear here).
- `operator_policies` contains the admin-type policies found in `admin/policies.json`; `operator_groups` lists the identity groups that hold them.

---
