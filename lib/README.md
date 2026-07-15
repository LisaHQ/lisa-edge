# Shared Libraries

This directory contains shell helpers shared by more than one operational
domain. Service-specific behavior belongs under `services/<service>/`; backup
validation belongs under `ops/backup-restore/`.

All code must source shared libraries from this directory.
