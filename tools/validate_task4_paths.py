from __future__ import annotations

from pathlib import Path
import re
import sys


TASK4_PATH_ROOTS = (
    Path(".github/workflows"),
    Path("docs/assets"),
    Path("docs/release"),
    Path("source_art/concepts"),
)
LOWERCASE_ASCII_SNAKE_CASE = re.compile(r"^[a-z0-9_]+(?:\.[a-z0-9_]+)*$")


def validate_task4_paths(root: Path) -> list[str]:
    errors: list[str] = []
    for relative_root in TASK4_PATH_ROOTS:
        directory = root / relative_root
        if not directory.is_dir():
            errors.append(f"missing Task 4 path root: {relative_root.as_posix()}")
            continue
        for path in directory.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            scoped_relative = path.relative_to(directory)
            invalid_parts = [part for part in scoped_relative.parts if not LOWERCASE_ASCII_SNAKE_CASE.fullmatch(part)]
            if invalid_parts:
                errors.append(
                    "Task 4 path is not lowercase ASCII snake_case: "
                    f"{relative.as_posix()}"
                )
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors = validate_task4_paths(root)
    if errors:
        for error in errors:
            print(f"TASK4_PATH_VALIDATION_ERROR: {error}", file=sys.stderr)
        return 1
    print("TASK4_PATH_VALIDATION_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
