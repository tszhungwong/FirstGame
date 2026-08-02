extends SceneTree

const PLAYER_SCENE_PATH := "res://player/player.tscn"
const FORGOTTEN_WORKER_SCENE_PATH := "res://enemies/forgotten_worker/forgotten_worker.tscn"
const INSPECTION_DRONE_SCENE_PATH := "res://enemies/inspection_drone/inspection_drone.tscn"
const GAME_SCENE_PATH := "res://scenes/game/game.tscn"
const HOME_SCENE_PATH := "res://scenes/home/home.tscn"
const SETTINGS_MENU_SCENE_PATH := "res://ui/settings/settings_menu.tscn"
const MESSAGE_TRIGGER_SCENE_PATH := "res://dialogue/message_trigger.tscn"
const APP_SETTINGS_SCRIPT_PATH := "res://core/app_settings/app_settings.gd"
const PAUSE_CONTROLLER_SCRIPT_PATH := "res://core/pause/pause_controller.gd"
const TEST_SETTINGS_PATH := "user://game_ghost_test_settings.cfg"
const DIALOGUE_REQUEST_SCRIPT_PATH := "res://dialogue/dialogue_request.gd"
const DIALOGUE_CONTROLLER_SCRIPT_PATH := "res://dialogue/dialogue_controller.gd"
const VERTICAL_SLICE_FLOW_SCRIPT_PATH := "res://game/vertical_slice_flow/vertical_slice_flow.gd"
const RUN_STATE_SCRIPT_PATH := "res://game/run_state/run_state.gd"
const INTERACTION_CONTROLLER_SCRIPT_PATH := "res://interaction/interaction_controller.gd"
const DAMAGE_REQUEST_SCRIPT_PATH := "res://combat/damage_request.gd"
const VITALS_SCRIPT_PATH := "res://combat/vitals.gd"
const KEYBOARD_INPUT_ADAPTER_SCRIPT_PATH := "res://player/input/keyboard_input_adapter.gd"
const TIME_EFFECTS_SCRIPT_PATH := "res://effects/time_effects_controller.gd"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_app_settings_switches_and_persists_supported_locale()
	_test_localization_catalog_resolves_all_supported_locales()
	_test_dialogue_controller_queues_priority_and_once_requests()
	_test_vertical_slice_flow_owns_progression_transitions()
	_test_run_state_restores_cross_level_progress()
	_test_interaction_controller_selects_registered_nearest_target()
	_test_vitals_owns_damage_invulnerability_and_restoration()
	_test_keyboard_input_adapter_builds_player_commands()
	_test_time_effects_controller_owns_global_time_scale()
	await _test_pause_controller_stops_pausable_gameplay()
	await _test_pause_settings_menu_restarts_from_checkpoint()
	await _test_player_animation_follows_horizontal_input()
	await _test_inspection_drone_animation_follows_motion_and_fire()
	await _test_player_moves_right_from_keyboard_input()
	await _test_player_jumps_from_keyboard_input()
	await _test_holding_jump_reaches_platform_height()
	await _test_player_dashes_in_the_facing_direction()
	await _test_player_drops_through_one_way_platform()
	await _test_basic_attack_damages_enemy_and_builds_memory()
	await _test_skill_spends_memory_and_damages_enemy()
	await _test_player_damage_has_brief_invulnerability()
	await _test_enemy_melee_attack_is_blocked_by_a_wall()
	await _test_enemy_attack_path_is_blocked_by_a_platform()
	await _test_death_respawns_at_checkpoint_with_persistent_progress()
	await _test_boss_defeat_unlocks_wall_module_and_return_route()
	await _test_wall_module_enables_wall_jump()
	await _test_boss_dialog_clears_before_the_next_battle_line()
	await _test_boss_battle_lines_do_not_repeat()
	await _test_checkpoint_dialog_only_appears_once()
	await _test_interact_dismisses_visible_dialog()
	await _test_checkpoint_dialog_lasts_two_seconds()
	await _test_nearest_interactable_shows_prompt()
	await _test_named_characters_display_identity_labels_that_follow_them()
	await _test_area_message_trigger_only_fires_once()
	await _test_crossing_return_gate_does_not_cause_unprompted_damage()
	await _test_distant_boss_does_not_attack_player_at_return_gate()

	if _failures == 0:
		print("PASS: all gameplay tests")
		quit(0)
	else:
		push_error("%d gameplay test(s) failed" % _failures)
		quit(1)


func _test_app_settings_switches_and_persists_supported_locale() -> void:
	var settings_script := load(APP_SETTINGS_SCRIPT_PATH) as GDScript
	if settings_script == null:
		_fail("AppSettings module is available")
		return
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	var settings: Object = settings_script.new()
	settings.configure_storage(TEST_SETTINGS_PATH)
	settings.set_locale(&"zh_Hans")
	var restored: Object = settings_script.new()
	restored.configure_storage(TEST_SETTINGS_PATH)
	restored.load_settings()
	_expect(
		restored.get_locale() == &"zh_Hans",
		"AppSettings switches and persists a supported locale"
	)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	settings.free()
	restored.free()


