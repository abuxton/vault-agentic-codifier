## Built-in mount skip list

`sys/`, `identity/`, `cubbyhole/`, `token/`, and any mount whose **type** is `agent_registry`,
`ns_agent_registry`, `system`, `identity`, `cubbyhole`, `ns_system`, `ns_identity` or `ns_cubbyhole`.
Vault 2.x mounts an `agent-registry/` engine (type `agent_registry`, `ns_agent_registry` in namespaces)
in every namespace; it is built in, so match on type as well as path.

Validated against the harness (Vault 2.2.2+ent): the exporter reads `sys/mounts`, `sys/mounts/<m>/tune`
and `<m>/config` for KV v2 with no 403s and no `data/` or `metadata/` requests. The root namespace also
has the dev-mode `secret/` KV v2 mount; it is real cluster state and is discovered like any other mount.
A mount that was never tuned reports `0` TTLs here (system default), unlike auth mounts.

---
