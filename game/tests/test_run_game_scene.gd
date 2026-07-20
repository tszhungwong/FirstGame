extends GutTest


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
