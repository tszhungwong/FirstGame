class_name DamageComponent
extends Node

@export var amount: int = 0


func apply_to(health: Node) -> int:
	return health.take_damage(amount)
