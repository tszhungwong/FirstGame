# Task 1 Report: Foundation and Data Contracts

## Delivered

- Created the Godot 4.6.3 Standard project at `game/`, with a landscape 1280×720 foundation scene.
- Vendored GUT 9.6.0 under `game/addons/gut` from the upstream `v9.6.0` tag.
- Configured only the permitted autoloads: `GameSession`, `LocalSave`, and `AudioService`.
- Added keyboard input actions for movement, dash, active skill, and pause.
- Added typed, data-only Resource contracts for character, weapon, enemy, upgrade, room, and asset-registry data.
- Added seed `mock_*.tres` Resource data and a typed `asset_registry.tres`.
- Added Android and iOS export presets. The iOS preset remains non-runnable/unverified by design.
- Added project/runtime asset documentation and baseline GUT coverage of the registry contracts.

## Files changed

- `.gitattributes`
- `game/.gitignore`
- `game/project.godot`
- `game/export_presets.cfg`
- `game/README.md`
- `game/scenes/foundation.tscn`
- `game/services/{game_session,local_save,audio_service}.gd`
- `game/data/{asset_registry,character_definition,weapon_definition,enemy_definition,upgrade_definition,room_definition}.gd`
- `game/data/{asset_registry,mock_ember_rifle,mock_ember_vanguard,mock_forest_chaser,mock_fire_rate_upgrade,mock_forest_combat_room}.tres`
- `game/assets/runtime/README.md`
- `game/tests/test_data_contracts.gd`
- `game/addons/gut/` (vendored GUT 9.6.0 and its MIT license)

Godot generated `.uid` files for project scripts are tracked. Generated GUT editor-asset `.import` descriptors are ignored.

## TDD record

The baseline registry test was created before the registry contracts/resources. Its initial invocation could not load the absent project scripts and unimported GUT class cache, which established the incomplete foundation state. After the minimal data-only contracts and seed registry were added and Godot was imported, GUT executed the two assertions successfully. No gameplay behavior was implemented in Task 1; the task contains only configuration/scaffolding and data contracts.

## Verification

Toolchain:

```text
Godot 4.6.3.stable.official.7d41c59c4
GUT 9.6.0
```

Fresh commands and results:

```text
Godot_v4.6.3-stable_win64_console.exe --headless --import --path game
IMPORT_EXIT=0

Godot_v4.6.3-stable_win64_console.exe --headless --editor --quit --path game
EDITOR_EXIT=0

Godot_v4.6.3-stable_win64_console.exe --headless --path game --quit-after 1
RUN_EXIT=0

Godot_v4.6.3-stable_win64_console.exe --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
2/2 passed; 9 asserts; GUT_EXIT=0

git diff --cached --check -- . ':(exclude)game/addons/gut'
CUSTOM_DIFF_CHECK_EXIT=0
```

## Concerns

- The local machine has no configured Android SDK `build-tools` directory. Godot reports that warning while scanning the configured Android preset, but all checks above exit successfully. An Android APK was not exported.
- Godot reports `ObjectDB instances leaked at exit` for headless import/editor startup with the enabled GUT editor plugin. There are no GDScript parse errors, and the runtime smoke test and GUT suite exit zero.
- The iOS preset is configured only; it cannot be verified on this Windows environment without macOS, Xcode, signing credentials, and an iPhone.

## Self-review

- Confirmed Resource classes contain exported data fields/enums only, with no gameplay logic.
- Confirmed the asset registry resolves one typed instance of each required definition and the character references its typed weapon.
- Confirmed autoload names do not collide with global GDScript class names.
- Confirmed third-party GUT import by version/tag and retained its upstream MIT license.
- Left the pre-existing untracked design and plan documents untouched.

## Fix Review Findings

### Changes

- Added the explicit Godot 4.6 landscape setting `display/window/handheld/orientation=0`; headless validation confirms it equals `DisplayServer.SCREEN_LANDSCAPE`.
- Added the lowercase machine-readable pin `game/godot_version.txt` (`4.6.3`) and `game/tools/validate_godot_version.gd`. The script fails with exit code 1 for any engine version mismatch and also validates the loaded landscape ProjectSettings value.
- Removed the GUT editor-plugin enablement from `project.godot`. GUT remains vendored and its CLI runner remains available; avoiding editor activation removes the ObjectDB warning from required headless import/editor startup.
- Renamed project-owned `README.md` files to lowercase `readme.md`, documented `source_art/concepts/`, and documented the third-party naming exemption for `addons/gut/`.

### Root-cause evidence

The original command below emitted `WARNING: ObjectDB instances leaked at exit` with exit 0:

```text
Godot_v4.6.3-stable_win64_console.exe --headless --editor --quit --path game
```

An isolated copy of the project with only the `res://addons/gut/plugin.cfg` editor enablement removed exited 0 with no ObjectDB warning. The plugin was therefore the cause, not a project autoload or scene. The project no longer enables it as an editor plugin.

### Fresh verification

```text
Godot_v4.6.3-stable_win64_console.exe --headless --import --path game
IMPORT_EXIT=0

Godot_v4.6.3-stable_win64_console.exe --headless --editor --quit --path game
EDITOR_EXIT=0

ObjectDB instances leaked scan across both logs
OBJECTDB_LEAK_WARNINGS=0

Godot_v4.6.3-stable_win64_console.exe --headless --path game --quit-after 1
RUN_EXIT=0

Godot_v4.6.3-stable_win64_console.exe --headless --path game --script res://tools/validate_godot_version.gd
Godot version pin and landscape ProjectSettings verified: 4.6.3
VERSION_AND_ORIENTATION_VALIDATOR_EXIT=0

Godot_v4.6.3-stable_win64_console.exe --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
5/5 passed; 14 asserts; GUT_EXIT=0
```

The mismatch behavior was also exercised in an ignored diagnostic copy with `godot_version.txt` set to `4.6.2`:

```text
Godot version pin mismatch: expected 4.6.2, got 4.6.3
MISMATCH_VALIDATOR_EXIT=1
```

The local editor still prints `Unable to open Android 'build-tools' directory` while scanning the required Android preset because its user-level Android SDK path has no build tools. This is an environment warning only; the listed commands exit 0, and no project-managed Android SDK was added.
