# Task 3 Report: Run Loop and Forest Rooms

## Status

Complete on top of approved Task 2 HEAD `2496038`.

The playable entry point is now a six-room forest run: three regular encounters, one elite, one harder regular encounter, and a telegraphed boss. Every non-final clear presents three deterministic seeded upgrade choices; the boss clear wins, and Ember reaching zero health loses. The six data-authored room duration targets total 665 seconds (11.1 minutes), inside the 8–12 minute vertical-slice target before playtest tuning.

## TDD chronology

1. Added failing GUT coverage for exact room sequence, clear → reward → next-room transition, seeded unique choices, stack limits, distinct upgrade builds, boss win, player-death loss, grass/mud/river/bridge/tree rules, schema migration, corrupt-save backup/reset, and active-run round trip.
2. Initial RED command could not start because `godot` was not installed or on `PATH`. A filesystem search found no pinned binary. Downloaded the official Godot 4.6.3 Standard Windows build to `%TEMP%\godot-4.6.3` (not committed).
3. First executable RED run exposed a test parse error plus corrupt JSON being reported as an unexpected engine error; forest tests passed and save tests were 2/3. Replaced error-logging `JSON.parse_string` with checked `JSON.parse`, fixed static typing, and attached test Nodes for leak-free cleanup.
4. The next focused run was 10/11: a deep-duplicated runtime Resource did not preserve non-exported transient stats. The test was corrected to capture scalar baselines, matching the intended runtime-only model.
5. Focused GREEN: 11/11 tests, 49 assertions.
6. Added a failing persistence-resume test (5/6; missing `restore_run`). Implemented reward/room/stack restoration and room-index-derived deterministic reward draws. GREEN: 6/6.
7. Added real combat integration tests. RED: 1/2 because the boss did not expose observable telegraph state. Added `is_telegraphing`; GREEN: 2/2. The projectile test proves the applied build reaches Ember-fired bullets (multishot, penetration, ricochet, burn).
8. Added pause/resume state coverage and river segment/bridge gap assertions. Final focused and full regression runs are green.

## Implementation

- `game/run/run_controller.gd`: typed run state machine, exact six-room progression, deterministic three-choice rewards, stacking, win/loss/pause, and active-run serialization/restoration.
- `game/run/runtime_combat_stats.gd`: runtime copy of weapon/dash stats and data-keyed upgrade application.
- `game/run/forest_room_rules.gd`: grass concealment, mud speed multipliers, river/bridge collision, tree actor/projectile blocking, and blocker segment checks.
- `game/run/run_game.gd`, `game/scenes/run_game.tscn`: playable orchestration, room/enemy spawning, forest drawing, reward UI, pause/resume, and win/loss panels.
- Combat extensions in Ember, enemy, projectile pool/bullets, and health component: actual multishot, penetration, ricochet, burn, dash cooldown, forest movement/projectile behavior, concealment-aware enemies, elite tuning, and boss aimed shots plus charge telegraph.
- `game/services/local_save.gd`, `game/services/game_session.gd`: schema version 2, v1 migration, atomic temporary-file replacement, corrupt backup before reset, active-run persistence, and foreground/background handling.
- Data contracts and fixtures: 6 `mock_forest_*room.tres` definitions, elite/boss definitions, 10 `mock_upgrade_*.tres` resources, expanded registry, and forest geometry/timing fields. All authored content remains data-only and lowercase.
- Tests: `test_run_controller.gd`, `test_run_combat_integration.gd`, `test_forest_room_rules.gd`, `test_local_save.gd`, and `smoke/run_loop_smoke.*`; Task 2 combat smoke remains unchanged and green.

## Verification

All commands ran from `game/` using `%TEMP%\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe`.

