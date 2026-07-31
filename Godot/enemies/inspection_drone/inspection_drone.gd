class_name InspectionDrone
extends "res://enemies/common/enemy.gd"

const BOLT_SCENE := preload("res://enemies/projectiles/electric_bolt.tscn")

enum AiState { IDLE, ENGAGED }

@export var behavior: InspectionDroneDefinition

var _fire_cooldown := 0.8
var _state := AiState.IDLE


func _ready() -> void:
	assert(behavior != null, "InspectionDrone requires behavior tuning")
	super()


func _physics_process(delta: float) -> void:
	var player: CombatantBody2D = get_target()
	if player == null:
		_state = AiState.IDLE
		velocity = Vector2.ZERO
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
			_fire_cooldown = behavior.fire_interval
			_fire_bolt(offset.normalized())

	move_and_slide()


func _fire_bolt(bolt_direction: Vector2) -> void:
	var bolt := BOLT_SCENE.instantiate()
	get_parent().add_child(bolt)
	bolt.global_position = global_position
	bolt.direction = bolt_direction


func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color("77aee8"))
	draw_rect(Rect2(-25.0, -5.0, 50.0, 10.0), Color("334d70"))
	draw_circle(Vector2(0.0, 2.0), 5.0, Color("ffcf5b"))
