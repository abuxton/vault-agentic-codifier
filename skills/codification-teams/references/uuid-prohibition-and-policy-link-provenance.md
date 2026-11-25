## 6. UUID prohibition and policy-link provenance

Verification command (run from the output root; must print `0`):

```bash
grep -rEn '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
  discovered_terraform/terraform --include='*.tf' --exclude='imports.tf' | wc -l
```

**Recorded vs inferred.** A policy link is *recorded* when the policy name is in
the group's or entity's own `policies` list in `identity.json`. When a team
group has `policies = []`, the generator looks in `correlation.json` for
policies in the tenant namespace whose names match the team (e.g. `sre` ->
`platform-sre-read`) and lists them as **inferred**, with the text "access
applied at the namespace layer". Inferred links are never emitted as HCL.
