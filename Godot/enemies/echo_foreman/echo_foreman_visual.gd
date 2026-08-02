class_name EchoForemanVisual
extends Node2D

signal attack_active_frame_reached
signal attack_finished
signal heavy_step_frame_reached

const IDLE_ANIMATION: StringName = &"idle"
const WALK_ANIMATION: StringName = &"walk"
const ATTACK_ANIMATION: StringName = &"cut_arm_attack"
const ATTACK_ACTIVE_FRAME := 6
const HEAVY_STEP_FRAMES: Array[int] = [2, 7]

@export_range(0.0, 128.0, 0.5) var motion_threshold := 4.0

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D

var _facing_direction := 1.0
var _is_attacking := false
var _attack_was_emitted := false


func _ready() -> void:
	assert(animated_sprite != null, "EchoForemanVisual requires AnimatedSprite2D")
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(IDLE_ANIMATION, true)


func sync_motion(
	motion_velocity: Vector2,
	facing_hint: float = 0.0,
	playback_scale: float = 1.0
) -> void:
	if _is_attacking:
		return
	_update_facing(
		motion_velocity.x if absf(motion_velocity.x) >= motion_threshold else facing_hint
	)
	animated_sprite.speed_scale = maxf(playback_scale, 0.01)
	_play_animation(
		WALK_ANIMATION if absf(motion_velocity.x) >= motion_threshold else IDLE_ANIMATION
	)


func play_attack(facing_direction: float) -> bool:
	if _is_attacking:
		return false
	_update_facing(facing_direction)
	_is_attacking = true
	_attack_was_emitted = false
	animated_sprite.speed_scale = 1.0
	_play_animation(ATTACK_ANIMATION, true)
	return true


func reset_visual(facing_direction: float = 1.0) -> void:
	_is_attacking = false
	_attack_was_emitted = false
	_update_facing(facing_direction)
	animated_sprite.speed_scale = 1.0
	_play_animation(IDLE_ANIMATION, true)


func is_attacking() -> bool:
	return _is_attacking


func _update_facing(horizontal_direction: float) -> void:
	if is_zero_approx(horizontal_direction):
		return
	_facing_direction = signf(horizontal_direction)
	# Source artwork faces right; mirror it only when the boss faces left.
	animated_sprite.flip_h = _facing_direction < 0.0


func _play_animation(animation_name: StringName, restart := false) -> void:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		push_warning("EchoForemanVisual animation '%s' is missing" % animation_name)
		return
	if not restart and animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return
	animated_sprite.play(animation_name)
	animated_sprite.set_frame_and_progress(0, 0.0)


func _on_frame_changed() -> void:
	if (
		animated_sprite.animation == WALK_ANIMATION
		and animated_sprite.frame in HEAVY_STEP_FRAMES
	):
		heavy_step_frame_reached.emit()
	elif (
		animated_sprite.animation == ATTACK_ANIMATION
		and animated_sprite.frame == ATTACK_ACTIVE_FRAME
		and not _attack_was_emitted
	):
		_attack_was_emitted = true
		attack_active_frame_reached.emit()


func _on_animation_finished() -> void:
	if animated_sprite.animation != ATTACK_ANIMATION or not _is_attacking:
		return
	_is_attacking = false
	attack_finished.emit()
