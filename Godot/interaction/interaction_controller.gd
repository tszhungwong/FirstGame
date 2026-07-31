class_name InteractionController
extends Node

var _targets: Array[Node2D] = []


func register(target: Node2D) -> void:
	assert(target != null, "Interaction target cannot be null")
	if target in _targets:
		return
	_targets.append(target)
	var cleanup := Callable(self, "unregister").bind(target)
	if not target.tree_exiting.is_connected(cleanup):
		target.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)


func unregister(target: Node2D) -> void:
	_targets.erase(target)


func find_nearest(origin: Vector2, maximum_distance: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := maximum_distance
	for target: Node2D in _targets:
		if not _is_available(target):
			continue
		var distance := origin.distance_to(target.global_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func update_prompts(origin: Vector2, maximum_distance: float, allow_prompt: bool) -> void:
	var nearest: Node2D
	if allow_prompt:
		nearest = find_nearest(origin, maximum_distance)
	for target: Node2D in _targets:
		if is_instance_valid(target) and target.has_method("set_interaction_prompt_visible"):
			target.set_interaction_prompt_visible(target == nearest)


func try_interact(actor: Node, origin: Vector2, maximum_distance: float) -> bool:
	var nearest := find_nearest(origin, maximum_distance)
	if nearest == null or not nearest.has_method("interact"):
		return false
	nearest.interact(actor)
	return true


func _is_available(target: Node2D) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if not target.visible or target.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	return not target.has_method("can_interact") or target.can_interact()
