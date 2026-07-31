class_name FallingDebris
extends Area2D

const CombatantBodyType := preload("res://combat/combatant_body_2d.gd")
const DamageRequestType := preload("res://combat/damage_request.gd")

@export var fall_speed := 390.0
@export var lifetime := 2.2


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	var receiver := body as CombatantBodyType
	if receiver != null:
		receiver.apply_damage(DamageRequestType.new(
			1,
			Vector2(0.0, 260.0),
			DamageRequestType.DamageType.IMPACT,
			self
		))
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(-13.0, -18.0, 26.0, 36.0), Color("9a6a52"))
	draw_line(Vector2(-9.0, -14.0), Vector2(8.0, 13.0), Color("ffc857"), 3.0)
