class_name EchoForeman
extends "res://enemies/common/enemy.gd"

signal battle_line_spoken(text_key: StringName)

const DEBRIS_SCENE := preload("res://enemies/projectiles/falling_debris.tscn")
const BATTLE_LINE_KEYS: Array[StringName] = [
	&"dialog.foreman.01",
	&"dialog.foreman.02",
	&"dialog.foreman.03",
]

enum AiState { APPROACH, CHARGE, MELEE }

@export var behavior: EchoForemanDefinition

var _attack_cooldown := 0.0
var _charge_cooldown := 0.0
var _charge_time := 0.0
var _charge_direction := 1.0
var _debris_cooldown := 0.0
var _battle_line_cooldown := 0.0
var _battle_line_index := 0
var _state := AiState.APPROACH


func _ready() -> void:
	assert(behavior != null, "EchoForeman requires behavior tuning")
	_attack_cooldown = behavior.initial_attack_delay
	_charge_cooldown = behavior.initial_charge_delay
	_debris_cooldown = behavior.initial_debris_delay
	_battle_line_cooldown = behavior.initial_battle_line_delay
	super()


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_charge_cooldown = maxf(_charge_cooldown - delta, 0.0)
	_charge_time = maxf(_charge_time - delta, 0.0)
	_debris_cooldown = maxf(_debris_cooldown - delta, 0.0)
	_battle_line_cooldown = maxf(_battle_line_cooldown - delta, 0.0)
	var player := get_target()
	if player != null:
		var offset := player.global_position - global_position
		if absf(offset.x) < behavior.encounter_range and _debris_cooldown <= 0.0:
			_debris_cooldown = behavior.debris_interval
			_drop_debris(player.global_position)
		if (
			absf(offset.x) < behavior.encounter_range
			and _battle_line_cooldown <= 0.0
			and _battle_line_index < BATTLE_LINE_KEYS.size()
		):
			_battle_line_cooldown = behavior.battle_line_interval
			battle_line_spoken.emit(BATTLE_LINE_KEYS[_battle_line_index])
			_battle_line_index += 1
		if _charge_time > 0.0:
			_state = AiState.CHARGE
			velocity.x = _charge_direction * behavior.move_speed * behavior.charge_speed_multiplier
			if absf(offset.x) < behavior.attack_range and absf(offset.y) < behavior.vertical_attack_range:
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
			player.apply_damage(DamageRequestType.new(
				behavior.contact_damage,
				Vector2(signf(offset.x) * behavior.melee_knockback.x, behavior.melee_knockback.y),
				DamageRequestType.DamageType.IMPACT,
				self
			))
	super(delta)


func _drop_debris(target_position: Vector2) -> void:
	var debris := DEBRIS_SCENE.instantiate()
	get_parent().add_child(debris)
	debris.global_position = Vector2(
		target_position.x,
		maxf(behavior.debris_minimum_y, target_position.y - behavior.debris_spawn_height)
	)


func _draw() -> void:
	draw_rect(Rect2(-34.0, -42.0, 68.0, 84.0), Color("aa554f"))
	draw_rect(Rect2(-27.0, -34.0, 54.0, 18.0), Color("3b2028"))
	draw_circle(Vector2(0.0, -25.0), 7.0, Color("ffcf5b"))
	draw_line(Vector2(25.0, -4.0), Vector2(50.0, 22.0), Color("ff8f4f"), 12.0)
