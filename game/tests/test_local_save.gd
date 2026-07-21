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


class RecoveryPromotionFailBackend extends LocalSaveBackend:
	func promote_temporary(_source_path: String, _destination_path: String) -> Error:
		return ERR_CANT_CREATE


class StorageDirectoryFailBackend extends LocalSaveBackend:
	func make_directory_recursive(_path: String) -> Error:
		return ERR_CANT_CREATE


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


func test_corrupt_primary_restores_valid_predecessor_without_rotating_over_it() -> void:
	var valid_predecessor := {
		"version": LocalSaveScript.CURRENT_VERSION,
		"progress": {"best_room": 5, "wins": 1},
		"settings": {"music_volume": 0.75, "sfx_volume": 0.5},
		"active_run": {"seed": 812, "room_index": 3, "upgrade_stacks": {}},
	}
	var predecessor_bytes := JSON.stringify(valid_predecessor).to_utf8_buffer()
	var corrupt_bytes := PackedByteArray([0xff, 0x00, 0x81, 0x7b])
	var writer := LocalSaveBackend.new()
	assert_true(writer.write_bytes_flush(_save_path, corrupt_bytes))
	assert_true(writer.write_bytes_flush(_save_path + ".previous", predecessor_bytes))
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path

	var loaded: Dictionary = save.load_data()

	assert_eq(int(loaded.progress.best_room), 5)
	assert_eq(int(loaded.active_run.seed), 812)
	assert_eq(writer.read_bytes(save.last_corrupt_backup_path), corrupt_bytes)
	assert_eq(writer.read_bytes(_save_path + ".previous"), predecessor_bytes)
	assert_eq(int(save.load_data().active_run.seed), 812)


func test_corrupt_primary_with_invalid_predecessor_preserves_both_evidence_files() -> void:
	var corrupt_primary := "primary corrupt evidence".to_utf8_buffer()
	var invalid_predecessor := "predecessor corrupt evidence".to_utf8_buffer()
	var writer := LocalSaveBackend.new()
	assert_true(writer.write_bytes_flush(_save_path, corrupt_primary))
	assert_true(writer.write_bytes_flush(_save_path + ".previous", invalid_predecessor))
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path

	var loaded: Dictionary = save.load_data()

	assert_eq(loaded, save.default_data())
	assert_eq(writer.read_bytes(save.last_corrupt_backup_path), corrupt_primary)
	assert_eq(writer.read_bytes(_save_path + ".previous"), invalid_predecessor)
	assert_eq(int(save.load_data().progress.best_room), 0)


func test_failed_predecessor_restoration_keeps_recovery_evidence_and_blocks_writes() -> void:
	var valid_predecessor := {
		"version": LocalSaveScript.CURRENT_VERSION,
		"progress": {"best_room": 7, "wins": 2},
		"settings": {"music_volume": 1.0, "sfx_volume": 1.0},
		"active_run": {},
	}
	var corrupt_primary := "do not discard this primary".to_utf8_buffer()
	var predecessor_bytes := JSON.stringify(valid_predecessor).to_utf8_buffer()
	var writer := LocalSaveBackend.new()
	assert_true(writer.write_bytes_flush(_save_path, corrupt_primary))
	assert_true(writer.write_bytes_flush(_save_path + ".previous", predecessor_bytes))
	var save = autofree(LocalSaveScript.new())
	save.save_path = _save_path
	save.backend = RecoveryPromotionFailBackend.new()

	var loaded: Dictionary = save.load_data()

	assert_eq(int(loaded.progress.best_room), 7)
	assert_eq(writer.read_bytes(save.last_corrupt_backup_path), corrupt_primary)
	assert_eq(writer.read_bytes(_save_path), corrupt_primary)
	assert_eq(writer.read_bytes(_save_path + ".previous"), predecessor_bytes)
	assert_false(save.save_data(save.default_data()))


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


func test_process_storage_root_override_applies_before_the_first_load() -> void:
	var environment_name: String = "GAME_GHOST_STORAGE_ROOT"
	var previous_value := OS.get_environment(environment_name)
	var storage_root := "user://mock_smoke_storage_%d" % Time.get_ticks_usec()
	OS.set_environment(environment_name, storage_root)
	var save = autofree(LocalSaveScript.new())
	OS.set_environment(environment_name, previous_value)

	assert_eq(save.save_path, storage_root.path_join("game_ghost_save.json"))
	assert_true(save.save_data(save.default_data()))
	assert_true(FileAccess.file_exists(save.save_path))

	for suffix: String in ["", ".tmp", ".previous"]:
		var path: String = save.save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_root))


func test_unavailable_storage_root_never_falls_back_to_the_production_path() -> void:
	var blocker_path := "user://mock_storage_blocker_%d" % Time.get_ticks_usec()
	var save = autofree(LocalSaveScript.new())
	save.backend = StorageDirectoryFailBackend.new()

	var configure_error: Error = save.configure_storage_root(blocker_path)
	assert_ne(configure_error, OK)
	if configure_error == OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
		return
	assert_eq(save.save_path, blocker_path.path_join("game_ghost_save.json"))
	assert_false(save.save_data(save.default_data()))


func _write_raw(content: String) -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _read_raw(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	return content
