from __future__ import annotations

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).parents[2]
TUNING_RESOURCE = ROOT / "game/data/mock_audio_tuning.tres"
REQUIRED_TOP_LEVEL_PROPERTIES = (
    "sample_rate",
    "sfx_voice_count",
    "sfx_bus",
    "telegraph_bus",
    "ui_bus",
    "telegraph_gain_db",
)


class AudioTuningResourceTests(unittest.TestCase):
    def test_runtime_tuning_explicitly_authors_every_top_level_property(self) -> None:
        payload = TUNING_RESOURCE.read_text(encoding="utf-8")

        for property_name in REQUIRED_TOP_LEVEL_PROPERTIES:
            with self.subTest(property_name=property_name):
                self.assertRegex(payload, rf"(?m)^{re.escape(property_name)}\s*=")


if __name__ == "__main__":
    unittest.main()
