class_name ObjectPool
extends Node

@export var pooled_scene: PackedScene
@export var initial_size: int = 0
@export var can_grow: bool = true

var _available: Array[Node] = []
var _in_use: Array[Node] = []


func _ready() -> void:
	if pooled_scene != null:
		_initialize()


func configure(scene: PackedScene, size: int, grow: bool) -> void:
	pooled_scene = scene
	initial_size = maxi(size, 0)
	can_grow = grow
	_initialize()


func acquire() -> Node:
	if _available.is_empty():
		if not can_grow or pooled_scene == null:
			return null
		_create_instance()
	var instance: Node = _available.pop_back()
	_in_use.append(instance)
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	if instance is CanvasItem:
		(instance as CanvasItem).visible = true
	if instance.has_method("on_spawn"):
		instance.call("on_spawn")
	return instance


func release(instance: Node) -> void:
	if not _in_use.has(instance):
		return
	_in_use.erase(instance)
	if instance.has_method("on_despawn"):
		instance.call("on_despawn")
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	_available.append(instance)


func available_count() -> int:
	return _available.size()


func in_use_count() -> int:
	return _in_use.size()


func release_all() -> void:
	for instance: Node in _in_use.duplicate():
		release(instance)


func _initialize() -> void:
	if pooled_scene == null or not _available.is_empty() or not _in_use.is_empty():
		return
	for _index: int in initial_size:
		_create_instance()


func _create_instance() -> Node:
	var instance: Node = pooled_scene.instantiate()
	add_child(instance)
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	if instance.has_signal("returned_to_pool"):
		instance.connect("returned_to_pool", release.bind(instance))
	_available.append(instance)
	return instance
