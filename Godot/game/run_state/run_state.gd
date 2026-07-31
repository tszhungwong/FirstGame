class_name RunState
extends Resource

signal checkpoint_changed(position: Vector2)
signal ability_granted(ability_id: StringName)

var _checkpoint_position := Vector2.ZERO
var _abilities: Dictionary[StringName, bool] = {}
var _completed: Dictionary[StringName, bool] = {}
var _objective_key := &"objective.find_exit"


func initialize(spawn_position: Vector2) -> void:
	_checkpoint_position = spawn_position


func activate_checkpoint(position: Vector2) -> void:
	_checkpoint_position = position
	checkpoint_changed.emit(position)


func get_checkpoint_position() -> Vector2:
	return _checkpoint_position


func grant_ability(ability_id: StringName) -> bool:
	if ability_id.is_empty() or _abilities.has(ability_id):
		return false
	_abilities[ability_id] = true
	ability_granted.emit(ability_id)
	return true


func has_ability(ability_id: StringName) -> bool:
	return _abilities.has(ability_id)


func mark_completed(content_id: StringName) -> void:
	if not content_id.is_empty():
		_completed[content_id] = true


func is_completed(content_id: StringName) -> bool:
	return _completed.has(content_id)


func set_objective_key(objective_key: StringName) -> void:
	if not objective_key.is_empty():
		_objective_key = objective_key


func get_objective_key() -> StringName:
	return _objective_key


func snapshot() -> Dictionary:
	return {
		"checkpoint": _checkpoint_position,
		"abilities": _abilities.keys(),
		"completed": _completed.keys(),
		"objective_key": _objective_key,
	}
