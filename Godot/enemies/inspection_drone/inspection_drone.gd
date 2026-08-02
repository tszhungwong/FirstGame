class_name InspectionDrone
extends "res://enemies/common/enemy.gd"

const BOLT_SCENE := preload("res://enemies/projectiles/electric_bolt.tscn")

enum AiState { IDLE, ENGAGED, FIRING }

@export var behavior: InspectionDroneDefinition

@onready var _visual: InspectionDroneVisual = %Visual

var _fire_cooldown := 0.0
var _state := AiState.IDLE
var _pending_bolt_direction := Vector2.RIGHT


func _ready() -> void:
	assert(behavior != null, "InspectionDrone requires behavior tuning")
	super()
	_fire_cooldown = behavior.initial_fire_delay
	_visual.projectile_frame_reached.connect(_on_projectile_frame_reached)
	_visual.fire_finished.connect(_on_fire_finished)


func _physics_process(delta: float) -> void:
	var player: CombatantBody2D = get_target()
	if _state == AiState.FIRING:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			behavior.move_speed * behavior.acceleration_multiplier * delta
		)
		move_and_slide()
		_visual.sync_motion(velocity, _pending_bolt_direction)
		return

	if player == null:
		_state = AiState.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, behavior.move_speed * delta)
		move_and_slide()
		_visual.sync_motion(velocity, Vector2.ZERO)
		return

	var offset := player.global_position - global_position
	if offset.length() > behavior.detection_range:
		_state = AiState.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, behavior.move_speed * delta)
	else:
		_state = AiState.ENGAGED
		var desired_velocity := Vector2.ZERO
		if absf(offset.x) > behavior.preferred_distance:
			desired_velocity.x = signf(offset.x) * behavior.move_speed
		elif absf(offset.x) < behavior.preferred_distance * behavior.retreat_distance_multiplier:
			desired_velocity.x = -signf(offset.x) * behavior.move_speed
		desired_velocity.y = clampf(
			offset.y * behavior.vertical_follow_multiplier,
			-behavior.move_speed,
			behavior.move_speed
		)
		velocity = velocity.move_toward(
			desired_velocity,
			behavior.move_speed * behavior.acceleration_multiplier * delta
		)

		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_begin_fire(offset.normalized())

	move_and_slide()
	_visual.sync_motion(velocity, offset)


func reset_enemy() -> void:
	super()
	_state = AiState.IDLE
	_fire_cooldown = behavior.initial_fire_delay
	_pending_bolt_direction = Vector2.RIGHT
	_visual.cancel_fire()
	_visual.sync_motion(Vector2.ZERO, Vector2.RIGHT)


func _begin_fire(bolt_direction: Vector2) -> void:
	if not _visual.play_fire(bolt_direction):
		return
	_state = AiState.FIRING
	_pending_bolt_direction = bolt_direction


func _fire_bolt(bolt_direction: Vector2) -> void:
	var bolt := BOLT_SCENE.instantiate()
	get_parent().add_child(bolt)
	bolt.global_position = _visual.get_projectile_spawn_position()
	bolt.direction = bolt_direction


func _on_projectile_frame_reached() -> void:
	if _state == AiState.FIRING:
		_fire_bolt(_pending_bolt_direction)


func _on_fire_finished() -> void:
	if _state != AiState.FIRING:
		return
	_state = AiState.ENGAGED if get_target() != null else AiState.IDLE
	_fire_cooldown = behavior.fire_interval