func _test_localization_catalog_resolves_all_supported_locales() -> void:
	var expected_prompts := {
		&"en": "Press E to interact",
		&"zh_Hans": "按 E 互动",
		&"zh_Hant": "按 E 互動",
	}
	for locale: StringName in expected_prompts:
		TranslationServer.set_locale(String(locale))
		_expect(
			tr(&"ui.interact") == expected_prompts[locale],
			"localization catalog resolves %s UI text" % locale
		)


func _test_dialogue_controller_queues_priority_and_once_requests() -> void:
	var request_script := load(DIALOGUE_REQUEST_SCRIPT_PATH) as GDScript
	var controller_script := load(DIALOGUE_CONTROLLER_SCRIPT_PATH) as GDScript
	if request_script == null or controller_script == null:
		_fail("DialogueController module is available")
		return
	var controller := controller_script.new() as Node
	var ambient: Resource = request_script.new()
	ambient.text_key = &"dialog.foreman.01"
	ambient.priority = 1
	var story: Resource = request_script.new()
	story.text_key = &"dialog.boss_defeated"
	story.priority = 10
	story.once_key = &"boss_defeated"
	story.speaker_id = &"echo_foreman"
	story.portrait_expression = &"angry"
	var duplicate_story: Resource = story.duplicate(true)
	controller.present(ambient)
	var first_story_was_presented: bool = controller.present(story)
	var story_preempted_ambient: bool = controller.get_current_text_key() == story.text_key
	var story_metadata_preserved: bool = (
		controller.get_current_request().speaker_id == &"echo_foreman"
		and controller.get_current_request().portrait_expression == &"angry"
	)
	controller.advance_or_dismiss()
	var ambient_resumed: bool = controller.get_current_text_key() == ambient.text_key
	var duplicate_was_rejected: bool = not controller.present(duplicate_story)
	_expect(
		first_story_was_presented
		and story_preempted_ambient
		and story_metadata_preserved
		and ambient_resumed
		and duplicate_was_rejected,
		"DialogueController owns priority queues and once-only presentation"
	)
	controller.free()


func _test_vertical_slice_flow_owns_progression_transitions() -> void:
	var flow_script := load(VERTICAL_SLICE_FLOW_SCRIPT_PATH) as GDScript
	if flow_script == null:
		_fail("VerticalSliceFlow module is available")
		return
	var flow: RefCounted = flow_script.new()
	var skill_transition: RefCounted = flow.handle_event(&"skill_terminal")
	var boss_transition: RefCounted = flow.handle_event(&"boss_defeated")
	var route_transition: RefCounted = flow.handle_event(&"return_control")
	_expect(
		skill_transition.objective_key == &"objective.use_direction_skill"
		and skill_transition.granted_ability == &"directional_skill"
		and boss_transition.granted_ability == &"wall_module"
		and boss_transition.objective_key == &"objective.use_wall_module"
		and route_transition.opens_return_route
		and route_transition.objective_key == &"objective.complete",
		"VerticalSliceFlow owns objective and ability progression transitions"
	)


func _test_run_state_restores_cross_level_progress() -> void:
	var run_state_script := load(RUN_STATE_SCRIPT_PATH) as GDScript
	var flow_script := load(VERTICAL_SLICE_FLOW_SCRIPT_PATH) as GDScript
	if run_state_script == null or flow_script == null:
		_fail("RunState and VerticalSliceFlow modules are available")
		return
	var run_state: Resource = run_state_script.new()
	run_state.initialize(Vector2(120.0, 620.0))
	run_state.grant_ability(&"wall_module")
	run_state.mark_completed(&"boss_defeated")
	run_state.set_objective_key(&"objective.use_wall_module")
	var flow: RefCounted = flow_script.new()
	flow.restore_from_run_state(run_state)
	var restored_transition: RefCounted = flow.handle_event(&"return_control")
	var snapshot: Dictionary = run_state.snapshot()
	_expect(
		restored_transition.opens_return_route
		and &"boss_defeated" in snapshot["completed"]
		and snapshot["objective_key"] == &"objective.use_wall_module",
		"RunState restores cross-level progression data"
	)


func _test_interaction_controller_selects_registered_nearest_target() -> void:
	var controller_script := load(INTERACTION_CONTROLLER_SCRIPT_PATH) as GDScript
	if controller_script == null:
		_fail("InteractionController module is available")
		return
	var controller := controller_script.new() as Node
	var near_target := Node2D.new()
	var far_target := Node2D.new()
	near_target.position = Vector2(40.0, 0.0)
	far_target.position = Vector2(90.0, 0.0)
	root.add_child(controller)
	root.add_child(near_target)
	root.add_child(far_target)
	controller.register(near_target)
	controller.register(far_target)
	_expect(
		controller.find_nearest(Vector2.ZERO, 112.0) == near_target,
		"InteractionController selects the nearest registered target"
	)
	controller.queue_free()
	near_target.queue_free()
	far_target.queue_free()


