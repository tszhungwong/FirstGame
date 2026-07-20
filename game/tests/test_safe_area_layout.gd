extends GutTest

const LAYOUT_PATH := "res://ui/safe_area_layout.gd"


func test_wide_notch_is_scaled_and_padded_inside_the_viewport() -> void:
	var layout_script: GDScript = load(LAYOUT_PATH) as GDScript
	assert_not_null(layout_script)
	if layout_script == null:
		return
	var content: Rect2 = layout_script.resolve_content_rect(
		Vector2(1280.0, 720.0),
		Rect2i(132, 0, 2404, 1080),
		Vector2i(2560, 1080),
		16.0,
	)

	assert_almost_eq(content.position.x, 82.0, 0.01)
	assert_almost_eq(content.position.y, 16.0, 0.01)
	assert_almost_eq(content.end.x, 1252.0, 0.01)
	assert_almost_eq(content.end.y, 704.0, 0.01)


func test_invalid_platform_safe_area_falls_back_to_edge_padding() -> void:
	var layout_script: GDScript = load(LAYOUT_PATH) as GDScript
	assert_not_null(layout_script)
	if layout_script == null:
		return
	var content: Rect2 = layout_script.resolve_content_rect(
		Vector2(1024.0, 768.0),
		Rect2i(),
		Vector2i(),
		16.0,
	)

	assert_eq(content, Rect2(16.0, 16.0, 992.0, 736.0))


func test_common_landscape_aspects_keep_minimum_usable_content() -> void:
	var layout_script: GDScript = load(LAYOUT_PATH) as GDScript
	assert_not_null(layout_script)
	if layout_script == null:
		return
	var cases: Array[Vector2] = [
		Vector2(1280.0, 720.0),
		Vector2(2532.0, 1170.0),
		Vector2(1024.0, 768.0),
	]
	for viewport_size: Vector2 in cases:
		var display_size := Vector2i(roundi(viewport_size.x), roundi(viewport_size.y))
		var content: Rect2 = layout_script.resolve_content_rect(
			viewport_size,
			Rect2i(Vector2i.ZERO, display_size),
			display_size,
			16.0,
		)
		assert_true(content.position.x >= 0.0)
		assert_true(content.position.y >= 0.0)
		assert_true(content.end.x <= viewport_size.x)
		assert_true(content.end.y <= viewport_size.y)
		assert_true(content.size.x >= 900.0)
		assert_true(content.size.y >= 650.0)
