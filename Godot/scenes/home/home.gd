class_name Home
extends Control

@export_file("*.tscn") var game_scene_path: String

@onready var _title_label := $Backdrop/Center/Panel/Margin/Content/Title as Label
@onready var _subtitle_label := $Backdrop/Center/Panel/Margin/Content/Subtitle as Label
@onready var _start_button := $Backdrop/Center/Panel/Margin/Content/StartButton as Button


func _ready() -> void:
	assert(not game_scene_path.is_empty(), "Home requires a game scene path")
	_start_button.pressed.connect(_start_game)
	AppSettings.locale_changed.connect(_on_locale_changed)
	_refresh_locale()
	_start_button.grab_focus.call_deferred()


func _start_game() -> void:
	var change_error := get_tree().change_scene_to_file(game_scene_path)
	if change_error != OK:
		push_error("Unable to start game scene (error %d)" % change_error)


func _on_locale_changed(_locale: StringName) -> void:
	_refresh_locale()


func _refresh_locale() -> void:
	_title_label.text = tr(&"ui.home.title")
	_subtitle_label.text = tr(&"ui.home.subtitle")
	_start_button.text = tr(&"ui.home.start")
