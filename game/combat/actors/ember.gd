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
var _targeting: TargetingComponent
var _target_candidates: Array[Node2D] = []
var _fire_timer: float = 0.0
var _skill_cooldown: float = 0.0
var _virtual_move: Vector2 = Vector2.ZERO
var _move_direction: Vector2 = Vector2.ZERO
var _dash_direction: Vector2 = Vector2.RIGHT
var _facing: Vector2 = Vector2.RIGHT
var _alive: bool = true


func configure(
	character_definition: CharacterDefinition,
	pool: ObjectPool,
	bounds: Rect2
) -> void:
	definition = character_definition
	projectile_pool = pool
	arena_rect = bounds


func _ready() -> void:
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

	_targeting = TargetingComponent.new()
	add_child(_targeting)
	dash = DashComponent.new()
	dash.cooldown = definition.dash_cooldown
	dash.duration = definition.dash_duration
	dash.health_component = health
	dash.dash_state_changed.connect(_on_dash_state_changed)
	add_child(dash)

	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = definition.camera_smoothing_speed
	camera.limit_left = int(arena_rect.position.x)
	camera.limit_top = int(arena_rect.position.y)
	camera.limit_right = int(arena_rect.end.x)
	camera.limit_bottom = int(arena_rect.end.y)
	add_child(camera)
	queue_redraw()


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
		queue_redraw()

	if Input.is_action_just_pressed("dash"):
		request_dash()
	if Input.is_action_just_pressed("active_skill"):
		request_active_skill()

	if dash.is_dashing():
		velocity = _dash_direction * definition.move_speed * definition.dash_speed_multiplier
	else:
		velocity = _move_direction * definition.move_speed
	move_and_slide()
	var arena_inset := Vector2.ONE * definition.arena_inset
	global_position = global_position.clamp(arena_rect.position + arena_inset, arena_rect.end - arena_inset)
	_auto_fire()


func set_virtual_move(direction: Vector2) -> void:
	_virtual_move = direction.limit_length(1.0)


func request_dash() -> void:
	if not _alive:
		return
	var requested_direction: Vector2 = _move_direction if _move_direction != Vector2.ZERO else _facing
	if dash.try_start():
		_dash_direction = requested_direction.normalized()


func request_active_skill() -> void:
	if not _alive or _skill_cooldown > 0.0:
		return
	_skill_cooldown = definition.active_skill_cooldown
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
	if definition.dash_cooldown <= 0.0:
		return 0.0
	return dash.remaining_cooldown / definition.dash_cooldown


func skill_cooldown_ratio() -> float:
	if definition.active_skill_cooldown <= 0.0:
		return 0.0
	return _skill_cooldown / definition.active_skill_cooldown


func is_alive() -> bool:
	return _alive


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
	_fire_timer = 1.0 / maxf(definition.starting_weapon.fire_rate, 0.01)


func _shoot(direction: Vector2) -> void:
	var bullet: PooledBullet = projectile_pool.acquire()
	if bullet == null:
		return
	bullet.initialize(
		global_position + direction * definition.projectile_spawn_offset,
		direction,
		definition.starting_weapon.projectile_speed,
		definition.starting_weapon.projectile_lifetime,
		definition.starting_weapon.damage,
		definition.starting_weapon.projectile_collision_radius,
		true,
	)


func _on_health_changed(current: int, maximum: int) -> void:
	health_changed.emit(current, maximum)


func _on_defeated() -> void:
	_alive = false
	defeated.emit()
	queue_redraw()


func _on_dash_state_changed(_is_dashing: bool) -> void:
	queue_redraw()


func _draw() -> void:
	var body_color := Color("68e0d1") if _alive else Color("52636a")
	draw_circle(Vector2.ZERO, 22.0, Color("17333a"))
	draw_circle(Vector2.ZERO, 17.0, body_color)
	draw_circle(Vector2(-6.0, -5.0), 3.0, Color("eafff9"))
	draw_circle(Vector2(6.0, -5.0), 3.0, Color("eafff9"))
	draw_line(Vector2.ZERO, _facing * 31.0, Color("f6c85f"), 6.0)
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 36, Color("f6c85f"), 3.0)
	if health != null and health.invulnerable:
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 40, Color(0.7, 1.0, 0.95, 0.8), 4.0)
