extends GutTest

const ORIENTATION_SETTING := "window/handheld/orientation"
const VERSION_VALIDATOR = preload("res://tools/validate_godot_version.gd")


func test_project_file_explicitly_forces_landscape_orientation() -> void:
	var project_config := ConfigFile.new()

	assert_eq(project_config.load("res://project.godot"), OK)
	assert_eq(
		project_config.get_value("display", ORIENTATION_SETTING, -1),
		DisplayServer.SCREEN_LANDSCAPE
	)
	assert_true(VERSION_VALIDATOR.is_landscape_forced())


func test_running_engine_matches_the_committed_version_pin() -> void:
	assert_true(VERSION_VALIDATOR.is_current_engine_pinned())


func test_version_validator_rejects_a_mismatched_engine_version() -> void:
	assert_false(VERSION_VALIDATOR.versions_match("4.6.2", "4.6.3"))
