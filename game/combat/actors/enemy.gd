class_name CombatEnemy
extends CharacterBody2D

signal defeated(enemy: CombatEnemy)

enum ChargeState {
	APPROACH,
	TELEGRAPH,
	CHARGE,
}

var definition: EnemyDefinition
var target: Ember
var projectile_pool: ObjectPool
var arena_rect: Rect2
var health: HealthComponent
var forest_rules: ForestRoomRules
var _attack_timer: float = 0.0
var _state: ChargeState = ChargeState.APPROACH
var _state_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO
var _alive: bool = true
var _boss_shot_timer: float = 0.0


func configure(
	enemy_definition: EnemyDefinition,
	player_target: Ember,
	pool: ObjectPool,
	bounds: Rect2,
	rules: ForestRoomRules = null
) -> void:
	definition = enemy_definition
	target = player_target
	projectile_pool = pool
	arena_rect = bounds
	forest_rules = rules


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = definition.collision_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = definition.max_health
	add_child(health)
	health.died.connect(_on_defeated)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _alive or not is_instance_valid(target) or not target.is_alive():
		velocity = Vector2.ZERO
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_boss_shot_timer = maxf(_boss_shot_timer - delta, 0.0)
	match definition.archetype:
		EnemyDefinition.Archetype.MELEE_CHASER:
			_update_melee()
		EnemyDefinition.Archetype.RANGED_SHOOTER:
			_update_ranged()
		EnemyDefinition.Archetype.TELEGRAPHED_CHARGER:
			_update_charger(delta)
		EnemyDefinition.Archetype.BOSS:
			_update_boss(delta)
	var previous_position := global_position
	move_and_slide()
	if forest_rules != null:
		global_position = forest_rules.resolve_actor_position(previous_position, global_position)
	var arena_inset := Vector2.ONE * definition.arena_inset
	global_position = global_position.clamp(arena_rect.position + arena_inset, arena_rect.end - arena_inset)


func get_health_component() -> HealthComponent:
	return health


func is_alive() -> bool:
	return _alive


func is_telegraphing() -> bool:
	return _state == ChargeState.TELEGRAPH


func _update_melee() -> void:
	var distance: float = _effective_target_distance()
	velocity = global_position.direction_to(target.global_position) * definition.move_speed
	if distance <= definition.attack_range + definition.contact_range_padding and _attack_timer <= 0.0:
		_damage_target(definition.contact_damage)
		_attack_timer = definition.attack_cooldown


func _update_ranged() -> void:
	var to_target: Vector2 = global_position.direction_to(target.global_position)
	var distance: float = _effective_target_distance()
	if distance > definition.attack_range * definition.ranged_approach_ratio:
		velocity = to_target * definition.move_speed
	elif distance < definition.attack_range * definition.ranged_retreat_ratio:
		velocity = -to_target * definition.move_speed
	else:
		velocity = Vector2.ZERO
	if distance <= definition.attack_range and _attack_timer <= 0.0:
		_fire_projectile(to_target)
		_attack_timer = definition.attack_cooldown


func _update_charger(delta: float) -> void:
	var distance: float = _effective_target_distance()
	match _state:
		ChargeState.APPROACH:
			velocity = global_position.direction_to(target.global_position) * definition.move_speed
			if distance <= definition.attack_range and _attack_timer <= 0.0:
				_state = ChargeState.TELEGRAPH
				_state_timer = definition.telegraph_duration
				_charge_direction = global_position.direction_to(target.global_position)
				velocity = Vector2.ZERO
				queue_redraw()
		ChargeState.TELEGRAPH:
			velocity = Vector2.ZERO
			_state_timer = maxf(_state_timer - delta, 0.0)
			if _state_timer <= 0.0:
				_state = ChargeState.CHARGE
				_state_timer = definition.charge_duration
				queue_redraw()
		ChargeState.CHARGE:
			velocity = _charge_direction * definition.charge_speed
			if distance <= definition.charge_hit_range and _attack_timer <= 0.0:
				_damage_target(definition.contact_damage)
				_attack_timer = definition.attack_cooldown
			_state_timer = maxf(_state_timer - delta, 0.0)
			if _state_timer <= 0.0:
				_state = ChargeState.APPROACH
				_attack_timer = definition.attack_cooldown


func _update_boss(delta: float) -> void:
	if _state == ChargeState.APPROACH and _boss_shot_timer <= 0.0:
		_fire_projectile(global_position.direction_to(target.global_position))
		_boss_shot_timer = definition.attack_cooldown
	_update_charger(delta)


func _effective_target_distance() -> float:
	var distance := global_position.distance_to(target.global_position)
	if forest_rules != null and forest_rules.is_concealed(target.global_position):
		return distance / 0.55
	return distance


func _fire_projectile(direction: Vector2) -> void:
	var bullet: PooledBullet = projectile_pool.acquire()
	if bullet == null:
		return
	bullet.initialize(
		global_position + direction * definition.projectile_spawn_offset,
		direction,
		definition.projectile_speed,
		definition.projectile_lifetime,
		definition.contact_damage,
		definition.projectile_collision_radius,
		false,
	)


func _damage_target(amount: int) -> void:
	var target_health: HealthComponent = target.get_health_component()
	if target_health != null:
		target_health.take_damage(amount)


func _on_defeated() -> void:
	_alive = false
	remove_from_group("enemies")
	defeated.emit(self)
	queue_free()


func _draw() -> void:
	match definition.archetype:
		EnemyDefinition.Archetype.MELEE_CHASER:
			draw_circle(Vector2.ZERO, 20.0, Color("e46b5d"))
			draw_circle(Vector2.ZERO, 11.0, Color("612d34"))
		EnemyDefinition.Archetype.RANGED_SHOOTER:
			var points := PackedVector2Array([Vector2(0.0, -23.0), Vector2(21.0, 15.0), Vector2(-21.0, 15.0)])
			draw_colored_polygon(points, Color("b58ae8"))
			draw_circle(Vector2.ZERO, 7.0, Color("402a5d"))
		EnemyDefinition.Archetype.TELEGRAPHED_CHARGER:
			draw_rect(Rect2(Vector2(-23.0, -23.0), Vector2(46.0, 46.0)), Color("f0a64a"))
			draw_rect(Rect2(Vector2(-13.0, -13.0), Vector2(26.0, 26.0)), Color("754627"))
			if _state == ChargeState.TELEGRAPH:
				draw_line(Vector2.ZERO, _charge_direction * definition.attack_range, Color(1.0, 0.35, 0.22, 0.75), 6.0)
				draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, Color("ff5d42"), 5.0)
		EnemyDefinition.Archetype.BOSS:
			draw_circle(Vector2.ZERO, 48.0, Color("7d3f65"))
			draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 40, Color("f6c85f"), 7.0)
			if _state == ChargeState.TELEGRAPH:
				draw_line(Vector2.ZERO, _charge_direction * definition.attack_range, Color(1.0, 0.22, 0.12, 0.9), 10.0)
