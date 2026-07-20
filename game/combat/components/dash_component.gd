class_name DashComponent
extends Node

@export var cooldown: float = 1.5
@export var duration: float = 0.2

var health_component: Node
var remaining_cooldown: float = 0.0
var remaining_duration: float = 0.0


func try_start() -> bool:
	if remaining_cooldown > 0.0:
		return false
	remaining_cooldown = cooldown
	remaining_duration = duration
	if health_component != null:
		health_component.invulnerable = true
	return true


func advance(delta: float) -> void:
	remaining_cooldown = maxf(remaining_cooldown - delta, 0.0)
	if remaining_duration <= 0.0:
		return
	remaining_duration = maxf(remaining_duration - delta, 0.0)
	if remaining_duration == 0.0 and health_component != null:
		health_component.invulnerable = false


func is_dashing() -> bool:
	return remaining_duration > 0.0
