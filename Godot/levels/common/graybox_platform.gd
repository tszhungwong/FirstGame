class_name GrayboxPlatform
extends StaticBody2D

@export var size := Vector2(320.0, 32.0)
@export var color := Color("354b57")
@export var one_way := false
@export var visual_texture: Texture2D
@export_range(0, 128, 1) var visual_end_margin := 48
@export_range(0, 32, 1) var visual_vertical_margin := 10


func _ready() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.one_way_collision = one_way
	add_child(collision)
	if one_way:
		collision_layer = 2
	if visual_texture != null:
		_add_textured_visual()
	queue_redraw()


func _draw() -> void:
	if visual_texture != null:
		return
	draw_rect(Rect2(-size * 0.5, size), color)
	draw_line(
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		color.lightened(0.28),
		3.0
	)


func _add_textured_visual() -> void:
	var visual := NinePatchRect.new()
	visual.name = "PlatformVisual"
	visual.texture = visual_texture
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.patch_margin_left = visual_end_margin
	visual.patch_margin_right = visual_end_margin
	visual.patch_margin_top = mini(visual_vertical_margin, int(size.y * 0.5))
	visual.patch_margin_bottom = mini(visual_vertical_margin, int(size.y * 0.5))
	if size.x >= size.y:
		visual.position = -size * 0.5
		visual.size = size
	else:
		visual.position = Vector2(size.x * 0.5, -size.y * 0.5)
		visual.size = Vector2(size.y, size.x)
		visual.rotation = PI * 0.5
	add_child(visual)