func _test_vitals_owns_damage_invulnerability_and_restoration() -> void:
	var damage_script := load(DAMAGE_REQUEST_SCRIPT_PATH) as GDScript
	var vitals_script := load(VITALS_SCRIPT_PATH) as GDScript
	if damage_script == null or vitals_script == null:
		_fail("DamageRequest and Vitals modules are available")
		return
	var vitals: RefCounted = vitals_script.new(5, 0.5)
	var damage: RefCounted = damage_script.new(2, Vector2.RIGHT * 100.0)
	var first_hit: bool = vitals.apply_damage(damage)
	var blocked_hit: bool = not vitals.apply_damage(damage)
	vitals.tick(0.5)
	var second_hit: bool = vitals.apply_damage(damage)
	vitals.restore_full()
	_expect(
		first_hit
		and blocked_hit
		and second_hit
		and vitals.get_health() == 5,
		"Vitals owns damage gates and restoration behind one interface"
	)


func _test_keyboard_input_adapter_builds_player_commands() -> void:
	var adapter_script := load(KEYBOARD_INPUT_ADAPTER_SCRIPT_PATH) as GDScript
	if adapter_script == null:
		_fail("KeyboardInputAdapter module is available")
		return
	var adapter: RefCounted = adapter_script.new()
	Input.action_press("move_right")
	Input.action_press("jump")
	var command: RefCounted = adapter.sample()
	Input.action_release("move_right")
	Input.action_release("jump")
	_expect(
		is_equal_approx(command.move_axis, 1.0)
		and command.jump_held,
		"KeyboardInputAdapter builds a PlayerCommand snapshot"
	)


func _test_time_effects_controller_owns_global_time_scale() -> void:
	var effects_script := load(TIME_EFFECTS_SCRIPT_PATH) as GDScript
	if effects_script == null:
		_fail("TimeEffectsController module is available")
		return
	var effects := effects_script.new() as Node
	effects.request_hit_stop(0.05, 0.1)
	var activated: bool = effects.is_hit_stop_active()
	effects.cancel_hit_stop()
	_expect(
		activated and not effects.is_hit_stop_active() and is_equal_approx(Engine.time_scale, 1.0),
		"TimeEffectsController owns and restores global time scale"
	)
	effects.free()


func _test_pause_controller_stops_pausable_gameplay() -> void:
	var pause_script := load(PAUSE_CONTROLLER_SCRIPT_PATH) as GDScript
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if pause_script == null or player_scene == null:
		_fail("PauseController and player modules are available")
		return
	var pause_controller := pause_script.new() as Node
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(pause_controller)
	root.add_child(player)
	await physics_frame
	var starting_position: Vector2 = player.global_position
	pause_controller.set_paused(true)
	Input.action_press("move_right")
	for _frame in range(4):
		await physics_frame
	Input.action_release("move_right")
	pause_controller.set_paused(false)
	_expect(
		player.global_position.is_equal_approx(starting_position),
		"PauseController stops pausable gameplay nodes"
	)
	pause_controller.queue_free()
	player.queue_free()
	await process_frame


func _test_pause_settings_menu_restarts_from_checkpoint() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	var home_scene := load(HOME_SCENE_PATH) as PackedScene
	var settings_scene := load(SETTINGS_MENU_SCENE_PATH) as PackedScene
	if game_scene == null or home_scene == null or settings_scene == null:
		_fail("pause settings and home scenes are available")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await physics_frame

	var player: CharacterBody2D = game.get_player()
	var checkpoint_position := Vector2(320.0, 180.0)
	var pause_controller := game.get_node("Systems/PauseController") as PauseController
	var settings_menu := game.get_node("SettingsMenu") as CanvasLayer
	var restart_button := settings_menu.get_node(
		"Backdrop/Center/Panel/Margin/Options/RestartButton"
	) as Button
	var locale_selector := settings_menu.get_node(
		"Backdrop/Center/Panel/Margin/Options/LanguageRow/LocaleSelector"
	) as OptionButton
	var app_settings := root.get_node("AppSettings")
	var original_locale: StringName = app_settings.get_locale()
	var requested_locale := &"zh_Hans" if original_locale != &"zh_Hans" else &"zh_Hant"
	game.activate_checkpoint(checkpoint_position)
	player.global_position = Vector2(900.0, 360.0)
	player.memory_energy = player.max_memory_energy
	player.health = 1
	pause_controller.set_paused(true)
	await process_frame
	var opened_while_paused := paused and settings_menu.visible
	var requested_locale_index := -1
	for item_index in range(locale_selector.item_count):
		if StringName(locale_selector.get_item_metadata(item_index)) == requested_locale:
			requested_locale_index = item_index
			break
	if requested_locale_index >= 0:
		locale_selector.item_selected.emit(requested_locale_index)
	var locale_changed_from_menu: bool = app_settings.get_locale() == requested_locale
	restart_button.pressed.emit()
	await process_frame

	_expect(
		opened_while_paused
		and not paused
		and not settings_menu.visible,
		"pausing opens the settings page and restart closes it"
	)
	_expect(
		player.global_position.distance_to(checkpoint_position) < 5.0
		and player.health == player.max_health
		and player.memory_energy == player.max_memory_energy / 2,
		"settings restart restores the player at the latest checkpoint"
	)
	_expect(locale_changed_from_menu, "settings language selection updates AppSettings")
	app_settings.set_locale(original_locale)
	game.queue_free()
	await process_frame


