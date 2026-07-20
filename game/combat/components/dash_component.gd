class_name DashComponent
extends Node

signal dash_state_changed(is_dashing: bool)

@export var cooldown: float = 0.0
@export var duration: float = 0.0

var health_component: HealthComponent
var remaining_cooldown: float = 0.0
var remaining_duration: float = 0.0


func try_start() -> bool:
	if remaining_cooldown > 0.0:
		return false
	remaining_cooldown = maxf(cooldown, 0.0)
	remaining_duration = maxf(duration, 0.0)
	if health_component != null:
		health_component.invulnerable = remaining_duration > 0.0
	if remaining_duration > 0.0:
		dash_state_changed.emit(true)
	return true


func advance(delta: float) -> void:
	remaining_cooldown = maxf(remaining_cooldown - delta, 0.0)
	if remaining_duration <= 0.0:
		return
	remaining_duration = maxf(remaining_duration - delta, 0.0)
	if remaining_duration == 0.0 and health_component != null:
		health_component.invulnerable = false
		dash_state_changed.emit(false)


func is_dashing() -> bool:
	return remaining_duration > 0.0
