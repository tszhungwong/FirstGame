class_name PooledBullet
extends Area2D

signal returned_to_pool(bullet: PooledBullet, lease_id: int)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var remaining_lifetime: float = 0.0
var from_player: bool = true
var collision_radius: float = 0.0
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
	is_player_projectile: bool
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


func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += direction * speed * delta
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		_return_to_pool()


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	var health := body.get_node_or_null("Health") as HealthComponent
	if health != null:
		_damage.apply_to(health)
	_return_to_pool()


func _return_to_pool() -> void:
	if not _active:
		return
	_active = false
	_emit_returned_to_pool.call_deferred(_lease_id)


func _emit_returned_to_pool(lease_id: int) -> void:
	returned_to_pool.emit(self, lease_id)


func _draw() -> void:
	var color := Color("68e0d1") if from_player else Color("ff846e")
	draw_circle(Vector2.ZERO, collision_radius, color)
	draw_line(Vector2(-13.0, 0.0), Vector2(-4.0, 0.0), color, 3.0)
