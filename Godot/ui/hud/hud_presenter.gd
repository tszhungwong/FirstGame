class_name HUDPresenter
extends CanvasLayer

@onready var _status := $Status as Label
@onready var _objective := $Objective as Label
@onready var _boss_status := $BossStatus as Label
@onready var _controls := $Controls as Label
@onready var _dialog_panel := $DialogPanel as ColorRect
@onready var _dialog := $DialogPanel/Dialog as Label
@onready var _continue_hint := $DialogPanel/ContinueHint as Label

var _objective_key := &"objective.find_exit"
var _dialogue_request: DialogueRequest
var _boss_current := 0
var _boss_maximum := 0
var _boss_status_active := false


func _ready() -> void:
	refresh_locale()


func update_status(health: int, max_health: int, memory: int, max_memory: int) -> void:
	_status.text = tr(&"ui.status") % [health, max_health, memory, max_memory]


func set_objective(objective_key: StringName) -> void:
	_objective_key = objective_key
	_objective.text = tr(&"ui.objective") % tr(_objective_key)


func show_boss_status(current: int, maximum: int) -> void:
	_boss_current = current
	_boss_maximum = maximum
	_boss_status_active = true
	_boss_status.visible = true
	_boss_status.text = tr(&"ui.boss_status") % [current, maximum]


func hide_boss_status() -> void:
	_boss_status_active = false
	_boss_status.visible = false


func show_dialog(request: DialogueRequest) -> void:
	_dialogue_request = request
	_dialog.text = tr(request.text_key)
	_dialog_panel.visible = true


func hide_dialog() -> void:
	_dialog_panel.visible = false
	_dialogue_request = null


func is_dialog_visible() -> bool:
	return _dialog_panel.visible


func refresh_locale() -> void:
	_controls.text = tr(&"ui.controls")
	_continue_hint.text = tr(&"ui.continue")
	set_objective(_objective_key)
	if _dialogue_request != null:
		_dialog.text = tr(_dialogue_request.text_key)
	if _boss_status_active and _boss_maximum > 0:
		show_boss_status(_boss_current, _boss_maximum)
