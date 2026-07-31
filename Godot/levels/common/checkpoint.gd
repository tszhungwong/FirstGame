class_name Checkpoint
extends Area2D

signal activated(checkpoint_position: Vector2, first_activation: bool)

var is_active := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	activate(body)


func activate(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var first_activation := not is_active
	is_active = true
	activated.emit(global_position, first_activation)
	queue_redraw()


func _draw() -> void:
	var glow := Color("7ef7d4") if is_active else Color("3d7a75")
	draw_circle(Vector2.ZERO, 23.0, Color(glow, 0.2))
	draw_circle(Vector2.ZERO, 11.0, glow)
	draw_line(Vector2(0.0, 12.0), Vector2(0.0, 42.0), glow, 5.0)
