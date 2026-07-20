from __future__ import annotations

import argparse
import csv
from pathlib import Path
import struct
import sys


REQUIRED_FIELDS = [
    "asset_id",
    "file_path",
    "category",
    "boundary",
    "creator",
    "source_url",
    "license_id",
    "license_status",
    "license_ref",
    "attribution",
    "ai_generated",
    "ai_tool",
    "ai_prompt_ref",
    "notes",
]
TRACKED_ASSET_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".wav", ".ogg",
    ".mp3", ".ttf", ".otf", ".kra", ".psd",
}
KNOWN_LICENSE_IDS = {
    "PROPRIETARY-PROJECT",
    "CC0-1.0",
    "CC-BY-4.0",
    "MIT",
    "OFL-1.1",
}
KNOWN_LICENSE_STATUSES = {"approved", "review_required", "restricted"}
SOURCE_PREFIX = "source_art/concepts/"
RUNTIME_PREFIX = "game/assets/runtime/"


def _normalized_relative_path(value: str) -> str:
    return value.strip().replace("\\", "/")


def _png_dimensions(path: Path) -> tuple[int, int] | None:
    try:
        with path.open("rb") as handle:
            signature = handle.read(24)
        if len(signature) >= 24 and signature[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", signature[16:24])
    except OSError:
        return None
    return None


def _discover_assets(root: Path) -> set[str]:
    discovered: set[str] = set()
    for relative_root in (Path("source_art/concepts"), Path("game/assets/runtime")):
        directory = root / relative_root
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix.lower() in TRACKED_ASSET_EXTENSIONS:
                discovered.add(path.relative_to(root).as_posix())
    return discovered


def _prompt_ref_exists(root: Path, reference: str) -> bool:
    file_part, _, anchor = reference.partition("#")
    path = root / _normalized_relative_path(file_part)
    if not path.is_file():
        return False
    if not anchor:
        return True
    wanted = anchor.strip().lower()
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            slug = line.lstrip("#").strip().lower().replace(" ", "-")
            if slug == wanted:
                return True
    return False


def validate_repository(root: Path) -> list[str]:
    root = root.resolve()
    registry_path = root / "docs/assets/asset-register.csv"
    if not registry_path.is_file():
        return ["missing asset registry: docs/assets/asset-register.csv"]
    errors: list[str] = []
    with registry_path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        fields = reader.fieldnames or []
        missing_fields = [field for field in REQUIRED_FIELDS if field not in fields]
        if missing_fields:
            return [f"asset registry missing required fields: {', '.join(missing_fields)}"]
        rows = list(reader)

    seen_ids: set[str] = set()
    seen_paths: set[str] = set()
    for row_number, row in enumerate(rows, start=2):
        asset_id = row["asset_id"].strip()
        relative_path = _normalized_relative_path(row["file_path"])
        context = asset_id or f"row {row_number}"
        if not asset_id:
            errors.append(f"row {row_number}: missing asset_id")
        elif asset_id in seen_ids:
            errors.append(f"{context}: duplicate asset_id")
        seen_ids.add(asset_id)
        if not relative_path:
            errors.append(f"{context}: missing file_path")
            continue
        path = root / relative_path
        try:
            path.resolve().relative_to(root)
        except ValueError:
            errors.append(f"{context}: file_path escapes repository")
            continue
        if not path.is_file():
            errors.append(f"{context}: missing file {relative_path}")
        if relative_path in seen_paths:
            errors.append(f"{context}: duplicate file_path")
        seen_paths.add(relative_path)

        boundary = row["boundary"].strip().lower()
        expected_boundary = "source" if relative_path.startswith(SOURCE_PREFIX) else "runtime" if relative_path.startswith(RUNTIME_PREFIX) else ""
        if not expected_boundary or boundary != expected_boundary:
            errors.append(f"{context}: boundary does not match {relative_path}")
        if not row["category"].strip():
            errors.append(f"{context}: missing category")
        if not row["creator"].strip():
            errors.append(f"{context}: missing creator")
        if not row["source_url"].strip():
            errors.append(f"{context}: missing source_url")
        license_id = row["license_id"].strip()
        if license_id not in KNOWN_LICENSE_IDS:
            errors.append(f"{context}: unknown license '{license_id}'")
        if row["license_status"].strip().lower() not in KNOWN_LICENSE_STATUSES:
            errors.append(f"{context}: unknown or missing license_status")
        license_ref = _normalized_relative_path(row["license_ref"])
        if not license_ref or not (root / license_ref).is_file():
            errors.append(f"{context}: missing license_ref")
        if not row["attribution"].strip():
            errors.append(f"{context}: missing attribution")

        ai_generated = row["ai_generated"].strip().lower()
        if ai_generated not in {"yes", "no"}:
            errors.append(f"{context}: ai_generated must be yes or no")
        elif ai_generated == "yes":
            if not row["ai_tool"].strip():
                errors.append(f"{context}: missing ai_tool")
            prompt_ref = row["ai_prompt_ref"].strip()
            if not prompt_ref or not _prompt_ref_exists(root, prompt_ref):
                errors.append(f"{context}: missing or invalid ai_prompt_ref")

        if boundary == "runtime" and path.suffix.lower() == ".png" and path.is_file():
            dimensions = _png_dimensions(path)
            if dimensions is None:
                errors.append(f"{context}: runtime PNG dimensions could not be read")
            elif dimensions[0] > 2048 or dimensions[1] > 2048:
                errors.append(f"{context}: runtime asset exceeds 2048x2048 ({dimensions[0]}x{dimensions[1]})")

    for missing in sorted(_discover_assets(root) - seen_paths):
        errors.append(f"unregistered asset: {missing}")

    game_root = root / "game"
    if game_root.exists():
        for path in game_root.rglob("*"):
            if path.suffix.lower() not in {".gd", ".tscn", ".tres", ".godot", ".cfg"} or not path.is_file():
                continue
            try:
                content = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            if "source_art/concepts" in content:
                errors.append(f"source/runtime boundary violation: {path.relative_to(root).as_posix()} references concept art")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Game Ghost asset provenance and runtime boundaries.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = validate_repository(args.root)
    if errors:
        for error in errors:
            print(f"ASSET_VALIDATION_ERROR: {error}", file=sys.stderr)
        return 1
    print("ASSET_VALIDATION_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
