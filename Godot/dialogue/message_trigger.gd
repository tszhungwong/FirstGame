class_name MessageTrigger
extends Area2D

signal triggered(text_key: StringName)

@export var message_key: StringName
var _has_triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	activate(body)


func activate(body: Node2D) -> void:
	if _has_triggered or not body.is_in_group("player"):
		return
	_has_triggered = true
	set_deferred("monitoring", false)
	triggered.emit(message_key)


func has_triggered() -> bool:
	return _has_triggered


func restore_triggered() -> void:
	_has_triggered = true
	monitoring = false
