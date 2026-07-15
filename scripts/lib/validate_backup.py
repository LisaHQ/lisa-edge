#!/usr/bin/env python3
"""Validate a LISA Edge backup before privileged extraction."""

from __future__ import annotations

import argparse
import os
import posixpath
from pathlib import PurePosixPath
import re
import shutil
import tarfile


ENV_KEY_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
UNQUOTED_VALUE_RE = re.compile(r"^[A-Za-z0-9_./:@?+,%=-]*$")
SINGLE_QUOTED_VALUE_RE = re.compile(r"^'[^']*'$")
DOUBLE_QUOTED_VALUE_RE = re.compile(r'^"[^"$`\\]*"$')


class ValidationError(Exception):
    pass


def normalize_member(name: str) -> str:
    if not name or name.startswith("/") or "\\" in name:
        raise ValidationError(f"unsafe archive member path: {name!r}")
    if any(ord(character) < 32 for character in name):
        raise ValidationError(f"control character in archive member: {name!r}")

    trimmed = name.rstrip("/")
    path = PurePosixPath(trimmed)
    if not trimmed or any(part in ("", ".", "..") for part in path.parts):
        raise ValidationError(f"unsafe archive member path: {name!r}")
    return str(path)


def normalize_allowed_path(path: str) -> str:
    normalized = normalize_member(path.lstrip("/"))
    if normalized in ("", "."):
        raise ValidationError("an archive allowlist path cannot be empty")
    return normalized


def is_allowed(member: str, allowed_paths: list[str]) -> bool:
    return any(member == path or member.startswith(path + "/") for path in allowed_paths)


def validate_symlink(member_name: str, link_name: str, allowed_paths: list[str] | None) -> None:
    if not link_name or link_name.startswith("/") or "\\" in link_name:
        raise ValidationError(f"unsafe symlink target for {member_name}: {link_name!r}")
    resolved = posixpath.normpath(posixpath.join(posixpath.dirname(member_name), link_name))
    if resolved == ".." or resolved.startswith("../"):
        raise ValidationError(f"symlink escapes archive root: {member_name}")
    if allowed_paths is not None and not is_allowed(resolved, allowed_paths):
        raise ValidationError(f"symlink target is outside the restore allowlist: {member_name}")


def load_allowed_env_keys(template_path: str) -> set[str]:
    keys: set[str] = set()
    with open(template_path, encoding="utf-8") as template:
        for raw_line in template:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key = line.split("=", 1)[0]
            if ENV_KEY_RE.fullmatch(key):
                keys.add(key)
    if not keys:
        raise ValidationError(f"no environment keys found in {template_path}")
    return keys


def validate_environment(content: bytes, allowed_keys: set[str]) -> str:
    if len(content) > 1024 * 1024:
        raise ValidationError("archived .env is unexpectedly large")
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ValidationError("archived .env is not valid UTF-8") from error

    seen: set[str] = set()
    normalized_lines: list[str] = []
    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValidationError(f"invalid .env line {line_number}")
        key, value = line.split("=", 1)
        if not ENV_KEY_RE.fullmatch(key) or key not in allowed_keys:
            raise ValidationError(f"unsupported .env key on line {line_number}: {key!r}")
        if key in seen:
            raise ValidationError(f"duplicate .env key: {key}")
        seen.add(key)
        if not (
            UNQUOTED_VALUE_RE.fullmatch(value)
            or SINGLE_QUOTED_VALUE_RE.fullmatch(value)
            or DOUBLE_QUOTED_VALUE_RE.fullmatch(value)
        ):
            raise ValidationError(f"unsafe .env value for {key} on line {line_number}")
        normalized_lines.append(f"{key}={value}")
    return "\n".join(normalized_lines) + "\n"


