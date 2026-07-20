extends GutTest

func test_selects_the_nearest_target_within_range() -> void:
	var targeting := autofree(TargetingComponent.new()) as TargetingComponent
	var nearest: Node2D = autofree(Node2D.new())
	var farther: Node2D = autofree(Node2D.new())
	var outside_range: Node2D = autofree(Node2D.new())
	nearest.global_position = Vector2(24.0, 0.0)
	farther.global_position = Vector2(80.0, 0.0)
	outside_range.global_position = Vector2(140.0, 0.0)
	var candidates: Array[Node2D] = [farther, outside_range, nearest]
	var outside_candidates: Array[Node2D] = [outside_range]

	assert_same(targeting.find_nearest(Vector2.ZERO, candidates, 100.0), nearest)
	assert_null(targeting.find_nearest(Vector2.ZERO, outside_candidates, 100.0))


func test_combat_hot_paths_reuse_targets_and_avoid_per_frame_hud_work() -> void:
	var ember_source := FileAccess.get_file_as_string("res://combat/actors/ember.gd")
	var enemy_source := FileAccess.get_file_as_string("res://combat/actors/enemy.gd")
	var hud_source := FileAccess.get_file_as_string("res://combat/ui/combat_hud.gd")
	var bullet_source := FileAccess.get_file_as_string("res://combat/projectiles/pooled_bullet.gd")

	assert_eq(ember_source.find("get_nodes_in_group"), -1, "Ember should use its cached target list")
	assert_ne(ember_source.find("var _target_candidates: Array[Node2D]"), -1)
	assert_eq(hud_source.find("func _process("), -1, "HUD should update from signals/timers")
	assert_eq(hud_source.find("get_nodes_in_group"), -1, "HUD should receive enemy counts")
	assert_eq(ember_source.find("_auto_fire()\n\tqueue_redraw()"), -1, "Ember should not redraw every physics tick")
	assert_eq(enemy_source.find("\tqueue_redraw()\n\n\nfunc get_health_component"), -1, "Enemies should redraw only on visual state transitions")
	assert_ne(bullet_source.find("if is_equal_approx(collision_radius, next_radius):"), -1, "Bullets should not redraw for unchanged geometry")
