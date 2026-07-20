class_name EmberVisualLayer
extends Node2D

const Palette = preload("res://presentation/game_palette.gd")

enum Kind { RIBBON, BODY, HAIR, WEAPON }

var kind: Kind = Kind.BODY
var facing: Vector2 = Vector2.RIGHT
var alive: bool = true
var concealed: bool = false
var invulnerable: bool = false


func configure(layer_kind: Kind) -> void:
	kind = layer_kind
	queue_redraw()


func set_state(next_facing: Vector2, is_alive: bool, is_concealed: bool, is_invulnerable: bool) -> void:
	var snapped_facing := _cardinal_facing(next_facing)
	if facing == snapped_facing and alive == is_alive and concealed == is_concealed and invulnerable == is_invulnerable:
		return
	facing = snapped_facing
	alive = is_alive
	concealed = is_concealed
	invulnerable = is_invulnerable
	modulate = Color(1.0, 1.0, 1.0, 0.48 if concealed else 1.0)
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.RIBBON:
			_draw_ribbons()
		Kind.BODY:
			_draw_body()
		Kind.HAIR:
			_draw_hair()
		Kind.WEAPON:
			_draw_weapon()


func _draw_ribbons() -> void:
	var side := Vector2(-facing.y, facing.x)
	var back := -facing
	for sign_value: float in [-1.0, 1.0]:
		var origin := back * 8.0 + side * 10.0 * sign_value
		var ribbon := PackedVector2Array([
			origin,
			origin + back * 13.0 + side * 5.0 * sign_value,
			origin + back * 25.0 - side * 3.0 * sign_value,
		])
		draw_polyline(ribbon, Palette.EMBER_RIBBON, 5.0, true)


func _draw_body() -> void:
	var body_color := Palette.EMBER_CLOTH if alive else Color("59666d")
	draw_circle(Vector2(0.0, 5.0), 19.0, Palette.INK)
	draw_circle(Vector2(0.0, 5.0), 15.0, body_color)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-16.0, 3.0), Vector2(16.0, 3.0), Vector2(11.0, 24.0), Vector2(-11.0, 24.0)]),
		body_color.darkened(0.12),
	)
	draw_arc(Vector2(0.0, 4.0), 16.0, 0.12, PI - 0.12, 16, Palette.BRASS, 3.0)
	draw_circle(Vector2.ZERO, 5.0, Palette.JADE_GLOW)
	draw_circle(Vector2.ZERO, 2.0, Palette.JADE_LIGHT)
	if invulnerable:
		draw_arc(Vector2.ZERO, 33.0, 0.0, TAU, 40, Color(Palette.JADE_LIGHT, 0.82), 4.0)


func _draw_hair() -> void:
	var front := facing * 3.0
	draw_circle(Vector2(0.0, -11.0) - front, 14.0, Palette.INK)
	draw_circle(Vector2(0.0, -10.0) - front, 11.0, Palette.EMBER_HAIR if alive else Color("4e505a"))
	var side := Vector2(-facing.y, facing.x)
	draw_line(-facing * 9.0 + side * 8.0, -facing * 18.0 + side * 11.0, Palette.EMBER_HAIR, 7.0, true)
	draw_line(-facing * 9.0 - side * 8.0, -facing * 18.0 - side * 11.0, Palette.EMBER_HAIR, 7.0, true)


func _draw_weapon() -> void:
	var side := Vector2(-facing.y, facing.x)
	var grip := facing * 8.0 + side * 6.0
	var muzzle := facing * 33.0 + side * 6.0
	draw_line(grip, muzzle, Palette.INK, 9.0, true)
	draw_line(grip + facing * 2.0, muzzle - facing * 2.0, Palette.BRASS, 4.0, true)
	draw_circle(muzzle, 4.5, Palette.JADE_GLOW)
	draw_circle(muzzle, 2.0, Palette.JADE_LIGHT)


func _cardinal_facing(value: Vector2) -> Vector2:
	if value == Vector2.ZERO:
		return Vector2.RIGHT
	return Vector2(signf(value.x), 0.0) if absf(value.x) >= absf(value.y) else Vector2(0.0, signf(value.y))
