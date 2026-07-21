# Final Whole-Branch Review Fix Report

Verification date: 2026-07-22

Worktree: `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\.worktrees\feat-game-ghost-vertical-slice`

Starting HEAD: `b8ff769` (`feat/game-ghost-vertical-slice`).

The user explicitly approved preserving upstream file names under `game/addons/gut/**`. The path validator therefore exempts that exact vendored boundary and required repository-control metadata only; no vendored GUT file was renamed or edited.

## Root causes and RED/GREEN evidence

### 1. Corrupt primary with a valid predecessor

- Root cause: `_recover_corrupt_save()` archived the corrupt primary and then called ordinary `save_data()`. That path deleted an existing `.previous`, rotated the corrupt primary into `.previous`, and promoted defaults, destroying the valid predecessor.
- RED command: pinned Godot GUT with `-gselect=test_local_save`.
- RED result: `10/13` passed and `39/45` asserts. A corrupt primary returned default progress instead of the valid predecessor; invalid-predecessor recovery replaced predecessor evidence; forced recovery promotion failure did not retain all evidence.
- GREEN: recovery now validates `.previous` first, archives the corrupt primary byte-for-byte to a unique backup, stages the recovered/default payload without normal rotation, leaves `.previous` untouched, restores the corrupt primary if promotion fails, and blocks later writes when safe recovery cannot complete.
- Self-review RED: the process storage-root test first failed `13/14` (`50/51` asserts) because a pre-start override was ignored. A second failure-path RED failed `14/15` (`51/52` asserts) because directory-creation failure did not fail closed.
- Final focused GREEN: `15/15` tests and `54` asserts. Coverage includes valid predecessor, invalid predecessor, exact raw archive bytes, archive failure, restoration failure, process-start storage injection, and unavailable-root fail-closed behavior.

### 2. Runtime finalization failure and retry

- Root cause: `RunGame._finish_run()` ignored the Boolean returned by `GameSession.finish_run()` and always displayed the successful ending text. `GameSession` retained a correct pending payload, but production UI exposed no retry path.
- RED command: pinned Godot GUT with `-gselect=test_run_game_scene`.
- RED result: `2/3` passed and `17/18` asserts; the pending-save ending content and retry button did not exist.
- GREEN: the end panel shows `RUN COMPLETE / SAVE PENDING` while persistence is pending, exposes a `RETRY SAVE` action wired to `GameSession.retry_pending_finalization()`, and displays the win/loss completion text only after persistence succeeds. Retrying uses the existing pending payload and cannot increment wins twice.
- Focused GREEN after all scene tests: `4/4` tests and `30` asserts, including failure, explicit retry success, idempotent progress, and authored player spawn consumption.

### 3. Release export contents

- Root cause: Android and iOS used `export_filter="all_resources"` with empty exclusions, and CI only asserted non-empty artifacts.
- RED command: `py -3 -m unittest tools.tests.test_export_contents -v`.
- RED result: all `5` tests failed because both exclusions, both CI checks, and the artifact validator were absent.
- GREEN: both presets exclude `tests/**,addons/gut/**` (repository paths `game/tests/**` and `game/addons/gut/**`). `validate_export_contents.py` inspects APK/ZIP entry paths plus decompressed member bytes and recursively inspects exported iOS directory layouts. Android and iOS CI jobs run it on the produced artifacts.
- Focused GREEN: `5/5` Python tests, including safe ZIP acceptance, embedded `res://tests/` rejection, iOS-layout `game/addons/gut/` rejection, preset coverage, and CI coverage.

### 4. Tracked path naming

- Root cause: the prior validator scanned only Task 4 directories, leaving six project-owned tracked names with hyphens.
- RED command: `py -3 -m unittest tools.tests.test_task4_path_naming -v` before the validator/test rename.
- RED result: `4/4` tests failed and listed exactly six project-owned violations: two SDD reports and four design/plan documents.
- GREEN: those six paths were renamed to lowercase ASCII `snake_case`; the validator and test were renamed to `validate_paths.py` and `test_path_naming.py`; validation now consumes `git ls-files -z` and covers every tracked path. The documented exception is limited to root repository-control metadata and `game/addons/gut/**` because GUT is unmodified upstream content.
- Focused GREEN: `4/4` Python tests and `PATH_VALIDATION_OK`.

### 5. Remaining script-owned gameplay tuning

