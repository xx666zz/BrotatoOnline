#!/usr/bin/env python3
"""Build and verify a deterministic Brotato Online runtime ZIP."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PREFIX = "mods-unpacked/six666-BrotatoOnline/"
RUNTIME_ROOT_FILES = ("manifest.json", "mod_main.gd")
RUNTIME_DIRS = ("scripts", "extensions", "translations")
FORBIDDEN_PARTS = {"__pycache__", "logs", "tests", "tools", "dist", ".git"}
FIXED_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


def protocol_config() -> tuple[str, int]:
    text = (ROOT / "scripts/network_protocol_config.gd").read_text(encoding="utf-8")
    version_match = re.search(r'^const MOD_VERSION = "([^"]+)"$', text, re.MULTILINE)
    protocol_match = re.search(r"^const PROTOCOL_VERSION = (\d+)$", text, re.MULTILINE)
    if not version_match or not protocol_match:
        raise RuntimeError("network_protocol_config.gd does not expose version constants")
    return version_match.group(1), int(protocol_match.group(1))


def runtime_files() -> list[Path]:
    files = [ROOT / name for name in RUNTIME_ROOT_FILES]
    for directory in RUNTIME_DIRS:
        files.extend(path for path in (ROOT / directory).rglob("*") if path.is_file())
    files = sorted(files, key=lambda path: path.relative_to(ROOT).as_posix())
    for path in files:
        relative = path.relative_to(ROOT)
        if any(part in FORBIDDEN_PARTS or part.startswith(".") for part in relative.parts):
            raise RuntimeError(f"forbidden runtime path: {relative}")
        if path.suffix.lower() in {".py", ".pyc", ".pyo", ".rar", ".zip", ".log"}:
            raise RuntimeError(f"forbidden runtime artifact: {relative}")
    return files


def validate_versions() -> tuple[str, int]:
    version, protocol = protocol_config()
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    if str(manifest.get("version_number", "")) != version:
        raise RuntimeError("manifest version does not match network_protocol_config.gd")
    if version != "4.1.1" or protocol != 2:
        raise RuntimeError(f"release must remain fixed at 4.1.1 / protocol 2, got {version} / {protocol}")
    return version, protocol


def build_zip_bytes(files: list[Path]) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            relative = path.relative_to(ROOT).as_posix()
            info = zipfile.ZipInfo(PREFIX + relative, FIXED_TIMESTAMP)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    return output.getvalue()


def verify_zip_bytes(payload: bytes, files: list[Path]) -> None:
    expected_names = [PREFIX + path.relative_to(ROOT).as_posix() for path in files]
    with zipfile.ZipFile(io.BytesIO(payload), "r") as archive:
        if archive.testzip() is not None:
            raise RuntimeError("ZIP CRC verification failed")
        if archive.namelist() != expected_names:
            raise RuntimeError("ZIP file list or ordering differs from the runtime allowlist")
        for path, archive_name in zip(files, expected_names):
            source_hash = hashlib.sha256(path.read_bytes()).digest()
            archive_hash = hashlib.sha256(archive.read(archive_name)).digest()
            if source_hash != archive_hash:
                raise RuntimeError(f"ZIP content differs from working tree: {archive_name}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify without writing dist")
    parser.add_argument("--output", type=Path, help="override release ZIP path")
    args = parser.parse_args()

    version, protocol = validate_versions()
    files = runtime_files()
    first = build_zip_bytes(files)
    second = build_zip_bytes(files)
    if hashlib.sha256(first).digest() != hashlib.sha256(second).digest():
        raise RuntimeError("release ZIP is not reproducible")
    verify_zip_bytes(first, files)

    digest = hashlib.sha256(first).hexdigest()
    if not args.check:
        output = args.output or ROOT / "dist" / f"BrotatoOnline-{version}-test.zip"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(first)
        print(f"built {output.relative_to(ROOT)} sha256={digest}")
    else:
        print(f"release verified: version={version} protocol={protocol} files={len(files)} sha256={digest}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, zipfile.BadZipFile) as error:
        print(f"release verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
