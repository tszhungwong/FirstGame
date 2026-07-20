extends GutTest

const AUDIO_SERVICE_SCRIPT = preload("res://services/audio_service.gd")


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

	service.stop_all()

	assert_false((service.get_node("SFXPlayer") as AudioStreamPlayer).playing)
	assert_null((service.get_node("SFXPlayer") as AudioStreamPlayer).stream)
