# Game Ghost

Game Ghost is a landscape, offline, mobile-first top-down roguelite vertical slice.

## Toolchain

- Godot 4.6.3 Standard
- GUT 9.6.0 at `addons/gut`

## Project layout

- `data/` contains typed, data-only Resource contracts and seed `mock_*.tres` data.
- `services/` contains the three permitted autoloads: session, local save, and audio.
- `assets/runtime/` is reserved for runtime-ready game assets.
- `tests/` contains deterministic GUT coverage.

Concept/source art belongs outside `assets/runtime/`; it is reference material and must not be treated as runtime sprites.

## Verification

From this directory, import and validate the project headlessly:

```powershell
godot --headless --import --path .
godot --headless --editor --quit --path .
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

`export_presets.cfg` includes Android and iOS. Android requires local SDK/JDK configuration before export. The iOS preset is intentionally unverified until macOS, Xcode, signing credentials, and an iPhone are available.
