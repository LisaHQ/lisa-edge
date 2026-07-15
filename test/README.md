# Tests

Tests are grouped by intent:

- `unit/` covers shell helpers, service selection, image policy, and wizard
  behavior without deploying containers.
- `security/` covers backup validation, mount guards, checksums, and recovery
  path safety.
- `integration/` exercises workflows that cross multiple scripts and temporary
  filesystem trees.

Run the complete repository validation from the repository root:

```bash
bash tools/validate-repo.sh
```

Individual tests may also be run directly. Every test must resolve
`REPO_ROOT` from its own location so it works regardless of the caller's current
directory. Tests must use temporary directories and must not modify live host or
production data.
