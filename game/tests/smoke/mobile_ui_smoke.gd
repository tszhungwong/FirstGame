extends Node

const VIEWPORT_CASES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(2532, 1170),
	Vector2i(1024, 768),
]


func _ready() -> void:
	GameSession.is_run_active = false
	GameSession.active_run_snapshot = {}
	var game := preload("res://scenes/run_game.tscn").instantiate() as RunGame
	add_child(game)
	await get_tree().process_frame
	var hud := game._room_root.get_node("CombatHud") as CombatHud
	var safe_root := hud.get_node("HudRoot/SafeAreaRoot") as Control
	if not _require(safe_root != null, "combat HUD did not create a safe-area root"):
		return
	for viewport_size: Vector2i in VIEWPORT_CASES:
		var content := SafeAreaLayout.resolve_content_rect(
			Vector2(viewport_size),
			Rect2i(Vector2i.ZERO, viewport_size),
			viewport_size,
			16.0,
		)
		hud.apply_content_rect(content)
		var viewport_bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
		var safe_bounds := Rect2(safe_root.position, safe_root.size)
		if not _require(viewport_bounds.encloses(safe_bounds), "safe-area content escaped %s" % viewport_size):
			return
		for control_name: String in ["VirtualJoystick", "DashButton", "SkillButton", "PerformanceOverlay"]:
			var control := safe_root.get_node(control_name) as Control
			if not _require(Rect2(Vector2.ZERO, safe_root.size).encloses(control.get_rect()), "%s escaped safe area at %s" % [control_name, viewport_size]):
				return

	var notched_content := SafeAreaLayout.resolve_content_rect(
		Vector2(1280.0, 720.0),
		Rect2i(132, 0, 2404, 1080),
		Vector2i(2560, 1080),
		16.0,
	)
	if not _require(notched_content.position.x > 16.0 and notched_content.end.x < 1280.0, "notch insets were not consumed"):
		return
	game.queue_free()
	await get_tree().process_frame
	AudioService.stop_all()
	await get_tree().create_timer(0.4).timeout
	print("MOBILE_UI_SMOKE_OK: 16:9, 19.5:9, 4:3, and synthetic notch layouts remain inside safe bounds")
	get_tree().quit(0)


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	printerr("MOBILE_UI_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
	return false
