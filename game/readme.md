# Game Ghost

Game Ghost is a landscape, offline, mobile-first top-down roguelite vertical slice.

## Toolchain

- Godot 4.6.3 Standard
- GUT 9.6.0 at `addons/gut`

## Project layout

- `data/` contains typed, data-only Resource contracts and seed `mock_*.tres` data.
- `services/` contains the three permitted autoloads: session, local save, and audio.
- `assets/runtime/` is reserved for runtime-ready game assets.
- Repository-level `../source_art/concepts/` holds concept references outside Godot's `res://` boundary.
- `tests/` contains deterministic GUT coverage.
- `tools/validate_godot_version.gd` enforces the version in `godot_version.txt` and the landscape ProjectSettings value.

The archived repository concept images live under `../source_art/concepts/`; they remain Git LFS files and must not be treated as runtime sprites. Runtime-ready derivatives belong under `assets/runtime/` and require an asset-register entry.

All project paths use lowercase ASCII snake_case. Vendored third-party paths, including `addons/gut/`, retain their upstream names and are exempt from this project naming rule.

## Run checkpoint policy

The local checkpoint is written at each room boundary. It stores Ember's exact health on entry to the current room. A cold resume restarts that room with all enemies reset and restores precisely that entry health—never the mid-room health and never a free full heal. Reward screens freeze combat and carry the just-cleared health forward as the next room's entry checkpoint.

## Verification

From the repository root, import and validate the project headlessly:

```powershell
py -3 tools/run_scene_smoke.py --godot godot --godot-args --headless --import --path game
py -3 tools/run_scene_smoke.py --godot godot --godot-args --headless --editor --quit --path game
py -3 tools/run_scene_smoke.py --godot godot --expect-marker "Godot version pin and landscape ProjectSettings verified: 4.6.3" --godot-args --headless --path game --script res://tools/validate_godot_version.gd
py -3 tools/run_scene_smoke.py --godot godot --expect-marker "All tests passed!" --godot-args --headless --path game --script res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

`export_presets.cfg` includes Android and iOS. Android requires local SDK/JDK configuration before export. The iOS preset is intentionally unverified until macOS, Xcode, signing credentials, and an iPhone are available.

Repository-level delivery checks also include:

```powershell
py -3 tools/validate_paths.py
py -3 tools/validate_assets.py
py -3 tools/run_scene_smoke.py --godot godot --expect-marker COMBAT_SMOKE_OK --godot-args --headless --path game res://tests/smoke/combat_smoke.tscn
py -3 tools/run_scene_smoke.py --godot godot --expect-marker RUN_LOOP_SMOKE_OK --godot-args --headless --path game res://tests/smoke/run_loop_smoke.tscn
py -3 tools/run_scene_smoke.py --godot godot --expect-marker MOBILE_UI_SMOKE_OK --godot-args --headless --path game res://tests/smoke/mobile_ui_smoke.tscn
py -3 tools/run_scene_smoke.py --godot godot --expect-marker RUNTIME_SHUTDOWN_SMOKE_OK --forbid-output "ObjectDB instances leaked" --godot-args --headless --path game res://tests/smoke/runtime_shutdown_smoke.tscn
```

All project-loading Godot commands use the wrapper so autoload initialization receives a unique disposable storage root and the production save is verified byte-for-byte afterward.

See `docs/release/mobile_release.md` for the verified-versus-configured platform matrix and guarded export scripts.
