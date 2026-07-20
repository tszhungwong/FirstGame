class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal died

@export var max_health: int = 1

var current_health: int = 0
var invulnerable: bool = false
var _burn_generation: int = 0


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


func apply_burn(damage_per_tick: int, duration: float, tick_interval: float = 0.5) -> void:
	if damage_per_tick <= 0 or duration <= 0.0 or current_health <= 0:
		return
	_burn_generation += 1
	_run_burn(_burn_generation, damage_per_tick, duration, tick_interval)


func _run_burn(generation: int, damage_per_tick: int, duration: float, tick_interval: float) -> void:
	var remaining := duration
	while generation == _burn_generation and remaining > 0.0 and current_health > 0:
		await get_tree().create_timer(minf(tick_interval, remaining)).timeout
		if generation != _burn_generation:
			return
		take_damage(damage_per_tick)
		remaining -= tick_interval
