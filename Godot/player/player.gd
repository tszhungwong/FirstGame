class_name Player
extends "res://combat/combatant_body_2d.gd"

const CombatantBodyType := preload("res://combat/combatant_body_2d.gd")
const VitalsType := preload("res://combat/vitals.gd")
const KeyboardInputAdapterType := preload("res://player/input/keyboard_input_adapter.gd")
const PlayerCommandType := preload("res://player/input/player_command.gd")

signal health_changed(current: int, maximum: int)
signal memory_changed(current: int, maximum: int)
signal died
signal hit_confirmed(duration: float)

@export var tuning: PlayerTuning

var _initial_health := 5
var max_health: int:
	get: return tuning.max_health
var max_memory_energy: int:
	get: return tuning.max_memory_energy
var health: int:
	get:
		return _vitals.get_health() if _vitals != null else _initial_health
	set(value):
		_initial_health = value
		if _vitals != null:
			_vitals.set_health(value)
var memory_energy := 0
var has_skill := false
var has_wall_module := false
var _attack_move_lock_remaining := 0.0
var _vitals: VitalsType
var _input_adapter := KeyboardInputAdapterType.new()

@onready var _visual := $Visual as PlayerVisual
@onready var _motor := $Motor as PlayerMotor
@onready var _combat := $Combat as PlayerCombat


func _ready() -> void:
	assert(tuning != null, "Player requires a PlayerTuning resource")
	_vitals = VitalsType.new(tuning.max_health, tuning.invulnerability_duration)
	_vitals.health_changed.connect(_on_vitals_health_changed)
	_vitals.died.connect(_on_vitals_died)
	_combat.attack_visual_requested.connect(_visual.show_attack)
	_combat.hit_confirmed.connect(hit_confirmed.emit)
	_motor.configure(tuning)
	_combat.configure(tuning)
	health = tuning.max_health
	memory_energy = 0


func _physics_process(delta: float) -> void:
	var command: PlayerCommandType = _input_adapter.sample()
	_vitals.tick(delta)
	_visual.set_hurt(_vitals.is_invulnerable())
	_attack_move_lock_remaining = maxf(_attack_move_lock_remaining - delta, 0.0)

	var attack_requested := command.attack_pressed
	var skill_requested := command.skill_pressed
	if attack_requested:
		_perform_basic_attack(command)
	elif skill_requested and has_skill and memory_energy >= _combat.get_skill_memory_cost():
		_perform_skill(command)

	var movement_scale := 0.25 if _attack_move_lock_remaining > 0.0 else 1.0
	_motor.step(self, command, delta, has_wall_module, movement_scale)
	_visual.sync_state(PlayerVisualState.new(
		velocity,
		_motor.facing_direction,
		is_on_floor(),
		is_on_wall(),
		_motor.is_dashing()
	))


func _perform_basic_attack(command: PlayerCommandType) -> void:
	var attack_direction := _get_attack_direction(command)
	var outcome := _combat.perform_basic(self, attack_direction)
	_attack_move_lock_remaining = outcome.movement_lock
	if outcome.memory_delta > 0:
		memory_energy = mini(memory_energy + outcome.memory_delta, tuning.max_memory_energy)
		memory_changed.emit(memory_energy, tuning.max_memory_energy)
	if outcome.vertical_velocity != null:
		velocity.y = outcome.vertical_velocity


func _perform_skill(command: PlayerCommandType) -> void:
	var attack_direction := _get_attack_direction(command)
	var outcome := _combat.perform_skill(self, attack_direction)
	_attack_move_lock_remaining = outcome.movement_lock
	memory_energy = clampi(memory_energy + outcome.memory_delta, 0, tuning.max_memory_energy)
	memory_changed.emit(memory_energy, tuning.max_memory_energy)
	if outcome.vertical_velocity != null:
		velocity.y = outcome.vertical_velocity


func enable_skill() -> void:
	has_skill = true


func _get_attack_direction(command: PlayerCommandType) -> Vector2:
	if command.aim_up:
		return Vector2.UP
	if command.aim_down:
		return Vector2.DOWN
	return Vector2(_motor.facing_direction, 0.0)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> bool:
	return apply_damage(DamageRequestType.new(amount, knockback))


func apply_damage(request: DamageRequestType) -> bool:
	var health_before_damage := _vitals.get_health()
	if not _vitals.apply_damage(request):
		return false
	if request.amount < health_before_damage:
		velocity = request.knockback
	return true


func respawn_at(checkpoint_position: Vector2) -> void:
	global_position = checkpoint_position
	velocity = Vector2.ZERO
	_vitals.restore_full()
	memory_energy = tuning.max_memory_energy / 2
	_motor.reset()
	memory_changed.emit(memory_energy, tuning.max_memory_energy)


func _on_vitals_health_changed(current: int, maximum: int) -> void:
	health_changed.emit(current, maximum)


func _on_vitals_died() -> void:
	died.emit()
