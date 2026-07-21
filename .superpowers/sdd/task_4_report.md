# Task 4 Report: Mobile Presentation and Delivery

## Status

Implemented and committed on `feat/game-ghost-vertical-slice` from approved base `1e4c5af`.

Commits:

- `4ecf350` — `feat: add mobile-safe presentation and procedural audio`
- `4f8db16` — `chore: enforce asset provenance and source boundaries`
- `1559323` — `ci: configure mobile export and release checks`

- `b7bbf84` — `fix: close task 4 review findings`
- `8a9f229` — `fix: close second task 4 review findings`
- `07e0180` — `docs: record second task 4 verification`
- `HEAD (this report)` — `fix: close third task 4 review findings`

## Delivered

- Added a shared palette and programmatic modular Ember `RibbonLayer`, `BodyLayer`, `HairLayer`, and `WeaponLayer`; no concept image is loaded by Godot.
- Improved projectile contrast and charge lanes/rings/endpoints for readable player/enemy effects and telegraphs.
- Added `SafeAreaLayout`, which maps `DisplayServer.get_display_safe_area()` into logical viewport coordinates. Combat HUD and run UI consume the result, and canvas stretch uses `expand`.
- Added safe-area controls and smoke coverage for 16:9, 19.5:9, 4:3, and a synthetic notched display.
- Added a 0.5-second timer-based performance overlay for FPS, static memory, active enemies, and active projectiles; it does not process or allocate metrics text every render frame.
- Expanded `AudioService` with cached, deterministic, self-authored `AudioStreamWAV` PCM cues routed through `SFX` and `UI` buses. Ember fire/dash/burst/hit, enemy telegraph, room clear, and reward selection use the service. No external audio files were added.
- Safely moved all nine root concept images with `git mv` to `source_art/concepts/{characters,items,maps}`. `git lfs ls-files` and `git lfs fsck` confirm they remain LFS objects.
- Added `docs/assets/asset-register.csv`, AI prompt records, project-owned license notice, third-party license template, and workflow documentation.
- Added `tools/validate_assets.py` with failures for required-field/missing-file errors, duplicate IDs/paths, unknown or missing license records, missing attribution, incomplete AI provenance, unregistered assets, source/runtime boundary violations, concept references from Godot resources, unreadable runtime PNGs, and runtime PNGs above 2048×2048.
- Expanded Android ARM64/iOS ARM64 presets, added guarded Windows Android and macOS iOS export scripts, and documented configured-versus-verified status.
- Added GitHub Actions jobs for pinned Godot headless validation, Python asset tests, resource import/editor/version checks, GUT, three scene smokes, Android debug APK export, and macOS iOS Xcode-project export smoke.

## TDD evidence

- Safe-area GUT: RED on missing `res://ui/safe_area_layout.gd`; GREEN at 3/3.
- Audio-service GUT: RED on missing `_ready`/routing API; GREEN at 2/2, later 3/3 after RED for deterministic `stop_all` cleanup.
- Asset-validator unit tests: RED on missing `tools/validate_assets.py`; GREEN at 5/5 after boundary, provenance, missing-file/attribution, and 2048px coverage.
- Presentation GUT: RED on missing Ember visual and performance overlay scripts; GREEN at 2/2.
- Expand-aspect project test: RED on missing `window/stretch/aspect`; GREEN at 4/4 project-configuration tests.
- Smoke regressions were reproduced before fixes: stale HUD node paths after safe-area nesting and an invalid physical-vs-logical viewport assumption. Both roots were corrected and their smokes rerun.

## Final verification on committed tree

- Python validator tests: 5/5 passed.
- Asset validation: `ASSET_VALIDATION_OK`.
- Godot import: exit 0.
- Godot editor parse/resource validation: exit 0.
- Godot version/orientation validation: `4.6.3`, exit 0.
- Full GUT: 52/52 tests, 239 assertions.
- Combat smoke: `COMBAT_SMOKE_OK`, exit 0.
- Run-loop smoke: `RUN_LOOP_SMOKE_OK`, exit 0.
- Mobile UI smoke: `MOBILE_UI_SMOKE_OK`, exit 0.
- Main runtime for 180 frames: exit 0.
- Git LFS fsck: OK.
- `git diff --check`: exit 0.
- Worktree: clean after the initial implementation commits.

## Platform verification boundary and concerns

