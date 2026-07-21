from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import unittest


ROOT = Path(__file__).parents[2]


class Task4PathNamingTests(unittest.TestCase):
    def test_task4_deliverable_paths_use_lowercase_ascii_snake_case(self) -> None:
        result = subprocess.run(
            [sys.executable, "tools/validate_task4_paths.py"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_tracked_task4_report_uses_snake_case_name(self) -> None:
        self.assertTrue((ROOT / ".superpowers/sdd/task_4_report.md").is_file())
        self.assertFalse((ROOT / ".superpowers/sdd/task-4-report.md").exists())


if __name__ == "__main__":
    unittest.main()