func _test_player_animation_follows_horizontal_input() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail("player scene is available for player animation")
		return
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await physics_frame

	var animated_sprite := player.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		_fail("Player scene owns its AnimatedSprite2D under Visual")
		player.queue_free()
		await process_frame
		return
	var starts_idle := animated_sprite.animation == &"idle"
	Input.action_press("move_left")
	await physics_frame
	var runs_left := animated_sprite.animation == &"run"
	Input.action_release("move_left")
	Input.action_press("move_right")
	await physics_frame
	var runs_right := animated_sprite.animation == &"run"
	Input.action_release("move_right")
	await physics_frame

	_expect(
		starts_idle and runs_left and runs_right and animated_sprite.animation == &"idle",
		"Player-owned animation is idle without horizontal input and run while A or D is pressed"
	)
	player.queue_free()
	await process_frame


func _test_inspection_drone_animation_follows_motion_and_fire() -> void:
	var drone_scene := load(INSPECTION_DRONE_SCENE_PATH) as PackedScene
	if drone_scene == null:
		_fail("inspection drone scene is available for animation validation")
		return
	var drone := drone_scene.instantiate() as CharacterBody2D
	root.add_child(drone)
	await physics_frame

	var visual := drone.get_node_or_null("Visual")
	var animated_sprite := drone.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if visual == null or animated_sprite == null:
		_fail("InspectionDrone owns an AnimatedSprite2D through its Visual adapter")
		drone.queue_free()
		await process_frame
		return

	var expected_animations := {
		&"hover": [6, 10.0, true],
		&"move_right": [6, 12.0, true],
		&"move_up": [6, 12.0, true],
		&"move_down": [6, 12.0, true],
		&"fire": [7, 15.0, false],
	}
	var animation_contract_matches := true
	for animation_name: StringName in expected_animations:
		var expected: Array = expected_animations[animation_name]
		animation_contract_matches = (
			animation_contract_matches
			and animated_sprite.sprite_frames.has_animation(animation_name)
			and animated_sprite.sprite_frames.get_frame_count(animation_name) == expected[0]
			and is_equal_approx(
				animated_sprite.sprite_frames.get_animation_speed(animation_name),
				expected[1]
			)
			and animated_sprite.sprite_frames.get_animation_loop(animation_name) == expected[2]
		)

	visual.call("sync_motion", Vector2.ZERO, Vector2.RIGHT)
	var idles_while_still := animated_sprite.animation == &"hover"
	visual.call("sync_motion", Vector2(80.0, 15.0), Vector2.RIGHT)
	var moves_horizontally := animated_sprite.animation == &"move_right"
	visual.call("sync_motion", Vector2(10.0, -80.0), Vector2.RIGHT)
	var moves_upward := animated_sprite.animation == &"move_up"
	visual.call("sync_motion", Vector2(10.0, 80.0), Vector2.RIGHT)
	var moves_downward := animated_sprite.animation == &"move_down"

	var projectile_events: Array[int] = []
	visual.connect(&"projectile_frame_reached", func() -> void: projectile_events.append(1))
	visual.call("play_fire", Vector2.LEFT)
	var attack_faces_target := animated_sprite.animation == &"fire" and animated_sprite.flip_h
	animated_sprite.set_frame_and_progress(4, 0.0)
	var projectile_event_matches_frame := projectile_events.size() == 1

	_expect(
		animation_contract_matches
		and idles_while_still
		and moves_horizontally
		and moves_upward
		and moves_downward
		and attack_faces_target
		and projectile_event_matches_frame,
		"InspectionDrone maps trajectories to animation states and emits fire on frame 4"
	)
	drone.queue_free()
	await process_frame


func _test_player_moves_right_from_keyboard_input() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail("player scene is available")
		return

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await physics_frame

	var starting_x := player.global_position.x
	Input.action_press("move_right")
	for _frame in range(8):
		await physics_frame
	Input.action_release("move_right")

	_expect(
		player.global_position.x > starting_x + 5.0,
		"keyboard move_right moves the player to the right"
	)
	player.queue_free()
	await process_frame


