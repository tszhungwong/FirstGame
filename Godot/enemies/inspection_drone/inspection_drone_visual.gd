class_name InspectionDroneVisual
extends Node2D

signal projectile_frame_reached
signal fire_finished

const HOVER_ANIMATION: StringName = &"hover"
const MOVE_RIGHT_ANIMATION: StringName = &"move_right"
const MOVE_UP_ANIMATION: StringName = &"move_up"
const MOVE_DOWN_ANIMATION: StringName = &"move_down"
const FIRE_ANIMATION: StringName = &"fire"
const FIRE_PROJECTILE_FRAME := 4

@export_range(0.0, 128.0, 0.5) var motion_threshold := 8.0

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var projectile_origin: Marker2D = %ProjectileOrigin

var _facing_direction := 1.0
var _is_firing := false
var _projectile_was_emitted := false
var _projectile_origin_x := 0.0


func _ready() -> void:
	assert(animated_sprite != null, "InspectionDroneVisual requires AnimatedSprite2D")
	assert(projectile_origin != null, "InspectionDroneVisual requires ProjectileOrigin")
	_projectile_origin_x = absf(projectile_origin.position.x)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(HOVER_ANIMATION, true)


func sync_motion(motion_velocity: Vector2, facing_hint: Vector2) -> void:
	if _is_firing:
		return
	_update_motion_facing(motion_velocity, facing_hint)
	_play_animation(resolve_motion_animation(motion_velocity))


func resolve_motion_animation(motion_velocity: Vector2) -> StringName:
	if motion_velocity.length() < motion_threshold:
		return HOVER_ANIMATION
	if absf(motion_velocity.y) > absf(motion_velocity.x):
		return MOVE_UP_ANIMATION if motion_velocity.y < 0.0 else MOVE_DOWN_ANIMATION
	return MOVE_RIGHT_ANIMATION


func play_fire(aim_direction: Vector2) -> bool:
	if _is_firing:
		return false
	_update_facing(aim_direction.x)
	_is_firing = true
	_projectile_was_emitted = false
	_play_animation(FIRE_ANIMATION, true)
	return true


func cancel_fire() -> void:
	_is_firing = false
	_projectile_was_emitted = false
	_play_animation(HOVER_ANIMATION, true)


func is_firing() -> bool:
	return _is_firing


func get_projectile_spawn_position() -> Vector2:
	return projectile_origin.global_position


func _update_motion_facing(motion_velocity: Vector2, facing_hint: Vector2) -> void:
	if absf(motion_velocity.x) >= motion_threshold:
		_update_facing(motion_velocity.x)
	elif absf(facing_hint.x) >= motion_threshold:
		_update_facing(facing_hint.x)


func _update_facing(horizontal_direction: float) -> void:
	if is_zero_approx(horizontal_direction):
		return
	_facing_direction = signf(horizontal_direction)
	animated_sprite.flip_h = _facing_direction < 0.0
	projectile_origin.position.x = _projectile_origin_x * _facing_direction


func _play_animation(animation_name: StringName, restart := false) -> void:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		push_warning("InspectionDroneVisual animation '%s' is missing" % animation_name)
		return
	if not restart and animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return
	animated_sprite.play(animation_name)
	animated_sprite.set_frame_and_progress(0, 0.0)


func _on_frame_changed() -> void:
	if (
		_is_firing
		and not _projectile_was_emitted
		and animated_sprite.animation == FIRE_ANIMATION
		and animated_sprite.frame == FIRE_PROJECTILE_FRAME
	):
		_projectile_was_emitted = true
		projectile_frame_reached.emit()


func _on_animation_finished() -> void:
	if not _is_firing or animated_sprite.animation != FIRE_ANIMATION:
		return
	_is_firing = false
	fire_finished.emit()