- Android export was not attempted locally. Exact detection result: `ANDROID_EXPORT_NOT_ATTEMPTED: no installed Android SDK build-tools found in ANDROID_SDK_ROOT, ANDROID_HOME, or LocalAppData\Android\Sdk.` The preset, guarded script, and Ubuntu CI export job are configured, not locally verified.
- iOS export was not attempted locally. Exact detection result: `IOS_EXPORT_NOT_ATTEMPTED: host is Win32NT; macOS/Xcode required.` The preset, guarded script, and macOS CI project-export job are configured, not device/signing verified.
- CI jobs were configured but not executed from this local environment.
- Forced main-scene termination with `--quit-after 180` exits 0 but can report an `ObjectDB instances leaked at exit` warning when procedural audio is active at the forced cutoff. The deterministic scene smokes explicitly stop playback, wait for the audio server, and exit without the warning; no gameplay/resource failure was observed.
- The iOS Team ID `XXXXXXXXXX` is an intentional valid-length project-generation placeholder. A real Apple Developer Team ID and signing material are still required outside source control.

## Task 4 Review-Fix Verification

### Review fixes closed

- Runtime PNG validation now walks the full chunk stream, checks chunk ordering and CRCs, requires IHDR/IDAT/IEND, validates zlib completion, decoded scanline size, and filter-byte ranges. The focused Python suite covers CRC, ordering, incomplete stream, scanline, and filter corruption cases.
- Asset, license, and AI prompt references are strictly resolved after symlink expansion. Canonical targets are repository-contained, constrained to their respective allowed directories, and de-duplicated case-insensitively. Traversal, alias, and symlink-escape coverage is present; the Windows local symlink case skipped because this host cannot create symlinks, while Linux CI runs the same test.
- `AudioService` now uses a six-voice routine SFX pool, a dedicated enemy-telegraph player, and a separate UI player. `begin_shutdown()` stops all voices, clears their streams/caches, and rejects future cues. The shutdown smoke treats any `ObjectDB instances leaked` output as a failure.
- The mobile smoke applies a synthetic notched content rect to the actual combat HUD and run UI, then verifies joystick, dash, skill, pause, reward choices, and end-state controls remain contained and usable.

### Exact verification on the review-fix tree

- `py -3 -m unittest discover -s tools/tests -p "test_*.py" -v`: 10 tests passed; 1 symlink-escape test skipped because Windows symlink creation is unavailable locally.
- `py -3 tools/validate_assets.py`: `ASSET_VALIDATION_OK`.
- `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe --version`: `4.6.3.stable.official.7d41c59c4`.
- The same pinned executable completed `--headless --import --path game`, `--headless --editor --quit --path game`, and `--headless --path game --script res://tools/validate_godot_version.gd`; the version/orientation validator reported `4.6.3`. Godot emitted only the expected local Android build-tools availability warning.
- `--headless --path game --script res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`: 54/54 GUT tests passed with 264 assertions, including all 5 audio review tests.
- Pinned-Godot scene smokes all passed: `COMBAT_SMOKE_OK`, `RUN_LOOP_SMOKE_OK`, `MOBILE_UI_SMOKE_OK`, and `RUNTIME_SHUTDOWN_SMOKE_OK`. The command wrapper explicitly failed on `ObjectDB instances leaked`; no such warning was emitted by any smoke.
- `git diff --check`: passed. `git lfs fsck`: `Git LFS fsck OK`.
- `.github/workflows/godot_ci.yml` was manually syntax-inspected in full. Python PyYAML and Ruby YAML parsers are not installed on this host, so a local YAML parser check could not be run; the workflow remains additionally validated by its committed GitHub Actions configuration.

### Local platform limits after review fixes

- `tools/export_android_debug.ps1` was deliberately not run past environment detection: `ANDROID_SDK_ROOT` and `ANDROID_HOME` are unset, so Android export is configured in CI but not verified locally.
- `tools/export_ios_smoke.sh` correctly stopped with `iOS export not attempted: macOS is required.` iOS export is configured in CI but cannot be verified on this Windows host.

## Second-Review Fix Verification

### RED-to-GREEN evidence

- Added lifecycle and data-resource audio tests to `game/tests/test_audio_service.gd`. The initial focused run was RED: the root close request left active voices and `mock_audio_tuning.tres`/the `audio_tuning` property were absent. The final focused result was 7/7 audio tests and 49 assertions passing.
- Added `tools/tests/test_task4_path_naming.py`. It was RED first because `tools/validate_task4_paths.py` did not exist, then correctly reported all 15 hyphenated Task 4 deliverable paths. It is GREEN after the lowercase ASCII snake_case renames and reference updates.
- The first resource implementation exposed an `@export_enum` type error because Godot only permits `String`, not `StringName`, for that annotation. Changing the data-only waveform field to `String` restored Resource class registration; this was the sole implementation correction after the initial GREEN attempt.

