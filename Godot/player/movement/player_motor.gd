class_name PlayerMotor
extends Node

const PlayerCommandType := preload("res://player/input/player_command.gd")

var _tuning: PlayerTuning

var facing_direction := 1.0
var _dash_time_remaining := 0.0
var _dash_cooldown_remaining := 0.0
var _platform_drop_remaining := 0.0
var _wall_jump_lock_remaining := 0.0
var _jump_hold_time_remaining := 0.0


func configure(tuning: PlayerTuning) -> void:
	_tuning = tuning


func step(
	body: CharacterBody2D,
	command: PlayerCommandType,
	delta: float,
	has_wall_module: bool,
	movement_scale := 1.0
) -> void:
	assert(_tuning != null, "PlayerMotor must be configured before stepping")
	_dash_time_remaining = maxf(_dash_time_remaining - delta, 0.0)
	_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)
	_wall_jump_lock_remaining = maxf(_wall_jump_lock_remaining - delta, 0.0)
	_update_platform_drop(body, delta)
	if not is_zero_approx(command.move_axis):
		facing_direction = signf(command.move_axis)
	if command.dash_pressed and _dash_cooldown_remaining <= 0.0:
		_dash_time_remaining = _tuning.dash_duration
		_dash_cooldown_remaining = _tuning.dash_cooldown
	if command.drop_pressed and body.is_on_floor() and not command.attack_pressed and not command.skill_pressed:
		_platform_drop_remaining = _tuning.platform_drop_duration
		body.set_collision_mask_value(2, false)
		body.position.y += 3.0
	if _dash_time_remaining > 0.0:
		body.velocity = Vector2(facing_direction * _tuning.dash_speed, 0.0)
		body.move_and_slide()
		return
	if not body.is_on_floor():
		var gravity_multiplier := 1.0
		if body.velocity.y < 0.0 and command.jump_held and _jump_hold_time_remaining > 0.0:
			gravity_multiplier = _tuning.jump_hold_gravity_multiplier
		body.velocity.y += _tuning.gravity * gravity_multiplier * delta
		_jump_hold_time_remaining = maxf(_jump_hold_time_remaining - delta, 0.0)
		if has_wall_module and body.is_on_wall() and body.velocity.y > _tuning.wall_slide_speed:
			body.velocity.y = _tuning.wall_slide_speed
	else:
		_jump_hold_time_remaining = 0.0
	if command.jump_pressed and body.is_on_floor():
		body.velocity.y = _tuning.jump_velocity
		_jump_hold_time_remaining = _tuning.jump_hold_duration
	elif command.jump_pressed and has_wall_module and body.is_on_wall():
		var wall_normal := body.get_wall_normal()
		body.velocity = Vector2(wall_normal.x * _tuning.wall_jump_horizontal_speed, _tuning.jump_velocity)
		_wall_jump_lock_remaining = _tuning.wall_jump_control_lock
		_jump_hold_time_remaining = _tuning.jump_hold_duration
	elif command.jump_released and body.velocity.y < 0.0:
		_jump_hold_time_remaining = 0.0
		body.velocity.y *= _tuning.jump_cut_multiplier
	if _wall_jump_lock_remaining <= 0.0:
		body.velocity.x = command.move_axis * _tuning.move_speed * movement_scale
	body.move_and_slide()


func reset() -> void:
	_dash_time_remaining = 0.0
	_dash_cooldown_remaining = 0.0
	_platform_drop_remaining = 0.0
	_wall_jump_lock_remaining = 0.0
	_jump_hold_time_remaining = 0.0


func is_dashing() -> bool:
	return _dash_time_remaining > 0.0


func _update_platform_drop(body: CharacterBody2D, delta: float) -> void:
	if _platform_drop_remaining <= 0.0:
		return
	_platform_drop_remaining = maxf(_platform_drop_remaining - delta, 0.0)
	if _platform_drop_remaining <= 0.0:
		body.set_collision_mask_value(2, true)
