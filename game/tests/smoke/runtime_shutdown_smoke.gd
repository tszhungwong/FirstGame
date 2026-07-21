extends Node


func _ready() -> void:
	GameSession.is_run_active = false
	GameSession.active_run_snapshot = {}
	var game := preload("res://scenes/run_game.tscn").instantiate() as RunGame
	add_child(game)
	await get_tree().create_timer(1.0).timeout
	if not _require(is_instance_valid(game.ember) and game.ember.enemy_count() > 0, "main run scene did not remain active long enough"):
		return
	if not _require(AudioService.play_cue(&"enemy_telegraph"), "AudioService did not start a cue before close"):
		return
	if not _require(AudioService.active_voice_count() > 0, "AudioService did not retain the queued cue before close"):
		return
	var root_window := get_tree().root
	if not _require(is_instance_valid(root_window), "runtime root window is unavailable"):
		return
	if not _require(root_window.close_requested.is_connected(AudioService._on_root_close_requested), "AudioService is not connected to the production close signal"):
		return
	AudioService._on_root_close_requested()
	if not _require(AudioService.active_voice_count() == 0, "AudioService retained active voices during shutdown"):
		return
	if not _require(not AudioService.play_cue(&"dash"), "AudioService accepted a cue after the production close request"):
		return
	game.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	print("RUNTIME_SHUTDOWN_SMOKE_OK: main scene ran, audio shut down deterministically, and the audio server drained")
	get_tree().quit(0)


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	printerr("RUNTIME_SHUTDOWN_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
	return false
