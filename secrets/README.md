# Secret Storage Policy

This repository directory is documentation-only. It must not contain real
tokens, private keys, passwords, recovery credentials, production `.env` files
or exported password-manager data.

Store production secrets outside the checkout, using one or more of:

- An ignored local `.env` with mode `0600`
- `${DATA_ROOT}/secrets` with restricted permissions
- A password manager or dedicated secret manager
- Encrypted offline recovery media
- SOPS/age-encrypted material managed by an explicit deployment workflow

`tools/generate-secrets.sh` prints candidate values to stdout; move them directly
to secure storage. If a real secret is ever added to Git, removing the file is
not sufficient: revoke or rotate it and purge it from repository history.
