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

For production, consider:

- password manager
- SOPS + age
- encrypted restic repository
- offline encrypted backup copy

Treat backup archives as privileged input: restore runs as root. Keep archives
on trusted storage, require their checksum sidecars, and use signed manifests
when backups cross an administrative trust boundary.