func _test_player_dashes_in_the_facing_direction() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail("player scene is available for dashing")
		return

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await physics_frame
	var starting_x := player.global_position.x

	Input.action_press("move_right")
	Input.action_press("dash")
	await physics_frame
	Input.action_release("dash")
	for _frame in range(2):
		await physics_frame
	Input.action_release("move_right")

	_expect(
		player.global_position.x > starting_x + 20.0,
		"keyboard dash creates a short burst in the facing direction"
	)
	player.queue_free()
	await process_frame


func _test_player_drops_through_one_way_platform() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail("player scene is available for platform dropping")
		return

	var platform := _make_one_way_floor()
	root.add_child(platform)
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	for _frame in range(30):
		await physics_frame
	var was_grounded := player.is_on_floor()
	var grounded_y := player.global_position.y

	Input.action_press("move_down")
	await physics_frame
	Input.action_release("move_down")
	for _frame in range(12):
		await physics_frame

	_expect(
		was_grounded and player.global_position.y > grounded_y + 5.0,
		"keyboard move_down drops the player through a one-way platform"
	)
	player.queue_free()
	platform.queue_free()
	await process_frame


func _test_basic_attack_damages_enemy_and_builds_memory() -> void:
	var fixture := await _spawn_combat_fixture(42.0)
	if fixture.is_empty():
		return
	var player := fixture.player as CharacterBody2D
	var worker := fixture.worker as CharacterBody2D

	var starting_health: int = worker.health
	var starting_memory: int = player.memory_energy
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	for _frame in range(3):
		await physics_frame

	_expect(
		worker.health < starting_health and player.memory_energy > starting_memory,
		"basic attack damages an enemy and builds memory energy"
	)
	await _clean_combat_fixture(fixture)


func _test_skill_spends_memory_and_damages_enemy() -> void:
	var fixture := await _spawn_combat_fixture(48.0)
	if fixture.is_empty():
		return
	var player := fixture.player as CharacterBody2D
	var worker := fixture.worker as CharacterBody2D

	player.has_skill = true
	player.memory_energy = 50
	var starting_health: int = worker.health
	var starting_memory: int = player.memory_energy
	Input.action_press("skill")
	await physics_frame
	Input.action_release("skill")
	for _frame in range(3):
		await physics_frame

	_expect(
		worker.health < starting_health and player.memory_energy < starting_memory,
		"skill damages an enemy and spends memory energy"
	)
	await _clean_combat_fixture(fixture)


func _spawn_combat_fixture(worker_x: float) -> Dictionary:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var worker_scene := load(FORGOTTEN_WORKER_SCENE_PATH) as PackedScene
	if player_scene == null or worker_scene == null:
		_fail("player and forgotten worker scenes are available for combat")
		return {}
	var floor_body := _make_floor()
	root.add_child(floor_body)
	var player := player_scene.instantiate() as CharacterBody2D
	var worker := worker_scene.instantiate() as CharacterBody2D
	player.global_position = Vector2.ZERO
	worker.global_position = Vector2(worker_x, 0.0)
	root.add_child(player)
	root.add_child(worker)
	for _frame in range(30):
		await physics_frame
	return {"floor": floor_body, "player": player, "worker": worker}


func _clean_combat_fixture(fixture: Dictionary) -> void:
	fixture.player.queue_free()
	fixture.worker.queue_free()
	fixture.floor.queue_free()
	await process_frame


func _test_player_damage_has_brief_invulnerability() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail("player scene is available for damage")
		return
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await physics_frame
	if not player.has_method("take_damage"):
		_fail("player exposes damage behavior")
		player.queue_free()
		return

	var starting_health: int = player.health
	var first_hit_applied: bool = player.take_damage(1, Vector2.LEFT * 100.0)
	var repeated_hit_blocked: bool = not player.take_damage(1, Vector2.LEFT * 100.0)

	_expect(
		first_hit_applied
		and repeated_hit_blocked
		and player.health == starting_health - 1,
		"player damage reduces health once during brief invulnerability"
	)
	player.queue_free()
	await process_frame


func _test_enemy_melee_attack_is_blocked_by_a_wall() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var worker_scene := load(FORGOTTEN_WORKER_SCENE_PATH) as PackedScene
	if player_scene == null or worker_scene == null:
		_fail("combat scenes are available for wall-blocked attack regression")
		return
	var floor_body := _make_floor()
	var wall := StaticBody2D.new()
	wall.global_position = Vector2(28.0, 0.0)
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(4.0, 100.0)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	var player := player_scene.instantiate() as CharacterBody2D
	var worker := worker_scene.instantiate() as CharacterBody2D
	player.global_position = Vector2(56.0, 0.0)
	worker.global_position = Vector2.ZERO
	root.add_child(floor_body)
	root.add_child(wall)
	root.add_child(player)
	root.add_child(worker)
	worker.set_target(player)
	for _frame in range(30):
		await physics_frame
	var starting_health: int = player.health
	for _frame in range(120):
		await physics_frame

	_expect(
		player.health == starting_health,
		"an enemy melee attack cannot damage the player through a solid wall"
	)
	player.queue_free()
	worker.queue_free()
	wall.queue_free()
	floor_body.queue_free()
	await process_frame


