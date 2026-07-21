class_name Ember
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal defeated
signal enemy_count_changed(count: int)

var definition: CharacterDefinition
var projectile_pool: ObjectPool
var arena_rect: Rect2
var health: HealthComponent
var dash: DashComponent
var combat_stats: RuntimeCombatStats
var forest_rules: ForestRoomRules
var _targeting: TargetingComponent
var _target_candidates: Array[Node2D] = []
var _fire_timer: float = 0.0
var _skill_cooldown: float = 0.0
var _virtual_move: Vector2 = Vector2.ZERO
var _move_direction: Vector2 = Vector2.ZERO
var _dash_direction: Vector2 = Vector2.RIGHT
var _facing: Vector2 = Vector2.RIGHT
var _alive: bool = true
var _last_health: int = -1
var _visual: EmberVisual


func configure(
	character_definition: CharacterDefinition,
	pool: ObjectPool,
	bounds: Rect2,
	runtime_stats: RuntimeCombatStats = null,
	rules: ForestRoomRules = null
) -> void:
	definition = character_definition
	projectile_pool = pool
	arena_rect = bounds
	combat_stats = runtime_stats
	forest_rules = rules


func _ready() -> void:
	if combat_stats == null:
		combat_stats = RuntimeCombatStats.from_definitions(definition)
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2
	var shape := CapsuleShape2D.new()
	shape.radius = definition.collision_radius
	shape.height = definition.collision_height
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = definition.max_health
	add_child(health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_defeated)
	_last_health = health.current_health

	_targeting = TargetingComponent.new()
	add_child(_targeting)
	dash = DashComponent.new()
	dash.cooldown = combat_stats.dash_cooldown
	dash.duration = definition.dash_duration
	dash.health_component = health
	dash.dash_state_changed.connect(_on_dash_state_changed)
	add_child(dash)
	_visual = EmberVisual.new()
	_visual.name = "Visual"
	add_child(_visual)

	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = definition.camera_smoothing_speed
	camera.limit_left = int(arena_rect.position.x)
	camera.limit_top = int(arena_rect.position.y)
	camera.limit_right = int(arena_rect.end.x)
	camera.limit_bottom = int(arena_rect.end.y)
	add_child(camera)
	_refresh_visual()


func _physics_process(delta: float) -> void:
	if not _alive:
		velocity = Vector2.ZERO
		return
	dash.advance(delta)
	_skill_cooldown = maxf(_skill_cooldown - delta, 0.0)
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	_move_direction = _read_move_direction()
	if _move_direction != Vector2.ZERO and not _facing.is_equal_approx(_move_direction):
		_facing = _move_direction
		_refresh_visual()

	if Input.is_action_just_pressed("dash"):
		request_dash()
	if Input.is_action_just_pressed("active_skill"):
		request_active_skill()

	var speed_multiplier := forest_rules.speed_multiplier_at(global_position) if forest_rules != null else 1.0
	if dash.is_dashing():
		velocity = _dash_direction * definition.move_speed * definition.dash_speed_multiplier * speed_multiplier
	else:
		velocity = _move_direction * definition.move_speed * speed_multiplier
	var previous_position := global_position
	move_and_slide()
	if forest_rules != null:
		global_position = forest_rules.resolve_actor_position(previous_position, global_position)
	var arena_inset := Vector2.ONE * definition.arena_inset
	global_position = global_position.clamp(arena_rect.position + arena_inset, arena_rect.end - arena_inset)
	_refresh_visual()
	_auto_fire()


func set_virtual_move(direction: Vector2) -> void:
	_virtual_move = direction.limit_length(1.0)


func request_dash() -> void:
	if not _alive:
		return
	var requested_direction: Vector2 = _move_direction if _move_direction != Vector2.ZERO else _facing
	if dash.try_start():
		_dash_direction = requested_direction.normalized()
		AudioService.play_cue(&"dash")


func request_active_skill() -> void:
	if not _alive or _skill_cooldown > 0.0:
		return
	_skill_cooldown = definition.active_skill_cooldown
	AudioService.play_cue(&"ember_burst")
	var projectile_count: int = maxi(definition.active_skill_projectiles, 1)
	for index: int in projectile_count:
		var angle: float = TAU * float(index) / float(projectile_count)
		_shoot(Vector2.from_angle(angle))


func register_enemy(enemy: CombatEnemy) -> void:
	if not _target_candidates.has(enemy):
		_target_candidates.append(enemy)
		enemy_count_changed.emit(_target_candidates.size())


func unregister_enemy(enemy: CombatEnemy) -> void:
	_target_candidates.erase(enemy)
	enemy_count_changed.emit(_target_candidates.size())


func enemy_count() -> int:
	return _target_candidates.size()


func get_health_component() -> HealthComponent:
	return health


func dash_cooldown_ratio() -> float:
	if combat_stats.dash_cooldown <= 0.0:
		return 0.0
	return dash.remaining_cooldown / combat_stats.dash_cooldown


func skill_cooldown_ratio() -> float:
	if definition.active_skill_cooldown <= 0.0:
		return 0.0
	return _skill_cooldown / definition.active_skill_cooldown


func is_alive() -> bool:
	return _alive


func is_concealed() -> bool:
	return forest_rules != null and forest_rules.is_concealed(global_position)


func apply_upgrade(upgrade: UpgradeDefinition) -> void:
	combat_stats.apply_upgrade(upgrade)
	dash.cooldown = combat_stats.dash_cooldown


func _read_move_direction() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return _virtual_move if _virtual_move.length_squared() > keyboard.length_squared() else keyboard


func _auto_fire() -> void:
	if _fire_timer > 0.0:
		return
	var target: Node2D = _targeting.find_nearest(
		global_position,
		_target_candidates,
		definition.starting_weapon.target_range
	)
	if target == null:
		return
	_shoot(global_position.direction_to(target.global_position))
	_fire_timer = 1.0 / maxf(combat_stats.fire_rate, 0.01)


func _shoot(direction: Vector2) -> void:
	AudioService.play_cue(&"ember_shot")
	var shot_count := maxi(combat_stats.multishot, 1)
	for shot_index: int in shot_count:
		var offset := (
			(float(shot_index) - float(shot_count - 1) * 0.5)
			* definition.starting_weapon.multishot_spread_radians
		)
		var shot_direction := direction.rotated(offset)
		var bullet: PooledBullet = projectile_pool.acquire()
		if bullet == null:
			return
		bullet.initialize(
			global_position + shot_direction * definition.projectile_spawn_offset,
			shot_direction,
			combat_stats.projectile_speed,
			combat_stats.projectile_lifetime,
			combat_stats.damage,
			combat_stats.projectile_collision_radius,
			true,
			{
				"penetration": combat_stats.penetration,
				"ricochet": combat_stats.ricochet,
				"burn_damage": combat_stats.burn_damage,
				"burn_duration": combat_stats.burn_duration,
			},
		)


func _on_health_changed(current: int, maximum: int) -> void:
	if _last_health >= 0 and current < _last_health:
		AudioService.play_cue(&"player_hit")
	_last_health = current
	health_changed.emit(current, maximum)


func _on_defeated() -> void:
	_alive = false
	defeated.emit()
	_refresh_visual()


func _on_dash_state_changed(_is_dashing: bool) -> void:
	_refresh_visual()


func _refresh_visual() -> void:
	if is_instance_valid(_visual):
		_visual.set_state(_facing, _alive, is_concealed(), health != null and health.invulnerable)
