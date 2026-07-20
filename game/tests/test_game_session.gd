extends GutTest

const GameSessionScript = preload("res://services/game_session.gd")


class FailableSaveService extends Node:
	var fail_saves: bool = true
	var stored: Dictionary = {
		"version": 2,
		"progress": {"best_room": 2, "wins": 0},
		"settings": {"music_volume": 1.0, "sfx_volume": 1.0},
		"active_run": {"seed": 77, "room_index": 5, "upgrade_stacks": {}},
	}

	func load_data() -> Dictionary:
		return stored.duplicate(true)

	func save_data(data: Dictionary) -> bool:
		if fail_saves:
			return false
		stored = data.duplicate(true)
		return true


func test_failed_finalization_retains_active_run_and_retry_commits_progress_once() -> void:
	var service := FailableSaveService.new()
	add_child_autofree(service)
	var session = GameSessionScript.new()
	session.save_service = service
	add_child_autofree(session)
	session.is_run_active = true
	session.active_run_seed = 77
	session.active_run_snapshot = service.stored.active_run.duplicate(true)
	watch_signals(session)

	assert_false(session.finish_run(true, 6))
	assert_true(session.is_run_active)
	assert_false(session.active_run_snapshot.is_empty())
	assert_false(session.pending_finalization.is_empty())
	assert_signal_emitted(session, "finalization_failed")
	assert_eq(int(service.stored.progress.wins), 0)

	service.fail_saves = false
	assert_true(session.retry_pending_finalization())
	assert_false(session.is_run_active)
	assert_true(session.active_run_snapshot.is_empty())
	assert_true(session.pending_finalization.is_empty())
	assert_eq(int(service.stored.progress.wins), 1)
	assert_eq(int(service.stored.progress.best_room), 6)
	assert_true(service.stored.active_run.is_empty())
