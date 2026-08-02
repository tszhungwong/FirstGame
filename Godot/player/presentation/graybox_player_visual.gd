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

@export_range(0.0, 24.0, 0.5) var hurt_recoil_distance := 8.0
@export_range(0.0, 12.0, 0.5) var hurt_lift_distance := 3.0
@export_range(0.0, 0.25, 0.01) var hurt_tilt_radians := 0.08
@export_range(0.01, 0.2, 0.01) var hurt_impact_duration := 0.06
@export_range(0.01, 0.4, 0.01) var hurt_recovery_duration := 0.16
@export var hurt_flash_color := Color(1.0, 0.7, 0.7, 1.0)

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
var _is_hurt := false
var _facing_direction := 1.0
var _state_initialized := false
var _was_grounded := false
var _attack_animation_active := false
var _landing_animation_active := false
var _latest_state: PlayerVisualState
var _hurt_tween: Tween
var _sprite_rest_position := Vector2.ZERO
var _sprite_rest_rotation := 0.0
var _sprite_rest_modulate := Color.WHITE


func _ready() -> void:
	_sprite_rest_position = animated_sprite.position
	_sprite_rest_rotation = animated_sprite.rotation
	_sprite_rest_modulate = animated_sprite.modulate
	animated_sprite.animation_finished.connect(_on_animation_finished)


func _exit_tree() -> void:
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()


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


func set_hurt(is_hurt: bool) -> void:
	if _is_hurt == is_hurt:
		return
	_is_hurt = is_hurt
	if is_hurt and animated_sprite != null:
		_play_hurt_animation()
	queue_redraw()


func _play_hurt_animation() -> void:
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	_reset_hurt_transform()
	var recoil_offset := Vector2(
		-_facing_direction * hurt_recoil_distance,
		-hurt_lift_distance
	)
	var recoil_rotation := _sprite_rest_rotation + _facing_direction * hurt_tilt_radians
	_hurt_tween = create_tween()
	_hurt_tween.set_trans(Tween.TRANS_QUAD)
	_hurt_tween.set_ease(Tween.EASE_OUT)
	_hurt_tween.tween_property(
		animated_sprite,
		"position",
		_sprite_rest_position + recoil_offset,
		hurt_impact_duration
	)
	_hurt_tween.parallel().tween_property(
		animated_sprite,
		"rotation",
		recoil_rotation,
		hurt_impact_duration
	)
	_hurt_tween.parallel().tween_property(
		animated_sprite,
		"modulate",
		hurt_flash_color,
		hurt_impact_duration
	)
	_hurt_tween.set_trans(Tween.TRANS_BACK)
	_hurt_tween.set_ease(Tween.EASE_OUT)
	_hurt_tween.tween_property(
		animated_sprite,
		"position",
		_sprite_rest_position,
		hurt_recovery_duration
	)
	_hurt_tween.parallel().tween_property(
		animated_sprite,
		"rotation",
		_sprite_rest_rotation,
		hurt_recovery_duration
	)
	_hurt_tween.parallel().tween_property(
		animated_sprite,
		"modulate",
		_sprite_rest_modulate,
		hurt_recovery_duration
	)
	_hurt_tween.finished.connect(_reset_hurt_transform)


func _reset_hurt_transform() -> void:
	if animated_sprite == null:
		return
	animated_sprite.position = _sprite_rest_position
	animated_sprite.rotation = _sprite_rest_rotation
	animated_sprite.modulate = _sprite_rest_modulate


func show_attack(
	direction: Vector2,
	_size: Vector2,
	_reach: float,
	_color: Color,
	_duration: float,
	animation_name: StringName
) -> void:
	if animation_name == ATTACK_SIDE_ANIMATION:
		_attack_animation_active = true
		_landing_animation_active = false
		if not is_zero_approx(direction.x):
			animated_sprite.flip_h = direction.x < 0.0
		animated_sprite.play(ATTACK_SIDE_ANIMATION)
		animated_sprite.set_frame_and_progress(0, 0.0)


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