- Root causes: Ember multiplied multishot offsets by `0.14`; enemies divided concealed-target distance by `0.55`; `RunGame` placed Ember at `Vector2(260.0, room.arena_size.y * 0.5)`.
- RED commands: focused GUT for `test_run_combat_integration` and `test_run_game_scene`.
- RED results: combat integration `4/6` with `14/16` asserts (missing weapon spread and enemy concealment fields); run-game scene `3/4` with `28/29` asserts (missing room player spawn field).
- GREEN: `WeaponDefinition.multishot_spread_radians`, `EnemyDefinition.concealment_detection_factor`, and `RoomDefinition.player_spawn_position` are typed fields. The rifle, all five enemy definitions, and every run room explicitly author the existing values. Runtime scripts consume only those fields.
- Mutation coverage changes spread to `0.6`, concealment factor from `0.25` to `0.5`, and spawn to `Vector2(777, 333)`, proving runtime consumption rather than constant matching.
- Focused GREEN: combat integration `6/6`, `20` asserts with no orphans/leaks; run-game scene `4/4`, `30` asserts.

### 6. Scene-smoke save isolation

- Root cause: saving smoke scenes configured state in their `_ready()` methods, after production autoloads could already read/write `user://game_ghost_save.json`.
- RED: `test_process_storage_root_override_applies_before_the_first_load` failed in focused GUT, and all three Python isolation checks failed because the process wrapper and CI integration were absent.
- GREEN: `LocalSave` consumes `GAME_GHOST_STORAGE_ROOT` during `_init()`. `run_scene_smoke.py` snapshots the platform production save, creates a unique temporary root before launching Godot, supplies the override in the child environment, verifies production existence and bytes are identical afterward, restores the snapshot if a violation occurs, and removes the disposable root on normal exit. An abruptly interrupted smoke can affect only its disposable root.
- Final self-review RED found that `game/readme.md` still advertised raw saving-smoke commands; the new documentation boundary test failed `1/4`. GREEN replaced every saving-smoke example with the isolation wrapper and passed `4/4`.
- Actual run-loop, mobile UI, and runtime-shutdown smokes each printed `SMOKE_SAVE_ISOLATION_OK` for `C:\Users\user\AppData\Roaming\Godot\app_userdata\Game Ghost\game_ghost_save.json`.

### 7. Real close-request signal

- Root cause: the shutdown smoke checked the connection but invoked `AudioService._on_root_close_requested()` directly.
- RED: the Python source-boundary test failed because `root_window.close_requested.emit()` was absent. The first actual signal-emission run exited before the success marker because `SceneTree.auto_accept_quit` was still enabled.
- GREEN: the smoke temporarily disables automatic quit, emits the production root `close_requested` signal, restores the setting, verifies audio is stopped and rejects later cues, drains the scene, and quits deterministically.
- Actual GREEN marker: `RUNTIME_SHUTDOWN_SMOKE_OK: production root close signal shut audio down and the audio server drained`; no `ObjectDB instances leaked` output.

## Fresh full acceptance evidence

Pinned binary: `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe`.

| Gate | Exact result |
| --- | --- |
| `py -3 -m unittest discover -s tools/tests -p "test_*.py" -v` | `23` passed; `1` expected skip because Windows could not create a symlink (`24` run total). |
| `py -3 tools/validate_paths.py` | `PATH_VALIDATION_OK`. |
| `py -3 tools/validate_assets.py` | `ASSET_VALIDATION_OK`. |
| Pinned Godot `--version` | `4.6.3.stable.official.7d41c59c4`. |
| Pinned Godot `--headless --import --path game` | Exit `0`; expected local Android build-tools warning only. |
| Pinned Godot `--headless --editor --quit --path game` | Exit `0`; expected local Android build-tools warning only. |
| Pinned version/project validator | `Godot version pin and landscape ProjectSettings verified: 4.6.3`. |
| Full GUT | `16` scripts, `68/68` tests, `354` asserts passed. |
| Combat smoke | `COMBAT_SMOKE_OK`. |
| Isolated run-loop smoke | `RUN_LOOP_SMOKE_OK` and production save unchanged. |
| Isolated mobile UI smoke | `MOBILE_UI_SMOKE_OK` and production save unchanged. |
| Isolated runtime shutdown smoke | Real root close signal marker, production save unchanged, and no ObjectDB leak text. |
| `git diff --check` | Exit `0`; no whitespace error (Git emitted only its line-ending notice for `export_presets.cfg`). |
| `git lfs fsck` | `Git LFS fsck OK`. |
| Android export guard | Correctly stopped before Godot: `ANDROID_SDK_ROOT or ANDROID_HOME is not set`. |
| iOS export guard | Static inspection confirms Darwin and `xcodebuild` preconditions; local execution is unavailable because `bash`, macOS, Xcode, signing, and an iPhone are absent. |
| Export configuration/CI inspection | Python tests confirm both preset exclusions, both artifact validators, all three isolated saving-smoke invocations, and the real close-signal source boundary. |

Android remains configured but not locally exported because the SDK/build-tools are absent. iOS remains configured but not locally exported because this host is Windows without bash/macOS/Xcode/signing/device access. Signed/device verification remains unverified by design.