func _test_enemy_attack_path_is_blocked_by_a_platform() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var worker_scene := load(FORGOTTEN_WORKER_SCENE_PATH) as PackedScene
	if player_scene == null or worker_scene == null:
		_fail("combat scenes are available for platform-blocked attack regression")
		return
	var platform := StaticBody2D.new()
	platform.global_position = Vector2(0.0, 28.0)
	var platform_collision := CollisionShape2D.new()
	var platform_shape := RectangleShape2D.new()
	platform_shape.size = Vector2(100.0, 4.0)
	platform_collision.shape = platform_shape
	platform.add_child(platform_collision)
	var player := player_scene.instantiate() as CharacterBody2D
	var worker := worker_scene.instantiate() as CharacterBody2D
	worker.global_position = Vector2.ZERO
	player.global_position = Vector2(0.0, 56.0)
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(platform)
	root.add_child(player)
	root.add_child(worker)
	await physics_frame

	_expect(
		not worker.has_clear_attack_path(player),
		"an enemy attack path cannot pass through a solid platform"
	)
	player.queue_free()
	worker.queue_free()
	platform.queue_free()
	await process_frame


func _test_death_respawns_at_checkpoint_with_persistent_progress() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for respawning")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await physics_frame
	if not game.has_method("get_player") or not game.has_method("activate_checkpoint"):
		_fail("game exposes player and checkpoint behavior")
		game.queue_free()
		return

	var player: CharacterBody2D = game.get_player()
	var checkpoint_position := Vector2(320.0, 180.0)
	game.activate_checkpoint(checkpoint_position)
	var ordinary_enemy := get_first_node_in_group("respawnable_enemy") as CharacterBody2D
	ordinary_enemy.take_damage(ordinary_enemy.max_health)
	player.has_wall_module = true
	player.memory_energy = player.max_memory_energy
	player.health = 1
	player.take_damage(1, Vector2(500.0, -300.0))
	var fatal_knockback_cleared := player.velocity.is_zero_approx()
	for _frame in range(3):
		await physics_frame

	_expect(
		player.global_position.distance_to(checkpoint_position) < 5.0
		and player.health == player.max_health
		and player.memory_energy == player.max_memory_energy / 2
		and player.has_wall_module,
		"death restores checkpoint state while permanent ability progress remains"
	)
	_expect(
		ordinary_enemy.visible and ordinary_enemy.health == ordinary_enemy.max_health,
		"ordinary enemies respawn when the player returns to a checkpoint"
	)
	_expect(fatal_knockback_cleared, "fatal knockback is cleared by checkpoint respawn")
	game.queue_free()
	await process_frame


func _test_boss_defeat_unlocks_wall_module_and_return_route() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for boss progression")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await physics_frame
	if not game.has_method("get_boss") or not game.has_method("is_return_route_open"):
		_fail("game exposes boss progression behavior")
		game.queue_free()
		return

	var player: CharacterBody2D = game.get_player()
	var boss: CharacterBody2D = game.get_boss()
	var boss_status := game.get_node("HUD/BossStatus") as Label
	_expect(
		not boss_status.text.contains("%d"),
		"boss status is formatted when the scene first appears"
	)
	boss.take_damage(boss.max_health)
	for _frame in range(3):
		await physics_frame
	var app_settings := root.get_node("AppSettings")
	app_settings.set_locale(&"zh_Hans")
	await process_frame
	var boss_status_stayed_hidden := not boss_status.visible
	app_settings.set_locale(&"zh_Hant")
	var module_unlocked_before_route: bool = (
		player.has_wall_module and not game.is_return_route_open()
	)
	game.activate_return_route()
	await physics_frame

	_expect(
		module_unlocked_before_route and game.is_return_route_open(),
		"defeating the foreman unlocks the wall module used to open the return route"
	)
	_expect(
		boss_status_stayed_hidden,
		"changing locale does not revive a defeated boss status"
	)
	game.queue_free()
	await process_frame


func _test_wall_module_enables_wall_jump() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail("player scene is available for wall jumping")
		return
	var wall := _make_wall()
	root.add_child(wall)
	var player := player_scene.instantiate() as CharacterBody2D
	player.global_position = Vector2(12.0, 0.0)
	player.has_wall_module = true
	root.add_child(player)
	Input.action_press("move_right")
	for _frame in range(4):
		await physics_frame
	var starting_y := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	Input.action_release("move_right")
	await physics_frame

	_expect(
		player.velocity.x < 0.0 and player.global_position.y < starting_y,
		"magnetic wall module enables jumping away from a wall"
	)
	player.queue_free()
	wall.queue_free()
	await process_frame


