class_name CombatHud
extends CanvasLayer

const VIRTUAL_JOYSTICK = preload("res://combat/controls/virtual_joystick.gd")

var ember: CharacterBody2D
var _health_bar: ProgressBar
var _health_label: Label
var _dash_button: Button
var _skill_button: Button
var _enemy_label: Label
var _defeat_panel: ColorRect


func configure(player: CharacterBody2D) -> void:
	ember = player


func _ready() -> void:
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title := Label.new()
	title.text = "EMBER VANGUARD  /  COMBAT CALIBRATION"
	title.add_theme_font_size_override("font_size", 20)
	title.position = Vector2(32.0, 22.0)
	root.add_child(title)

	_health_bar = ProgressBar.new()
	_health_bar.position = Vector2(32.0, 54.0)
	_health_bar.size = Vector2(360.0, 28.0)
	_health_bar.show_percentage = false
	_health_bar.max_value = ember.definition.max_health
	_health_bar.value = ember.definition.max_health
	_health_bar.add_theme_stylebox_override("background", _panel_style(Color(0.03, 0.08, 0.09, 0.82), Color("244b50"), 2))
	_health_bar.add_theme_stylebox_override("fill", _panel_style(Color("45c9aa"), Color("9cf5d5"), 1))
	root.add_child(_health_bar)

	_health_label = Label.new()
	_health_label.position = Vector2(42.0, 57.0)
	_health_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_health_label)

	_enemy_label = Label.new()
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_enemy_label.offset_left = -330.0
	_enemy_label.offset_top = 28.0
	_enemy_label.offset_right = -32.0
	_enemy_label.offset_bottom = 60.0
	_enemy_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_enemy_label)

	var hint := Label.new()
	hint.text = "WASD / ARROWS TO MOVE   •   SPACE DASH   •   E BURST"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 88.0
	hint.offset_bottom = 116.0
	hint.modulate = Color(0.75, 0.88, 0.86, 0.78)
	root.add_child(hint)

	var joystick: Control = VIRTUAL_JOYSTICK.new()
	joystick.name = "VirtualJoystick"
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 28.0
	joystick.offset_top = -206.0
	joystick.offset_right = 206.0
	joystick.offset_bottom = -28.0
	joystick.direction_changed.connect(_on_virtual_move)
	root.add_child(joystick)

	_dash_button = _make_action_button("DASH\nSPACE", Color("318a83"))
	_dash_button.name = "DashButton"
	_dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dash_button.offset_left = -194.0
	_dash_button.offset_top = -178.0
	_dash_button.offset_right = -54.0
	_dash_button.offset_bottom = -38.0
	_dash_button.pressed.connect(ember.call.bind("request_dash"))
	root.add_child(_dash_button)

	_skill_button = _make_action_button("EMBER BURST\nE", Color("9a6330"))
	_skill_button.name = "SkillButton"
	_skill_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skill_button.offset_left = -354.0
	_skill_button.offset_top = -142.0
	_skill_button.offset_right = -224.0
	_skill_button.offset_bottom = -12.0
	_skill_button.pressed.connect(ember.call.bind("request_active_skill"))
	root.add_child(_skill_button)

	_defeat_panel = ColorRect.new()
	_defeat_panel.color = Color(0.04, 0.06, 0.07, 0.84)
	_defeat_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defeat_panel.visible = false
	_defeat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_defeat_panel)
	var defeat_label := Label.new()
	defeat_label.text = "CALIBRATION FAILED\nRELAUNCH TO TRY AGAIN"
	defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	defeat_label.add_theme_font_size_override("font_size", 30)
	defeat_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defeat_panel.add_child(defeat_label)

	ember.defeated.connect(_on_ember_defeated)


func _process(_delta: float) -> void:
	if not is_instance_valid(ember) or ember.health == null:
		return
	_health_bar.value = ember.health.current_health
	_health_label.text = "%d / %d" % [ember.health.current_health, ember.health.max_health]
	_enemy_label.text = "HOSTILES  %02d" % get_tree().get_nodes_in_group("enemies").size()
	var dash_ratio: float = ember.call("dash_cooldown_ratio")
	var skill_ratio: float = ember.call("skill_cooldown_ratio")
	_dash_button.text = "DASH\nREADY" if dash_ratio <= 0.0 else "DASH\n%0.1fs" % ember.dash.remaining_cooldown
	_skill_button.text = "EMBER BURST\nREADY" if skill_ratio <= 0.0 else "EMBER BURST\n%0.1fs" % (skill_ratio * ember.definition.active_skill_cooldown)
	_dash_button.disabled = dash_ratio > 0.0
	_skill_button.disabled = skill_ratio > 0.0


func _make_action_button(label: String, color: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _panel_style(Color(color, 0.84), color.lightened(0.28), 3, 28))
	button.add_theme_stylebox_override("hover", _panel_style(Color(color.lightened(0.1), 0.92), Color.WHITE, 3, 28))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(color.darkened(0.18), 0.95), Color("f6c85f"), 4, 28))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.08, 0.12, 0.13, 0.72), Color(0.3, 0.38, 0.39), 2, 28))
	return button


func _panel_style(color: Color, border: Color, width: int, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _on_ember_defeated() -> void:
	_defeat_panel.visible = true


func _on_virtual_move(direction: Vector2) -> void:
	ember.call("set_virtual_move", direction)
