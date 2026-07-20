# Game Ghost

Game Ghost is a landscape, offline, mobile-first top-down roguelite vertical slice.

## Toolchain

- Godot 4.6.3 Standard
- GUT 9.6.0 at `addons/gut`

## Project layout

- `data/` contains typed, data-only Resource contracts and seed `mock_*.tres` data.
- `services/` contains the three permitted autoloads: session, local save, and audio.
- `assets/runtime/` is reserved for runtime-ready game assets.
- `source_art/concepts/` holds concept references that are never loaded as runtime sprites.
- `tests/` contains deterministic GUT coverage.
- `tools/validate_godot_version.gd` enforces the version in `godot_version.txt` and the landscape ProjectSettings value.

The existing repository-level `assets/` reference images remain untouched. New concept art belongs under `source_art/concepts/`; it is reference material and must not be treated as runtime sprites.

All project paths use lowercase ASCII snake_case. Vendored third-party paths, including `addons/gut/`, retain their upstream names and are exempt from this project naming rule.

## Verification

From this directory, import and validate the project headlessly:

```powershell
godot --headless --import --path .
godot --headless --editor --quit --path .
godot --headless --path . --script res://tools/validate_godot_version.gd
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

`export_presets.cfg` includes Android and iOS. Android requires local SDK/JDK configuration before export. The iOS preset is intentionally unverified until macOS, Xcode, signing credentials, and an iPhone are available.