### Second-review changes

- `AudioService` loads typed, data-only `AudioTuningDefinition` and `AudioCueDefinition` Resources from `res://data/mock_audio_tuning.tres`. The resource owns sample rate, voice-pool size, bus routing, telegraph gain, and every cue's frequency, duration, volume, waveform, and channel.
- `AudioService` connects the root window's `close_requested` signal to its production shutdown handler and invokes the same shutdown from `_exit_tree()`. The runtime smoke confirms that connection and invokes the production handler, never `begin_shutdown()` directly; it then asserts no active voices and that subsequent cue requests are rejected.
- The Task 4 workflow, asset documents, release document, asset register, license/prompt files, and all nine source concept filenames now use lowercase ASCII snake_case. `tools/validate_task4_paths.py` is exercised by Python tests and GitHub Actions before the asset validator.

### Exact second-review verification

- Pinned `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe` completed `--headless --import --path game`, `--headless --editor --quit --path game`, and `--headless --path game --script res://tools/validate_godot_version.gd`; version/orientation validation reported `4.6.3`.
- `py -3 -m unittest discover -s tools/tests -p "test_*.py" -v`: 11 tests passed; the one symlink-escape test skipped because this Windows host cannot create symlinks. `py -3 tools/validate_task4_paths.py`: `TASK4_PATH_VALIDATION_OK`. `py -3 tools/validate_assets.py`: `ASSET_VALIDATION_OK`.
- Full GUT: 56/56 tests passed with 275 assertions. Scene smokes passed: `COMBAT_SMOKE_OK`, `RUN_LOOP_SMOKE_OK`, `MOBILE_UI_SMOKE_OK`, and `RUNTIME_SHUTDOWN_SMOKE_OK`; the smoke wrapper rejects any `ObjectDB instances leaked` warning and none was emitted.
- `git diff --check` passed, `git lfs fsck` reported `Git LFS fsck OK`, and `.github/workflows/godot_ci.yml` received a full manual syntax inspection. Python PyYAML and Ruby YAML parsers remain unavailable locally.
- Android remains unverified locally because `ANDROID_SDK_ROOT`/`ANDROID_HOME` are unset and build-tools are unavailable. iOS remains unverified on this Windows host because macOS/Xcode are required.

## Third-Review Fix Verification

### RED-to-GREEN evidence

- New `tools/tests/test_audio_tuning_resource.py` was RED for all six required authored top-level tuning fields: `sample_rate`, `sfx_voice_count`, `sfx_bus`, `telegraph_bus`, `ui_bus`, and `telegraph_gain_db`. `game/tests/test_audio_service.gd` was also RED because the schema supplied production defaults and lacked the dedicated telegraph bus/gain properties.
- The GREEN resource explicitly serializes all six values in `mock_audio_tuning.tres`; `AudioTuningDefinition` now has neutral zero/empty schema defaults, and `AudioService` rejects an incomplete tuning resource before it creates routing/voices.
- `tools/tests/test_task4_path_naming.py` was RED because the tracked report filename was hyphenated. It is GREEN after the rename to `.superpowers/sdd/task_4_report.md`; `tools/validate_task4_paths.py` now requires that exact tracked Task 4 deliverable while leaving pre-existing plan and skill scratch files outside its scope.

### Exact third-review verification

- Focused checks: `py -3 -m unittest tools.tests.test_audio_tuning_resource tools.tests.test_task4_path_naming -v` passed 3/3; `py -3 tools/validate_task4_paths.py` reported `TASK4_PATH_VALIDATION_OK`; focused audio GUT passed 8/8 tests with 56 assertions.
- Pinned Godot 4.6.3 completed `--headless --import --path game`, `--headless --editor --quit --path game`, and the version/orientation script. Python discovery passed 13 tests with one Windows symlink-creation skip; `py -3 tools/validate_assets.py` reported `ASSET_VALIDATION_OK`.
- Full GUT passed 57/57 tests with 282 assertions. All scene smokes passed: `COMBAT_SMOKE_OK`, `RUN_LOOP_SMOKE_OK`, `MOBILE_UI_SMOKE_OK`, and `RUNTIME_SHUTDOWN_SMOKE_OK`; no `ObjectDB instances leaked` warning was emitted.
- `git diff --check` and `git lfs fsck` passed. `.github/workflows/godot_ci.yml` was manually syntax-inspected because PyYAML and Ruby YAML are unavailable locally. Android and iOS remain unverified locally for the existing SDK and host-platform limitations.
