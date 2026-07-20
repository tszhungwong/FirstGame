extends GutTest

const LocalSaveScript = preload("res://services/local_save.gd")
const LocalSaveBackendScript = preload("res://services/local_save_backend.gd")
var _save_path: String


class PromotionFailBackend extends LocalSaveBackend:
	var fail_promotion: bool = false

	func promote_temporary(source_path: String, destination_path: String) -> Error:
		if fail_promotion:
			return ERR_CANT_CREATE
		return super.promote_temporary(source_path, destination_path)


class BackupFailBackend extends LocalSaveBackend:
	func write_bytes_flush(path: String, bytes: PackedByteArray) -> bool:
		if ".corrupt." in path:
			return false
		return super.write_bytes_flush(path, bytes)


func before_each() -> void:
	_save_path = "user://mock_task_3_%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	for suffix: String in ["", ".tmp", ".previous", ".corrupt.bak"]:
		if FileAccess.file_exists(_save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path + suffix))
	var directory := DirAccess.open("user://")
	if directory != null:
		for filename: String in directory.get_files():
			if filename.begins_with(_save_path.get_file() + ".corrupt."):
				directory.remove(filename)


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
	assert_true(FileAccess.file_exists(save.last_corrupt_backup_path))
	var backup := FileAccess.open(save.last_corrupt_backup_path, FileAccess.READ)
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


func test_failed_promotion_restores_the_previous_valid_primary() -> void:
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	var backend := PromotionFailBackend.new()
	save.backend = backend
	var original: Dictionary = save.default_data()
	original.active_run = {"seed": 41, "room_index": 2, "upgrade_stacks": {}}
	assert_true(save.save_data(original))
	backend.fail_promotion = true
	var replacement: Dictionary = save.default_data()
	replacement.active_run = {"seed": 99, "room_index": 4, "upgrade_stacks": {}}

	assert_false(save.save_data(replacement))
	assert_eq(int(save.load_data().active_run.seed), 41)


func test_load_recovers_predecessor_when_primary_is_missing() -> void:
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	var data: Dictionary = save.default_data()
	data.active_run = {"seed": 73, "room_index": 1, "upgrade_stacks": {}}
	assert_true(save.save_data(data))
	assert_eq(DirAccess.rename_absolute(ProjectSettings.globalize_path(_save_path), ProjectSettings.globalize_path(_save_path + ".previous")), OK)

	assert_eq(int(save.load_data().active_run.seed), 73)
	assert_true(FileAccess.file_exists(_save_path))


func test_repeated_corruption_uses_unique_exact_backups() -> void:
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	_write_raw("first corrupt bytes")
	save.load_data()
	var first_backup: String = save.last_corrupt_backup_path
	_write_raw("second corrupt bytes")
	save.load_data()
	var second_backup: String = save.last_corrupt_backup_path

	assert_ne(first_backup, second_backup)
	assert_eq(_read_raw(first_backup), "first corrupt bytes")
	assert_eq(_read_raw(second_backup), "second corrupt bytes")


func test_backup_failure_does_not_replace_corrupt_primary() -> void:
	_write_raw("evidence must survive")
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	save.backend = BackupFailBackend.new()

	save.load_data()
	assert_false(save.save_data(save.default_data()))
	assert_eq(_read_raw(_save_path), "evidence must survive")


func test_parseable_schema_corruption_enters_recovery() -> void:
	_write_raw(JSON.stringify({"version": 2, "progress": [], "settings": {}, "active_run": {}}))
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	var loaded: Dictionary = save.load_data()

	assert_eq(loaded, save.default_data())
	assert_true(not save.last_corrupt_backup_path.is_empty())


func test_corrupt_backup_preserves_non_utf8_raw_bytes_exactly() -> void:
	var raw_bytes := PackedByteArray([0xff, 0x00, 0x81, 0x7b])
	var writer := LocalSaveBackend.new()
	assert_true(writer.write_bytes_flush(_save_path, raw_bytes))
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	save.load_data()

	assert_eq(writer.read_bytes(save.last_corrupt_backup_path), raw_bytes)


func test_legacy_schema_validates_nested_active_run_types_before_migration() -> void:
	_write_raw(JSON.stringify({
		"version": 1,
		"best_room": 4,
		"active_run": {"seed": "not an integer", "room_index": 1, "upgrade_stacks": {}},
	}))
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	var loaded: Dictionary = save.load_data()

	assert_eq(loaded, save.default_data())
	assert_true(not save.last_corrupt_backup_path.is_empty())


func _write_raw(content: String) -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _read_raw(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	return content
