class_name AppSettingsController
extends Node

signal locale_changed(locale: StringName)

const DEFAULT_LOCALE := &"en"
const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"zh_Hans", &"zh_Hant"]
const DEFAULT_STORAGE_PATH := "user://settings.cfg"

var _locale := DEFAULT_LOCALE
var _storage_path := DEFAULT_STORAGE_PATH


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	load_settings()


func configure_storage(storage_path: String) -> void:
	assert(not storage_path.is_empty(), "Settings storage path cannot be empty")
	_storage_path = storage_path


func get_locale() -> StringName:
	return _locale


func set_locale(requested_locale: StringName) -> void:
	var normalized_locale := _normalize_locale(requested_locale)
	if normalized_locale == _locale:
		TranslationServer.set_locale(String(_locale))
		_save_settings()
		return
	_locale = normalized_locale
	TranslationServer.set_locale(String(_locale))
	_save_settings()
	locale_changed.emit(_locale)


func load_settings() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(_storage_path)
	var requested_locale := StringName(OS.get_locale())
	if load_error == OK:
		requested_locale = StringName(
			config.get_value("localization", "locale", String(DEFAULT_LOCALE))
		)
	_locale = _normalize_locale(requested_locale)
	TranslationServer.set_locale(String(_locale))
	locale_changed.emit(_locale)


func _save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("localization", "locale", String(_locale))
	var save_error := config.save(_storage_path)
	if save_error != OK:
		push_error("Unable to save settings to %s (error %d)" % [_storage_path, save_error])
		return false
	return true


func _normalize_locale(requested_locale: StringName) -> StringName:
	var locale_text := String(requested_locale).replace("-", "_")
	if locale_text in ["zh_Hans", "zh_CN", "zh_SG"]:
		return &"zh_Hans"
	if locale_text in ["zh_Hant", "zh_TW", "zh_HK", "zh_MO"]:
		return &"zh_Hant"
	if locale_text.begins_with("en"):
		return &"en"
	return DEFAULT_LOCALE
