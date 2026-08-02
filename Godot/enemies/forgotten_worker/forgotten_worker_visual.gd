class_name ForgottenWorkerVisual
extends Node2D

signal attack_active_frame_reached
signal attack_finished
signal death_hurtbox_off_frame_reached
signal death_finished
signal footstep_frame_reached

const PATROL_ANIMATION: StringName = &"patrol_left"
const JUMP_ANIMATION: StringName = &"jump_left"
const ATTACK_ANIMATION: StringName = &"attack_left"
const DEATH_ANIMATION: StringName = &"death_left"
const ATTACK_ACTIVE_FRAME := 5
const ATTACK_ACTIVE_OFF_FRAME := 6
const DEATH_HURTBOX_OFF_FRAME := 7
const FOOTSTEP_FRAMES: Array[int] = [1, 5]

@export_range(0.0, 128.0, 0.5) var motion_threshold := 4.0

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D

var _facing_direction := -1.0
var _is_attacking := false
var _is_dying := false
var _attack_was_emitted := false
var _death_hurtbox_off_was_emitted := false


func _ready() -> void:
	assert(animated_sprite != null, "ForgottenWorkerVisual requires AnimatedSprite2D")
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_show_grounded_idle(true)


func sync_motion(
	motion_velocity: Vector2,
	is_grounded: bool,
	facing_hint: float = 0.0
) -> void:
	if _is_attacking or _is_dying:
		return
	_update_facing(motion_velocity.x if absf(motion_velocity.x) >= motion_threshold else facing_hint)
	if not is_grounded:
		_play_animation(JUMP_ANIMATION)
	elif absf(motion_velocity.x) >= motion_threshold:
		_play_animation(PATROL_ANIMATION)
	else:
		_show_grounded_idle()


func play_attack(facing_direction: float) -> bool:
	if _is_attacking or _is_dying:
		return false
	_update_facing(facing_direction)
	_is_attacking = true
	_attack_was_emitted = false
	_play_animation(ATTACK_ANIMATION, true)
	return true


func play_death(facing_direction: float) -> void:
	_update_facing(facing_direction)
	_is_attacking = false
	_is_dying = true
	_attack_was_emitted = false
	_death_hurtbox_off_was_emitted = false
	_play_animation(DEATH_ANIMATION, true)


func reset_visual(facing_direction: float = -1.0) -> void:
	_is_attacking = false
	_is_dying = false
	_attack_was_emitted = false
	_death_hurtbox_off_was_emitted = false
	_update_facing(facing_direction)
	_show_grounded_idle(true)


func is_attacking() -> bool:
	return _is_attacking


func is_dying() -> bool:
	return _is_dying


func _update_facing(horizontal_direction: float) -> void:
	if is_zero_approx(horizontal_direction):
		return
	_facing_direction = signf(horizontal_direction)
	# Source artwork faces left, so right-facing movement uses a horizontal mirror.
	animated_sprite.flip_h = _facing_direction > 0.0


func _show_grounded_idle(restart := false) -> void:
	if restart or animated_sprite.animation != PATROL_ANIMATION:
		_play_animation(PATROL_ANIMATION, true)
	animated_sprite.pause()
	animated_sprite.set_frame_and_progress(0, 0.0)


func _play_animation(animation_name: StringName, restart := false) -> void:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		push_warning("ForgottenWorkerVisual animation '%s' is missing" % animation_name)
		return
	if not restart and animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return
	animated_sprite.play(animation_name)
	animated_sprite.set_frame_and_progress(0, 0.0)


func _on_frame_changed() -> void:
	if animated_sprite.animation == PATROL_ANIMATION and animated_sprite.frame in FOOTSTEP_FRAMES:
		footstep_frame_reached.emit()
	elif animated_sprite.animation == ATTACK_ANIMATION:
		if animated_sprite.frame == ATTACK_ACTIVE_FRAME and not _attack_was_emitted:
			_attack_was_emitted = true
			attack_active_frame_reached.emit()
		elif animated_sprite.frame == ATTACK_ACTIVE_OFF_FRAME:
			# The hit is instantaneous today; retaining this boundary keeps the
			# animation contract ready for a persistent Area2D hitbox later.
			pass
	elif (
		animated_sprite.animation == DEATH_ANIMATION
		and animated_sprite.frame == DEATH_HURTBOX_OFF_FRAME
		and not _death_hurtbox_off_was_emitted
	):
		_death_hurtbox_off_was_emitted = true
		death_hurtbox_off_frame_reached.emit()


func _on_animation_finished() -> void:
	if animated_sprite.animation == ATTACK_ANIMATION and _is_attacking:
		_is_attacking = false
		attack_finished.emit()
	elif animated_sprite.animation == DEATH_ANIMATION and _is_dying:
		death_finished.emit()