func _test_boss_dialog_clears_before_the_next_battle_line() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for dialog timing")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame

	var boss: CharacterBody2D = game.get_boss()
	var dialog_panel := game.get_node("HUD/DialogPanel") as ColorRect
	boss.battle_line_spoken.emit("測試工作口令")
	game.get_dialogue_controller().tick(boss.behavior.battle_line_interval)

	_expect(
		not dialog_panel.visible,
		"boss dialog clears before another battle line can replace it"
	)
	game.queue_free()
	await process_frame


func _test_boss_battle_lines_do_not_repeat() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for boss battle line sequencing")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame

	var player: CharacterBody2D = game.get_player()
	var boss: CharacterBody2D = game.get_boss()
	var spoken_lines: Array[String] = []
	boss.battle_line_spoken.connect(
		func(line: String) -> void: spoken_lines.append(line)
	)
	player.global_position = boss.global_position + Vector2.LEFT * 100.0
	boss.behavior = boss.behavior.duplicate(true)
	boss.behavior.battle_line_interval = 0.01
	for _frame in range(140):
		await physics_frame

	var unique_lines := {}
	for line in spoken_lines:
		unique_lines[line] = true
	_expect(
		spoken_lines.size() == 3 and unique_lines.size() == 3,
		"the foreman's three battle lines each play once without repeating"
	)
	game.queue_free()
	await process_frame


func _test_checkpoint_dialog_only_appears_once() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for checkpoint dialog behavior")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame

	var player: CharacterBody2D = game.get_player()
	var checkpoint := get_first_node_in_group("checkpoint") as Area2D
	var dialog_panel := game.get_node("HUD/DialogPanel") as ColorRect
	checkpoint.activate(player)
	dialog_panel.visible = false
	checkpoint.activate(player)

	_expect(
		not dialog_panel.visible,
		"checkpoint dialog only appears on its first activation"
	)
	game.queue_free()
	await process_frame


func _test_interact_dismisses_visible_dialog() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for dismissing dialog")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame

	var dialog_panel := game.get_node("HUD/DialogPanel") as ColorRect
	var continue_hint := game.get_node("HUD/DialogPanel/ContinueHint") as Label
	game.present_dialogue(&"dialog.supervisor")
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")

	_expect(not dialog_panel.visible, "interact dismisses a visible dialog")
	_expect(
		continue_hint.text == tr(&"ui.continue"),
		"dialog displays the localized continue hint"
	)
	game.queue_free()
	await process_frame


func _test_checkpoint_dialog_lasts_two_seconds() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for checkpoint dialog timing")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame

	var player: CharacterBody2D = game.get_player()
	var checkpoint := get_first_node_in_group("checkpoint") as Area2D
	var dialog_panel := game.get_node("HUD/DialogPanel") as ColorRect
	checkpoint.activate(player)
	game.get_dialogue_controller().tick(1.99)
	var visible_before_two_seconds := dialog_panel.visible
	game.get_dialogue_controller().tick(0.02)

	_expect(
		visible_before_two_seconds and not dialog_panel.visible,
		"checkpoint dialog remains visible until its two-second duration ends"
	)
	game.queue_free()
	await process_frame


func _test_player_jumps_from_keyboard_input() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail("player scene is available for jumping")
		return

	var floor_body := _make_floor()
	root.add_child(floor_body)
	var player := player_scene.instantiate() as CharacterBody2D
	player.global_position = Vector2(0.0, 0.0)
	root.add_child(player)
	for _frame in range(30):
		await physics_frame

	var grounded_y := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame

	_expect(
		player.global_position.y < grounded_y - 2.0,
		"keyboard jump moves the grounded player upward"
	)
	player.queue_free()
	floor_body.queue_free()
	await process_frame


func _test_holding_jump_reaches_platform_height() -> void:
	var short_jump_height := await _measure_jump_height(1)
	var held_jump_height := await _measure_jump_height(12)

	_expect(
		held_jump_height > 110.0
		and held_jump_height > short_jump_height + 50.0,
		(
			"holding jump reaches a platform and rises higher than a short tap "
			+ "(short %.1f, held %.1f)" % [short_jump_height, held_jump_height]
		)
	)


func _measure_jump_height(hold_frames: int) -> float:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail("player scene is available for variable jump measurement")
		return 0.0

	var floor_body := _make_floor()
	root.add_child(floor_body)
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	for _frame in range(30):
		await physics_frame

	var starting_y := player.global_position.y
	var peak_y := starting_y
	Input.action_press("jump")
	for frame in range(45):
		await physics_frame
		peak_y = minf(peak_y, player.global_position.y)
		if frame + 1 == hold_frames:
			Input.action_release("jump")
	Input.action_release("jump")

	var jump_height := starting_y - peak_y
	player.queue_free()
	floor_body.queue_free()
	await process_frame
	return jump_height


