class_name PauseController
extends Node

signal pause_changed(is_paused: bool)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_paused(not is_paused())
		get_viewport().set_input_as_handled()


func set_paused(should_pause: bool) -> void:
	if get_tree() == null or get_tree().paused == should_pause:
		return
	get_tree().paused = should_pause
	pause_changed.emit(should_pause)


func is_paused() -> bool:
	return get_tree() != null and get_tree().paused
