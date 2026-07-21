from __future__ import annotations

from pathlib import Path, PurePosixPath
import sys
from typing import BinaryIO
import zipfile


FORBIDDEN_RESOURCE_MARKERS = (
    b"res://tests/",
    b"res://addons/gut/",
)
READ_SIZE = 1024 * 1024


def validate_export_artifact(artifact: Path) -> list[str]:
    if not artifact.exists():
        return [f"export artifact does not exist: {artifact}"]
    if artifact.is_dir():
        return _validate_directory(artifact)
    if not zipfile.is_zipfile(artifact):
        return [f"export artifact is not an APK/ZIP or directory: {artifact}"]
    return _validate_zip(artifact)


def _validate_zip(artifact: Path) -> list[str]:
    errors: list[str] = []
    with zipfile.ZipFile(artifact) as archive:
        for member in archive.infolist():
            if member.is_dir():
                continue
            normalized_name = member.filename.replace("\\", "/")
            if _is_forbidden_path(normalized_name):
                errors.append(f"forbidden exported path: {normalized_name}")
            with archive.open(member) as content:
                marker = _find_forbidden_marker(content)
            if marker is not None:
                errors.append(
                    f"forbidden resource marker {marker.decode('ascii')} "
                    f"inside {normalized_name}"
                )
    return errors


def _validate_directory(artifact: Path) -> list[str]:
    errors: list[str] = []
    for path in artifact.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(artifact).as_posix()
        if _is_forbidden_path(relative):
            errors.append(f"forbidden exported path: {relative}")
        with path.open("rb") as content:
            marker = _find_forbidden_marker(content)
        if marker is not None:
            errors.append(
                f"forbidden resource marker {marker.decode('ascii')} inside {relative}"
            )
    return errors


def _is_forbidden_path(path: str) -> bool:
    parts = PurePosixPath(path.lstrip("/")).parts
    for index, part in enumerate(parts):
        if part == "tests":
            return True
        if part == "addons" and index + 1 < len(parts) and parts[index + 1] == "gut":
            return True
    return False


def _find_forbidden_marker(content: BinaryIO) -> bytes | None:
    overlap = max(len(marker) for marker in FORBIDDEN_RESOURCE_MARKERS) - 1
    previous = b""
    while chunk := content.read(READ_SIZE):
        combined = previous + chunk
        for marker in FORBIDDEN_RESOURCE_MARKERS:
            if marker in combined:
                return marker
        previous = combined[-overlap:]
    return None


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_export_contents.py <apk-zip-or-directory>", file=sys.stderr)
        return 2
    artifact = Path(argv[1])
    errors = validate_export_artifact(artifact)
    if errors:
        for error in errors:
            print(f"EXPORT_CONTENT_VALIDATION_ERROR: {error}", file=sys.stderr)
        return 1
    print(f"EXPORT_CONTENT_VALIDATION_OK: {artifact}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
