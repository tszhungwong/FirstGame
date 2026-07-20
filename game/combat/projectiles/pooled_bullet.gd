class_name PooledBullet
extends Area2D

signal returned_to_pool

const DAMAGE_COMPONENT = preload("res://combat/components/damage_component.gd")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var remaining_lifetime: float = 0.0
var from_player: bool = true
var _active: bool = false
var _damage: Node


func _ready() -> void:
	collision_layer = 0
	monitoring = true
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	_damage = DAMAGE_COMPONENT.new()
	add_child(_damage)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func initialize(
	spawn_position: Vector2,
	travel_direction: Vector2,
	projectile_speed: float,
	lifetime: float,
	damage_amount: int,
	is_player_projectile: bool
) -> void:
	global_position = spawn_position
	direction = travel_direction.normalized()
	rotation = direction.angle()
	speed = projectile_speed
	remaining_lifetime = lifetime
	from_player = is_player_projectile
	collision_mask = 2 if from_player else 1
	_damage.amount = damage_amount
	_active = true
	queue_redraw()


func on_spawn() -> void:
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
	if not _active or not body.has_method("get_health_component"):
		return
	var health: Node = body.call("get_health_component")
	if health != null:
		_damage.call("apply_to", health)
	_return_to_pool()


func _return_to_pool() -> void:
	if not _active:
		return
	_active = false
	call_deferred("_emit_returned_to_pool")


func _emit_returned_to_pool() -> void:
	returned_to_pool.emit()


func _draw() -> void:
	var color := Color("68e0d1") if from_player else Color("ff846e")
	draw_circle(Vector2.ZERO, 6.0, color)
	draw_line(Vector2(-13.0, 0.0), Vector2(-4.0, 0.0), color, 3.0)
