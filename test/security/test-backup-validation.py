#!/usr/bin/env python3
"""Security regression tests for privileged backup restore validation."""

from __future__ import annotations

import io
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile


REPO_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = REPO_ROOT / "scripts" / "lib" / "validate_backup.py"
ENV_TEMPLATE = REPO_ROOT / ".env.template"
ENV_MEMBER = "opt/lisa-edge/.env"
SAFE_ENV = b"DATA_ROOT='/srv/lisa-edge'\nOTBR_DATASET_BACKUP_DIR='/srv/lisa-edge/backups/otbr'\n"


def add_bytes(archive: tarfile.TarFile, name: str, content: bytes) -> None:
    member = tarfile.TarInfo(name)
    member.size = len(content)
    member.mode = 0o600
    archive.addfile(member, io.BytesIO(content))


def create_archive(path: Path, extra_member: tarfile.TarInfo | None = None, env: bytes = SAFE_ENV) -> None:
    with tarfile.open(path, "w:gz") as archive:
        add_bytes(archive, ENV_MEMBER, env)
        add_bytes(archive, "opt/lisa-edge/compose/docker-compose.yml", b"services: {}\n")
        add_bytes(archive, "srv/lisa-edge/docker/volumes/test/data", b"persistent\n")
        if extra_member is not None:
            if extra_member.isfile():
                payload = b"malicious\n"
                extra_member.size = len(payload)
                archive.addfile(extra_member, io.BytesIO(payload))
            else:
                archive.addfile(extra_member)


def validate(archive: Path, workdir: Path, *, extract: bool = False) -> subprocess.CompletedProcess[str]:
    command = [
        sys.executable,
        str(VALIDATOR),
        "--archive",
        str(archive),
        "--env-member",
        ENV_MEMBER,
        "--env-output",
        str(workdir / "validated.env"),
        "--env-template",
        str(ENV_TEMPLATE),
        "--allow",
        "opt/lisa-edge/.env",
        "--allow",
        "opt/lisa-edge/compose",
        "--allow",
        "srv/lisa-edge/docker",
    ]
    if extract:
        command.extend(("--extract-root", str(workdir / "staging")))
    return subprocess.run(command, text=True, capture_output=True, check=False)


def expect_rejected(result: subprocess.CompletedProcess[str], label: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"validator accepted {label}")


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="lisa-backup-test-") as temp:
        root = Path(temp)

        safe_archive = root / "safe.tar.gz"
        create_archive(safe_archive)
        result = validate(safe_archive, root / "safe", extract=True)
        if result.returncode != 0:
            raise AssertionError(result.stderr)
        restored = root / "safe" / "staging" / "srv/lisa-edge/docker/volumes/test/data"
        if restored.read_bytes() != b"persistent\n":
            raise AssertionError("safe archive was not staged correctly")

        outside = tarfile.TarInfo("etc/cron.d/lisa-test")
        outside_archive = root / "outside.tar.gz"
        create_archive(outside_archive, outside)
        expect_rejected(validate(outside_archive, root / "outside"), "out-of-scope path")

        parent = tarfile.TarInfo("../etc/cron.d/lisa-test")
        parent_archive = root / "parent.tar.gz"
        create_archive(parent_archive, parent)
        expect_rejected(validate(parent_archive, root / "parent"), "parent traversal")

        symlink = tarfile.TarInfo("srv/lisa-edge/docker/escape")
        symlink.type = tarfile.SYMTYPE
        symlink.linkname = "../../../../etc"
        symlink_archive = root / "symlink.tar.gz"
        create_archive(symlink_archive, symlink)
        expect_rejected(validate(symlink_archive, root / "symlink"), "escaping symlink")

        hardlink = tarfile.TarInfo("srv/lisa-edge/docker/hardlink")
        hardlink.type = tarfile.LNKTYPE
        hardlink.linkname = ENV_MEMBER
        hardlink_archive = root / "hardlink.tar.gz"
        create_archive(hardlink_archive, hardlink)
        expect_rejected(validate(hardlink_archive, root / "hardlink"), "hard link")

        unsafe_env_archive = root / "unsafe-env.tar.gz"
        create_archive(unsafe_env_archive, env=b"DATA_ROOT=$(touch /tmp/pwned)\n")
        expect_rejected(validate(unsafe_env_archive, root / "unsafe-env"), "executable .env")

    print("Backup-validation security tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
