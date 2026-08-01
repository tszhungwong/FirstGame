class_name SettingsMenu
extends CanvasLayer

signal resume_requested
signal restart_requested
signal home_requested
signal locale_requested(locale: StringName)

@export var open_on_ready := true

@onready var _title_label := $Backdrop/Center/Panel/Margin/Options/Title as Label
@onready var _paused_label := $Backdrop/Center/Panel/Margin/Options/PausedLabel as Label
@onready var _language_label := $Backdrop/Center/Panel/Margin/Options/LanguageRow/LanguageLabel as Label
@onready var _locale_selector := $Backdrop/Center/Panel/Margin/Options/LanguageRow/LocaleSelector as OptionButton
@onready var _resume_button := $Backdrop/Center/Panel/Margin/Options/ResumeButton as Button
@onready var _restart_button := $Backdrop/Center/Panel/Margin/Options/RestartButton as Button
@onready var _home_button := $Backdrop/Center/Panel/Margin/Options/HomeButton as Button


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)
	_restart_button.pressed.connect(restart_requested.emit)
	_home_button.pressed.connect(home_requested.emit)
	_locale_selector.item_selected.connect(_on_locale_item_selected)
	AppSettings.locale_changed.connect(_on_locale_changed)
	_refresh_locale()
	set_open(open_on_ready)


func set_open(is_open: bool) -> void:
	visible = is_open
	if is_open and is_node_ready():
		_refresh_locale()
		_resume_button.grab_focus.call_deferred()


func _on_locale_item_selected(index: int) -> void:
	var locale := StringName(_locale_selector.get_item_metadata(index))
	locale_requested.emit(locale)


func _on_locale_changed(_locale: StringName) -> void:
	_refresh_locale()


func _refresh_locale() -> void:
	_title_label.text = tr(&"ui.settings.title")
	_paused_label.text = tr(&"ui.settings.paused")
	_language_label.text = tr(&"ui.settings.language")
	_resume_button.text = tr(&"ui.settings.resume")
	_restart_button.text = tr(&"ui.settings.restart")
	_home_button.text = tr(&"ui.settings.home")
	_rebuild_locale_selector()


func _rebuild_locale_selector() -> void:
	_locale_selector.clear()
	var current_locale := AppSettings.get_locale()
	for locale: StringName in AppSettings.SUPPORTED_LOCALES:
		var translation_key := StringName("locale.%s" % String(locale))
		_locale_selector.add_item(tr(translation_key))
		var item_index := _locale_selector.item_count - 1
		_locale_selector.set_item_metadata(item_index, locale)
		if locale == current_locale:
			_locale_selector.select(item_index)
