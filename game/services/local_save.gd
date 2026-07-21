extends Node

signal save_recovered(backup_path: String)
signal save_failed(message: String)

const CURRENT_VERSION := 2
const SAVE_FILE_NAME := "game_ghost_save.json"
const SAVE_PATH := "user://" + SAVE_FILE_NAME
const STORAGE_ROOT_ENVIRONMENT := "GAME_GHOST_STORAGE_ROOT"

var save_path: String = SAVE_PATH
var backend: LocalSaveBackend = LocalSaveBackend.new()
var last_corrupt_backup_path: String = ""
var _backup_sequence: int = 0
var _writes_blocked_by_recovery: bool = false


func _init() -> void:
	var storage_root := OS.get_environment(STORAGE_ROOT_ENVIRONMENT).strip_edges()
	if not storage_root.is_empty():
		configure_storage_root(storage_root)


func configure_storage_root(storage_root: String) -> Error:
	var normalized_root := storage_root.strip_edges().trim_suffix("/").trim_suffix("\\")
	if normalized_root.is_empty():
		return ERR_INVALID_PARAMETER
	save_path = normalized_root.path_join(SAVE_FILE_NAME)
	var error := backend.make_directory_recursive(normalized_root)
	if error != OK:
		_writes_blocked_by_recovery = true
		return error
	_writes_blocked_by_recovery = false
	return OK


func default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"progress": {"best_room": 0, "wins": 0},
		"settings": {"music_volume": 1.0, "sfx_volume": 1.0},
		"active_run": {},
	}


func save_data(data: Dictionary) -> bool:
	if _writes_blocked_by_recovery:
		save_failed.emit("Writes blocked until corrupt save evidence is preserved")
		return false
	var normalized := _normalize(data)
	var temporary_path := save_path + ".tmp"
	var predecessor_path := save_path + ".previous"
	if not backend.write_bytes_flush(temporary_path, JSON.stringify(normalized).to_utf8_buffer()):
		save_failed.emit("Unable to write temporary save")
		return false
	if backend.file_exists(save_path):
		if backend.file_exists(predecessor_path) and backend.remove_file(predecessor_path) != OK:
			save_failed.emit("Unable to rotate recovery predecessor")
			return false
		if backend.rename_file(save_path, predecessor_path) != OK:
			save_failed.emit("Unable to preserve previous save")
			return false
	var promotion_error := backend.promote_temporary(temporary_path, save_path)
	if promotion_error != OK:
		if backend.file_exists(predecessor_path):
			backend.rename_file(predecessor_path, save_path)
		save_failed.emit("Unable to finalize save")
		return false
	return true


func load_data() -> Dictionary:
	last_corrupt_backup_path = ""
	var predecessor_path := save_path + ".previous"
	if not backend.file_exists(save_path) and backend.file_exists(predecessor_path):
		if backend.rename_file(predecessor_path, save_path) != OK:
			save_failed.emit("Unable to recover previous save")
	if not backend.file_exists(save_path):
		var defaults := default_data()
		save_data(defaults)
		return defaults
	var raw_bytes := backend.read_bytes(save_path)
	var parsed := _decode_valid_data(raw_bytes)
	if parsed.is_empty():
		return _recover_corrupt_save(raw_bytes)
	_writes_blocked_by_recovery = false
	return _migrate(parsed)


func _migrate(source: Dictionary, persist_changes: bool = true) -> Dictionary:
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
	if persist_changes and migrated != source:
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


func _recover_corrupt_save(raw_bytes: PackedByteArray) -> Dictionary:
	var backup_path := _unique_corrupt_backup_path()
	if not backend.write_bytes_flush(backup_path, raw_bytes) or backend.read_bytes(backup_path) != raw_bytes:
		_writes_blocked_by_recovery = true
		save_failed.emit("Unable to preserve corrupt save evidence")
		return default_data()
	last_corrupt_backup_path = backup_path
	var predecessor_path := save_path + ".previous"
	var recovered := default_data()
	if backend.file_exists(predecessor_path):
		var predecessor_data := _decode_valid_data(backend.read_bytes(predecessor_path))
		if not predecessor_data.is_empty():
			recovered = _migrate(predecessor_data, false)
	var recovered_bytes := JSON.stringify(_normalize(recovered)).to_utf8_buffer()
	if not _replace_primary_without_rotation(recovered_bytes, raw_bytes):
		_writes_blocked_by_recovery = true
		return recovered
	_writes_blocked_by_recovery = false
	save_recovered.emit(backup_path)
	return recovered


