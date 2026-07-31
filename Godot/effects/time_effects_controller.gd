class_name TimeEffectsController
extends Node

signal hit_stop_started(duration: float, scale: float)
signal hit_stop_finished

var _hit_stop_deadline_msec := 0
var _restore_scale := 1.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if is_hit_stop_active() and Time.get_ticks_msec() >= _hit_stop_deadline_msec:
		cancel_hit_stop()


func request_hit_stop(duration: float, scale := 0.08) -> void:
	if duration <= 0.0:
		return
	var now_msec := Time.get_ticks_msec()
	var requested_deadline := now_msec + int(duration * 1000.0)
	if not is_hit_stop_active():
		_restore_scale = Engine.time_scale
	_hit_stop_deadline_msec = maxi(_hit_stop_deadline_msec, requested_deadline)
	Engine.time_scale = clampf(scale, 0.01, 1.0)
	hit_stop_started.emit(duration, scale)


func cancel_hit_stop() -> void:
	if _hit_stop_deadline_msec == 0:
		return
	_hit_stop_deadline_msec = 0
	Engine.time_scale = _restore_scale
	hit_stop_finished.emit()


func is_hit_stop_active() -> bool:
	return _hit_stop_deadline_msec > 0


func _exit_tree() -> void:
	cancel_hit_stop()
