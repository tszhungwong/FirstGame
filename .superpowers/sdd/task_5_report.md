# Task 5: Verification and Review

Verification date: 2026-07-22

Worktree and starting HEAD: `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\.worktrees\feat-game-ghost-vertical-slice` at `442a393` (`feat/game-ghost-vertical-slice`).

## Review findings and fixes

1. Corrected the carry-forward documentation typo in `task_4_report.md`: `docs/assets/asset-register.csv` is now the actual tracked path, `docs/assets/asset_register.csv`.
2. Found a data-driven-runtime violation during direct review. `RuntimeCombatStats.apply_upgrade` hard-coded both Wildfire's minimum burn duration (`2.0`) and the dash cooldown floor (`0.35`). Neither value could be authored by the relevant Resource schema.
   - Root cause: `UpgradeDefinition` lacked `minimum_burn_duration`, and `CharacterDefinition` lacked `minimum_dash_cooldown`; the stat layer therefore owned gameplay tuning that belongs in data.
   - Red: added focused GUT contract tests and ran the full suite. Result: 57/59 passed; the two new tests failed at `test_run_controller.gd:91` and `:100` because neither property existed.
   - Green: added the two typed Resource properties, authored the existing values in `mock_upgrade_wildfire.tres` and `mock_ember_vanguard.tres`, and made `RuntimeCombatStats` consume them. The post-fix suite passed 59/59.

No other code, resource, license, path, lifecycle, or spec-compliance defect was found in this review.

## Fresh local acceptance chain

Pinned binary used throughout:

```powershell
& 'C:\Users\user\OneDrive\Documents\Project\Game_Ghost\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
```

| Command | Result |
| --- | --- |
| `py -3 -m unittest discover -s tools/tests -p "test_*.py" -v` | 13 passed; 1 expected skip because this Windows environment cannot create symlinks. |
| `py -3 tools/validate_task4_paths.py` | `TASK4_PATH_VALIDATION_OK`. |
| `py -3 tools/validate_assets.py` | `ASSET_VALIDATION_OK`. |
| `Godot_v4.6.3-stable_win64_console.exe --version` | `4.6.3.stable.official.7d41c59c4`. |
| `Godot_v4.6.3-stable_win64_console.exe --headless --import --path game` | Exit 0. Godot reported missing local Android build-tools, then completed import. |
| `Godot_v4.6.3-stable_win64_console.exe --headless --editor --quit --path game` | Exit 0. Same non-fatal local Android build-tools warning. |
| `Godot_v4.6.3-stable_win64_console.exe --headless --path game --script res://tools/validate_godot_version.gd` | `Godot version pin and landscape ProjectSettings verified: 4.6.3`. |
| `Godot_v4.6.3-stable_win64_console.exe --headless --path game --script res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` | 16 scripts, 59/59 tests, 284 asserts passed. |
| `Godot_v4.6.3-stable_win64_console.exe --headless --path game res://tests/smoke/combat_smoke.tscn` | `COMBAT_SMOKE_OK`. |
| `Godot_v4.6.3-stable_win64_console.exe --headless --path game res://tests/smoke/run_loop_smoke.tscn` | `RUN_LOOP_SMOKE_OK`. |
| `Godot_v4.6.3-stable_win64_console.exe --headless --path game res://tests/smoke/mobile_ui_smoke.tscn` | `MOBILE_UI_SMOKE_OK` for 16:9, 19.5:9, 4:3, and a synthetic notch. |
| `Godot_v4.6.3-stable_win64_console.exe --headless --path game res://tests/smoke/runtime_shutdown_smoke.tscn` | `RUNTIME_SHUTDOWN_SMOKE_OK`; production root close request shut audio down and drained the server. No `ObjectDB instances leaked` output. |
| `git diff --check` | Exit 0 with no whitespace errors. |
| `git lfs fsck` | `Git LFS fsck OK`. |

The Task 5 delta also passes `git diff --check 442a393..HEAD`. A branch-range scan from the implementation baseline, `git diff --check 9f3f076..HEAD`, reports pre-existing whitespace warnings in vendored `game/addons/gut/` files and two prior plan/spec documents. Those warnings are outside this Task 5 delta; vendored source was left unchanged rather than silently modifying third-party code.

## Manual branch review

- Read the design, implementation plan, game readme, mobile release matrix, progress file, source/resources, autoloads, scene smoke scripts, validators, asset register/licenses, export scripts, and `.github/workflows/godot_ci.yml` directly.
- Landscape and mobile UI are enforced by the version/project validator and the safe-area smoke. The run scene has pause/focus-out handling, room-boundary checkpoint persistence, and deterministic end-state shutdown. Audio listens to the production root close request, stops players, rejects new cues while shutting down, and is covered by both GUT and the shutdown smoke.
- Runtime gameplay tuning is held in typed `.tres` resources. The only resource-path manifests are the run's data-resource selections; combat values, room geometry, pool capacity, actor tuning, upgrades, and audio tuning are Resource-authored. The corrected burn/dash limits now follow this rule as well.
- Object pools preallocate projectiles, reject stale deferred returns through lease IDs, and release all active bullets when combat freezes. The performance overlay is timer-driven rather than frame-updated. No unbounded process-time allocation or lifecycle leak was found in the reviewed runtime code.
- `rg` found no prohibited account, network, cloud, ads, purchase, ranking, or telemetry integration outside vendored GUT. Runtime content has no reference to source concept files; `validate_assets.py` verifies the source/runtime boundary, registration, license references, AI prompt anchors, and runtime PNG constraints.
- Runtime assets are currently programmatic shapes and procedural PCM only. The source concepts remain under `source_art/concepts/`, the runtime media directory contains its boundary readme only, and all nine source concepts are registered with project-owned license records. `git lfs fsck` passed.
- The CI workflow pins Godot 4.6.3, runs Python/path/asset checks, import/editor/version/GUT/smokes, requires the runtime shutdown success marker, and fails on `ObjectDB instances leaked`. Android and macOS iOS export jobs install pinned export templates and require non-empty artifacts.

## Export and platform boundary

Executed Android guard exactly:

```powershell
.\tools\export_android_debug.ps1 -GodotPath 'C:\Users\user\OneDrive\Documents\Project\Game_Ghost\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
```

It correctly stopped before Godot with `Android export not attempted: ANDROID_SDK_ROOT or ANDROID_HOME is not set.` No APK was produced, so Android is **configured; not locally verified**.

The iOS guard script was inspected and requires Darwin plus `xcodebuild` before export. It could not be run on this Windows host because no `bash` executable is installed; macOS, Xcode, signing credentials, and an iPhone are also absent. iOS remains **configured; not locally verified**, and signed iOS/device verification remains **unverified by design**.

The Windows headless gameplay acceptance boundary is locally verified by the commands above. Physical-device safe-area, background/resume, performance, and signed-store checks remain release tasks as stated in `docs/release/mobile_release.md`.
