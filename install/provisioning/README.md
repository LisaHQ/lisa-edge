# Provisioning

Provisioning collects site-specific settings and writes the local `.env` file
before bootstrap or deployment.

The main entrypoint is:

```bash
sudo ./lisa-edge setup
```

The implementation lives at `install/provisioning/lisa-first-boot.sh`.

The wizard supports first-boot setup, configuration-only runs, and restore
workflows. Shared prompts and validation helpers live in `lib/`; service-specific
questions live in `services/`.

The systemd unit in `systemd/` only notifies an unprovisioned host. The installer
creates the `lisa-edge-provision` command as a link to the main entrypoint.

Do not store production credentials in this directory. Generated values belong
in the ignored `.env` file or an external secret manager.
