class_name DamageRequest
extends RefCounted

enum DamageType {
	PHYSICAL = 1,
	ELECTRIC = 2,
	IMPACT = 4,
}

var amount: int
var knockback: Vector2
var damage_types: int
var source: Node


func _init(
	requested_amount := 0,
	requested_knockback := Vector2.ZERO,
	requested_types := DamageType.PHYSICAL,
	requested_source: Node = null
) -> void:
	amount = requested_amount
	knockback = requested_knockback
	damage_types = requested_types
	source = requested_source

