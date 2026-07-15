# Secrets

Do not commit secrets to Git.

Examples of secrets:

- `.env`
- MQTT passwords
- Tailscale auth keys
- OTBR dataset files
- private keys
- certificates
- backup encryption keys

Use `.env.template` only for safe placeholders. Keep the real `.env` at mode
`0600` and outside Git.

Do not create a repository-managed `secrets/` workflow for production
credentials. Runtime service secrets belong in the configured
`${DATA_ROOT}/secrets`, an external secret manager, or another explicitly
secured host path. A Git ignore rule is not a security boundary.

For production, consider:

- password manager
- SOPS + age
- encrypted restic repository
- offline encrypted backup copy

Treat backup archives as privileged input: restore runs as root. Keep archives
on trusted storage, require their checksum sidecars, and use signed manifests
when backups cross an administrative trust boundary.
