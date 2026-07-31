class_name GrayboxPlatform
extends StaticBody2D

@export var size := Vector2(320.0, 32.0)
@export var color := Color("354b57")
@export var one_way := false


func _ready() -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.one_way_collision = one_way
	add_child(collision)
	if one_way:
		collision_layer = 2
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-size * 0.5, size), color)
	draw_line(
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		color.lightened(0.28),
		3.0
	)