func _test_nearest_interactable_shows_prompt() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for interaction prompts")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame

	var player: CharacterBody2D = game.get_player()
	var lamplighter := game.get_node(
		"LevelContainer/AbandonedMaintenanceLevel/Lamplighter"
	) as Area2D
	var prompt := lamplighter.get_node("InteractionPrompt") as Label
	player.global_position = lamplighter.global_position
	await process_frame

	_expect(
		prompt.visible and prompt.text == "按 E 互動",
		"the nearest interactable shows an E interaction prompt"
	)
	game.queue_free()
	await process_frame


func _test_named_characters_display_identity_labels_that_follow_them() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for identity labels")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame

	var lamplighter := game.get_node(
		"LevelContainer/AbandonedMaintenanceLevel/Lamplighter"
	) as Area2D
	var boss: CharacterBody2D = game.get_boss()
	var lamplighter_label := lamplighter.get_node("IdentityLabel") as Label
	var boss_label := boss.get_node("IdentityLabel") as Label
	var lamplighter_offset := lamplighter_label.global_position - lamplighter.global_position
	var boss_offset := boss_label.global_position - boss.global_position
	lamplighter.global_position += Vector2(70.0, -20.0)
	boss.global_position += Vector2(-80.0, -10.0)
	await process_frame

	_expect(
		lamplighter_label.visible
		and lamplighter_label.text == "守燈人"
		and lamplighter_label.global_position - lamplighter.global_position == lamplighter_offset,
		"the named NPC displays a localized identity label that follows movement"
	)
	_expect(
		boss_label.visible
		and boss_label.text == "殘響監工"
		and boss_label.global_position - boss.global_position == boss_offset,
		"the important monster displays a localized identity label that follows movement"
	)
	game.queue_free()
	await process_frame


func _test_area_message_trigger_only_fires_once() -> void:
	var trigger_scene := load(MESSAGE_TRIGGER_SCENE_PATH) as PackedScene
	if trigger_scene == null:
		_fail("message trigger scene is available")
		return
	var trigger := trigger_scene.instantiate() as Area2D
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	root.add_child(trigger)
	root.add_child(player)
	await process_frame

	var messages: Array[String] = []
	trigger.triggered.connect(func(message: String) -> void: messages.append(message))
	trigger.activate(player)
	trigger.activate(player)
	await process_frame

	_expect(
		messages.size() == 1
		and trigger.has_triggered()
		and not trigger.monitoring,
		"an automatic area dialog disables itself after its first trigger"
	)
	trigger.queue_free()
	player.queue_free()
	await process_frame


func _test_crossing_return_gate_does_not_cause_unprompted_damage() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for return gate damage regression")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await physics_frame

	var player: CharacterBody2D = game.get_player()
	player.global_position = Vector2(1560.0, 620.0)
	player.velocity = Vector2.ZERO
	var starting_health: int = player.health
	for _frame in range(180):
		await physics_frame

	_expect(
		player.health == starting_health,
		(
			"crossing the return gate does not cause unprompted damage "
			+ "(health %d -> %d)" % [starting_health, player.health]
		)
	)
	game.queue_free()
	await process_frame


func _test_distant_boss_does_not_attack_player_at_return_gate() -> void:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	if game_scene == null:
		_fail("game scene is available for boss encounter range regression")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	await physics_frame

	var player: CharacterBody2D = game.get_player()
	var level := game.get_node("LevelContainer/AbandonedMaintenanceLevel")
	for enemy_name: String in ["WorkerA", "WorkerB", "WorkerC", "WorkerD", "DroneA", "DroneB"]:
		level.get_node(enemy_name).queue_free()
	player.global_position = Vector2(1460.0, 620.0)
	player.velocity = Vector2.ZERO
	await physics_frame
	var starting_health: int = player.health
	for _frame in range(600):
		await physics_frame

	_expect(
		player.health == starting_health,
		(
			"the distant boss does not attack the player before the boss area "
			+ "(health %d -> %d)" % [starting_health, player.health]
		)
	)
	game.queue_free()
	await process_frame


func _make_floor() -> StaticBody2D:
	var floor_body := StaticBody2D.new()
	floor_body.global_position = Vector2(0.0, 42.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(400.0, 20.0)
	collision.shape = shape
	floor_body.add_child(collision)
	return floor_body


func _make_one_way_floor() -> StaticBody2D:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.global_position = Vector2(0.0, 42.0)
	var collision := CollisionShape2D.new()
	collision.one_way_collision = true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(400.0, 20.0)
	collision.shape = shape
	floor_body.add_child(collision)
	return floor_body


func _make_wall() -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.global_position = Vector2(40.0, 0.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 320.0)
	collision.shape = shape
	wall.add_child(collision)
	return wall


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	push_error("FAIL: %s" % message)
