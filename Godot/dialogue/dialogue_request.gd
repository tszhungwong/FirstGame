class_name DialogueRequest
extends Resource

enum DismissMode {
	INPUT_OR_TIMEOUT,
	INPUT_ONLY,
	TIMEOUT_ONLY,
}

@export var text_key: StringName
@export var speaker_id: StringName
@export var portrait_expression := &"neutral"
@export var duration := 5.5
@export var priority := 0
@export var once_key: StringName
@export var dismiss_mode := DismissMode.INPUT_OR_TIMEOUT

