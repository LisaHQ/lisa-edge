#!/usr/bin/env python3
"""Security regression tests for canonical v3 and legacy v2 backup validation."""

from __future__ import annotations

import io
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile


REPO_ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = REPO_ROOT / "ops" / "backup-restore" / "lib" / "validate_backup.py"
ENV_TEMPLATE = REPO_ROOT / ".env.template"
SAFE_ENV = (
    b"DATA_ROOT='/srv/lisa-edge'\n"
    b"OTBR_DATASET_BACKUP_DIR='/srv/lisa-edge/backups/otbr'\n"
)


def add_bytes(archive: tarfile.TarFile, name: str, content: bytes) -> None:
    member = tarfile.TarInfo(name)
    member.size = len(content)
    member.mode = 0o600
    archive.addfile(member, io.BytesIO(content))


def layout(version: int) -> tuple[str, str, list[str]]:
    if version == 2:
        return (
            "opt/lisa-edge/.env",
            "srv/lisa-edge/docker/volumes/test/data",
            ["opt/lisa-edge/.env", "opt/lisa-edge/compose", "srv/lisa-edge/docker"],
        )
    if version == 3:
        return ".env", "docker/volumes/test/data", [".env", "docker"]
    raise ValueError(f"unsupported fixture version: {version}")


def create_archive(
    path: Path,
    *,
    version: int,
    extra_member: tarfile.TarInfo | None = None,
    env: bytes = SAFE_ENV,
) -> None:
    env_member, data_member, _ = layout(version)
    with tarfile.open(path, "w:gz") as archive:
        add_bytes(archive, env_member, env)
        if version == 2:
            add_bytes(archive, "opt/lisa-edge/compose/docker-compose.yml", b"services: {}\n")
        add_bytes(archive, data_member, b"persistent\n")
        if extra_member is not None:
            if extra_member.isfile():
                payload = b"malicious\n"
                extra_member.size = len(payload)
                archive.addfile(extra_member, io.BytesIO(payload))
            else:
                archive.addfile(extra_member)


def validate(
    archive: Path,
    workdir: Path,
    *,
    version: int,
    extract: bool = False,
) -> subprocess.CompletedProcess[str]:
    env_member, _, allowed = layout(version)
    command = [
        sys.executable,
        str(VALIDATOR),
        "--archive",
        str(archive),
        "--env-member",
        env_member,
        "--env-output",
        str(workdir / "validated.env"),
        "--env-template",
        str(ENV_TEMPLATE),
    ]
    for allowed_path in allowed:
        command.extend(("--allow", allowed_path))
    if extract:
        command.extend(("--extract-root", str(workdir / "staging")))
    return subprocess.run(command, text=True, capture_output=True, check=False)


def expect_rejected(result: subprocess.CompletedProcess[str], label: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"validator accepted {label}")


def assert_safe_layout(root: Path, version: int) -> None:
    archive = root / f"safe-v{version}.tar.gz"
    workdir = root / f"safe-v{version}"
    create_archive(archive, version=version)
    result = validate(archive, workdir, version=version, extract=True)
    if result.returncode != 0:
        raise AssertionError(result.stderr)
    _, data_member, _ = layout(version)
    restored = workdir / "staging" / data_member
    if restored.read_bytes() != b"persistent\n":
        raise AssertionError(f"safe v{version} archive was not staged correctly")


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="lisa-backup-test-") as temp:
        root = Path(temp)

        assert_safe_layout(root, 2)
        assert_safe_layout(root, 3)

        outside = tarfile.TarInfo("etc/cron.d/lisa-test")
        outside_archive = root / "outside.tar.gz"
        create_archive(outside_archive, version=3, extra_member=outside)
        expect_rejected(validate(outside_archive, root / "outside", version=3), "out-of-scope path")

        parent = tarfile.TarInfo("../etc/cron.d/lisa-test")
        parent_archive = root / "parent.tar.gz"
        create_archive(parent_archive, version=3, extra_member=parent)
        expect_rejected(validate(parent_archive, root / "parent", version=3), "parent traversal")

        symlink = tarfile.TarInfo("docker/escape")
        symlink.type = tarfile.SYMTYPE
        symlink.linkname = "../../../../etc"
        symlink_archive = root / "symlink.tar.gz"
        create_archive(symlink_archive, version=3, extra_member=symlink)
        expect_rejected(validate(symlink_archive, root / "symlink", version=3), "escaping symlink")

        hardlink = tarfile.TarInfo("docker/hardlink")
        hardlink.type = tarfile.LNKTYPE
        hardlink.linkname = ".env"
        hardlink_archive = root / "hardlink.tar.gz"
        create_archive(hardlink_archive, version=3, extra_member=hardlink)
        expect_rejected(validate(hardlink_archive, root / "hardlink", version=3), "hard link")

        unsafe_env_archive = root / "unsafe-env.tar.gz"
        create_archive(
            unsafe_env_archive,
            version=3,
            env=b"DATA_ROOT=$(touch /tmp/pwned)\n",
        )
        expect_rejected(
            validate(unsafe_env_archive, root / "unsafe-env", version=3),
            "executable .env",
        )

    print("Backup-validation security tests passed for v2 and v3.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
