extends Node

const RunControllerScript = preload("res://run/run_controller.gd")
const LocalSaveScript = preload("res://services/local_save.gd")


func _ready() -> void:
	GameSession.is_run_active = false
	GameSession.active_run_snapshot = {}
	var game := preload("res://scenes/run_game.tscn").instantiate() as RunGame
	add_child(game)
	await get_tree().process_frame
	var run := game.controller
	if not _require(run.room_count() == 6, "run did not load exactly six rooms"):
		return
	var base_rate: float = run.combat_stats.fire_rate
	var base_dash: float = run.combat_stats.dash_cooldown
	if not _require(run.grant_upgrade_for_test(&"rapid_embers"), "fire-rate upgrade was unavailable"):
		return
	if not _require(run.grant_upgrade_for_test(&"split_cinders"), "multishot upgrade was unavailable"):
		return
	if not _require(run.grant_upgrade_for_test(&"fleet_ash"), "dash upgrade was unavailable"):
		return
	if not _require(run.combat_stats.fire_rate > base_rate and run.combat_stats.multishot == 2 and run.combat_stats.dash_cooldown < base_dash, "upgrades did not change runtime combat stats"):
		return

	if not await _kill_current_room(game):
		return
	if not _require(run.state == RunControllerScript.State.REWARD and run.current_reward_choices.size() == 3, "room clear did not open a three-choice reward"):
		return
	if not _require(run.choose_upgrade(run.current_reward_choices[0].id) and run.current_room_index == 1, "reward selection did not start the next room"):
		return

	var forest_room := load("res://data/mock_forest_combat_room.tres") as RoomDefinition
	var rules := ForestRoomRules.new(forest_room)
	if not _require(rules.is_concealed(forest_room.grass_areas[0].get_center()), "grass did not conceal an actor"):
		return
	if not _require(rules.speed_multiplier_at(forest_room.mud_areas[0].get_center()) < 1.0, "mud did not slow an actor"):
		return
	if not _require(rules.blocks_actor_at(forest_room.river_areas[0].get_center() + Vector2(0.0, 300.0)), "river did not block movement"):
		return
	var tree := forest_room.tree_positions[0]
	if not _require(rules.blocks_projectile_segment(tree - Vector2(70.0, 0.0), tree + Vector2(70.0, 0.0)), "tree did not block a projectile"):
		return

	while run.current_room_index < 5:
		if not await _kill_current_room(game):
			return
		if not _require(run.choose_upgrade(run.current_reward_choices[0].id), "intermediate reward could not be chosen"):
			return
		await get_tree().process_frame
	if not _require(run.current_room().kind == RoomDefinition.Kind.BOSS, "final room was not the boss"):
		return
	var boss_enemies := _current_enemies(game)
	if not _require(not boss_enemies.is_empty(), "boss room spawned no actual boss"):
		return
	var boss := boss_enemies[0] as CombatEnemy
	if not _require(boss.definition.archetype == EnemyDefinition.Archetype.BOSS, "spawned final enemy was not the boss"):
		return
	boss.health.take_damage(100000)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _require(run.state == RunControllerScript.State.WON, "boss clear did not win the run"):
		return

	var losing_run = RunControllerScript.new()
	add_child(losing_run)
	losing_run.start_run(2718)
	losing_run.player_defeated()
	if not _require(losing_run.state == RunControllerScript.State.LOST, "player death did not lose the run"):
		return
	if not _smoke_save_recovery():
		return
	print("RUN_LOOP_SMOKE_OK: clear, reward, upgrade stats, forest rules, boss win, death loss, and save recovery are observable")
	get_tree().quit(0)


func _kill_current_room(game: RunGame) -> bool:
	var enemies := _current_enemies(game)
	if not _require(not enemies.is_empty(), "room spawned no actual enemies"):
		return false
	for node: Node in enemies:
		(node as CombatEnemy).health.take_damage(100000)
	await get_tree().process_frame
	await get_tree().process_frame
	return _require(game.controller.state == RunController.State.REWARD, "actual enemy deaths did not clear room into reward")


func _current_enemies(game: RunGame) -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(game._room_root) and game._room_root.is_ancestor_of(node):
			result.append(node)
	return result


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	printerr("RUN_LOOP_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
	return false


func _smoke_save_recovery() -> bool:
	var path := "user://mock_run_loop_smoke_corrupt.json"
	for cleanup_path: String in [path, path + ".previous", path + ".tmp"]:
		if FileAccess.file_exists(cleanup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path))
	var corrupt_file := FileAccess.open(path, FileAccess.WRITE)
	corrupt_file.store_string("not-json")
	corrupt_file.close()
	var save = LocalSaveScript.new()
	add_child(save)
	save.save_path = path
	var recovered: Dictionary = save.load_data()
	var backup_path: String = save.last_corrupt_backup_path
	var succeeded := recovered == save.default_data() and FileAccess.file_exists(backup_path)
	for cleanup_path: String in [path, path + ".previous", path + ".tmp", backup_path]:
		if FileAccess.file_exists(cleanup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path))
	save.queue_free()
	return _require(succeeded, "corrupt save was not backed up and reset")
