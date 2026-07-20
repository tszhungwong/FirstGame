extends Node

signal session_paused
signal session_resumed
signal run_state_changed(active: bool)

var active_run_seed: int = 0
var is_run_active: bool = false
var active_run_snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var loaded: Dictionary = LocalSave.load_data()
	active_run_snapshot = loaded.get("active_run", {})
	if not active_run_snapshot.is_empty():
		active_run_seed = int(active_run_snapshot.get("seed", 0))
		is_run_active = true


func begin_run(seed_value: int) -> void:
	active_run_seed = seed_value
	is_run_active = true
	active_run_snapshot = {"seed": seed_value, "room_index": 0, "upgrade_stacks": {}}
	run_state_changed.emit(true)
	persist()


func update_run(snapshot: Dictionary) -> void:
	active_run_snapshot = snapshot.duplicate(true)
	is_run_active = not active_run_snapshot.is_empty()
	if is_run_active:
		active_run_seed = int(active_run_snapshot.get("seed", active_run_seed))
	persist()


func finish_run(won: bool, reached_room: int) -> void:
	var data: Dictionary = LocalSave.load_data()
	data.progress.best_room = maxi(int(data.progress.get("best_room", 0)), reached_room)
	if won:
		data.progress.wins = int(data.progress.get("wins", 0)) + 1
	data.active_run = {}
	LocalSave.save_data(data)
	active_run_snapshot = {}
	is_run_active = false
	run_state_changed.emit(false)


func persist() -> void:
	var data: Dictionary = LocalSave.load_data()
	data.active_run = active_run_snapshot if is_run_active else {}
	LocalSave.save_data(data)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if is_run_active:
				persist()
			session_paused.emit()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			session_resumed.emit()
