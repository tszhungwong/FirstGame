class_name TargetingComponent
extends Node


func find_nearest(
	origin: Vector2,
	candidates: Array[Node2D],
	maximum_range: float = INF
) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance_squared: float = maximum_range * maximum_range
	for candidate: Node2D in candidates:
		if not is_instance_valid(candidate):
			continue
		var distance_squared: float = origin.distance_squared_to(candidate.global_position)
		if distance_squared <= nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared
	return nearest
