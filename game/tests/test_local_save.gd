extends GutTest

const LocalSaveScript = preload("res://services/local_save.gd")
var _save_path: String


func before_each() -> void:
	_save_path = "user://mock_task_3_%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	for suffix: String in ["", ".corrupt.bak"]:
		if FileAccess.file_exists(_save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path + suffix))


func test_migrates_version_one_save_to_current_schema() -> void:
	_write_raw(JSON.stringify({"version": 1, "best_room": 4}))
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	var loaded: Dictionary = save.load_data()

	assert_eq(loaded.version, LocalSaveScript.CURRENT_VERSION)
	assert_eq(loaded.progress.best_room, 4)
	assert_eq(loaded.settings, {"music_volume": 1.0, "sfx_volume": 1.0})


func test_corrupt_save_is_backed_up_before_default_reset() -> void:
	_write_raw("{definitely not json")
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	var loaded: Dictionary = save.load_data()

	assert_eq(loaded, save.default_data())
	assert_true(FileAccess.file_exists(_save_path + ".corrupt.bak"))
	var backup := FileAccess.open(_save_path + ".corrupt.bak", FileAccess.READ)
	assert_eq(backup.get_as_text(), "{definitely not json")
	backup.close()
	assert_true(FileAccess.file_exists(_save_path))


func test_round_trip_preserves_active_run_state() -> void:
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	var data: Dictionary = save.default_data()
	data.active_run = {"seed": 42, "room_index": 2, "upgrade_stacks": {"wildfire": 2}}
	assert_true(save.save_data(data))
	assert_eq(int(save.load_data().active_run.seed), 42)
	assert_eq(int(save.load_data().active_run.upgrade_stacks.wildfire), 2)


func _write_raw(content: String) -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
