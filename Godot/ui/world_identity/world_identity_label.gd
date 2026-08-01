class_name WorldIdentityLabel
extends Label

@export var text_key: StringName


func _ready() -> void:
	_refresh_localized_text()
	AppSettings.locale_changed.connect(_on_locale_changed)


func set_text_key(value: StringName) -> void:
	text_key = value
	if is_node_ready():
		_refresh_localized_text()


func _on_locale_changed(_locale: StringName) -> void:
	_refresh_localized_text()


func _refresh_localized_text() -> void:
	visible = not text_key.is_empty()
	text = tr(text_key) if visible else ""
