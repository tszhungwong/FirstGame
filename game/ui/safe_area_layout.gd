class_name SafeAreaLayout
extends RefCounted


static func resolve_content_rect(
	viewport_size: Vector2,
	display_safe_area: Rect2i,
	display_size: Vector2i,
	edge_padding: float = 16.0
) -> Rect2:
	var viewport_bounds := Rect2(Vector2.ZERO, viewport_size.max(Vector2.ZERO))
	var safe_rect := viewport_bounds
	if display_size.x > 0 and display_size.y > 0 and display_safe_area.size.x > 0 and display_safe_area.size.y > 0:
		var scale := Vector2(
			viewport_size.x / float(display_size.x),
			viewport_size.y / float(display_size.y),
		)
		safe_rect = Rect2(
			Vector2(display_safe_area.position) * scale,
			Vector2(display_safe_area.size) * scale,
		).intersection(viewport_bounds)
	var padding := maxf(edge_padding, 0.0)
	var padded_position := safe_rect.position + Vector2.ONE * padding
	var padded_end := safe_rect.end - Vector2.ONE * padding
	if padded_end.x < padded_position.x:
		padded_end.x = padded_position.x
	if padded_end.y < padded_position.y:
		padded_end.y = padded_position.y
	return Rect2(padded_position, padded_end - padded_position)


static func current_content_rect(viewport_size: Vector2, edge_padding: float = 16.0) -> Rect2:
	return resolve_content_rect(
		viewport_size,
		DisplayServer.get_display_safe_area(),
		DisplayServer.screen_get_size(),
		edge_padding,
	)
