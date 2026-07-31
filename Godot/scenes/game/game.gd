class_name Game
extends Node2D

const DialogueRequestType := preload("res://dialogue/dialogue_request.gd")
const VerticalSliceFlowType := preload("res://game/vertical_slice_flow/vertical_slice_flow.gd")
const RunStateType := preload("res://game/run_state/run_state.gd")
const DEFAULT_DIALOG_DURATION := 5.5
const BATTLE_DIALOG_DURATION := 3.2
const CHECKPOINT_DIALOG_DURATION := 2.0
const INTERACTION_DISTANCE := 112.0

@onready var _player := $Player as Player
@onready var _level_container := $LevelContainer as Node2D
@onready var _hud := $HUD as HUDPresenter
@onready var _dialogue_controller := $Systems/DialogueController as DialogueController
@onready var _interaction_controller := $Systems/InteractionController as InteractionController
@onready var _time_effects := $Systems/TimeEffectsController as TimeEffectsController

var _return_route_open := false
var _objective_key := &"objective.find_exit"
var _flow := VerticalSliceFlowType.new()
var _run_state := RunStateType.new()
var _run_state_was_injected := false
var _level: GameLevel
var _boss: Enemy


func _ready() -> void:
	if not _run_state_was_injected:
		_run_state.initialize(_player.global_position)
	_player.died.connect(_on_player_died)
	_player.hit_confirmed.connect(_time_effects.request_hit_stop)
	_dialogue_controller.dialogue_changed.connect(_on_dialogue_changed)
	_dialogue_controller.dialogue_hidden.connect(_on_dialogue_hidden)
	AppSettings.locale_changed.connect(_on_locale_changed)
	_hud.hide_dialog()
	_attach_level(_level_container.get_child(0) as GameLevel)
	_refresh_localized_ui()
	queue_redraw()


func _process(_delta: float) -> void:
	_hud.update_status(
		_player.health,
		_player.max_health,
		_player.memory_energy,
		_player.max_memory_energy
	)
	_hud.set_objective(_objective_key)
	if Input.is_action_just_pressed("interact"):
		if _dialogue_controller.is_visible():
			_dialogue_controller.advance_or_dismiss()
		else:
			_interact_with_nearest()
	_update_interaction_prompts()


func get_player() -> CharacterBody2D:
	return _player


func activate_checkpoint(checkpoint_position: Vector2) -> void:
	_run_state.activate_checkpoint(checkpoint_position)


func get_boss() -> CharacterBody2D:
	return _boss


func is_return_route_open() -> bool:
	return _return_route_open


func get_dialogue_controller() -> DialogueController:
	return _dialogue_controller


func configure_run_state(run_state: RunState) -> void:
	assert(run_state != null, "Game requires a valid RunState")
	_run_state = run_state
	_run_state_was_injected = true
	if is_node_ready() and _level != null:
		_hydrate_runtime_from_run_state()


func replace_level(level_scene: PackedScene) -> void:
	assert(level_scene != null, "A level scene is required")
	if _level != null:
		_level_container.remove_child(_level)
		_level.queue_free()
	var next_level := level_scene.instantiate() as GameLevel
	assert(next_level != null, "Level scene root must inherit GameLevel")
	_level_container.add_child(next_level)
	_attach_level(next_level)


func _on_player_died() -> void:
	_level.reset_respawnable_enemies()
	_player.respawn_at(_run_state.get_checkpoint_position())
	present_dialogue(&"dialog.respawn")


func _on_boss_defeated() -> void:
	_run_state.mark_completed(&"boss_defeated")
	_apply_flow_transition(_flow.handle_event(&"boss_defeated"))
	_hud.hide_boss_status()


func _interact_with_nearest() -> void:
	_interaction_controller.try_interact(
		_player,
		_player.global_position,
		INTERACTION_DISTANCE
	)


func _update_interaction_prompts() -> void:
	_interaction_controller.update_prompts(
		_player.global_position,
		INTERACTION_DISTANCE,
		not _dialogue_controller.is_visible()
	)


func _on_interacted(
	entry: DialogueEntry,
	interaction_id: StringName,
	source: Node
) -> void:
	present_dialogue_entry(entry)
	var should_apply_flow := true
	if source is Interactable and source.one_shot:
		should_apply_flow = not _run_state.is_completed(interaction_id)
		_run_state.mark_completed(interaction_id)
	if not should_apply_flow:
		return
	var transition = _flow.handle_event(interaction_id)
	_apply_flow_transition(transition)
	if transition.opens_return_route:
		source.visible = false


