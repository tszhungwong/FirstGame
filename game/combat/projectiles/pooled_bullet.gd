class_name PooledBullet
extends Area2D

signal returned_to_pool(bullet: PooledBullet, lease_id: int)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var remaining_lifetime: float = 0.0
var from_player: bool = true
var collision_radius: float = 0.0
var penetration_remaining: int = 0
var ricochet_remaining: int = 0
var burn_damage: int = 0
var burn_duration: float = 0.0
var forest_rules: ForestRoomRules
var _active: bool = false
var _damage: DamageComponent
var _collision_shape: CircleShape2D
var _lease_id: int = 0


func _ready() -> void:
	collision_layer = 0
	monitoring = true
	_collision_shape = CircleShape2D.new()
	_collision_shape.radius = 0.001
	var collision := CollisionShape2D.new()
	collision.shape = _collision_shape
	add_child(collision)
	_damage = DamageComponent.new()
	add_child(_damage)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func configure_collision_radius(radius: float) -> void:
	var next_radius: float = maxf(radius, 0.001)
	if is_equal_approx(collision_radius, next_radius):
		return
	collision_radius = next_radius
	_collision_shape.radius = collision_radius
	queue_redraw()


func initialize(
	spawn_position: Vector2,
	travel_direction: Vector2,
	projectile_speed: float,
	lifetime: float,
	damage_amount: int,
	projectile_radius: float,
	is_player_projectile: bool,
	combat_properties: Dictionary = {}
) -> void:
	var team_changed: bool = from_player != is_player_projectile
	global_position = spawn_position
	direction = travel_direction.normalized()
	rotation = direction.angle()
	speed = projectile_speed
	remaining_lifetime = lifetime
	configure_collision_radius(projectile_radius)
	from_player = is_player_projectile
	collision_mask = 2 if from_player else 1
	_damage.amount = damage_amount
	penetration_remaining = int(combat_properties.get("penetration", 0))
	ricochet_remaining = int(combat_properties.get("ricochet", 0))
	burn_damage = int(combat_properties.get("burn_damage", 0))
	burn_duration = float(combat_properties.get("burn_duration", 0.0))
	_active = true
	if team_changed:
		queue_redraw()


func on_spawn(lease_id: int) -> void:
	_lease_id = lease_id
	_active = true


func on_despawn() -> void:
	_active = false
	direction = Vector2.ZERO
	remaining_lifetime = 0.0
	collision_mask = 0
	penetration_remaining = 0
	ricochet_remaining = 0
	burn_damage = 0
	burn_duration = 0.0


func configure_forest_rules(rules: ForestRoomRules) -> void:
	forest_rules = rules


func _physics_process(delta: float) -> void:
	if not _active:
		return
	var previous_position := global_position
	var next_position := global_position + direction * speed * delta
	if forest_rules != null and forest_rules.blocks_projectile_segment(previous_position, next_position):
		if ricochet_remaining > 0:
			ricochet_remaining -= 1
			global_position = forest_rules.projectile_rebound_position(previous_position, next_position)
			direction = -direction
			rotation = direction.angle()
			return
		else:
			_return_to_pool()
			return
	global_position = next_position
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		_return_to_pool()


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	var health := body.get_node_or_null("Health") as HealthComponent
	if health != null:
		_damage.apply_to(health)
		if from_player and burn_damage > 0:
			health.apply_burn(burn_damage, burn_duration)
		if from_player and penetration_remaining > 0:
			penetration_remaining -= 1
			return
	_return_to_pool()


func _return_to_pool() -> void:
	if not _active:
		return
	_active = false
	_emit_returned_to_pool.call_deferred(_lease_id)


func _emit_returned_to_pool(lease_id: int) -> void:
	returned_to_pool.emit(self, lease_id)


func _draw() -> void:
	var color := Color("5ee0bd") if from_player else Color("ff5b45")
	var core := Color("d8fff2") if from_player else Color("ffd064")
	draw_line(Vector2(-18.0, 0.0), Vector2(-4.0, 0.0), Color(color, 0.42), collision_radius * 1.15, true)
	draw_circle(Vector2.ZERO, collision_radius + 2.5, Color(color, 0.28))
	draw_circle(Vector2.ZERO, collision_radius, color)
	draw_circle(Vector2.ZERO, maxf(2.0, collision_radius * 0.38), core)
