class_name GrayboxPlayerVisual
extends PlayerVisual

const IDLE_ANIMATION: StringName = &"idle"
const RUN_ANIMATION: StringName = &"run"

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
var _is_hurt := false
var _attack_time_remaining := 0.0
var _attack_direction := Vector2.RIGHT
var _attack_size := Vector2.ZERO
var _attack_reach := 0.0
var _attack_color := Color.TRANSPARENT
var _facing_direction := 1.0


func sync_state(state: PlayerVisualState) -> void:
	_facing_direction = state.facing_direction
	if animated_sprite == null:
		return
	animated_sprite.flip_h = state.facing_direction < 0.0
	var next_animation := (
		RUN_ANIMATION if not is_zero_approx(state.velocity.x) else IDLE_ANIMATION
	)
	if animated_sprite.animation != next_animation or not animated_sprite.is_playing():
		animated_sprite.play(next_animation)


func _process(delta: float) -> void:
	if _attack_time_remaining > 0.0:
		_attack_time_remaining = maxf(_attack_time_remaining - delta, 0.0)
		queue_redraw()


func set_hurt(is_hurt: bool) -> void:
	if _is_hurt == is_hurt:
		return
	_is_hurt = is_hurt
	queue_redraw()


func show_attack(
	direction: Vector2,
	size: Vector2,
	reach: float,
	color: Color,
	duration: float
) -> void:
	_attack_direction = direction
	_attack_size = size
	_attack_reach = reach
	_attack_color = color
	_attack_time_remaining = duration
	queue_redraw()


func _draw() -> void:
	if animated_sprite == null:
		var body_color := Color("ff9f8f") if _is_hurt else Color("d7f4ff")
		draw_rect(Rect2(-14.0, -22.0, 28.0, 44.0), body_color)
		draw_rect(Rect2(-10.0, -17.0, 20.0, 5.0), Color("54d2e8"))
	if _attack_time_remaining <= 0.0:
		return
	var attack_rotation := 0.0 if not is_zero_approx(_attack_direction.x) else PI * 0.5
	var attack_rect := Rect2(-_attack_size * 0.5, _attack_size)
	draw_set_transform(_attack_direction * _attack_reach, attack_rotation)
	draw_rect(attack_rect, _attack_color)
	draw_set_transform(Vector2.ZERO)
