class_name ForgottenWorker
extends "res://enemies/common/enemy.gd"

enum AiState { PATROL, CHASE, ATTACK, DYING }

signal footstep_requested

@export var behavior: ForgottenWorkerDefinition

@onready var _visual: ForgottenWorkerVisual = %Visual

var _attack_cooldown := 0.0
var _patrol_origin := 0.0
var _patrol_direction := 1.0
var _state := AiState.PATROL
var _facing_direction := -1.0


func _ready() -> void:
	assert(behavior != null, "ForgottenWorker requires behavior tuning")
	super()
	_patrol_origin = global_position.x
	_visual.attack_active_frame_reached.connect(_on_attack_active_frame_reached)
	_visual.attack_finished.connect(_on_attack_finished)
	_visual.death_hurtbox_off_frame_reached.connect(_on_death_hurtbox_off_frame_reached)
	_visual.death_finished.connect(_on_death_finished)
	_visual.footstep_frame_reached.connect(footstep_requested.emit)
	_visual.sync_motion(Vector2.ZERO, true, _facing_direction)


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _state == AiState.DYING:
		velocity.x = 0.0
		super(delta)
		return
	if _state == AiState.ATTACK:
		velocity.x = 0.0
		super(delta)
		return

	var player := get_target()
	if player != null:
		var offset := player.global_position - global_position
		if absf(offset.x) <= behavior.detection_range and absf(offset.y) < behavior.vertical_detection_range:
			_state = AiState.CHASE
			_update_facing(offset.x)
			if absf(offset.x) > behavior.attack_range:
				velocity.x = signf(offset.x) * behavior.move_speed
			elif _attack_cooldown <= 0.0:
				_begin_attack()
		else:
			_patrol()
	else:
		_patrol()
	super(delta)
	_visual.sync_motion(velocity, is_on_floor(), _facing_direction)


func _patrol() -> void:
	_state = AiState.PATROL
	if absf(global_position.x - _patrol_origin) >= behavior.patrol_distance:
		_patrol_direction *= -1.0
	velocity.x = _patrol_direction * behavior.move_speed * behavior.patrol_speed_multiplier
	_update_facing(velocity.x)


func reset_enemy() -> void:
	super()
	_state = AiState.PATROL
	_attack_cooldown = 0.0
	_patrol_origin = global_position.x
	_patrol_direction = 1.0
	_facing_direction = -1.0
	_visual.reset_visual(_facing_direction)


func _begin_attack() -> void:
	if not _visual.play_attack(_facing_direction):
		return
	_state = AiState.ATTACK
	velocity.x = 0.0
	_attack_cooldown = behavior.attack_interval


func _update_facing(horizontal_direction: float) -> void:
	if not is_zero_approx(horizontal_direction):
		_facing_direction = signf(horizontal_direction)


func _on_attack_active_frame_reached() -> void:
	if _state != AiState.ATTACK:
		return
	var player := get_target()
	if player == null:
		return
	var strike_offset := player.global_position - global_position
	if (
		absf(strike_offset.x) > behavior.attack_range * behavior.strike_range_multiplier
		or absf(strike_offset.y) >= behavior.vertical_detection_range
		or not has_clear_attack_path(player)
	):
		return
	player.apply_damage(DamageRequestType.new(
		behavior.contact_damage,
		Vector2(signf(strike_offset.x) * behavior.knockback.x, behavior.knockback.y),
		DamageRequestType.DamageType.IMPACT,
		self
	))


func _on_attack_finished() -> void:
	if _state != AiState.ATTACK:
		return
	_state = AiState.CHASE if get_target() != null else AiState.PATROL
	_visual.sync_motion(velocity, is_on_floor(), _facing_direction)


func _on_vitals_died() -> void:
	if _state == AiState.DYING:
		return
	_state = AiState.DYING
	velocity = Vector2.ZERO
	defeated.emit()
	_visual.play_death(_facing_direction)


func _on_death_hurtbox_off_frame_reached() -> void:
	if _state == AiState.DYING:
		collision_layer = 0


func _on_death_finished() -> void:
	if _state != AiState.DYING:
		return
	if definition.respawns_on_checkpoint:
		_set_active(false)
	else:
		queue_free()
