extends GutTest

const ForestRoomRulesScript = preload("res://run/forest_room_rules.gd")


func test_grass_conceals_and_mud_slows_actors() -> void:
	var room := load("res://data/mock_forest_combat_room.tres") as RoomDefinition
	var rules = ForestRoomRulesScript.new(room)

	assert_true(rules.is_concealed(room.grass_areas[0].get_center()))
	assert_eq(rules.speed_multiplier_at(room.mud_areas[0].get_center()), room.mud_speed_multiplier)
	assert_eq(rules.speed_multiplier_at(Vector2(50.0, 50.0)), 1.0)


func test_river_blocks_except_at_bridge_gaps() -> void:
	var room := load("res://data/mock_forest_combat_room.tres") as RoomDefinition
	var rules = ForestRoomRulesScript.new(room)
	var river := room.river_areas[0]
	var blocked_point := river.get_center() + Vector2(0.0, river.size.y * 0.35)
	var bridge_point := room.bridge_areas[0].get_center()

	assert_true(rules.blocks_actor_at(blocked_point))
	assert_false(rules.blocks_actor_at(bridge_point))
	assert_true(rules.blocks_projectile_segment(blocked_point - Vector2(180.0, 0.0), blocked_point + Vector2(180.0, 0.0)))
	assert_false(rules.blocks_projectile_segment(bridge_point - Vector2(180.0, 0.0), bridge_point + Vector2(180.0, 0.0)))


func test_trees_block_actors_and_projectile_segments() -> void:
	var room := load("res://data/mock_forest_combat_room.tres") as RoomDefinition
	var rules = ForestRoomRulesScript.new(room)
	var tree: Vector2 = room.tree_positions[0]

	assert_true(rules.blocks_actor_at(tree))
	assert_true(rules.blocks_projectile_segment(tree - Vector2(80.0, 0.0), tree + Vector2(80.0, 0.0)))
	assert_false(rules.blocks_projectile_segment(Vector2(30.0, 30.0), Vector2(80.0, 30.0)))
