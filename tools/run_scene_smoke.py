from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


SAVE_FILE_NAME = "game_ghost_save.json"
STORAGE_ROOT_ENVIRONMENT = "GAME_GHOST_STORAGE_ROOT"


def _project_name(project_file: Path) -> str:
    project_text = project_file.read_text(encoding="utf-8")
    match = re.search(r'^config/name="([^"]+)"$', project_text, re.MULTILINE)
    if match is None:
        raise ValueError(f"config/name is missing from {project_file}")
    return match.group(1)


def _production_save_path(project_name: str) -> Path:
    if sys.platform == "win32":
        application_data = os.environ.get("APPDATA")
        if not application_data:
            raise ValueError("APPDATA is not set")
        user_data = Path(application_data) / "Godot" / "app_userdata"
    elif sys.platform == "darwin":
        user_data = Path.home() / "Library/Application Support/Godot/app_userdata"
    else:
        xdg_data_home = os.environ.get("XDG_DATA_HOME")
        data_home = Path(xdg_data_home) if xdg_data_home else Path.home() / ".local/share"
        user_data = data_home / "godot/app_userdata"
    return user_data / project_name / SAVE_FILE_NAME


def _snapshot(path: Path) -> tuple[bool, bytes]:
    return (path.exists(), path.read_bytes() if path.exists() else b"")


def _restore_snapshot(path: Path, snapshot: tuple[bool, bytes]) -> None:
    existed, content = snapshot
    if existed:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    elif path.exists():
        path.unlink()


def run_smoke(
    root: Path,
    godot: str,
    scene: str,
    expect_marker: str,
    forbidden_output: list[str],
) -> int:
    production_path = _production_save_path(_project_name(root / "game/project.godot"))
    before = _snapshot(production_path)
    with tempfile.TemporaryDirectory(prefix="game_ghost_smoke_") as storage_root:
        environment = os.environ.copy()
        environment[STORAGE_ROOT_ENVIRONMENT] = storage_root
        result = subprocess.run(
            [godot, "--headless", "--path", "game", scene],
            cwd=root,
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        output = result.stdout
        sys.stdout.write(output)
    after = _snapshot(production_path)
    if after != before:
        _restore_snapshot(production_path, before)
        print(
            "SMOKE_SAVE_ISOLATION_ERROR: production save changed and was restored: "
            f"{production_path}",
            file=sys.stderr,
        )
        return 1
    if result.returncode != 0:
        return result.returncode
    if expect_marker and expect_marker not in output:
        print(
            f"SMOKE_SAVE_ISOLATION_ERROR: missing success marker {expect_marker}",
            file=sys.stderr,
        )
        return 1
    for forbidden in forbidden_output:
        if forbidden in output:
            print(
                f"SMOKE_SAVE_ISOLATION_ERROR: forbidden output detected: {forbidden}",
                file=sys.stderr,
            )
            return 1
    print(f"SMOKE_SAVE_ISOLATION_OK: production save unchanged: {production_path}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Run a Godot scene smoke with an isolated disposable save root."
    )
    parser.add_argument("--godot", required=True, help="Godot console executable")
    parser.add_argument("--scene", required=True, help="res:// smoke scene path")
    parser.add_argument("--expect-marker", default="", help="required output marker")
    parser.add_argument(
        "--forbid-output",
        action="append",
        default=[],
        help="output text that makes the smoke fail",
    )
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    return run_smoke(
        root,
        args.godot,
        args.scene,
        args.expect_marker,
        args.forbid_output,
    )


if __name__ == "__main__":
    raise SystemExit(main())
