class_name VerticalSliceFlow
extends RefCounted

const FlowTransitionType := preload("res://game/vertical_slice_flow/flow_transition.gd")

const EVENT_SKILL_TERMINAL := &"skill_terminal"
const EVENT_MEMORY_FRAGMENT := &"memory_fragment"
const EVENT_BOSS_DEFEATED := &"boss_defeated"
const EVENT_RETURN_CONTROL := &"return_control"

var _wall_module_unlocked := false


func restore_from_run_state(run_state: RunState) -> void:
	_wall_module_unlocked = run_state.has_ability(&"wall_module")


func get_initial_objective_key() -> StringName:
	return &"objective.find_exit"


func handle_event(event_id: StringName) -> FlowTransitionType:
	var transition := FlowTransitionType.new()
	match event_id:
		EVENT_SKILL_TERMINAL:
			transition.objective_key = &"objective.use_direction_skill"
			transition.granted_ability = &"directional_skill"
		EVENT_MEMORY_FRAGMENT:
			transition.objective_key = &"objective.reach_lockdown"
		EVENT_BOSS_DEFEATED:
			_wall_module_unlocked = true
			transition.objective_key = &"objective.use_wall_module"
			transition.dialogue_key = &"dialog.boss_defeated"
			transition.granted_ability = &"wall_module"
			transition.hides_lamplighter = true
		EVENT_RETURN_CONTROL:
			if _wall_module_unlocked:
				transition.objective_key = &"objective.complete"
				transition.dialogue_key = &"dialog.return_open"
				transition.opens_return_route = true
	return transition
