from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).parents[2]


def production_save_path(environment: dict[str, str]) -> Path:
    if sys.platform == "win32":
        return (
            Path(environment["APPDATA"])
            / "Godot/app_userdata/Game Ghost/game_ghost_save.json"
        )
    if sys.platform == "darwin":
        return (
            Path(environment["HOME"])
            / "Library/Application Support/Godot/app_userdata/Game Ghost/game_ghost_save.json"
        )
    return (
        Path(environment["XDG_DATA_HOME"])
        / "godot/app_userdata/Game Ghost/game_ghost_save.json"
    )


class SmokeSaveIsolationTests(unittest.TestCase):
    def test_ci_runs_every_project_godot_check_through_the_isolation_wrapper(self) -> None:
        workflow = (ROOT / ".github/workflows/godot_ci.yml").read_text(
            encoding="utf-8"
        )
        for command in (
            "python tools/run_scene_smoke.py --godot godot --godot-args --headless --import --path game",
            "python tools/run_scene_smoke.py --godot godot --godot-args --headless --editor --quit --path game",
            "python tools/run_scene_smoke.py --godot godot --expect-marker \"Godot version pin and landscape ProjectSettings verified: 4.6.3\" --godot-args --headless --path game --script res://tools/validate_godot_version.gd",
            "python tools/run_scene_smoke.py --godot godot --expect-marker \"All tests passed!\" --godot-args --headless --path game --script res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit",
            "python tools/run_scene_smoke.py --godot godot --expect-marker COMBAT_SMOKE_OK --godot-args --headless --path game res://tests/smoke/combat_smoke.tscn",
            "python tools/run_scene_smoke.py --godot godot --expect-marker RUN_LOOP_SMOKE_OK --godot-args --headless --path game res://tests/smoke/run_loop_smoke.tscn",
            "python tools/run_scene_smoke.py --godot godot --expect-marker MOBILE_UI_SMOKE_OK --godot-args --headless --path game res://tests/smoke/mobile_ui_smoke.tscn",
            "python tools/run_scene_smoke.py --godot godot --expect-marker RUNTIME_SHUTDOWN_SMOKE_OK --forbid-output \"ObjectDB instances leaked\" --godot-args --headless --path game res://tests/smoke/runtime_shutdown_smoke.tscn",
        ):
            self.assertIn(command, workflow)

        self.assertNotIn("\n          godot --headless", workflow)
        self.assertNotIn("run: godot --headless", workflow)

    def test_arbitrary_wrapped_process_cannot_change_production_save(self) -> None:
        sentinel = b"production-save-sentinel\x00\xff"
        with tempfile.TemporaryDirectory(prefix="game_ghost_wrapper_test_") as temp:
            temp_root = Path(temp)
            environment = os.environ.copy()
            environment["APPDATA"] = str(temp_root / "appdata")
            environment["XDG_DATA_HOME"] = str(temp_root / "xdg_data")
            environment["HOME"] = str(temp_root / "home")
            production_save = production_save_path(environment)
            production_save.parent.mkdir(parents=True)
            production_save.write_bytes(sentinel)

            probe = (
                "from pathlib import Path; import os; "
                "root = Path(os.environ['GAME_GHOST_STORAGE_ROOT']); "
                "(root / 'probe.txt').write_bytes(b'isolated'); "
                "print(f'STORAGE_ROOT={root}'); print('ARBITRARY_GODOT_OK')"
            )
            result = subprocess.run(
                [
                    sys.executable,
                    "tools/run_scene_smoke.py",
                    "--godot",
                    sys.executable,
                    "--expect-marker",
                    "ARBITRARY_GODOT_OK",
                    "--godot-args",
                    "-c",
                    probe,
                ],
                cwd=ROOT,
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(production_save.read_bytes(), sentinel)
            self.assertIn("ARBITRARY_GODOT_OK", result.stdout)
            self.assertIn("SMOKE_SAVE_ISOLATION_OK", result.stdout)
            storage_line = next(
                line
                for line in result.stdout.splitlines()
                if line.startswith("STORAGE_ROOT=")
            )
            self.assertFalse(Path(storage_line.removeprefix("STORAGE_ROOT=")).exists())

    def test_arbitrary_wrapped_process_fails_closed_and_restores_violation(self) -> None:
        sentinel = b"production-save-sentinel"
        with tempfile.TemporaryDirectory(prefix="game_ghost_wrapper_test_") as temp:
            temp_root = Path(temp)
            environment = os.environ.copy()
            environment["APPDATA"] = str(temp_root / "appdata")
            environment["XDG_DATA_HOME"] = str(temp_root / "xdg_data")
            environment["HOME"] = str(temp_root / "home")
            production_save = production_save_path(environment)
            production_save.parent.mkdir(parents=True)
            production_save.write_bytes(sentinel)
            environment["PRODUCTION_SAVE_SENTINEL_PATH"] = str(production_save)

            violation = (
                "from pathlib import Path; import os; "
                "Path(os.environ['PRODUCTION_SAVE_SENTINEL_PATH']).write_bytes(b'changed'); "
                "print('VIOLATION_ATTEMPTED')"
            )
            result = subprocess.run(
                [
                    sys.executable,
                    "tools/run_scene_smoke.py",
                    "--godot",
                    sys.executable,
                    "--godot-args",
                    "-c",
                    violation,
                ],
                cwd=ROOT,
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(production_save.read_bytes(), sentinel)
            self.assertIn("production save changed and was restored", result.stderr)

    def test_wrapped_process_output_is_safe_for_the_console_encoding(self) -> None:
        environment = os.environ.copy()
        environment["PYTHONIOENCODING"] = "ascii"
        result = subprocess.run(
            [
                sys.executable,
                "tools/run_scene_smoke.py",
                "--godot",
                sys.executable,
                "--godot-args",
                "-c",
                "import sys; sys.stdout.buffer.write(b'INVALID_UTF8=\\xff\\n')",
            ],
            cwd=ROOT,
            env=environment,
            capture_output=True,
            check=False,
        )

        self.assertEqual(
            result.returncode,
            0,
            (result.stdout + result.stderr).decode(errors="replace"),
        )
        self.assertIn(b"SMOKE_SAVE_ISOLATION_OK", result.stdout)

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
        self.assertIn("--godot-args", result.stdout)

    def test_shutdown_smoke_emits_the_real_root_signal(self) -> None:
        script = (ROOT / "game/tests/smoke/runtime_shutdown_smoke.gd").read_text(
            encoding="utf-8"
        )

        self.assertIn("root_window.close_requested.emit()", script)
        self.assertNotIn("AudioService._on_root_close_requested()", script)

    def test_documented_project_godot_checks_use_the_isolation_wrapper(self) -> None:
        documents = (
            (ROOT / "game/readme.md").read_text(encoding="utf-8"),
            (ROOT / "docs/release/mobile_release.md").read_text(encoding="utf-8"),
        )
        for document in documents:
            for arguments in (
                "--godot-args --headless --import --path game",
                "--godot-args --headless --editor --quit --path game",
                "--godot-args --headless --path game --script res://tools/validate_godot_version.gd",
                "--godot-args --headless --path game --script res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit",
                "--godot-args --headless --path game res://tests/smoke/combat_smoke.tscn",
                "--godot-args --headless --path game res://tests/smoke/run_loop_smoke.tscn",
                "--godot-args --headless --path game res://tests/smoke/mobile_ui_smoke.tscn",
                "--godot-args --headless --path game res://tests/smoke/runtime_shutdown_smoke.tscn",
            ):
                self.assertIn(
                    f"tools/run_scene_smoke.py --godot godot",
                    document,
                )
                self.assertIn(arguments, document)

            for raw_command in (
                "godot --headless --import",
                "godot --headless --editor",
                "godot --headless --path game --script",
                "godot --headless --path game res://tests/smoke",
                "godot --headless -s res://addons/gut",
            ):
                self.assertNotIn(raw_command, document)

        for document in documents:
            self.assertIn(
                "--expect-marker RUNTIME_SHUTDOWN_SMOKE_OK --forbid-output \"ObjectDB instances leaked\"",
                document,
            )


if __name__ == "__main__":
    unittest.main()
