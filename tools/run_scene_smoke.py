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


def _write_process_output(output: str) -> None:
    console_encoding = sys.stdout.encoding or "utf-8"
    safe_output = output.encode(console_encoding, errors="replace").decode(
        console_encoding
    )
    sys.stdout.write(safe_output)


def run_isolated_godot(
    root: Path,
    godot: str,
    godot_arguments: list[str],
    expect_marker: str,
    forbidden_output: list[str],
) -> int:
    production_path = _production_save_path(_project_name(root / "game/project.godot"))
    before = _snapshot(production_path)
    output = ""
    return_code = 1
    launch_error = ""
    with tempfile.TemporaryDirectory(prefix="game_ghost_smoke_") as storage_root:
        environment = os.environ.copy()
        environment[STORAGE_ROOT_ENVIRONMENT] = storage_root
        try:
            result = subprocess.run(
                [godot, *godot_arguments],
                cwd=root,
                env=environment,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                errors="replace",
                check=False,
            )
            output = result.stdout
            return_code = result.returncode
            _write_process_output(output)
        except OSError as error:
            launch_error = str(error)
    after = _snapshot(production_path)
    if after != before:
        _restore_snapshot(production_path, before)
        print(
            "SMOKE_SAVE_ISOLATION_ERROR: production save changed and was restored: "
            f"{production_path}",
            file=sys.stderr,
        )
        return 1
    if launch_error:
        print(
            f"SMOKE_SAVE_ISOLATION_ERROR: failed to start process: {launch_error}",
            file=sys.stderr,
        )
        return 1
    if return_code != 0:
        return return_code
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
        description="Run Godot arguments with an isolated disposable save root."
    )
    parser.add_argument("--godot", required=True, help="Godot console executable")
    parser.add_argument("--expect-marker", default="", help="required output marker")
    parser.add_argument(
        "--forbid-output",
        action="append",
        default=[],
        help="output text that makes the smoke fail",
    )
    parser.add_argument(
        "--godot-args",
        dest="godot_arguments",
        nargs=argparse.REMAINDER,
        required=True,
        help="all remaining arguments are passed to Godot",
    )
    args = parser.parse_args(argv)
    godot_arguments = list(args.godot_arguments)
    if not godot_arguments:
        parser.error("Godot arguments are required after --godot-args")
    root = Path(__file__).resolve().parents[1]
    return run_isolated_godot(
        root,
        args.godot,
        godot_arguments,
        args.expect_marker,
        args.forbid_output,
    )


if __name__ == "__main__":
    raise SystemExit(main())