func activate_return_route() -> void:
	_run_state.mark_completed(&"return_route")
	_return_route_open = true
	_objective_key = &"objective.complete"
	_run_state.set_objective_key(_objective_key)
	var transition := FlowTransition.new()
	transition.opens_return_route = true
	_level.apply_transition(transition, _interaction_controller)
	present_dialogue(&"dialog.return_open")


func _on_message_triggered(message_key: StringName) -> void:
	_run_state.mark_completed(&"supervisor_broadcast")
	present_dialogue(message_key)


func _on_checkpoint_activated(
	checkpoint_position: Vector2,
	first_activation: bool
) -> void:
	activate_checkpoint(checkpoint_position)
	if first_activation:
		present_dialogue(
			&"dialog.checkpoint",
			CHECKPOINT_DIALOG_DURATION
		)


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_hud.show_boss_status(current, maximum)


func _show_battle_dialog(message_key: StringName) -> void:
	present_dialogue(message_key, BATTLE_DIALOG_DURATION, 1)


func present_dialogue(
	message_key: StringName,
	duration := DEFAULT_DIALOG_DURATION,
	priority := 5,
	once_key: StringName = &""
) -> void:
	var request := DialogueRequestType.new()
	request.text_key = message_key
	request.duration = duration
	request.priority = priority
	request.once_key = once_key
	_dialogue_controller.present(request)


func present_dialogue_entry(
	entry: DialogueEntry,
	duration := DEFAULT_DIALOG_DURATION,
	priority := 5,
	once_key: StringName = &""
) -> void:
	var request := DialogueRequestType.new()
	request.text_key = entry.text_key
	request.speaker_id = entry.speaker_id
	request.portrait_expression = entry.portrait_expression
	request.duration = duration
	request.priority = priority
	request.once_key = once_key
	_dialogue_controller.present(request)


func _apply_flow_transition(transition: FlowTransition) -> void:
	if not transition.objective_key.is_empty():
		_objective_key = transition.objective_key
		_run_state.set_objective_key(_objective_key)
	if transition.granted_ability == &"directional_skill":
		_player.enable_skill()
		_run_state.grant_ability(transition.granted_ability)
	elif transition.granted_ability == &"wall_module":
		_player.has_wall_module = true
		_run_state.grant_ability(transition.granted_ability)
	if transition.opens_return_route:
		activate_return_route()
	else:
		_level.apply_transition(transition, _interaction_controller)
		if not transition.dialogue_key.is_empty():
			present_dialogue(transition.dialogue_key, DEFAULT_DIALOG_DURATION, 10)


func _on_dialogue_changed(request: DialogueRequest) -> void:
	_hud.show_dialog(request)


func _on_dialogue_hidden() -> void:
	_hud.hide_dialog()


func _on_locale_changed(_locale: StringName) -> void:
	_hud.refresh_locale()


func _refresh_localized_ui() -> void:
	_hud.set_objective(_objective_key)
	_hud.refresh_locale()


func _attach_level(level: GameLevel) -> void:
	assert(level != null, "LevelContainer requires a GameLevel child")
	_level = level
	_level.configure(_player, _interaction_controller)
	_level.boss_defeated.connect(_on_boss_defeated)
	_level.boss_health_changed.connect(_on_boss_health_changed)
	_level.battle_line_spoken.connect(_show_battle_dialog)
	_level.interaction_requested.connect(_on_interacted)
	_level.checkpoint_activated.connect(_on_checkpoint_activated)
	_level.message_triggered.connect(_on_message_triggered)
	_boss = _level.get_primary_encounter()
	_hydrate_runtime_from_run_state()


func _hydrate_runtime_from_run_state() -> void:
	_flow.restore_from_run_state(_run_state)
	_objective_key = _run_state.get_objective_key()
	if _run_state.has_ability(&"directional_skill"):
		_player.enable_skill()
	if _run_state.has_ability(&"wall_module"):
		_player.has_wall_module = true
	_level.restore_run_state(_run_state, _interaction_controller)
	_return_route_open = _run_state.is_completed(&"return_route")
	if _boss == null or _run_state.is_completed(&"boss_defeated"):
		_hud.hide_boss_status()
	else:
		_on_boss_health_changed(_boss.health, _boss.max_health)
