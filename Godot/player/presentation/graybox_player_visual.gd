class_name GrayboxPlayerVisual
extends PlayerVisual

const IDLE_ANIMATION: StringName = &"idle"
const RUN_ANIMATION: StringName = &"run"
const JUMP_START_ANIMATION: StringName = &"jump_start"
const JUMP_RISE_ANIMATION: StringName = &"jump_rise"
const JUMP_APEX_ANIMATION: StringName = &"jump_apex"
const FALL_ANIMATION: StringName = &"fall"
const LAND_ANIMATION: StringName = &"land"
const ATTACK_SIDE_ANIMATION: StringName = &"attack_side"
const APEX_ENTER_SPEED := 110.0
const FALL_ENTER_SPEED := 70.0

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
var _is_hurt := false
var _attack_time_remaining := 0.0
var _attack_direction := Vector2.RIGHT
var _attack_size := Vector2.ZERO
var _attack_reach := 0.0
var _attack_color := Color.TRANSPARENT
var _facing_direction := 1.0
var _state_initialized := false
var _was_grounded := false
var _attack_animation_active := false
var _landing_animation_active := false
var _latest_state: PlayerVisualState


func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)


func sync_state(state: PlayerVisualState) -> void:
	_facing_direction = state.facing_direction
	_latest_state = state
	if animated_sprite == null:
		return
	animated_sprite.flip_h = state.facing_direction < 0.0
	if not _state_initialized:
		_state_initialized = true
		_was_grounded = state.is_grounded
		_sync_locomotion(state, false, false)
		return

	var just_landed := state.is_grounded and not _was_grounded
	var just_left_ground := not state.is_grounded and _was_grounded
	_was_grounded = state.is_grounded
	if _attack_animation_active:
		return
	_sync_locomotion(state, just_left_ground, just_landed)


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
	duration: float,
	animation_name: StringName
) -> void:
	_attack_direction = direction
	_attack_size = size
	_attack_reach = reach
	_attack_color = color
	_attack_time_remaining = duration
	if animation_name == ATTACK_SIDE_ANIMATION:
		_attack_animation_active = true
		_landing_animation_active = false
		if not is_zero_approx(direction.x):
			animated_sprite.flip_h = direction.x < 0.0
		animated_sprite.play(ATTACK_SIDE_ANIMATION)
		animated_sprite.set_frame_and_progress(0, 0.0)
	queue_redraw()


func _sync_locomotion(
	state: PlayerVisualState,
	just_left_ground: bool,
	just_landed: bool
) -> void:
	if just_landed:
		_landing_animation_active = true
		_play_animation(LAND_ANIMATION)
		return
	if _landing_animation_active:
		return
	if state.is_grounded:
		_play_animation(
			RUN_ANIMATION if not is_zero_approx(state.velocity.x) else IDLE_ANIMATION
		)
		return
	if just_left_ground and state.velocity.y < 0.0:
		_play_animation(JUMP_START_ANIMATION)
		return
	if (
		animated_sprite.animation == JUMP_START_ANIMATION
		and animated_sprite.is_playing()
		and state.velocity.y < FALL_ENTER_SPEED
	):
		return
	if state.velocity.y < -APEX_ENTER_SPEED:
		_play_animation(JUMP_RISE_ANIMATION)
	elif state.velocity.y <= FALL_ENTER_SPEED:
		if animated_sprite.animation != JUMP_APEX_ANIMATION:
			_play_animation(JUMP_APEX_ANIMATION)
	elif animated_sprite.animation != FALL_ANIMATION:
		_play_animation(FALL_ANIMATION)


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return
	animated_sprite.play(animation_name)
	animated_sprite.set_frame_and_progress(0, 0.0)


func _on_animation_finished() -> void:
	if animated_sprite.animation == ATTACK_SIDE_ANIMATION:
		_attack_animation_active = false
	elif animated_sprite.animation == LAND_ANIMATION:
		_landing_animation_active = false
	else:
		return
	if _latest_state != null:
		_sync_locomotion(_latest_state, false, false)


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
