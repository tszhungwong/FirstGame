# Task 2 Report: Combat Sandbox

## Delivered

- Replaced the inert foundation main scene with a playable, programmatic-shape combat sandbox at `res://scenes/combat_sandbox.tscn`.
- Added Ember Vanguard movement, nearest-target automatic rifle fire, cooldown-gated dash with temporary invulnerability, and an eight-direction active burst skill.
- Added data-driven melee chaser, ranged shooter, and telegraphed charger enemies. The charger displays its locked charge line and warning ring before moving.
- Added pooled player and enemy projectiles. The pool preallocates 48 bullets, reuses released instances, and can grow only when the configured capacity is exhausted.
- Added a smoothing, arena-limited camera; health/hostile/cooldown HUD; keyboard controls; landscape virtual joystick; and touch action buttons.
- Kept the graybox visual layer self-contained in `_draw()` methods and standard Godot controls. No concept image is loaded as a runtime sprite.
- Extended the existing typed Resource contracts only with combat-owned tuning fields and added `mock_forest_shooter.tres` and `mock_forest_charger.tres`. The room Resource owns its six enemy definitions and spawn points, so the sandbox actor mix and layout are data-driven.
- Added an executable headless smoke scene that verifies Ember, all three enemy archetypes, the projectile pool, camera, HUD joystick/buttons, dash, active skill, and a 120-physics-frame combat interval.

## TDD chronology

All commands below were run from `game/` with `Godot_v4.6.3-stable_win64_console.exe`.

### Baseline

```text
--headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
5/5 passed; 14 asserts.
```

### Health: clamp, death, and post-death idempotence

1. Added `test_damage_clamps_at_zero_and_emits_death_once` before the component.
2. The first test invocation exposed a test-only static-inference error for the dynamically loaded instance; no production code was added. The test variable was corrected to `Node`.
3. RED: the corrected test failed `0/1` because `res://combat/components/health_component.gd` did not exist.
4. GREEN: implemented the minimal typed component with reset, clamped damage, health signal, and single death transition.
5. Result: `1/1 passed; 6 asserts`.

### Nearest valid target within range

1. Added `test_selects_the_nearest_target_within_range` before the component.
2. The first invocation exposed test-only inferred types for GUT-owned nodes; the fixtures were explicitly typed. A second fixture correction supplied the required `Array[Node2D]` for the one-item range case.
3. RED: the corrected test failed `0/1` because `res://combat/components/targeting_component.gd` did not exist.
4. GREEN: implemented a squared-distance scan that ignores invalid instances and returns `null` when no candidate is within range.
5. Result: `1/1 passed; 3 asserts`.

### Damage delegation

1. Added `test_applies_configured_damage_to_health` before the component.
2. RED: failed `0/1` because `res://combat/components/damage_component.gd` did not exist.
3. GREEN: implemented the minimal damage component that delegates its configured amount to the supplied health component and returns the applied amount. An initial custom-type annotation could not resolve until the editor class cache refreshed, so the public boundary was kept statically typed as `Node`; the real health implementation remains exercised, not mocked.
4. Result: `1/1 passed; 3 asserts`.

### Dash cooldown and invulnerability

1. Added `test_dash_grants_temporary_invulnerability_and_respects_cooldown` before the component.
2. RED: failed `0/1` because `res://combat/components/dash_component.gd` did not exist.
3. GREEN: implemented deterministic `try_start()` and `advance(delta)` state with cooldown and duration timers, driving the health component's invulnerability state.
4. Initial result: `1/1 passed; 7 asserts`.
5. Self-review found that the test proved the state flag but did not directly prove rejection of damage. The unproven guard was removed, and assertions for zero applied damage and unchanged health were added.
6. RED: `0/1`; expected `0` applied damage but got `4`, and expected health `20` but got `16` (`7/9` assertions passed).
7. GREEN: restored only the `invulnerable` guard in health damage processing.
8. Final result: `1/1 passed; 9 asserts`.

### Object-pool lifecycle

