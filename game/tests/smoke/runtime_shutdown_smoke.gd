extends Node


func _ready() -> void:
	GameSession.is_run_active = false
	GameSession.active_run_snapshot = {}
	var game := preload("res://scenes/run_game.tscn").instantiate() as RunGame
	add_child(game)
	await get_tree().create_timer(1.0).timeout
	if not _require(is_instance_valid(game.ember) and game.ember.enemy_count() > 0, "main run scene did not remain active long enough"):
		return
	if not _require(AudioService.has_method("begin_shutdown"), "AudioService has no deterministic shutdown lifecycle"):
		return
	AudioService.begin_shutdown()
	if not _require(AudioService.active_voice_count() == 0, "AudioService retained active voices during shutdown"):
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
