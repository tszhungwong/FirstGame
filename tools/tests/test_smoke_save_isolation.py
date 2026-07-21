from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import unittest


ROOT = Path(__file__).parents[2]


class SmokeSaveIsolationTests(unittest.TestCase):
    def test_ci_runs_every_saving_smoke_through_the_isolation_wrapper(self) -> None:
        workflow = (ROOT / ".github/workflows/godot_ci.yml").read_text(
            encoding="utf-8"
        )
        for scene in (
            "run_loop_smoke.tscn",
            "mobile_ui_smoke.tscn",
            "runtime_shutdown_smoke.tscn",
        ):
            self.assertIn(
                f"python tools/run_scene_smoke.py --godot godot --scene res://tests/smoke/{scene}",
                workflow,
            )

    def test_isolation_wrapper_has_a_runnable_cli(self) -> None:
        result = subprocess.run(
            [sys.executable, "tools/run_scene_smoke.py", "--help"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("--godot", result.stdout)
        self.assertIn("--scene", result.stdout)

    def test_shutdown_smoke_emits_the_real_root_signal(self) -> None:
        script = (ROOT / "game/tests/smoke/runtime_shutdown_smoke.gd").read_text(
            encoding="utf-8"
        )

        self.assertIn("root_window.close_requested.emit()", script)
        self.assertNotIn("AudioService._on_root_close_requested()", script)

    def test_documented_saving_smokes_use_the_isolation_wrapper(self) -> None:
        readme = (ROOT / "game/readme.md").read_text(encoding="utf-8")

        for scene in (
            "run_loop_smoke.tscn",
            "mobile_ui_smoke.tscn",
            "runtime_shutdown_smoke.tscn",
        ):
            self.assertIn(
                f"tools/run_scene_smoke.py --godot godot --scene res://tests/smoke/{scene}",
                readme,
            )
            self.assertNotIn(
                f"godot --headless --path game res://tests/smoke/{scene}",
                readme,
            )


if __name__ == "__main__":
    unittest.main()
