## Idempotency

Run twice into separate directories and compare:

```bash
cp -R discovered_terraform/raw /tmp/raw_run1
# ... second run ...
diff -r /tmp/raw_run1 discovered_terraform/raw && echo IDENTICAL

# or hash the tree
(cd discovered_terraform/raw && find . -type f | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256)
```

The run report is excluded from the comparison (it contains timestamps). Any diff means a volatile field leaked or an array is unsorted: fix the offending skill.

---
