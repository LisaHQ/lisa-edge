# Bootstrap

This directory prepares a supported Linux host to run LISA Edge.

Run the orchestrator as root:

```bash
sudo ./lisa-edge bootstrap
```

The root command dispatches to `install/bootstrap/bootstrap.sh`. The bootstrap
script loads `.env`, executes every script in `phases/` in lexical order,
deploys the selected Compose services, installs the systemd units, and finalizes
administrator access.

## Phase convention

- Use a two-digit numeric prefix to make execution order explicit.
- Keep each phase focused on one host-level responsibility.
- Make phases safe to run again whenever practical.
- Put reusable runtime behavior in `lib/`, not in a bootstrap phase.

Bootstrap changes the host and therefore must be tested on a disposable machine
or VM before production rollout.
