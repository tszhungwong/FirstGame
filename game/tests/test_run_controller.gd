extends GutTest

const RunControllerScript = preload("res://run/run_controller.gd")


func test_run_is_six_rooms_with_elite_and_final_boss() -> void:
	var run = RunControllerScript.new()
	add_child_autofree(run)
	run.start_run(8142)

	assert_eq(run.room_count(), 6)
	assert_eq(run.room_kind_at(3), RoomDefinition.Kind.ELITE)
	assert_eq(run.room_kind_at(5), RoomDefinition.Kind.BOSS)
	assert_eq(run.state, RunControllerScript.State.COMBAT)


func test_clear_reward_pick_and_next_room_flow() -> void:
	var run = RunControllerScript.new()
	add_child_autofree(run)
	run.start_run(99)

	run.complete_room()
	assert_eq(run.state, RunControllerScript.State.REWARD)
	assert_eq(run.current_reward_choices.size(), 3)
	assert_ne(run.current_reward_choices[0].id, run.current_reward_choices[1].id)
	assert_true(run.choose_upgrade(run.current_reward_choices[0].id))
	assert_eq(run.current_room_index, 1)
	assert_eq(run.state, RunControllerScript.State.COMBAT)


func test_reward_choices_are_seeded_and_upgrade_stacks() -> void:
	var first = RunControllerScript.new()
	var second = RunControllerScript.new()
	add_child_autofree(first)
	add_child_autofree(second)
	first.start_run(12345)
	second.start_run(12345)
	first.complete_room()
	second.complete_room()

	assert_eq(first.reward_choice_ids(), second.reward_choice_ids())
	var chosen: StringName = first.current_reward_choices[0].id
	assert_true(first.choose_upgrade(chosen))
	first.grant_upgrade_for_test(chosen)
	assert_eq(first.upgrade_stacks.get(chosen, 0), 2)


func test_boss_clear_wins_and_player_death_loses() -> void:
	var run = RunControllerScript.new()
	add_child_autofree(run)
	run.start_run(7)
	for room_index: int in 5:
		run.complete_room()
		assert_true(run.choose_upgrade(run.current_reward_choices[0].id))
		assert_eq(run.current_room_index, room_index + 1)
	run.complete_room()
	assert_eq(run.state, RunControllerScript.State.WON)

	run.start_run(8)
	run.player_defeated()
	assert_eq(run.state, RunControllerScript.State.LOST)


func test_distinct_upgrade_builds_change_runtime_combat_stats() -> void:
	var run = RunControllerScript.new()
	add_child_autofree(run)
	run.start_run(5)
	var base_fire_rate: float = run.combat_stats.fire_rate
	var base_multishot: int = run.combat_stats.multishot
	var base_penetration: int = run.combat_stats.penetration
	var base_ricochet: int = run.combat_stats.ricochet
	var base_burn_damage: int = run.combat_stats.burn_damage
	var base_dash_cooldown: float = run.combat_stats.dash_cooldown
	for id: StringName in [&"rapid_embers", &"split_cinders", &"thorn_piercer", &"bark_ricochet", &"wildfire", &"fleet_ash"]:
		run.grant_upgrade_for_test(id)

	assert_gt(run.combat_stats.fire_rate, base_fire_rate)
	assert_gt(run.combat_stats.multishot, base_multishot)
	assert_gt(run.combat_stats.penetration, base_penetration)
	assert_gt(run.combat_stats.ricochet, base_ricochet)
	assert_gt(run.combat_stats.burn_damage, base_burn_damage)
	assert_lt(run.combat_stats.dash_cooldown, base_dash_cooldown)


func test_active_run_snapshot_restores_reward_room_and_upgrade_stacks() -> void:
	var original = RunControllerScript.new()
	var restored = RunControllerScript.new()
	add_child_autofree(original)
	add_child_autofree(restored)
	original.start_run(2026)
	original.grant_upgrade_for_test(&"wildfire")
	original.complete_room()
	var expected_choices: Array[StringName] = original.reward_choice_ids()

	restored.restore_run(original.serialize_active_run())
	assert_eq(restored.run_seed, 2026)
	assert_eq(restored.current_room_index, 0)
	assert_eq(restored.state, RunControllerScript.State.REWARD)
	assert_eq(restored.reward_choice_ids(), expected_choices)
	assert_eq(restored.upgrade_stacks.get(&"wildfire", 0), 1)
	assert_gt(restored.combat_stats.burn_damage, 0)


func test_pause_and_resume_preserve_combat_state() -> void:
	var run = RunControllerScript.new()
	add_child_autofree(run)
	run.start_run(55)
	run.set_paused(true)
	assert_eq(run.state, RunControllerScript.State.PAUSED)
	assert_true(get_tree().paused)
	run.set_paused(false)
	assert_eq(run.state, RunControllerScript.State.COMBAT)
	assert_false(get_tree().paused)


func test_restore_rejects_duplicate_stale_and_maxed_reward_choices() -> void:
	var run = RunControllerScript.new()
	add_child_autofree(run)
	var snapshot := {
		"seed": 404,
		"room_index": 2,
		"state": RunControllerScript.State.REWARD,
		"upgrade_stacks": {"wildfire": 3},
		"reward_choices": ["wildfire", "wildfire", "removed_upgrade"],
	}
	run.restore_run(snapshot)
	var choices: Array[StringName] = run.reward_choice_ids()
	var unique_choices: Dictionary = {}
	for id: StringName in choices:
		unique_choices[id] = true

	assert_eq(choices.size(), 3)
	assert_eq(unique_choices.size(), 3)
	assert_false(choices.has(&"wildfire"))
	assert_false(choices.has(&"removed_upgrade"))


func test_failed_reward_application_keeps_reward_state_and_choices() -> void:
	var run = RunControllerScript.new()
	add_child_autofree(run)
	run.start_run(303)
	for _stack: int in 3:
		run.grant_upgrade_for_test(&"wildfire")
	run.state = RunControllerScript.State.REWARD
	var forced_choices: Array[UpgradeDefinition] = [load("res://data/mock_upgrade_wildfire.tres") as UpgradeDefinition]
	run.current_reward_choices = forced_choices

	assert_false(run.choose_upgrade(&"wildfire"))
	assert_eq(run.state, RunControllerScript.State.REWARD)
	assert_eq(run.reward_choice_ids(), [&"wildfire"])


func test_room_entry_health_checkpoint_round_trips_exactly() -> void:
	var original = RunControllerScript.new()
	var restored = RunControllerScript.new()
	add_child_autofree(original)
	add_child_autofree(restored)
	original.start_run(808)
	original.set_room_entry_health(63)
	restored.restore_run(original.serialize_active_run())

	assert_eq(restored.room_entry_health, 63)
