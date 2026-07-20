class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal died

@export var max_health: int = 1

var current_health: int = 0
var invulnerable: bool = false


func _ready() -> void:
	reset()


func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> int:
	if amount <= 0 or invulnerable or current_health <= 0:
		return 0

	var applied_damage: int = mini(amount, current_health)
	current_health -= applied_damage
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()
	return applied_damage
