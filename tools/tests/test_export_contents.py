from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).parents[2]
VALIDATOR = ROOT / "tools/validate_export_contents.py"


class ExportContentsTests(unittest.TestCase):
    def test_mobile_presets_exclude_tests_and_vendored_gut(self) -> None:
        presets = (ROOT / "game/export_presets.cfg").read_text(encoding="utf-8")

        self.assertEqual(
            presets.count('exclude_filter="tests/**,addons/gut/**"'),
            2,
        )

    def test_ci_inspects_both_exported_mobile_artifacts(self) -> None:
        workflow = (ROOT / ".github/workflows/godot_ci.yml").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "python tools/validate_export_contents.py game/builds/android/game_ghost.apk",
            workflow,
        )
        self.assertIn(
            "python tools/validate_export_contents.py game/builds/ios/game_ghost.zip",
            workflow,
        )

    def test_accepts_safe_zip_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact = Path(temporary_directory) / "safe.apk"
            with zipfile.ZipFile(artifact, "w") as archive:
                archive.writestr("assets/game_ghost.pck", b"res://scenes/run_game.tscn")

            result = self._run_validator(artifact)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_forbidden_resource_path_embedded_in_zip_member(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact = Path(temporary_directory) / "unsafe.apk"
            with zipfile.ZipFile(artifact, "w") as archive:
                archive.writestr(
                    "assets/game_ghost.pck",
                    b"binary-prefix\x00res://tests/smoke/run_loop_smoke.tscn\x00suffix",
                )

            result = self._run_validator(artifact)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("res://tests/", result.stderr)

    def test_rejects_forbidden_path_in_exported_ios_directory_layout(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact = Path(temporary_directory) / "ios_export"
            forbidden = artifact / "game/addons/gut/editor_plugin.gd"
            forbidden.parent.mkdir(parents=True)
            forbidden.write_text("vendored editor code", encoding="utf-8")

            result = self._run_validator(artifact)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("game/addons/gut/", result.stderr)

    def _run_validator(self, artifact: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(VALIDATOR), str(artifact)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )


if __name__ == "__main__":
    unittest.main()