func _replace_primary_without_rotation(replacement: PackedByteArray, original: PackedByteArray) -> bool:
	var temporary_path := save_path + ".tmp"
	if not backend.write_bytes_flush(temporary_path, replacement) or backend.read_bytes(temporary_path) != replacement:
		save_failed.emit("Unable to stage recovered save")
		return false
	if backend.file_exists(save_path) and backend.remove_file(save_path) != OK:
		backend.remove_file(temporary_path)
		save_failed.emit("Unable to replace corrupt primary save")
		return false
	if backend.promote_temporary(temporary_path, save_path) == OK:
		return true
	backend.remove_file(temporary_path)
	var restored := backend.write_bytes_flush(save_path, original) and backend.read_bytes(save_path) == original
	if not restored:
		save_failed.emit("Unable to restore corrupt primary after recovery failure")
		return false
	save_failed.emit("Unable to finalize recovered save")
	return false


func _decode_valid_data(raw_bytes: PackedByteArray) -> Dictionary:
	if raw_bytes.is_empty() or not _is_valid_utf8(raw_bytes):
		return {}
	var parser := JSON.new()
	if parser.parse(raw_bytes.get_string_from_utf8()) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or not _is_valid_schema(parsed as Dictionary):
		return {}
	return parsed as Dictionary


func _unique_corrupt_backup_path() -> String:
	_backup_sequence += 1
	var candidate := "%s.corrupt.%d.%d.bak" % [save_path, Time.get_ticks_usec(), _backup_sequence]
	while backend.file_exists(candidate):
		_backup_sequence += 1
		candidate = "%s.corrupt.%d.%d.bak" % [save_path, Time.get_ticks_usec(), _backup_sequence]
	return candidate


func _is_valid_schema(data: Dictionary) -> bool:
	if not _is_integer_number(data.get("version")):
		return false
	var version := int(data.version)
	if version == 1:
		if not _is_integer_number(data.get("best_room", 0)) or not _is_integer_number(data.get("wins", 0)):
			return false
		return not data.has("active_run") or (data.active_run is Dictionary and _is_valid_active_run(data.active_run))
	if version != CURRENT_VERSION:
		return false
	if not data.get("progress") is Dictionary or not data.get("settings") is Dictionary or not data.get("active_run") is Dictionary:
		return false
	var progress: Dictionary = data.progress
	if not _is_integer_number(progress.get("best_room")) or not _is_integer_number(progress.get("wins")):
		return false
	var settings: Dictionary = data.settings
	if not _is_number(settings.get("music_volume")) or not _is_number(settings.get("sfx_volume")):
		return false
	var active_run: Dictionary = data.active_run
	return _is_valid_active_run(active_run)


func _is_valid_active_run(active_run: Dictionary) -> bool:
	if active_run.is_empty():
		return true
	if not _is_integer_number(active_run.get("seed")) or not _is_integer_number(active_run.get("room_index")):
		return false
	if not active_run.get("upgrade_stacks") is Dictionary:
		return false
	for id: Variant in active_run.upgrade_stacks:
		if not id is String or not _is_integer_number(active_run.upgrade_stacks[id]) or int(active_run.upgrade_stacks[id]) < 0:
			return false
	if active_run.has("state") and not _is_integer_number(active_run.state):
		return false
	if active_run.has("reward_choices"):
		if not active_run.reward_choices is Array:
			return false
		for id: Variant in active_run.reward_choices:
			if not id is String:
				return false
	if active_run.has("room_entry_health") and not _is_integer_number(active_run.room_entry_health):
		return false
	return true


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _is_integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, roundf(value)))


func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var index := 0
	while index < bytes.size():
		var first := int(bytes[index])
		var continuation_count := 0
		if first <= 0x7f:
			index += 1
			continue
		elif first >= 0xc2 and first <= 0xdf:
			continuation_count = 1
		elif first >= 0xe0 and first <= 0xef:
			continuation_count = 2
		elif first >= 0xf0 and first <= 0xf4:
			continuation_count = 3
		else:
			return false
		if index + continuation_count >= bytes.size():
			return false
		var second := int(bytes[index + 1])
		if first == 0xe0 and second < 0xa0:
			return false
		if first == 0xed and second > 0x9f:
			return false
		if first == 0xf0 and second < 0x90:
			return false
		if first == 0xf4 and second > 0x8f:
			return false
		for continuation_index: int in range(1, continuation_count + 1):
			var continuation := int(bytes[index + continuation_index])
			if continuation < 0x80 or continuation > 0xbf:
				return false
		index += continuation_count + 1
	return true