1. Added `test_reuses_released_instances_without_growing_when_exhausted` before the pool. The test builds its `PackedScene` in memory, so no executable fixture or non-data mock file was introduced.
2. RED: failed `0/1` because `res://combat/projectiles/object_pool.gd` did not exist.
3. GREEN: implemented preallocation, acquisition, optional growth, release, bulk release, processing/visibility lifecycle, and identity-preserving reuse.
4. Result: `1/1 passed; 8 asserts`.

### Combat scene acceptance and runtime regression

1. Added `tests/smoke/combat_smoke.tscn` and its runner before the sandbox.
2. RED: `Cannot open file 'res://scenes/combat_sandbox.tscn'` followed by `COMBAT_SMOKE_FAILED: sandbox scene did not load`.
3. GREEN: implemented the sandbox integration. The smoke scene reported `COMBAT_SMOKE_OK: ember, enemies, pool, dash, and active skill are live`.
4. A longer 180-frame headless runtime then consistently reported that disabling a `CollisionObject2D` during `body_entered` was invalid. The stack traced from `PooledBullet._on_body_entered()` through its synchronous return signal to `ObjectPool.release()`.
5. The smallest root-cause fix deferred only emission of the pool-return signal; bullet logical deactivation remains immediate. Re-running the identical 180-frame command produced only the engine banner, with no error or warning.
6. The smoke interval was extended to 120 physics frames and strengthened to check all three archetypes, camera, virtual joystick, and both action buttons.

## Files

### Gameplay

- `game/combat/components/{health_component,targeting_component,damage_component,dash_component}.gd`
- `game/combat/projectiles/{object_pool,pooled_bullet}.gd`
- `game/combat/projectiles/pooled_bullet.tscn`
- `game/combat/actors/{ember,enemy}.gd`
- `game/combat/controls/virtual_joystick.gd`
- `game/combat/ui/combat_hud.gd`
- `game/combat/combat_sandbox.gd`
- `game/scenes/combat_sandbox.tscn`

### Data and configuration

- Extended `character_definition.gd`, `weapon_definition.gd`, `enemy_definition.gd`, and `room_definition.gd` with combat tuning fields owned by those models.
- Updated the existing Ember, rifle, chaser, and combat-room `.tres` values without replacing their seed values.
- Added data-only `mock_forest_shooter.tres` and `mock_forest_charger.tres`.
- Updated `game/project.godot` to launch the combat sandbox.

### Tests

- `game/tests/test_health_component.gd`
- `game/tests/test_targeting_component.gd`
- `game/tests/test_damage_component.gd`
- `game/tests/test_dash_component.gd`
- `game/tests/test_object_pool.gd`
- `game/tests/smoke/{combat_smoke.gd,combat_smoke.tscn}`
- Godot-generated `.uid` companions for the new scripts are tracked consistently with the foundation.

## Verification

Fresh final commands and exact results:

```text
Godot --headless --import --path game
Exit 0. No parse/runtime errors and no ObjectDB leak report.

Godot --headless --editor --quit --path game
Exit 0. No parse/runtime errors and no ObjectDB leak report.

Godot --headless --path game --script res://tools/validate_godot_version.gd
Godot version pin and landscape ProjectSettings verified: 4.6.3
Exit 0.

Godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
10/10 passed; 43 asserts; exit 0.

Godot --headless --path game res://tests/smoke/combat_smoke.tscn
COMBAT_SMOKE_OK: ember, enemies, pool, dash, and active skill are live
Exit 0. No parse/runtime errors and no ObjectDB leak report.

Godot --headless --path game --quit-after 180
Exit 0. No parse/runtime errors and no ObjectDB leak report.

git diff --cached --check
Exit 0.
```

Godot prints `Unable to open Android 'build-tools' directory` during import/editor startup because the machine's user-level Android SDK remains unconfigured. This is the same environment-only warning documented by Task 1; the commands exit zero, and Task 2 does not change export setup.

## Scope and self-review

