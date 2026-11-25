## 3. Reference implementation (validated against the harness)

`make codify-test`: all 11 stages PASS. Per CAC: CAC1 to CAC7 PASS. Per capability: `auth-mounts`, `namespaces`,
`policies`, `root-config`, `secrets-engines` and `teams` pass zero-diff; `admin-config` reports "none declared" (the
harness has no human auth mount, and the variants cover it). `make -C test smoke-test` passes before and after, and
the harness digest is unchanged.

`--selftest` copies the committed output and raw trees twice, confirms identical trees pass, then requires
`idempotent` to fail on a changed byte, a missing file and an extra raw payload. All three are detected.
