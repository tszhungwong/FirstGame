extends SceneTree

const VERSION_FILE_PATH := "res://godot_version.txt"
const ORIENTATION_SETTING_PATH := "display/window/handheld/orientation"


static func is_current_engine_pinned() -> bool:
	return versions_match(current_engine_version(), pinned_version())


static func is_landscape_forced() -> bool:
	return ProjectSettings.get_setting(ORIENTATION_SETTING_PATH) == DisplayServer.SCREEN_LANDSCAPE


static func versions_match(actual_version: String, expected_version: String) -> bool:
	return actual_version == expected_version


static func current_engine_version() -> String:
	var version_info := Engine.get_version_info()
	return "%d.%d.%d" % [version_info.major, version_info.minor, version_info.patch]


static func pinned_version() -> String:
	return FileAccess.get_file_as_string(VERSION_FILE_PATH).strip_edges()


func _init() -> void:
	var expected_version := pinned_version()
	var actual_version := current_engine_version()

	if not versions_match(actual_version, expected_version):
		printerr("Godot version pin mismatch: expected %s, got %s" % [expected_version, actual_version])
		quit(1)
		return

	if not is_landscape_forced():
		printerr("Landscape orientation is not forced in ProjectSettings")
		quit(1)
		return

	print("Godot version pin and landscape ProjectSettings verified: %s" % actual_version)
	quit(0)
