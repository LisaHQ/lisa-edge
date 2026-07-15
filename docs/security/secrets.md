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
