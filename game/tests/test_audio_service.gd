extends GutTest

const AUDIO_SERVICE_SCRIPT = preload("res://services/audio_service.gd")
const AUDIO_TUNING_PATH := "res://data/mock_audio_tuning.tres"
const AUDIO_TUNING_SCHEMA_SCRIPT = preload("res://data/audio_tuning_definition.gd")


func test_procedural_cues_are_cached_and_routable_without_external_files() -> void:
	var service = add_child_autofree(AUDIO_SERVICE_SCRIPT.new())
	service._ready()

	assert_true(service.has_cue(&"ember_shot"))
	assert_true(service.has_cue(&"dash"))
	assert_true(service.has_cue(&"enemy_telegraph"))
	assert_true(service.cue_duration_seconds(&"ember_shot") > 0.0)
	assert_true(service.play_cue(&"ember_shot"))
	assert_false(service.play_cue(&"missing"))


func test_master_volume_is_clamped_and_mute_state_is_applied() -> void:
	var service = add_child_autofree(AUDIO_SERVICE_SCRIPT.new())
	service._ready()

	service.set_master_volume_linear(2.0)
	assert_eq(service.master_volume_linear(), 1.0)
	service.set_master_volume_linear(-1.0)
	assert_eq(service.master_volume_linear(), 0.0)
	service.set_muted(true)
	assert_true(service.is_muted())
	service.set_muted(false)
	assert_false(service.is_muted())


func test_stop_all_releases_active_procedural_playback() -> void:
	var service = add_child_autofree(AUDIO_SERVICE_SCRIPT.new())
	service._ready()
	assert_true(service.play_cue(&"ember_burst"))
	assert_true(service.play_cue(&"dash"))

	service.stop_all()

	assert_eq(service.active_cue_count(&"ember_burst"), 0)
	assert_eq(service.active_cue_count(&"dash"), 0)
	assert_false(service.is_telegraph_playing())


func test_sfx_voices_overlap_without_interrupting_priority_telegraph() -> void:
	var service = add_child_autofree(AUDIO_SERVICE_SCRIPT.new())
	service._ready()

	assert_true(service.play_cue(&"ember_shot"))
	assert_true(service.play_cue(&"dash"))
	assert_eq(service.active_cue_count(&"ember_shot"), 1)
	assert_eq(service.active_cue_count(&"dash"), 1)
	assert_true(service.play_cue(&"enemy_telegraph"))
	for _index: int in 12:
		assert_true(service.play_cue(&"ember_shot"))

	assert_true(service.is_telegraph_playing())
	assert_eq(service.active_cue_count(&"enemy_telegraph"), 1)


func test_begin_shutdown_stops_audio_and_rejects_new_cues() -> void:
	var service = add_child_autofree(AUDIO_SERVICE_SCRIPT.new())
	service._ready()
	assert_true(service.play_cue(&"ember_shot"))
	assert_true(service.play_cue(&"enemy_telegraph"))

	service.begin_shutdown()

	assert_eq(service.active_voice_count(), 0)
	assert_false(service.play_cue(&"dash"))


func test_runtime_close_request_triggers_the_production_shutdown_lifecycle() -> void:
	var service = add_child_autofree(AUDIO_SERVICE_SCRIPT.new())
	service._ready()
	assert_true(service.play_cue(&"ember_shot"))
	assert_true(service.play_cue(&"enemy_telegraph"))

	assert_true(get_tree().root.close_requested.is_connected(service._on_root_close_requested))
	service._on_root_close_requested()

	assert_eq(service.active_voice_count(), 0)
	assert_false(service.play_cue(&"dash"))


func test_audio_tuning_is_loaded_from_the_typed_resource_data() -> void:
	var service = add_child_autofree(AUDIO_SERVICE_SCRIPT.new())
	service._ready()
	var tuning := service.get("audio_tuning") as Resource

	assert_true(ResourceLoader.exists(AUDIO_TUNING_PATH))
	assert_not_null(tuning)
	if tuning == null:
		return
	assert_eq(tuning.get("sample_rate"), 22050)
	assert_eq(tuning.get("sfx_voice_count"), 6)
	assert_eq(tuning.get("telegraph_bus"), &"SFX")
	assert_eq(tuning.get("telegraph_gain_db"), 2.0)
	assert_eq(tuning.get("cue_definitions").size(), 7)


func test_audio_tuning_schema_uses_neutral_defaults() -> void:
	var schema := AUDIO_TUNING_SCHEMA_SCRIPT.new() as Resource

	assert_eq(schema.get("sample_rate"), 0)
	assert_eq(schema.get("sfx_voice_count"), 0)
	assert_eq(schema.get("sfx_bus"), &"")
	assert_eq(schema.get("telegraph_bus"), &"")
	assert_eq(schema.get("ui_bus"), &"")
	assert_eq(schema.get("telegraph_gain_db"), 0.0)