- Confirmed the implementation contains no run progression, reward choice, upgrade application, boss, river, grass, mud, tree, or other Task 3 mechanics.
- Confirmed all gameplay values introduced for Ember, weapons, enemies, and the arena are stored in the appropriate typed Resource rather than embedded in actor behavior. Programmatic drawing constants are presentation-only.
- Confirmed the object pool owns bullet lifetime, disables inactive instances, and uses deferred return only where physics callback safety requires it.
- Confirmed player and enemy projectiles select different collision masks and both apply damage through the tested damage/health path.
- Confirmed keyboard and touch controls call the same Ember methods and that cooldown state is reflected in the action buttons.
- Confirmed project-owned paths are lowercase snake_case and the only new mock files are data-only `.tres` Resources.

## Concerns

- Android packaging remains blocked by the local machine's missing Android SDK build-tools. It does not affect desktop/headless combat execution.
- Touch controls are exercised structurally and share the same callable paths as keyboard controls, but physical-device gesture feel still needs device playtesting when Android tooling is available.

## Reviewer-finding remediation (2026-07-21)

### Behavioral smoke coverage

The original smoke only proved node presence and survival. It now performs deterministic observable checks and fails with a named `COMBAT_SMOKE_FAILED` condition when any system is inert:

- Finds all three typed enemy archetypes, then verifies a melee enemy changes position under its own AI.
- Repositions that melee enemy inside its Resource-defined attack geometry and verifies Ember loses health and the signal-driven health HUD text changes.
- Fires a real pooled `PooledBullet` through physics collision and verifies enemy health decreases, the bullet returns, and the next acquisition has the same instance ID.
- Initializes that reused bullet with a short lifetime away from colliders and verifies expiry also returns it.
- Supplies a real `InputEventScreenTouch` to `VirtualJoystick._gui_input`, verifies Ember moves, and verifies the enabled smoothing camera follows.
- Activates the HUD dash button through its typed `pressed` signal, then verifies cooldown starts, health invulnerability starts and ends, cooldown remains active, and the timer-driven button text/disabled state changes.
- Activates the HUD skill button through its typed `pressed` signal, then verifies skill cooldown, nonzero projectile activity, HUD cooldown state, and full pool return.
- Checks runtime pool capacity/growth policy, player/enemy collider geometry, bullet radius, and camera smoothing values against their typed Resources.

Headless viewport dispatch did not route a synthetic touch to `Button`; this produced the expected RED `injected dash button did not start cooldown`. The action buttons are therefore exercised at the typed `pressed` signal boundary, while the custom virtual joystick is exercised with the real touch event object that its control code consumes.

### Additional RED/GREEN chronology

All focused commands used:

```text
Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/<focused_test>.gd -gexit
Godot --headless --path . res://tests/smoke/combat_smoke.tscn
```

1. **Zero-duration dash boundary**
   - RED: `test_zero_duration_dash_never_leaves_health_invulnerable` failed because invulnerability stayed true and damage applied `0` instead of `4`; focused result `1/2 passed`, `11/13` assertions.
   - GREEN: clamped duration/cooldown to zero and only enabled invulnerability for a positive duration; focused result `2/2 passed`, `13` assertions.
2. **Real pooled-bullet preallocation**
   - RED: a real `pooled_bullet.tscn` instance started with `collision_mask=1` and direction `(1,0)` instead of a fully despawned state; focused result `1/2 passed`, `12/14` assertions.
   - GREEN: every newly preallocated bullet runs `on_despawn()` before becoming available; focused result `2/2 passed`, `14` assertions at that point.
3. **Data-driven collision/performance tuning**
   - RED: smoke printed `collision or pool tuning is missing from typed resources`.
   - Intermediate RED: after adding non-default Resource values, runtime equivalence still failed, proving script constants were still active.
   - GREEN: `.tres` values now drive pool capacity/growth, projectile radius, Ember collider/inset/projectile offset/camera smoothing, and enemy collider/inset/attack padding/ranged spacing/projectile offset/charge hit range.
   - A follow-up ownership RED moved projectile radius out of `RoomDefinition`; it now belongs to `WeaponDefinition` and `EnemyDefinition`, while pool capacity/growth remain room-level performance settings.
