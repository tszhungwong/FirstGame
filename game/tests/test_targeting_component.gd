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
