class_name PlayerCombat
extends Node

const CombatantBodyType := preload("res://combat/combatant_body_2d.gd")
const DamageRequestType := preload("res://combat/damage_request.gd")
const CombatOutcomeType := preload("res://player/combat/combat_outcome.gd")
const BASIC_SIDE_ANIMATION: StringName = &"attack_side"

signal attack_visual_requested(
	direction: Vector2,
	size: Vector2,
	reach: float,
	color: Color,
	duration: float,
	animation_name: StringName
)
signal hit_confirmed(duration: float)

var _tuning: PlayerTuning


func configure(tuning: PlayerTuning) -> void:
	_tuning = tuning


func perform_basic(body: CombatantBodyType, direction: Vector2) -> CombatOutcomeType:
	assert(_tuning != null, "PlayerCombat must be configured before attacking")
	var outcome := _execute(
		body,
		direction,
		_tuning.basic_attack_damage,
		_tuning.basic_attack_size,
		_tuning.basic_attack_reach,
		_tuning.basic_attack_knockback,
		_tuning.basic_attack_color,
		_tuning.basic_attack_visual_duration,
		BASIC_SIDE_ANIMATION if not is_zero_approx(direction.x) else StringName()
	)
	outcome.memory_delta = _tuning.basic_attack_memory_gain if outcome.hit_something else 0
	outcome.movement_lock = _tuning.basic_attack_move_lock
	if outcome.hit_something and direction == Vector2.DOWN and not body.is_on_floor():
		outcome.vertical_velocity = _tuning.downward_attack_rebound_velocity
	return outcome


func perform_skill(body: CombatantBodyType, direction: Vector2) -> CombatOutcomeType:
	assert(_tuning != null, "PlayerCombat must be configured before attacking")
	var outcome := _execute(
		body,
		direction,
		_tuning.skill_damage,
		_tuning.skill_size,
		_tuning.skill_reach,
		_tuning.skill_knockback,
		_tuning.skill_color,
		_tuning.skill_visual_duration,
		StringName()
	)
	outcome.memory_delta = -_tuning.skill_memory_cost
	outcome.movement_lock = _tuning.skill_move_lock
	if direction == Vector2.UP:
		outcome.vertical_velocity = minf(body.velocity.y, _tuning.upward_skill_velocity)
	elif direction == Vector2.DOWN:
		outcome.vertical_velocity = maxf(body.velocity.y, _tuning.downward_skill_velocity)
	return outcome


func get_skill_memory_cost() -> int:
	return _tuning.skill_memory_cost


func _execute(
	body: CombatantBodyType,
	direction: Vector2,
	damage: int,
	size: Vector2,
	reach: float,
	knockback_strength: float,
	visual_color: Color,
	flash_duration: float,
	animation_name: StringName
) -> CombatOutcomeType:
	var attack_shape := RectangleShape2D.new()
	attack_shape.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.collision_mask = 4
	var rotation := 0.0 if not is_zero_approx(direction.x) else PI * 0.5
	query.transform = Transform2D(rotation, body.global_position + direction * reach)
	var outcome := CombatOutcomeType.new()
	for collision: Dictionary in body.get_world_2d().direct_space_state.intersect_shape(query):
		var target := collision.get("collider") as CombatantBodyType
		if target == null:
			continue
		var request := DamageRequestType.new(
			damage,
			direction * knockback_strength,
			DamageRequestType.DamageType.PHYSICAL,
			body
		)
		outcome.hit_something = target.apply_damage(request) or outcome.hit_something
	attack_visual_requested.emit(
		direction,
		size,
		reach,
		visual_color,
		flash_duration,
		animation_name
	)
	if outcome.hit_something:
		hit_confirmed.emit(_tuning.hit_stop_duration)
	return outcome
