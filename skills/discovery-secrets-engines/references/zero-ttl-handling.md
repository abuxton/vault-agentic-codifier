## Zero TTL handling

Capture the raw value `0` for `default_lease_ttl` and `max_lease_ttl` exactly as returned. `0` means "use system default"; the generator omits the attribute when the value is `0`. Do not substitute system defaults in the raw payload.

---
