class_name ElectricBolt
extends Area2D

const CombatantBodyType := preload("res://combat/combatant_body_2d.gd")
const DamageRequestType := preload("res://combat/damage_request.gd")

@export var speed := 235.0
@export var lifetime := 4.0
@export var damage := 1

var direction := Vector2.LEFT


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	position += direction.normalized() * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	var receiver := body as CombatantBodyType
	if receiver != null:
		receiver.apply_damage(DamageRequestType.new(
			damage,
			direction.normalized() * 170.0,
			DamageRequestType.DamageType.ELECTRIC,
			self
		))
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color("72e6ff"))
	draw_circle(Vector2.ZERO, 12.0, Color(0.35, 0.9, 1.0, 0.2))
