from __future__ import annotations

import csv
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest


VALIDATOR_PATH = Path(__file__).parents[1] / "validate_assets.py"


def load_validator():
    spec = importlib.util.spec_from_file_location("validate_assets", VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("validator module could not be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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
        path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + struct.pack(">II", 2049, 512))
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


if __name__ == "__main__":
    unittest.main()
