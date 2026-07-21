from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import unittest


ROOT = Path(__file__).parents[2]


LOWERCASE_ASCII_SNAKE_CASE = re.compile(r"^[a-z0-9_]+(?:\.[a-z0-9_]+)*$")
REPOSITORY_METADATA_PARTS = {".github", ".superpowers"}
REPOSITORY_METADATA_FILES = {".gitattributes", ".gitignore"}


class PathNamingTests(unittest.TestCase):
    def test_all_project_owned_tracked_paths_use_lowercase_ascii_snake_case(self) -> None:
        tracked = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=ROOT,
            capture_output=True,
            check=True,
        ).stdout.decode("utf-8").split("\0")
        invalid: list[str] = []
        for path in filter(None, tracked):
            if path.startswith("game/addons/gut/"):
                continue
            for part in Path(path).parts:
                if part in REPOSITORY_METADATA_PARTS or part in REPOSITORY_METADATA_FILES:
                    continue
                if not LOWERCASE_ASCII_SNAKE_CASE.fullmatch(part):
                    invalid.append(path)
                    break

        self.assertEqual(invalid, [])

    def test_path_validator_covers_all_tracked_paths(self) -> None:
        result = subprocess.run(
            [sys.executable, "tools/validate_paths.py"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_project_reports_and_design_docs_use_snake_case_names(self) -> None:
        self.assertTrue((ROOT / ".superpowers/sdd/task_2_report.md").is_file())
        self.assertTrue((ROOT / ".superpowers/sdd/task_3_report.md").is_file())
        self.assertFalse((ROOT / ".superpowers/sdd/task-2-report.md").exists())
        self.assertFalse((ROOT / ".superpowers/sdd/task-3-report.md").exists())

    def test_vendor_exception_is_narrow_and_documented(self) -> None:
        tracked = subprocess.run(
            ["git", "ls-files", "game/addons/gut"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.splitlines()
        self.assertTrue(any("Gut" in path for path in tracked))
        policy = (ROOT / "docs/release/mobile_release.md").read_text(encoding="utf-8")
        self.assertIn("game/addons/gut/**", policy)
        self.assertIn("upstream file names", policy)


if __name__ == "__main__":
    unittest.main()
