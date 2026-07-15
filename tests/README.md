# Tests

tests/ is the canonical LISA Edge test suite.

- structure/ protects the repository layout, service catalog, stable CLI,
  and hard-coded installed paths.
- unit/ covers service selection, image policy, and provisioning behavior
  without deploying containers.
- security/ covers archive validation, checksums, mount guards, target-root
  parsing, and Rescue OS path safety.
- integration/ exercises complete workflows against isolated temporary
  filesystem trees.

Run the same validation used by CI:

    bash tools/validate-repo.sh

Tests must resolve REPO_ROOT from their own path, use temporary directories,
and never modify a live host or production data.