def inspect_archive(
    archive_path: str,
    env_member_name: str,
    env_output_path: str,
    env_template_path: str,
    allowed_paths: list[str] | None,
    extract_root: str | None,
) -> None:
    env_member_name = normalize_member(env_member_name)
    normalized_allowed = (
        [normalize_allowed_path(path) for path in allowed_paths]
        if allowed_paths is not None
        else None
    )
    seen: set[str] = set()
    symlink_names: set[str] = set()
    env_content: bytes | None = None

    try:
        archive = tarfile.open(archive_path, mode="r:gz")
    except (OSError, tarfile.TarError) as error:
        raise ValidationError(f"cannot read backup archive: {error}") from error

    with archive:
        for member in archive.getmembers():
            name = normalize_member(member.name)
            if name in seen:
                raise ValidationError(f"duplicate archive member: {name}")
            seen.add(name)

            if not (member.isfile() or member.isdir() or member.issym()):
                raise ValidationError(
                    f"unsupported archive member type for {name}; hard links and devices are forbidden"
                )
            if normalized_allowed is not None and not is_allowed(name, normalized_allowed):
                raise ValidationError(f"archive member is outside the restore allowlist: {name}")
            if member.issym():
                validate_symlink(name, member.linkname, normalized_allowed)
                symlink_names.add(name)
            if name == env_member_name:
                if not member.isfile():
                    raise ValidationError("archived .env is not a regular file")
                extracted = archive.extractfile(member)
                if extracted is None:
                    raise ValidationError("cannot read archived .env")
                env_content = extracted.read(1024 * 1024 + 1)

        for name in seen:
            if any(name.startswith(symlink + "/") for symlink in symlink_names):
                raise ValidationError(f"archive member is nested below a symlink: {name}")

    if env_content is None:
        raise ValidationError(f"required archive member is missing: {env_member_name}")

    text = validate_environment(env_content, load_allowed_env_keys(env_template_path))
    output_dir = os.path.dirname(os.path.abspath(env_output_path))
    os.makedirs(output_dir, mode=0o700, exist_ok=True)
    with open(env_output_path, "w", encoding="utf-8", newline="\n") as output:
        output.write(text)
    os.chmod(env_output_path, 0o600)

    if extract_root is not None:
        root = os.path.abspath(extract_root)
        os.makedirs(root, mode=0o700, exist_ok=True)
        directory_metadata: list[tuple[str, tarfile.TarInfo]] = []
        pending_symlinks: list[tuple[str, tarfile.TarInfo]] = []
        extraction_seen: set[str] = set()
        extraction_symlinks: set[str] = set()
        with tarfile.open(archive_path, mode="r:gz") as extraction_archive:
            extraction_members: list[tuple[tarfile.TarInfo, str]] = []
            for member in extraction_archive.getmembers():
                name = normalize_member(member.name)
                if name in extraction_seen:
                    raise ValidationError(f"duplicate archive member: {name}")
                extraction_seen.add(name)
                if not (member.isfile() or member.isdir() or member.issym()):
                    raise ValidationError(f"unsupported archive member type for {name}")
                if normalized_allowed is not None and not is_allowed(name, normalized_allowed):
                    raise ValidationError(f"archive member is outside the restore allowlist: {name}")
                if member.issym():
                    validate_symlink(name, member.linkname, normalized_allowed)
                    extraction_symlinks.add(name)
                extraction_members.append((member, name))

            for name in extraction_seen:
                if any(name.startswith(symlink + "/") for symlink in extraction_symlinks):
                    raise ValidationError(f"archive member is nested below a symlink: {name}")

            for member, name in extraction_members:
                destination = os.path.abspath(os.path.join(root, *PurePosixPath(name).parts))
                if os.path.commonpath((root, destination)) != root:
                    raise ValidationError(f"archive member escapes extraction root: {name}")
                if member.isdir():
                    os.makedirs(destination, mode=0o700, exist_ok=True)
                    directory_metadata.append((destination, member))
                    continue

                if member.issym():
                    pending_symlinks.append((destination, member))
                    continue

                os.makedirs(os.path.dirname(destination), mode=0o700, exist_ok=True)
                source = extraction_archive.extractfile(member)
                if source is None:
                    raise ValidationError(f"cannot extract archive member: {name}")
                with source, open(destination, "wb") as output:
                    shutil.copyfileobj(source, output, length=1024 * 1024)
                os.chmod(destination, member.mode & 0o7777)
                if hasattr(os, "geteuid") and os.geteuid() == 0:
                    os.chown(destination, member.uid, member.gid)
                os.utime(destination, (member.mtime, member.mtime))

        # Create links only after all regular files. This prevents an archive
        # from using an earlier symlink as the parent of a later file.
        for destination, member in pending_symlinks:
            os.makedirs(os.path.dirname(destination), mode=0o700, exist_ok=True)
            os.symlink(member.linkname, destination)

        for destination, member in reversed(directory_metadata):
            os.chmod(destination, member.mode & 0o7777)
            if hasattr(os, "geteuid") and os.geteuid() == 0:
                os.chown(destination, member.uid, member.gid)
            os.utime(destination, (member.mtime, member.mtime))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True)
    parser.add_argument("--env-member", required=True)
    parser.add_argument("--env-output", required=True)
    parser.add_argument("--env-template", required=True)
    parser.add_argument("--allow", action="append", dest="allowed_paths")
    parser.add_argument("--extract-root")
    args = parser.parse_args()

    try:
        inspect_archive(
            args.archive,
            args.env_member,
            args.env_output,
            args.env_template,
            args.allowed_paths,
            args.extract_root,
        )
    except ValidationError as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
