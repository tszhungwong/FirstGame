# Mobile release and verification

## Current verification boundary

| Target | Status | Evidence required before changing status |
| --- | --- | --- |
| Windows headless gameplay | Locally verified | Fresh import/editor/version, GUT, scene-smoke, runtime, and asset-validator output |
| Android ARM64 debug | Configured; not locally verified | Android SDK/JDK/export templates installed and a non-empty APK produced |
| iOS ARM64 Xcode project | Configured; not locally verified | macOS CI or local macOS produces the export archive |
| Signed iOS app/device | Unverified by design | Xcode signing team, provisioning profile, successful device build, and iPhone test |

Do not describe Android or iOS as verified based only on a committed preset. The CI jobs are export smoke configuration; they do not replace signing, store validation, or hardware testing.

The committed iOS Team ID `XXXXXXXXXX` is a deliberate ten-character CI placeholder because Godot requires this field even to generate the Xcode project. Replace it with the real Apple Developer Team ID outside source control before signing. Godot's current platform requirements are documented in the official [iOS export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) and [Android export guide](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_android.html).

## Required release checks

From the repository root on Windows, using the pinned Godot console executable when `godot` is not on `PATH`:

```powershell
py -3 -m unittest discover -s tools/tests -p "test_*.py" -v
py -3 tools/validate_assets.py
godot --headless --import --path game
godot --headless --editor --quit --path game
godot --headless --path game --script res://tools/validate_godot_version.gd
godot --headless --path game --script res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
godot --headless --path game res://tests/smoke/combat_smoke.tscn
godot --headless --path game res://tests/smoke/run_loop_smoke.tscn
godot --headless --path game res://tests/smoke/mobile_ui_smoke.tscn
```

Android debug export is guarded so missing SDK components are reported before Godot is invoked:

```powershell
.\tools\export_android_debug.ps1 -GodotPath "C:\path\to\godot.exe"
```

On macOS with Xcode and templates installed:

```bash
GODOT_BIN=/path/to/godot ./tools/export_ios_smoke.sh
```

## Asset and audio policy

- Concept art is outside `res://` at `source_art/concepts/` and is never shipped as a sprite.
- Runtime media belongs only under `game/assets/runtime/` and must be registered.
- The current sounds are deterministic PCM placeholders synthesized by `AudioService`; there are no externally licensed runtime audio files.
- Replace a procedural cue only after its recorded source, license, attribution, and runtime dimensions/format pass validation.

## Mobile review

- Exercise 16:9, 19.5:9, and 4:3 landscape sizes plus at least one physical notched device.
- Confirm joystick, dash, skill, pause, rewards, and end-state UI stay within the safe area.
- Verify lifecycle pause/resume and checkpoint recovery after backgrounding.
- Capture FPS, memory, active enemies, and active projectiles from the timer-based overlay during the boss room.
- For signed release, update bundle versions, Android signing, Apple team/provisioning, privacy declarations, icons, and store metadata outside source control.