4. **Concrete typed boundaries**
   - RED: the source-contract test reported 15 missing concrete declarations across damage, dash, pool, bullet, Ember, enemy, sandbox, and HUD.
   - GREEN: `DamageComponent`, `HealthComponent`, `DashComponent`, `ObjectPool`, `PooledBullet`, `Ember`, `CombatEnemy`, `CombatSandbox`, and `CombatHud` now use concrete properties, arguments, return values, and typed signal connections. Dynamic `Node.call`, string signal connections, and capability checks were removed from gameplay boundaries; focused result `2/2 passed`, `17` assertions.
5. **Hot-path work**
   - RED: the hot-path test identified four failures: HUD `_process`, HUD group query, Ember per-physics redraw, and enemy per-physics redraw.
   - GREEN: sandbox registration maintains Ember's reusable target buffer; HUD health/enemy values are signal-driven and cooldowns use a 10 Hz Timer; actor redraws occur only on facing/dash/charger/death visual changes.
   - RED/GREEN follow-up: bullet geometry lacked an unchanged-value guard; the added guard prevents redraw work when pooled projectiles reuse the same radius. Focused result `2/2 passed`, `9` assertions.
6. **HUD observability**
   - RED: strengthened smoke failed because stable `HealthLabel` and `EnemyLabel` nodes did not exist.
   - GREEN: named controls plus health/enemy/cooldown assertions prove the signal/timer refactor changes visible HUD state.

### Files refined

- Typed components and boundaries: `game/combat/components/*.gd`, `actors/{ember,enemy}.gd`, `projectiles/{object_pool,pooled_bullet}.gd`, `combat_sandbox.gd`, and `ui/combat_hud.gd`.
- Performance/input behavior: `actors/{ember,enemy}.gd`, `controls/virtual_joystick.gd`, `projectiles/pooled_bullet.gd`, and `ui/combat_hud.gd`.
- Typed tuning contracts/data: `character_definition.gd`, `weapon_definition.gd`, `enemy_definition.gd`, `room_definition.gd`, and their existing `mock_*.tres` values.
- Focused coverage: `test_damage_component.gd`, `test_dash_component.gd`, `test_health_component.gd`, `test_object_pool.gd`, `test_targeting_component.gd`, and `tests/smoke/combat_smoke.gd`.

### Fresh final verification

```text
Godot --headless --import --path game
EXIT=0; ERROR_OR_LEAK_COUNT=0

Godot --headless --editor --quit --path game
EXIT=0; ERROR_OR_LEAK_COUNT=0

Godot --headless --path game --script res://tools/validate_godot_version.gd
Godot version pin and landscape ProjectSettings verified: 4.6.3
EXIT=0; ERROR_OR_LEAK_COUNT=0

Godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
14/14 passed; 70 assertions; EXIT=0; ERROR_OR_LEAK_COUNT=0

Godot --headless --path game res://tests/smoke/combat_smoke.tscn
COMBAT_SMOKE_OK: controls, cooldowns, damage, enemy AI, camera, and projectile reuse are observable
EXIT=0; ERROR_OR_LEAK_COUNT=0

Godot --headless --path game --quit-after 180
EXIT=0; ERROR_OR_LEAK_COUNT=0
```

Import/editor retain only the previously documented environment message `Unable to open Android 'build-tools' directory`; it is not a parse/runtime/ObjectDB failure.

### Reviewer-fix self-review

- Confirmed the smoke cannot pass when dash, active skill, bullet collision, bullet expiry, pool reuse, enemy movement, enemy attack, camera follow, virtual joystick handling, action button wiring, or HUD updates are inert.
- Confirmed all preallocated bullets have zero collision mask, zero direction/lifetime, hidden state, and disabled processing before entering the available list.
- Confirmed zero and negative dash durations cannot leave health invulnerable.
- Confirmed gameplay source has no `Node.call`, string-based gameplay signal connection, `has_method`, or `has_signal` boundary.
- Confirmed auto-fire reuses a registered target buffer, HUD has no frame `_process`, group queries are absent from gameplay hot paths, and redraws are state-driven.
- Confirmed newly added attributes remain owned by their correct models: character geometry/camera values on `CharacterDefinition`, projectile geometry on weapon/enemy definitions, enemy movement/attack geometry on `EnemyDefinition`, and pool capacity/growth on `RoomDefinition`.
