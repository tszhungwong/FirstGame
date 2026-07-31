class_name GameLevel
extends Node2D

signal boss_defeated
signal boss_health_changed(current: int, maximum: int)
signal battle_line_spoken(text_key: StringName)
signal interaction_requested(entry: DialogueEntry, interaction_id: StringName, source: Node)
signal checkpoint_activated(position: Vector2, first_activation: bool)
signal message_triggered(text_key: StringName)


func configure(_player: Player, _interaction_controller: InteractionController) -> void:
	push_error("GameLevel.configure must be implemented")


func restore_run_state(_run_state: RunState, _interaction_controller: InteractionController) -> void:
	pass


func reset_respawnable_enemies() -> void:
	pass


func apply_transition(
	_transition: FlowTransition,
	_interaction_controller: InteractionController
) -> void:
	pass


func get_primary_encounter() -> Enemy:
	return null
