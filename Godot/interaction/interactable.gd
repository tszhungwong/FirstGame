class_name Interactable
extends Area2D

signal interacted(entry: DialogueEntry, interaction_id: StringName)

@export var dialogue: DialogueSequence
@export var interaction_id: StringName
@export var display_color := Color("f4c95d")
@export var display_size := Vector2(34.0, 54.0)
@export var one_shot := false
@export var show_interaction_prompt := true
@export var interaction_prompt_key := &"ui.interact"
@export var identity_label_key: StringName

@onready var _interaction_prompt := $InteractionPrompt as Label
@onready var _identity_label := $IdentityLabel as WorldIdentityLabel

var _line_index := 0
var _completed := false


func _ready() -> void:
	_identity_label.set_text_key(identity_label_key)
	_refresh_localized_text()
	AppSettings.locale_changed.connect(_on_locale_changed)
	_interaction_prompt.visible = false


func can_interact() -> bool:
	return dialogue != null and not dialogue.is_empty() and not (_completed and one_shot)


func set_interaction_prompt_visible(is_visible: bool) -> void:
	_interaction_prompt.visible = (
		is_visible
		and show_interaction_prompt
		and can_interact()
	)


func interact(_player: Node) -> void:
	if not can_interact():
		return
	if one_shot:
		for index in range(_line_index, dialogue.entries.size()):
			interacted.emit(dialogue.entry_at(index), interaction_id)
		_line_index = dialogue.entries.size() - 1
		_completed = true
		_interaction_prompt.visible = false
	else:
		interacted.emit(dialogue.entry_at(_line_index), interaction_id)
		_line_index = mini(_line_index + 1, dialogue.entries.size() - 1)
	queue_redraw()


func restore_completed() -> void:
	if not one_shot:
		return
	_completed = true
	_interaction_prompt.visible = false
	queue_redraw()


func _on_locale_changed(_locale: StringName) -> void:
	_refresh_localized_text()


func _refresh_localized_text() -> void:
	_interaction_prompt.text = tr(interaction_prompt_key)


func _draw() -> void:
	var draw_color := display_color.darkened(0.45) if _completed else display_color
	draw_rect(Rect2(-display_size * 0.5, display_size), draw_color)
	draw_circle(Vector2(0.0, -display_size.y * 0.35), 5.0, Color("fff0bb"))
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.18), 2.0)
