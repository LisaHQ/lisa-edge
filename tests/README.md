# Tests

tests/ is the canonical LISA Edge test suite.

- structure/ protects the repository layout, service catalog, stable CLI,
  and hard-coded installed paths.
- unit/ covers service selection, image policy, provisioning behavior, the
  OTBR/Matter CLI (with mocked docker/ot-ctl and a mocked Matter WebSocket
  server under node), Thread dataset parsing, network creation, the image
  resolver, and the health outcome model - without deploying containers.
- security/ covers archive validation, checksums, mount guards, target-root
  parsing, Rescue OS path safety, and Thread dataset secret redaction.
- integration/ exercises complete workflows against isolated temporary
  filesystem trees.

Run the same validation used by CI:

    bash tools/validate-repo.sh

Tests must resolve REPO_ROOT from their own path, use temporary directories,
and never modify a live host or production data.
