class_name EchoForeman
extends "res://enemies/common/enemy.gd"

signal battle_line_spoken(text_key: StringName)

const DEBRIS_SCENE := preload("res://enemies/projectiles/falling_debris.tscn")
const BATTLE_LINE_KEYS: Array[StringName] = [
	&"dialog.foreman.01",
	&"dialog.foreman.02",
	&"dialog.foreman.03",
]

enum AiState { IDLE, APPROACH, CHARGE, MELEE }

@export var behavior: EchoForemanDefinition

var _attack_cooldown := 0.0
var _attack_windup_remaining := 0.0
var _charge_cooldown := 0.0
var _charge_time := 0.0
var _charge_direction := 1.0
var _debris_cooldown := 0.0
var _battle_line_cooldown := 0.0
var _battle_line_index := 0
var _encounter_origin_x := 0.0
var _attack_direction := 1.0
var _state := AiState.IDLE


func _ready() -> void:
	assert(behavior != null, "EchoForeman requires behavior tuning")
	_attack_cooldown = behavior.initial_attack_delay
	_charge_cooldown = behavior.initial_charge_delay
	_debris_cooldown = behavior.initial_debris_delay
	_battle_line_cooldown = behavior.initial_battle_line_delay
	_encounter_origin_x = global_position.x
	super()


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var was_winding_up := _attack_windup_remaining > 0.0
	_attack_windup_remaining = maxf(_attack_windup_remaining - delta, 0.0)
	_charge_cooldown = maxf(_charge_cooldown - delta, 0.0)
	_charge_time = maxf(_charge_time - delta, 0.0)
	_debris_cooldown = maxf(_debris_cooldown - delta, 0.0)
	_battle_line_cooldown = maxf(_battle_line_cooldown - delta, 0.0)
	var player := get_target()
	if (
		player == null
		or absf(player.global_position.x - _encounter_origin_x) > behavior.encounter_range
	):
		_state = AiState.IDLE
		velocity.x = 0.0
		queue_redraw()
		super(delta)
		return

	if player != null:
		var offset := player.global_position - global_position
		if _debris_cooldown <= 0.0:
			_debris_cooldown = behavior.debris_interval
			_drop_debris(player.global_position)
		if (
			_battle_line_cooldown <= 0.0
			and _battle_line_index < BATTLE_LINE_KEYS.size()
		):
			_battle_line_cooldown = behavior.battle_line_interval
			battle_line_spoken.emit(BATTLE_LINE_KEYS[_battle_line_index])
			_battle_line_index += 1
		if was_winding_up:
			_state = AiState.MELEE
			velocity.x = 0.0
			if (
				_attack_windup_remaining <= 0.0
				and absf(offset.x) < behavior.attack_range
				and absf(offset.y) < behavior.vertical_attack_range
				and has_clear_attack_path(player)
			):
				player.apply_damage(DamageRequestType.new(
					behavior.contact_damage,
					Vector2(_attack_direction * behavior.melee_knockback.x, behavior.melee_knockback.y),
					DamageRequestType.DamageType.IMPACT,
					self
				))
		elif _charge_time > 0.0:
			_state = AiState.CHARGE
			velocity.x = _charge_direction * behavior.move_speed * behavior.charge_speed_multiplier
			if (
				absf(offset.x) < behavior.attack_range
				and absf(offset.y) < behavior.vertical_attack_range
				and has_clear_attack_path(player)
			):
				player.apply_damage(DamageRequestType.new(
					behavior.contact_damage,
					Vector2(_charge_direction * behavior.charge_knockback.x, behavior.charge_knockback.y),
					DamageRequestType.DamageType.IMPACT,
					self
				))
		elif (
			_charge_cooldown <= 0.0
			and absf(offset.x) > behavior.attack_range * behavior.charge_minimum_distance_multiplier
		):
			_state = AiState.CHARGE
			_charge_cooldown = behavior.charge_interval
			_charge_time = behavior.charge_duration
			_charge_direction = signf(offset.x)
		elif absf(offset.x) > behavior.attack_range:
			_state = AiState.APPROACH
			velocity.x = signf(offset.x) * behavior.move_speed
		elif _attack_cooldown <= 0.0:
			_state = AiState.MELEE
			_attack_cooldown = behavior.attack_interval
			_attack_direction = signf(offset.x) if not is_zero_approx(offset.x) else _attack_direction
			_attack_windup_remaining = behavior.attack_windup
			velocity.x = 0.0
		queue_redraw()
	super(delta)


func _drop_debris(target_position: Vector2) -> void:
	var debris := DEBRIS_SCENE.instantiate()
	get_parent().add_child(debris)
	debris.global_position = Vector2(
		target_position.x,
		maxf(behavior.debris_minimum_y, target_position.y - behavior.debris_spawn_height)
	)
	debris.configure_warning(target_position.y)


func _draw() -> void:
	draw_rect(Rect2(-34.0, -42.0, 68.0, 84.0), Color("aa554f"))
	draw_rect(Rect2(-27.0, -34.0, 54.0, 18.0), Color("3b2028"))
	draw_circle(Vector2(0.0, -25.0), 7.0, Color("ffcf5b"))
	draw_line(Vector2(25.0, -4.0), Vector2(50.0, 22.0), Color("ff8f4f"), 12.0)
	if _attack_windup_remaining > 0.0 or _state == AiState.CHARGE:
		var direction := _attack_direction if _state == AiState.MELEE else _charge_direction
		var left := 0.0 if direction > 0.0 else -behavior.attack_range
		var attack_rect := Rect2(
			left,
			-behavior.vertical_attack_range,
			behavior.attack_range,
			behavior.vertical_attack_range * 2.0
		)
		draw_rect(attack_rect, Color(1.0, 0.12, 0.08, 0.2), true)
		draw_rect(attack_rect, Color("ff4b38"), false, 4.0)
