class_name Vitals
extends RefCounted

const DamageRequestType := preload("res://combat/damage_request.gd")

signal health_changed(current: int, maximum: int)
signal died

var _maximum: int
var _health: int
var _invulnerability_duration: float
var _invulnerability_remaining := 0.0


func _init(maximum := 1, invulnerability_duration := 0.0) -> void:
	assert(maximum > 0, "Maximum health must be positive")
	_maximum = maximum
	_health = maximum
	_invulnerability_duration = maxf(invulnerability_duration, 0.0)


func tick(delta: float) -> void:
	_invulnerability_remaining = maxf(_invulnerability_remaining - delta, 0.0)


func apply_damage(request: DamageRequestType) -> bool:
	assert(request != null, "Damage request cannot be null")
	if request.amount <= 0 or _health <= 0 or _invulnerability_remaining > 0.0:
		return false
	_health = maxi(_health - request.amount, 0)
	_invulnerability_remaining = _invulnerability_duration
	health_changed.emit(_health, _maximum)
	if _health == 0:
		died.emit()
	return true


func restore_full() -> void:
	set_health(_maximum)
	_invulnerability_remaining = 0.0


func set_health(value: int) -> void:
	_health = clampi(value, 0, _maximum)
	health_changed.emit(_health, _maximum)


func get_health() -> int:
	return _health


func get_maximum() -> int:
	return _maximum


func is_invulnerable() -> bool:
	return _invulnerability_remaining > 0.0
