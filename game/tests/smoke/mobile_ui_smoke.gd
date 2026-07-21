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
	hud.apply_content_rect(notched_content)
	game.apply_content_rect(notched_content)
	var interactive_controls: Array[Control] = [
		safe_root.get_node("VirtualJoystick") as Control,
		safe_root.get_node("DashButton") as Control,
		safe_root.get_node("SkillButton") as Control,
		game.get_node("RunUi/PauseButton") as Control,
	]
	for control: Control in interactive_controls:
		if not _require(notched_content.encloses(control.get_global_rect()), "%s escaped the applied notch safe area" % control.name):
			return
		if not _require(control.visible and control.mouse_filter != Control.MOUSE_FILTER_IGNORE, "%s is not usable" % control.name):
			return

	var joystick := safe_root.get_node("VirtualJoystick") as VirtualJoystick
	var ember_start := game.ember.global_position
	var touch := InputEventScreenTouch.new()
	touch.index = 41
	touch.position = joystick.size * 0.5 + Vector2.RIGHT * joystick.radius * 0.75
	touch.pressed = true
	joystick._gui_input(touch)
	for _frame: int in 5:
		await get_tree().physics_frame
	touch.pressed = false
	joystick._gui_input(touch)
	if not _require(game.ember.global_position.x > ember_start.x, "notched joystick did not receive input"):
		return

	var dash_button := safe_root.get_node("DashButton") as Button
	dash_button.pressed.emit()
	await get_tree().process_frame
	if not _require(game.ember.dash.remaining_cooldown > 0.0, "notched dash control did not receive input"):
		return
	var skill_button := safe_root.get_node("SkillButton") as Button
	skill_button.pressed.emit()
	await get_tree().process_frame
	if not _require(game.ember.skill_cooldown_ratio() > 0.0, "notched skill control did not receive input"):
		return

	var pause_button := game.get_node("RunUi/PauseButton") as Button
	pause_button.pressed.emit()
	if not _require(game.controller.state == RunController.State.PAUSED, "notched pause control did not pause"):
		return
	pause_button.pressed.emit()
	if not _require(game.controller.state == RunController.State.COMBAT, "notched pause control did not resume"):
		return

	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if game._room_root.is_ancestor_of(enemy_node):
			(enemy_node as CombatEnemy).health.take_damage(100000)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _require(game.controller.state == RunController.State.REWARD, "room clear did not expose reward controls"):
		return
	game.apply_content_rect(notched_content)
	var reward_panel := game.get_node("RunUi/RewardPanel") as Control
	if not _require(notched_content.encloses(reward_panel.get_global_rect()), "reward panel escaped notch safe area"):
		return
	var reward_buttons: Array[Button] = []
	for child: Node in reward_panel.get_node("Choices").get_children():
		if child is Button:
			reward_buttons.append(child as Button)
	if not _require(reward_buttons.size() == 3, "reward controls are incomplete"):
		return
	for reward_button: Button in reward_buttons:
		if not _require(notched_content.encloses(reward_button.get_global_rect()), "reward choice escaped notch safe area"):
			return
		if not _require(not reward_button.disabled and reward_button.mouse_filter != Control.MOUSE_FILTER_IGNORE, "reward choice is not usable"):
			return
	reward_buttons[0].pressed.emit()
	await get_tree().process_frame
	if not _require(game.controller.state == RunController.State.COMBAT and game.controller.current_room_index == 1, "reward control did not receive input"):
		return

	game._finish_run(false)
	game.apply_content_rect(notched_content)
	var end_panel := game.get_node("RunUi/EndPanel") as Control
	if not _require(end_panel.visible and notched_content.encloses(end_panel.get_global_rect()), "end-state panel escaped notch safe area"):
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
