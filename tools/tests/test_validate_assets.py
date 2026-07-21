from __future__ import annotations

import csv
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zlib


VALIDATOR_PATH = Path(__file__).parents[1] / "validate_assets.py"


def load_validator():
    spec = importlib.util.spec_from_file_location("validate_assets", VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("validator module could not be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def png_chunk(chunk_type: bytes, data: bytes, corrupt_crc: bool = False) -> bytes:
    crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
    if corrupt_crc:
        crc ^= 0xFFFFFFFF
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)


def make_rgba_png(width: int, height: int) -> bytes:
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    rows = b"".join(b"\x00" + (b"\x22\x66\x99\xff" * width) for _ in range(height))
    return b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", zlib.compress(rows)) + png_chunk(b"IEND", b"")


class ValidateAssetsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "source_art/concepts/characters").mkdir(parents=True)
        (self.root / "game/assets/runtime").mkdir(parents=True)
        (self.root / "docs/assets/licenses").mkdir(parents=True)
        (self.root / "docs/assets").mkdir(parents=True, exist_ok=True)
        (self.root / "docs/assets/licenses/project-owned.md").write_text("owned", encoding="utf-8")
        (self.root / "docs/assets/ai-prompts.md").write_text("# Prompt\n", encoding="utf-8")
        (self.root / "source_art/concepts/characters/ember.png").write_bytes(b"not-decoded-in-source")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write_registry(self, rows: list[dict[str, str]]) -> Path:
        path = self.root / "docs/assets/asset-register.csv"
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=load_validator().REQUIRED_FIELDS)
            writer.writeheader()
            writer.writerows(rows)
        return path

    def valid_row(self) -> dict[str, str]:
        return {
            "asset_id": "concept.ember",
            "file_path": "source_art/concepts/characters/ember.png",
            "category": "character_concept",
            "boundary": "source",
            "creator": "Game Ghost team",
            "source_url": "n/a",
            "license_id": "PROPRIETARY-PROJECT",
            "license_status": "approved",
            "license_ref": "docs/assets/licenses/project-owned.md",
            "attribution": "Game Ghost team; AI-assisted concept",
            "ai_generated": "yes",
            "ai_tool": "OpenAI image generation",
            "ai_prompt_ref": "docs/assets/ai-prompts.md#prompt",
            "notes": "Reference only; never loaded at runtime",
        }

    def test_accepts_complete_registered_source_asset(self) -> None:
        validator = load_validator()
        self.write_registry([self.valid_row()])

        self.assertEqual(validator.validate_repository(self.root), [])

    def test_rejects_duplicate_ids_unknown_license_and_missing_prompt(self) -> None:
        validator = load_validator()
        row = self.valid_row()
        invalid = self.valid_row()
        invalid["license_id"] = "UNKNOWN"
        invalid["license_ref"] = ""
        invalid["ai_prompt_ref"] = ""
        self.write_registry([row, invalid])

        errors = validator.validate_repository(self.root)

        self.assertTrue(any("duplicate asset_id" in error for error in errors))
        self.assertTrue(any("unknown license" in error for error in errors))
        self.assertTrue(any("ai_prompt_ref" in error for error in errors))

    def test_rejects_unregistered_asset_and_boundary_mismatch(self) -> None:
        validator = load_validator()
        row = self.valid_row()
        row["boundary"] = "runtime"
        self.write_registry([row])
        (self.root / "source_art/concepts/characters/unregistered.png").write_bytes(b"x")

        errors = validator.validate_repository(self.root)

        self.assertTrue(any("boundary" in error for error in errors))
        self.assertTrue(any("unregistered asset" in error for error in errors))

    def test_rejects_missing_file_and_attribution(self) -> None:
        validator = load_validator()
        row = self.valid_row()
        row["file_path"] = "source_art/concepts/characters/missing.png"
        row["attribution"] = ""
        self.write_registry([row])

        errors = validator.validate_repository(self.root)

        self.assertTrue(any("missing file" in error for error in errors))
        self.assertTrue(any("missing attribution" in error for error in errors))

    def test_rejects_runtime_png_above_2048_pixels(self) -> None:
        validator = load_validator()
        path = self.root / "game/assets/runtime/oversized.png"
        path.write_bytes(make_rgba_png(2049, 1))
        row = self.valid_row()
        row.update(
            {
                "asset_id": "runtime.oversized",
                "file_path": "game/assets/runtime/oversized.png",
                "category": "runtime_texture",
                "boundary": "runtime",
                "ai_generated": "no",
                "ai_tool": "",
                "ai_prompt_ref": "",
            }
        )
        self.write_registry([row])

        errors = validator.validate_repository(self.root)

        self.assertTrue(any("exceeds 2048x2048" in error for error in errors))

    def test_rejects_corrupt_runtime_png_mutations_with_small_dimensions(self) -> None:
        validator = load_validator()
        valid = make_rgba_png(2, 2)
        ihdr = struct.pack(">IIBBBBB", 2, 2, 8, 6, 0, 0, 0)
        mutations = {
            "truncated": valid[:-3],
            "crc_invalid": b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr, True) + valid[33:],
            "missing_ihdr": b"\x89PNG\r\n\x1a\n" + png_chunk(b"IDAT", zlib.compress(b"\x00")) + png_chunk(b"IEND", b""),
            "missing_idat": b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IEND", b""),
            "missing_iend": valid[:-12],
            "invalid_zlib": b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", b"invalid") + png_chunk(b"IEND", b""),
            "wrong_decode_size": b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", zlib.compress(b"\x00\x00")) + png_chunk(b"IEND", b""),
        }
        for mutation_name, payload in mutations.items():
            with self.subTest(mutation=mutation_name):
                path = self.root / "game/assets/runtime/corrupt.png"
                path.write_bytes(payload)
                row = self.valid_row()
                row.update(
                    {
                        "asset_id": "runtime.corrupt",
                        "file_path": "game/assets/runtime/corrupt.png",
                        "category": "runtime_texture",
                        "boundary": "runtime",
                        "ai_generated": "no",
                        "ai_tool": "",
                        "ai_prompt_ref": "",
                    }
                )
                self.write_registry([row])

                errors = validator.validate_repository(self.root)

                self.assertTrue(any("runtime PNG" in error for error in errors), errors)

    def test_rejects_traversal_and_canonical_alias_duplicate_target(self) -> None:
        validator = load_validator()
        (self.root / "outside.png").write_bytes(b"outside")
        first = self.valid_row()
        alias = self.valid_row()
        alias["asset_id"] = "concept.alias"
        alias["file_path"] = "source_art/concepts/characters/../characters/ember.png"
        traversal = self.valid_row()
        traversal["asset_id"] = "concept.traversal"
        traversal["file_path"] = "source_art/concepts/../../outside.png"
        self.write_registry([first, alias, traversal])

        errors = validator.validate_repository(self.root)

        self.assertTrue(any("duplicate canonical file target" in error for error in errors), errors)
        self.assertTrue(any("outside source boundary" in error for error in errors), errors)

    def test_rejects_case_insensitive_canonical_target_aliases(self) -> None:
        validator = load_validator()
        upper_path = self.root / "source_art/concepts/characters/Case.png"
        lower_path = self.root / "source_art/concepts/characters/case.png"
        upper_path.write_bytes(b"upper")
        lower_path.write_bytes(b"lower")
        upper = self.valid_row()
        upper["asset_id"] = "concept.case_upper"
        upper["file_path"] = "source_art/concepts/characters/Case.png"
        lower = self.valid_row()
        lower["asset_id"] = "concept.case_lower"
        lower["file_path"] = "source_art/concepts/characters/case.png"
        self.write_registry([self.valid_row(), upper, lower])

        errors = validator.validate_repository(self.root)

        self.assertTrue(any("duplicate canonical file target" in error for error in errors), errors)

    def test_rejects_license_and_prompt_refs_outside_their_allowed_docs_paths(self) -> None:
        validator = load_validator()
        (self.root / "docs/assets/license-outside.md").write_text("outside", encoding="utf-8")
        (self.root / "docs/outside-prompts.md").write_text("# Prompt\n", encoding="utf-8")
        row = self.valid_row()
        row["license_ref"] = "docs/assets/licenses/../license-outside.md"
        row["ai_prompt_ref"] = "docs/assets/../../docs/outside-prompts.md#prompt"
        self.write_registry([row])

        errors = validator.validate_repository(self.root)

        self.assertTrue(any("license_ref outside docs/assets/licenses" in error for error in errors), errors)
        self.assertTrue(any("ai_prompt_ref outside docs/assets" in error for error in errors), errors)

    def test_rejects_symlink_that_escapes_repository_when_supported(self) -> None:
        validator = load_validator()
        outside = self.root.parent / f"{self.root.name}-outside.png"
        outside.write_bytes(b"outside")
        self.addCleanup(lambda: outside.unlink(missing_ok=True))
        link = self.root / "source_art/concepts/characters/escape.png"
        try:
            link.symlink_to(outside)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation is unavailable")
        row = self.valid_row()
        row["file_path"] = "source_art/concepts/characters/escape.png"
        self.write_registry([row])

        errors = validator.validate_repository(self.root)

        self.assertTrue(any("escapes repository" in error for error in errors), errors)


if __name__ == "__main__":
    unittest.main()
