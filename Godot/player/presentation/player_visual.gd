class_name PlayerVisual
extends Node2D


func sync_state(_state: PlayerVisualState) -> void:
	pass


func set_hurt(_is_hurt: bool) -> void:
	pass


func show_attack(
	_direction: Vector2,
	_size: Vector2,
	_reach: float,
	_color: Color,
	_duration: float
) -> void:
	pass
