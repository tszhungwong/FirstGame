class_name DialogueController
extends Node

const DialogueRequestType := preload("res://dialogue/dialogue_request.gd")

signal dialogue_changed(request: DialogueRequestType)
signal dialogue_hidden

var _current: DialogueRequestType
var _queue: Array[DialogueRequestType] = []
var _seen_once_keys: Dictionary[StringName, bool] = {}
var _time_remaining := 0.0


func _process(delta: float) -> void:
	tick(delta)


func present(request: DialogueRequestType) -> bool:
	assert(request != null, "Dialogue request cannot be null")
	assert(not request.text_key.is_empty(), "Dialogue request requires a text key")
	if not request.once_key.is_empty() and _seen_once_keys.has(request.once_key):
		return false
	if not request.once_key.is_empty():
		_seen_once_keys[request.once_key] = true
	if _current == null:
		_activate(request)
	elif request.priority > _current.priority:
		_queue.push_front(_current)
		_activate(request)
	else:
		_queue.append(request)
	return true


func advance_or_dismiss() -> void:
	if _current == null:
		return
	_show_next_or_hide()


func tick(delta: float) -> void:
	if _current == null or _current.dismiss_mode == DialogueRequestType.DismissMode.INPUT_ONLY:
		return
	_time_remaining = maxf(_time_remaining - delta, 0.0)
	if _time_remaining <= 0.0:
		_show_next_or_hide()


func is_visible() -> bool:
	return _current != null


func get_current_text_key() -> StringName:
	return _current.text_key if _current != null else &""


func get_current_text() -> String:
	return tr(get_current_text_key()) if _current != null else ""


func get_current_request() -> DialogueRequestType:
	return _current


func clear() -> void:
	_queue.clear()
	_current = null
	_time_remaining = 0.0
	dialogue_hidden.emit()


func _activate(request: DialogueRequestType) -> void:
	_current = request
	_time_remaining = request.duration
	dialogue_changed.emit(request)


func _show_next_or_hide() -> void:
	if _queue.is_empty():
		_current = null
		_time_remaining = 0.0
		dialogue_hidden.emit()
		return
	_activate(_queue.pop_front())
