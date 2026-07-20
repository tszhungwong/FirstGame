class_name ForestRoomRules
extends RefCounted

var definition: RoomDefinition


func _init(room_definition: RoomDefinition = null) -> void:
	definition = room_definition


func is_concealed(point: Vector2) -> bool:
	if definition == null or not definition.includes_grass:
		return false
	return _inside_any(point, definition.grass_areas)


func speed_multiplier_at(point: Vector2) -> float:
	if definition != null and definition.includes_mud and _inside_any(point, definition.mud_areas):
		return definition.mud_speed_multiplier
	return 1.0


func blocks_actor_at(point: Vector2) -> bool:
	if definition == null:
		return false
	if definition.includes_trees:
		for tree: Vector2 in definition.tree_positions:
			if point.distance_squared_to(tree) <= definition.tree_radius * definition.tree_radius:
				return true
	if definition.includes_river and _inside_any(point, definition.river_areas):
		return not _inside_any(point, definition.bridge_areas)
	return false


func blocks_projectile_segment(from: Vector2, to: Vector2) -> bool:
	var segment_length := from.distance_to(to)
	var sample_count := maxi(1, ceili(segment_length / 18.0))
	for sample_index: int in range(sample_count + 1):
		if blocks_actor_at(from.lerp(to, float(sample_index) / float(sample_count))):
			return true
	if definition == null or not definition.includes_trees:
		return false
	for tree: Vector2 in definition.tree_positions:
		if _distance_to_segment(tree, from, to) <= definition.tree_radius:
			return true
	return false


func resolve_actor_position(from: Vector2, requested: Vector2) -> Vector2:
	return from if blocks_actor_at(requested) else requested


func projectile_rebound_position(from: Vector2, requested: Vector2) -> Vector2:
	if definition == null:
		return from
	var distance := from.distance_to(requested)
	var sample_count := maxi(1, ceili(distance / 8.0))
	var last_clear := from
	for sample_index: int in range(1, sample_count + 1):
		var point := from.lerp(requested, float(sample_index) / float(sample_count))
		if blocks_actor_at(point):
			var away := requested.direction_to(from)
			return last_clear + away * definition.projectile_blocker_separation
		last_clear = point
	return from


func _inside_any(point: Vector2, areas: Array[Rect2]) -> bool:
	for area: Rect2 in areas:
		if area.has_point(point):
			return true
	return false


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.is_zero_approx():
		return point.distance_to(start)
	var progress := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * progress)
