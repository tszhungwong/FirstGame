from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys


LOWERCASE_ASCII_SNAKE_CASE = re.compile(r"^[a-z0-9_]+(?:\.[a-z0-9_]+)*$")
REPOSITORY_METADATA_DIRECTORIES = {".github", ".superpowers"}
REPOSITORY_METADATA_FILES = {".gitattributes", ".gitignore"}
VENDORED_GUT_PREFIX = "game/addons/gut/"


def validate_tracked_paths(root: Path) -> list[str]:
    errors: list[str] = []
    tracked_output = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=root,
        capture_output=True,
        check=True,
    ).stdout.decode("utf-8")
    for tracked_path in filter(None, tracked_output.split("\0")):
        if tracked_path.startswith(VENDORED_GUT_PREFIX):
            continue
        for index, part in enumerate(Path(tracked_path).parts):
            if index == 0 and part in REPOSITORY_METADATA_DIRECTORIES:
                continue
            if part in REPOSITORY_METADATA_FILES:
                continue
            if not LOWERCASE_ASCII_SNAKE_CASE.fullmatch(part):
                errors.append(
                    "project-owned tracked path is not lowercase ASCII snake_case: "
                    f"{tracked_path}"
                )
                break
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors = validate_tracked_paths(root)
    if errors:
        for error in errors:
            print(f"PATH_VALIDATION_ERROR: {error}", file=sys.stderr)
        return 1
    print("PATH_VALIDATION_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
