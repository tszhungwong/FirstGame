from __future__ import annotations

import argparse
import csv
from pathlib import Path
import struct
import sys
import zlib


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
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
PNG_COLOR_SAMPLES = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
PNG_VALID_BIT_DEPTHS = {
    0: {1, 2, 4, 8, 16},
    2: {8, 16},
    3: {1, 2, 4, 8},
    4: {8, 16},
    6: {8, 16},
}


def _normalized_relative_path(value: str) -> str:
    return value.strip().replace("\\", "/")


def _is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def _resolve_strict_reference(
    root: Path,
    value: str,
    allowed_root: Path | None = None,
    allowed_label: str = "",
) -> tuple[Path | None, str | None]:
    normalized = _normalized_relative_path(value)
    if not normalized:
        return None, "missing reference"
    try:
        resolved = (root / normalized).resolve(strict=True)
    except (OSError, RuntimeError):
        return None, f"missing file {normalized}"
    if not _is_within(resolved, root):
        return None, "escapes repository after canonical resolution"
    if allowed_root is not None and not _is_within(resolved, allowed_root):
        return None, f"outside {allowed_label}"
    if not resolved.is_file():
        return None, f"not a file: {normalized}"
    return resolved, None


def _expected_png_decode_size(width: int, height: int, bits_per_pixel: int, interlace: int) -> int:
    if interlace == 0:
        return height * (1 + ((width * bits_per_pixel + 7) // 8))
    total = 0
    for x_start, y_start, x_step, y_step in (
        (0, 0, 8, 8),
        (4, 0, 8, 8),
        (0, 4, 4, 8),
        (2, 0, 4, 4),
        (0, 2, 2, 4),
        (1, 0, 2, 2),
        (0, 1, 1, 2),
    ):
        pass_width = 0 if width <= x_start else (width - x_start + x_step - 1) // x_step
        pass_height = 0 if height <= y_start else (height - y_start + y_step - 1) // y_step
        if pass_width > 0 and pass_height > 0:
            total += pass_height * (1 + ((pass_width * bits_per_pixel + 7) // 8))
    return total


def _png_filter_bytes_are_valid(
    decoded: bytes,
    width: int,
    height: int,
    bits_per_pixel: int,
    interlace: int,
) -> bool:
    offset = 0
    passes = ((0, 0, 1, 1),) if interlace == 0 else (
        (0, 0, 8, 8),
        (4, 0, 8, 8),
        (0, 4, 4, 8),
        (2, 0, 4, 4),
        (0, 2, 2, 4),
        (1, 0, 2, 2),
        (0, 1, 1, 2),
    )
    for x_start, y_start, x_step, y_step in passes:
        pass_width = 0 if width <= x_start else (width - x_start + x_step - 1) // x_step
        pass_height = 0 if height <= y_start else (height - y_start + y_step - 1) // y_step
        row_size = (pass_width * bits_per_pixel + 7) // 8
        for _row in range(pass_height if pass_width > 0 else 0):
            if offset >= len(decoded) or decoded[offset] > 4:
                return False
            offset += 1 + row_size
    return offset == len(decoded)


def _validate_png(path: Path) -> tuple[tuple[int, int] | None, str | None]:
    try:
        payload = path.read_bytes()
    except OSError as error:
        return None, f"could not read file: {error}"
    if not payload.startswith(PNG_SIGNATURE):
        return None, "invalid PNG signature"
    offset = len(PNG_SIGNATURE)
    chunk_index = 0
    width = height = bit_depth = color_type = interlace = 0
    saw_ihdr = saw_idat = saw_iend = saw_plte = False
    idat_closed = False
    idat_parts: list[bytes] = []
    while offset < len(payload):
        if len(payload) - offset < 12:
            return None, "truncated PNG chunk"
        length = struct.unpack(">I", payload[offset:offset + 4])[0]
        chunk_end = offset + 12 + length
        if chunk_end > len(payload):
            return None, "truncated PNG chunk data"
        chunk_type = payload[offset + 4:offset + 8]
        chunk_data = payload[offset + 8:offset + 8 + length]
        stored_crc = struct.unpack(">I", payload[offset + 8 + length:chunk_end])[0]
        actual_crc = zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF
        if stored_crc != actual_crc:
            return None, f"CRC mismatch in {chunk_type.decode('ascii', errors='replace')} chunk"
        if chunk_index == 0 and chunk_type != b"IHDR":
            return None, "IHDR must be the first PNG chunk"
        if chunk_type == b"IHDR":
            if saw_ihdr or length != 13:
                return None, "invalid or duplicate IHDR"
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(">IIBBBBB", chunk_data)
            if width <= 0 or height <= 0:
                return None, "PNG dimensions must be positive"
            if color_type not in PNG_VALID_BIT_DEPTHS or bit_depth not in PNG_VALID_BIT_DEPTHS[color_type]:
                return None, "invalid PNG color type or bit depth"
            if compression != 0 or filter_method != 0 or interlace not in {0, 1}:
                return None, "unsupported PNG compression, filter, or interlace method"
            saw_ihdr = True
        elif chunk_type == b"PLTE":
            if not saw_ihdr or saw_idat or saw_plte or length == 0 or length % 3 != 0 or length > 768:
                return None, "invalid PLTE chunk"
            saw_plte = True
        elif chunk_type == b"IDAT":
            if not saw_ihdr or idat_closed:
                return None, "invalid or non-consecutive IDAT chunks"
            saw_idat = True
            idat_parts.append(chunk_data)
        elif chunk_type == b"IEND":
            if not saw_ihdr or not saw_idat or saw_iend or length != 0:
                return None, "invalid IEND chunk"
            saw_iend = True
            offset = chunk_end
            if offset != len(payload):
                return None, "trailing bytes after IEND"
            break
        else:
            if saw_idat:
                idat_closed = True
            if chunk_type and 65 <= chunk_type[0] <= 90:
                return None, f"unknown critical PNG chunk {chunk_type!r}"
        offset = chunk_end
        chunk_index += 1
    if not saw_ihdr:
        return None, "missing IHDR chunk"
    dimensions = (width, height)
    if not saw_idat:
        return dimensions, "missing IDAT chunk"
    if not saw_iend:
        return dimensions, "missing IEND chunk"
    if color_type == 3 and not saw_plte:
        return dimensions, "indexed PNG is missing PLTE"
    if width > 2048 or height > 2048:
        return dimensions, None
    bits_per_pixel = PNG_COLOR_SAMPLES[color_type] * bit_depth
    expected_size = _expected_png_decode_size(width, height, bits_per_pixel, interlace)
    try:
        decompressor = zlib.decompressobj()
        decoded = decompressor.decompress(b"".join(idat_parts), expected_size + 1)
        if decompressor.unconsumed_tail:
            return dimensions, "decoded scanline data exceeds expected size"
        decoded += decompressor.flush()
    except zlib.error as error:
        return dimensions, f"IDAT zlib decode failed: {error}"
    if not decompressor.eof or decompressor.unused_data:
        return dimensions, "IDAT zlib stream is incomplete or has trailing data"
    if len(decoded) != expected_size:
        return dimensions, f"decoded scanline size mismatch: expected {expected_size}, got {len(decoded)}"
    if not _png_filter_bytes_are_valid(decoded, width, height, bits_per_pixel, interlace):
        return dimensions, "invalid PNG scanline filter bytes"
    return dimensions, None


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


def _prompt_anchor_exists(path: Path, anchor: str) -> bool:
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
    try:
        root = root.resolve(strict=True)
    except OSError as error:
        return [f"repository root could not be resolved: {error}"]
    registry_path, registry_error = _resolve_strict_reference(root, "docs/assets/asset-register.csv")
    if registry_path is None:
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
    seen_canonical_targets: set[str] = set()
    registered_canonical_paths: set[Path] = set()
    source_root = (root / "source_art/concepts").resolve(strict=True)
    runtime_root = (root / "game/assets/runtime").resolve(strict=True)
    license_root = (root / "docs/assets/licenses").resolve(strict=True)
    ai_docs_root = (root / "docs/assets").resolve(strict=True)
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
        path, path_error = _resolve_strict_reference(root, relative_path)
        if path_error is not None:
            errors.append(f"{context}: file_path {path_error}")
        if relative_path.casefold() in seen_paths:
            errors.append(f"{context}: duplicate file_path")
        seen_paths.add(relative_path.casefold())
        if path is not None:
            canonical_key = path.as_posix().casefold()
            if canonical_key in seen_canonical_targets:
                errors.append(f"{context}: duplicate canonical file target")
            seen_canonical_targets.add(canonical_key)
            registered_canonical_paths.add(path)

        boundary = row["boundary"].strip().lower()
        expected_boundary = ""
        if path is not None and _is_within(path, source_root):
            expected_boundary = "source"
        elif path is not None and _is_within(path, runtime_root):
            expected_boundary = "runtime"
        if not expected_boundary:
            errors.append(f"{context}: file_path outside {boundary or 'declared'} boundary")
        elif boundary != expected_boundary:
            errors.append(f"{context}: boundary does not match canonical file target")
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
        _license_path, license_error = _resolve_strict_reference(
            root,
            license_ref,
            license_root,
            "docs/assets/licenses",
        )
        if license_error is not None:
            errors.append(f"{context}: license_ref {license_error}")
        if not row["attribution"].strip():
            errors.append(f"{context}: missing attribution")

        ai_generated = row["ai_generated"].strip().lower()
        if ai_generated not in {"yes", "no"}:
            errors.append(f"{context}: ai_generated must be yes or no")
        elif ai_generated == "yes":
            if not row["ai_tool"].strip():
                errors.append(f"{context}: missing ai_tool")
            prompt_ref = row["ai_prompt_ref"].strip()
            prompt_file, separator, prompt_anchor = prompt_ref.partition("#")
            prompt_path, prompt_error = _resolve_strict_reference(
                root,
                prompt_file,
                ai_docs_root,
                "docs/assets",
            )
            if prompt_error is not None:
                errors.append(f"{context}: ai_prompt_ref {prompt_error}")
            elif not separator or not prompt_anchor or not _prompt_anchor_exists(prompt_path, prompt_anchor):
                errors.append(f"{context}: missing or invalid ai_prompt_ref anchor")

        if expected_boundary == "runtime" and path is not None and path.suffix.lower() == ".png":
            dimensions, png_error = _validate_png(path)
            if png_error is not None:
                errors.append(f"{context}: runtime PNG invalid: {png_error}")
            elif dimensions is None:
                errors.append(f"{context}: runtime PNG invalid: dimensions unavailable")
            elif dimensions[0] > 2048 or dimensions[1] > 2048:
                errors.append(f"{context}: runtime asset exceeds 2048x2048 ({dimensions[0]}x{dimensions[1]})")

    registered_relative_paths = {
        path.relative_to(root).as_posix()
        for path in registered_canonical_paths
        if _is_within(path, root)
    }
    for missing in sorted(_discover_assets(root) - registered_relative_paths):
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