- `--headless --import --path .` — exit 0; resources/classes imported. Only the known local Android SDK `build-tools` warning appeared.
- `--headless --editor --quit --path .` — exit 0; no parse errors.
- `--headless --path . --script res://tools/validate_godot_version.gd` — exit 0; pinned 4.6.3 and landscape verified.
- focused Task 3 GUT — GREEN after the RED chronology above.
- `--headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` — 28/28 tests, 124 assertions, no failures or orphans.
- `--headless --path . res://tests/smoke/run_loop_smoke.tscn` — `RUN_LOOP_SMOKE_OK`, exit 0; includes save recovery.
- `--headless --path . res://tests/smoke/combat_smoke.tscn` — `COMBAT_SMOKE_OK`, exit 0.
- `--headless --path . --quit-after 180` — exit 0; no parse/runtime/ObjectDB errors.
- `git diff --check` — clean.

## Self-review

- Root cause boundaries are preserved: definitions remain immutable data, while per-run mutation lives in `RuntimeCombatStats`; no shared `.tres` is mutated.
- Seeded choices are derived from seed + room index, so restoring a run cannot drift because of lost RNG call history.
- Corrupt raw bytes are written to `.corrupt.bak` before defaults replace the primary file.
- Forest rules are consumed by both actor movement and pooled projectile movement; they are not visual-only flags.
- Boss behavior reuses the approved combat actor/projectile boundaries and exposes an observed telegraph before the charge.
- Existing combat defaults and call sites remain backward compatible through optional configuration parameters; Task 2 regression smoke passes.
- No new autoload, external runtime asset, audio polish, CI, export work, backend, or Task 4 scope was added.

## Concerns

- The 665-second duration is data-authored and structurally within target, but final enemy health/count tuning still benefits from a human mobile playtest.
- Android SDK `build-tools` is unavailable on this machine; this is an existing environment warning and Android export verification belongs to Task 4.

## Review remediation

Commit follow-up addresses every Task 3 review finding with new RED/GREEN evidence.

### Additional RED/GREEN chronology

1. Save durability/corruption tests first failed because `LocalSaveBackend` did not exist. After adding the injectable filesystem boundary, the focused suite exposed the old fixed backup-path expectation; the updated durability suite reached GREEN at 8/8.
2. Failure injection proved a forced temporary-file promotion failure restores the prior valid primary. A separate crash-window test proves `load_data` promotes `.previous` when the primary is absent.
3. Repeated corruption, backup-write failure, and parseable bad-schema tests were RED against the original implementation. GREEN behavior now creates unique evidence files, verifies exact bytes before reset, blocks subsequent writes when evidence preservation fails, and validates current and legacy nested schemas.
4. A non-UTF-8 evidence test was RED because String conversion replaced bytes. Recovery now carries `PackedByteArray` end-to-end and validates UTF-8 before JSON parsing; focused save suite is GREEN at 10/10 with no Unicode warning.
5. Run scene behavior was RED: reward state left Ember processing, health vulnerable, and the projectile pool active. The scene now freezes Ember/enemies, grants reward-state invulnerability, releases/disables the pool, and keeps the reward panel `PROCESS_MODE_ALWAYS`; actual clear → reward → next room is GREEN.
6. Checkpoint test was RED because `set_room_entry_health` did not exist. The boundary checkpoint now serializes exact entry health. Cold resume reconstructs the same room and restores precisely that value. The policy is documented in `game/readme.md`.
7. Restored duplicate/maxed/stale reward IDs and failed application cases were RED. Restore now accepts only exactly three unique, known, non-maxed IDs or deterministically regenerates; failed application leaves state and choices unchanged.
8. Ricochet and real-enemy mud tests were RED. Rebound now places bullets on the near side using per-room `.tres` separation, and all enemy velocity—including charge movement—uses the mud multiplier. Both tree/river ricochet and normal-vs-mud displacement are GREEN.
9. Run-loop smoke now clears every room by damaging the actual spawned `CombatEnemy` nodes and wins only after the actual boss health reaches zero; direct `complete_room` calls were removed from the smoke path.

### Final review verification

- Full GUT: 42/42 tests, 171 assertions, no failures or orphans.
- Run-loop smoke: exit 0, actual spawned-enemy clears and actual boss death observed.
- Combat regression smoke: exit 0.
- Import, editor parse, pinned-version/landscape validation: exit 0 (only existing Android `build-tools` environment warning).
- 180-frame main-scene runtime: exit 0 with no parse/runtime/ObjectDB errors.
- `git diff --check`: clean.
