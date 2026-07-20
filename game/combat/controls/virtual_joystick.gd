class_name VirtualJoystick
extends Control

signal direction_changed(direction: Vector2)

@export var radius: float = 72.0
@export var knob_radius: float = 28.0

var _direction: Vector2 = Vector2.ZERO
var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func movement_vector() -> Vector2:
	return _direction


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_set_from_position(touch.position)
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_set_direction(Vector2.ZERO)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_set_from_position(drag.position)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_set_from_position(mouse_button.position if mouse_button.pressed else size * 0.5)
			if not mouse_button.pressed:
				_set_direction(Vector2.ZERO)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_from_position((event as InputEventMouseMotion).position)


func _set_from_position(local_position: Vector2) -> void:
	var offset: Vector2 = local_position - size * 0.5
	_set_direction(offset.limit_length(radius) / radius)


func _set_direction(value: Vector2) -> void:
	var next_direction: Vector2 = value.limit_length(1.0)
	if _direction.is_equal_approx(next_direction):
		return
	_direction = next_direction
	direction_changed.emit(_direction)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, Color(0.05, 0.09, 0.11, 0.55))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.35, 0.85, 0.78, 0.65), 3.0)
	draw_circle(center + _direction * radius, knob_radius, Color(0.40, 0.94, 0.82, 0.82))
