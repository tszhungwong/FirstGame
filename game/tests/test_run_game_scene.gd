extends GutTest


class FailableSaveService extends Node:
	var fail_saves: bool = true
	var stored: Dictionary = {
		"version": 2,
		"progress": {"best_room": 0, "wins": 0},
		"settings": {"music_volume": 1.0, "sfx_volume": 1.0},
		"active_run": {"seed": 77, "room_index": 0, "upgrade_stacks": {}},
	}

	func load_data() -> Dictionary:
		return stored.duplicate(true)

	func save_data(data: Dictionary) -> bool:
		if fail_saves:
			return false
		stored = data.duplicate(true)
		return true


func after_each() -> void:
	GameSession.save_service = LocalSave
	GameSession.pending_finalization = {}
	GameSession.is_run_active = false
	GameSession.active_run_snapshot = {}


func test_actual_room_clear_freezes_combat_until_reward_selection() -> void:
	GameSession.is_run_active = false
	GameSession.active_run_snapshot = {}
	var game := preload("res://scenes/run_game.tscn").instantiate() as RunGame
	add_child_autofree(game)
	await get_tree().process_frame
	var enemies := get_tree().get_nodes_in_group("enemies")
	assert_gt(enemies.size(), 0)
	for node: Node in enemies:
		(node as CombatEnemy).health.take_damage(10000)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(game.controller.state, RunController.State.REWARD)
	assert_false(game.ember.is_physics_processing())
	assert_true(game.ember.health.invulnerable)
	assert_eq(game.projectile_pool.in_use_count(), 0)
	assert_eq(game.projectile_pool.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_true(game.get_node("RunUi/RewardPanel").visible)
	assert_eq(game.get_node("RunUi/RewardPanel").process_mode, Node.PROCESS_MODE_ALWAYS)
	var health_before: int = game.ember.health.current_health
	game.ember.health.take_damage(999)
	assert_eq(game.ember.health.current_health, health_before)

	assert_true(game.controller.choose_upgrade(game.controller.current_reward_choices[0].id))
	await get_tree().process_frame
	assert_eq(game.controller.state, RunController.State.COMBAT)
	assert_true(game.ember.is_physics_processing())
	assert_false(game.ember.health.invulnerable)


func test_cold_resume_restarts_room_at_exact_entry_health_checkpoint() -> void:
	GameSession.is_run_active = true
	GameSession.active_run_seed = 909
	GameSession.active_run_snapshot = {
		"seed": 909,
		"room_index": 2,
		"state": RunController.State.COMBAT,
		"upgrade_stacks": {},
		"reward_choices": [],
		"room_entry_health": 63,
	}
	var game := preload("res://scenes/run_game.tscn").instantiate() as RunGame
	add_child_autofree(game)
	await get_tree().process_frame

	assert_eq(game.controller.current_room_index, 2)
	assert_eq(game.ember.health.current_health, 63)
	assert_eq(game.controller.room_entry_health, 63)


func test_failed_run_finalization_shows_pending_save_and_retries_progress_once() -> void:
	var service := FailableSaveService.new()
	add_child_autofree(service)
	GameSession.save_service = service
	GameSession.pending_finalization = {}
	GameSession.is_run_active = true
	GameSession.active_run_seed = 77
	GameSession.active_run_snapshot = service.stored.active_run.duplicate(true)
	var game := preload("res://scenes/run_game.tscn").instantiate() as RunGame
	add_child_autofree(game)
	await get_tree().process_frame

	game._finish_run(true)

	var end_label := game.get_node_or_null("RunUi/EndPanel/EndContent/EndLabel") as Label
	var retry_button := game.get_node_or_null("RunUi/EndPanel/EndContent/RetrySaveButton") as Button
	assert_true(game.get_node("RunUi/EndPanel").visible)
	assert_not_null(end_label)
	if end_label == null:
		return
	assert_true("SAVE PENDING" in end_label.text)
	assert_false("FOREST RESTORED" in end_label.text)
	assert_not_null(retry_button)
	if retry_button == null:
		return
	assert_true(retry_button.visible)
	assert_eq(int(service.stored.progress.wins), 0)

	service.fail_saves = false
	retry_button.pressed.emit()
	assert_eq(int(service.stored.progress.wins), 1)
	assert_eq(int(service.stored.progress.best_room), 1)
	assert_true("FOREST RESTORED" in end_label.text)
	assert_false(retry_button.visible)

	retry_button.pressed.emit()
	assert_eq(int(service.stored.progress.wins), 1)


func test_room_start_consumes_the_authored_player_spawn_position() -> void:
	GameSession.is_run_active = false
	GameSession.active_run_snapshot = {}
	var game := preload("res://scenes/run_game.tscn").instantiate() as RunGame
	add_child_autofree(game)
	await get_tree().process_frame
	var room := game.controller.current_room().duplicate(true) as RoomDefinition
	assert_true(_has_property(room, &"player_spawn_position"))
	if not _has_property(room, &"player_spawn_position"):
		return
	room.set("player_spawn_position", Vector2(777.0, 333.0))

	game._start_room(0, room)
	await get_tree().process_frame

	assert_eq(game.ember.global_position, Vector2(777.0, 333.0))


func _has_property(resource: Resource, property_name: StringName) -> bool:
	for property: Dictionary in resource.get_property_list():
		if property.name == property_name:
			return true
	return false
