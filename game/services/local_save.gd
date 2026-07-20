extends Node

signal save_recovered(backup_path: String)
signal save_failed(message: String)

const CURRENT_VERSION := 2
const SAVE_PATH := "user://game_ghost_save.json"

var save_path: String = SAVE_PATH


func default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"progress": {"best_room": 0, "wins": 0},
		"settings": {"music_volume": 1.0, "sfx_volume": 1.0},
		"active_run": {},
	}


func save_data(data: Dictionary) -> bool:
	var normalized := _normalize(data)
	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit("Unable to write temporary save")
		return false
	file.store_string(JSON.stringify(normalized))
	file.close()
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(save_path):
		var remove_error := DirAccess.remove_absolute(absolute_save)
		if remove_error != OK:
			save_failed.emit("Unable to replace previous save")
			return false
	var rename_error := DirAccess.rename_absolute(absolute_temporary, absolute_save)
	if rename_error != OK:
		save_failed.emit("Unable to finalize save")
		return false
	return true


func load_data() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		var defaults := default_data()
		save_data(defaults)
		return defaults
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _recover_corrupt_save("")
	var raw := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return _recover_corrupt_save(raw)
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return _recover_corrupt_save(raw)
	return _migrate(parsed as Dictionary)


func _migrate(source: Dictionary) -> Dictionary:
	var version := int(source.get("version", 1))
	var migrated := source.duplicate(true)
	if version <= 1:
		migrated = {
			"version": CURRENT_VERSION,
			"progress": {
				"best_room": int(source.get("best_room", 0)),
				"wins": int(source.get("wins", 0)),
			},
			"settings": {"music_volume": 1.0, "sfx_volume": 1.0},
			"active_run": source.get("active_run", {}),
		}
	else:
		migrated = _normalize(migrated)
	if migrated != source:
		save_data(migrated)
	return migrated


func _normalize(source: Dictionary) -> Dictionary:
	var defaults := default_data()
	var normalized := defaults.duplicate(true)
	normalized.progress.merge(source.get("progress", {}), true)
	normalized.settings.merge(source.get("settings", {}), true)
	normalized.active_run = source.get("active_run", {}).duplicate(true)
	normalized.version = CURRENT_VERSION
	return normalized


func _recover_corrupt_save(raw: String) -> Dictionary:
	var backup_path := save_path + ".corrupt.bak"
	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup != null:
		backup.store_string(raw)
		backup.close()
	var defaults := default_data()
	save_data(defaults)
	save_recovered.emit(backup_path)
	return defaults
