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


if __name__ == "__main__":
    unittest.main()
