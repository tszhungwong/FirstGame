class_name ForgottenWorker
extends "res://enemies/common/enemy.gd"

enum AiState { PATROL, CHASE, WINDUP }

@export var behavior: ForgottenWorkerDefinition

var _attack_cooldown := 0.0
var _attack_windup_remaining := 0.0
var _patrol_origin := 0.0
var _patrol_direction := 1.0
var _state := AiState.PATROL


func _ready() -> void:
	assert(behavior != null, "ForgottenWorker requires behavior tuning")
	super()
	_patrol_origin = global_position.x


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var previous_windup := _attack_windup_remaining
	_attack_windup_remaining = maxf(_attack_windup_remaining - delta, 0.0)
	if previous_windup > 0.0:
		_state = AiState.WINDUP
		queue_redraw()
	var player := get_target()
	if previous_windup > 0.0:
		velocity.x = 0.0
		if _attack_windup_remaining <= 0.0 and player != null:
			var strike_offset := player.global_position - global_position
			if (
				absf(strike_offset.x) <= behavior.attack_range * behavior.strike_range_multiplier
				and absf(strike_offset.y) < behavior.vertical_detection_range
				and has_clear_attack_path(player)
			):
				player.apply_damage(DamageRequestType.new(
					behavior.contact_damage,
					Vector2(signf(strike_offset.x) * behavior.knockback.x, behavior.knockback.y),
					DamageRequestType.DamageType.IMPACT,
					self
				))
	elif player != null:
		var offset := player.global_position - global_position
		if absf(offset.x) <= behavior.detection_range and absf(offset.y) < behavior.vertical_detection_range:
			_state = AiState.CHASE
			if absf(offset.x) > behavior.attack_range:
				velocity.x = signf(offset.x) * behavior.move_speed
			elif _attack_cooldown <= 0.0:
				_attack_cooldown = behavior.attack_interval
				_attack_windup_remaining = behavior.attack_windup
				queue_redraw()
		else:
			_patrol()
	else:
		_patrol()
	super(delta)


func _patrol() -> void:
	_state = AiState.PATROL
	if absf(global_position.x - _patrol_origin) >= behavior.patrol_distance:
		_patrol_direction *= -1.0
	velocity.x = _patrol_direction * behavior.move_speed * behavior.patrol_speed_multiplier


func _draw() -> void:
	draw_rect(Rect2(-17.0, -23.0, 34.0, 46.0), Color("d36d5f"))
	draw_rect(Rect2(-12.0, -18.0, 24.0, 8.0), Color("5b2527"))
	draw_line(Vector2(12.0, -4.0), Vector2(28.0, 12.0), Color("ffc857"), 6.0)
	if _attack_windup_remaining > 0.0:
		var strike_range := behavior.attack_range * behavior.strike_range_multiplier
		var attack_rect := Rect2(
			-strike_range,
			-behavior.vertical_detection_range,
			strike_range * 2.0,
			behavior.vertical_detection_range * 2.0
		)
		draw_rect(attack_rect, Color(1.0, 0.2, 0.12, 0.16), true)
		draw_rect(attack_rect, Color("ff6b4a"), false, 3.0)
