class_name ObjectPool
extends Node

@export var pooled_scene: PackedScene
@export var initial_size: int = 0
@export var can_grow: bool = false

var _available: Array[PooledBullet] = []
var _in_use: Array[PooledBullet] = []
var _active_leases: Dictionary[PooledBullet, int] = {}
var _next_lease_id: int = 0
var _projectile_collision_radius: float = 0.0


func _ready() -> void:
	if pooled_scene != null:
		_initialize()


func configure(scene: PackedScene, size: int, grow: bool, collision_radius: float = 0.0) -> void:
	pooled_scene = scene
	initial_size = maxi(size, 0)
	can_grow = grow
	_projectile_collision_radius = maxf(collision_radius, 0.0)
	_initialize()


func acquire() -> PooledBullet:
	if _available.is_empty():
		if not can_grow or pooled_scene == null:
			return null
		_create_instance()
	var instance: PooledBullet = _available.pop_back()
	_in_use.append(instance)
	_next_lease_id += 1
	_active_leases[instance] = _next_lease_id
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.visible = true
	instance.on_spawn(_next_lease_id)
	return instance


func release(instance: PooledBullet) -> void:
	if not _in_use.has(instance):
		return
	_in_use.erase(instance)
	_active_leases.erase(instance)
	instance.on_despawn()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.visible = false
	_available.append(instance)


func available_count() -> int:
	return _available.size()


func in_use_count() -> int:
	return _in_use.size()


func release_all() -> void:
	for instance: PooledBullet in _in_use.duplicate():
		release(instance)


func _initialize() -> void:
	if pooled_scene == null or not _available.is_empty() or not _in_use.is_empty():
		return
	for _index: int in initial_size:
		_create_instance()


func _create_instance() -> PooledBullet:
	var instance := pooled_scene.instantiate() as PooledBullet
	assert(instance != null, "ObjectPool requires a PooledBullet root scene")
	add_child(instance)
	instance.configure_collision_radius(_projectile_collision_radius)
	instance.on_despawn()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.visible = false
	instance.returned_to_pool.connect(_on_instance_returned)
	_available.append(instance)
	return instance


func _on_instance_returned(instance: PooledBullet, lease_id: int) -> void:
	if _active_leases.get(instance, -1) != lease_id:
		return
	release(instance)
