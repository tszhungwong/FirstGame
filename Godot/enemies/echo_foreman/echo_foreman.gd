class_name EchoForeman
extends "res://enemies/common/enemy.gd"

signal battle_line_spoken(text_key: StringName)
signal heavy_step_requested

const DEBRIS_SCENE := preload("res://enemies/projectiles/falling_debris.tscn")
const BATTLE_LINE_KEYS: Array[StringName] = [
	&"dialog.foreman.01",
	&"dialog.foreman.02",
	&"dialog.foreman.03",
]

enum AiState { IDLE, APPROACH, CHARGE, MELEE }

@export var behavior: EchoForemanDefinition

var _attack_cooldown := 0.0
var _charge_cooldown := 0.0
var _charge_time := 0.0
var _charge_direction := 1.0
var _debris_cooldown := 0.0
var _battle_line_cooldown := 0.0
var _battle_line_index := 0
var _encounter_origin_x := 0.0
var _attack_direction := 1.0
var _state := AiState.IDLE
var _facing_direction := 1.0

@onready var _visual: EchoForemanVisual = %Visual


func _ready() -> void:
	assert(behavior != null, "EchoForeman requires behavior tuning")
	_attack_cooldown = behavior.initial_attack_delay
	_charge_cooldown = behavior.initial_charge_delay
	_debris_cooldown = behavior.initial_debris_delay
	_battle_line_cooldown = behavior.initial_battle_line_delay
	_encounter_origin_x = global_position.x
	super()
	_visual.attack_active_frame_reached.connect(_on_attack_active_frame_reached)
	_visual.attack_finished.connect(_on_attack_finished)
	_visual.heavy_step_frame_reached.connect(heavy_step_requested.emit)
	_visual.reset_visual(_facing_direction)


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_charge_cooldown = maxf(_charge_cooldown - delta, 0.0)
	_charge_time = maxf(_charge_time - delta, 0.0)
	_debris_cooldown = maxf(_debris_cooldown - delta, 0.0)
	_battle_line_cooldown = maxf(_battle_line_cooldown - delta, 0.0)
	if _state == AiState.MELEE:
		velocity.x = 0.0
		super(delta)
		return
	var player := get_target()
	if (
		player == null
		or absf(player.global_position.x - _encounter_origin_x) > behavior.encounter_range
	):
		_state = AiState.IDLE
		velocity.x = 0.0
		_visual.sync_motion(velocity, _facing_direction)
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
		if _charge_time > 0.0:
			_state = AiState.CHARGE
			velocity.x = _charge_direction * behavior.move_speed * behavior.charge_speed_multiplier
			_update_facing(_charge_direction)
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
			_update_facing(_charge_direction)
		elif absf(offset.x) > behavior.attack_range:
			_state = AiState.APPROACH
			velocity.x = signf(offset.x) * behavior.move_speed
			_update_facing(velocity.x)
		elif _attack_cooldown <= 0.0:
			_begin_melee_attack(offset.x)
		else:
			_state = AiState.IDLE
			velocity.x = 0.0
		_visual.sync_motion(
			velocity,
			_facing_direction,
			behavior.charge_animation_speed_scale if _state == AiState.CHARGE else 1.0
		)
	super(delta)


func reset_enemy() -> void:
	super()
	_attack_cooldown = behavior.initial_attack_delay
	_charge_cooldown = behavior.initial_charge_delay
	_charge_time = 0.0
	_debris_cooldown = behavior.initial_debris_delay
	_battle_line_cooldown = behavior.initial_battle_line_delay
	_battle_line_index = 0
	_attack_direction = 1.0
	_facing_direction = 1.0
	_state = AiState.IDLE
	_visual.reset_visual(_facing_direction)


func _begin_melee_attack(horizontal_direction: float) -> void:
	_attack_direction = (
		signf(horizontal_direction)
		if not is_zero_approx(horizontal_direction)
		else _attack_direction
	)
	if not _visual.play_attack(_attack_direction):
		return
	_update_facing(_attack_direction)
	_state = AiState.MELEE
	_attack_cooldown = behavior.attack_interval
	velocity.x = 0.0


func _update_facing(horizontal_direction: float) -> void:
	if not is_zero_approx(horizontal_direction):
		_facing_direction = signf(horizontal_direction)


func _on_attack_active_frame_reached() -> void:
	if _state != AiState.MELEE:
		return
	var player := get_target()
	if player == null:
		return
	var offset := player.global_position - global_position
	if (
		absf(offset.x) >= behavior.attack_range
		or absf(offset.y) >= behavior.vertical_attack_range
		or not has_clear_attack_path(player)
	):
		return
	player.apply_damage(DamageRequestType.new(
		behavior.contact_damage,
		Vector2(
			_attack_direction * behavior.melee_knockback.x,
			behavior.melee_knockback.y
		),
		DamageRequestType.DamageType.IMPACT,
		self
	))


func _on_attack_finished() -> void:
	if _state != AiState.MELEE:
		return
	_state = AiState.IDLE
	_visual.sync_motion(Vector2.ZERO, _facing_direction)


func _drop_debris(target_position: Vector2) -> void:
	var debris := DEBRIS_SCENE.instantiate()
	get_parent().add_child(debris)
	debris.global_position = Vector2(
		target_position.x,
		maxf(behavior.debris_minimum_y, target_position.y - behavior.debris_spawn_height)
	)
	debris.configure_warning(target_position.y)
