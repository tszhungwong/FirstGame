class_name Enemy
extends "res://combat/combatant_body_2d.gd"

const VitalsType := preload("res://combat/vitals.gd")
const WORLD_GEOMETRY_MASK := 3

signal health_changed(current: int, maximum: int)
signal defeated

@export var definition: EnemyDefinition

var _initial_health := 30
var max_health: int:
	get: return definition.max_health
var health: int:
	get:
		return _vitals.get_health() if _vitals != null else _initial_health
	set(value):
		_initial_health = value
		if _vitals != null:
			_vitals.set_health(value)
var _spawn_position := Vector2.ZERO
var _spawn_collision_layer := 4
var _vitals: VitalsType
var _target: CombatantBody2D


func _ready() -> void:
	assert(definition != null, "Enemy requires an EnemyDefinition resource")
	_vitals = VitalsType.new(definition.max_health)
	_vitals.health_changed.connect(health_changed.emit)
	_vitals.died.connect(_on_vitals_died)
	health = definition.max_health
	_spawn_position = global_position
	_spawn_collision_layer = collision_layer


func _physics_process(delta: float) -> void:
	_vitals.tick(delta)
	if not is_on_floor():
		velocity.y += definition.gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, definition.horizontal_deceleration * delta)
	move_and_slide()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> bool:
	return apply_damage(DamageRequestType.new(amount, knockback))


func apply_damage(request: DamageRequestType) -> bool:
	if not _vitals.apply_damage(request):
		return false
	velocity = request.knockback
	queue_redraw()
	return true


func reset_enemy() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_vitals.restore_full()
	_set_active(true)


func set_target(target: CombatantBody2D) -> void:
	_target = target


func get_target() -> CombatantBody2D:
	return _target


func has_clear_attack_path(target: CollisionObject2D) -> bool:
	if target == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		target.global_position,
		WORLD_GEOMETRY_MASK,
		[get_rid(), target.get_rid()]
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func restore_defeated() -> void:
	_set_active(false)


func _set_active(active: bool) -> void:
	visible = active
	collision_layer = _spawn_collision_layer if active else 0
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _on_vitals_died() -> void:
	defeated.emit()
	if definition.respawns_on_checkpoint:
		_set_active(false)
	else:
		call_deferred("queue_free")
