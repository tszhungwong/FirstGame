class_name AbandonedMaintenanceLevel
extends GameLevel

@onready var _boss := $EchoForeman as EchoForeman
@onready var _lamplighter := $Lamplighter as Interactable
@onready var _return_gate := $ReturnGate as StaticBody2D
@onready var _return_gate_collision := $ReturnGate/CollisionShape2D as CollisionShape2D
@onready var _enemies: Array[Enemy] = [
	$WorkerA,
	$WorkerB,
	$WorkerC,
	$WorkerD,
	$DroneA,
	$DroneB,
	$EchoForeman,
]
@onready var _respawnable_enemies: Array[Enemy] = [
	$WorkerA,
	$WorkerB,
	$WorkerC,
	$WorkerD,
	$DroneA,
	$DroneB,
]
@onready var _interactables: Array[Interactable] = [
	$Lamplighter,
	$SkillTerminal,
	$MemoryFragment,
	$HiddenMemory,
	$ReturnControl,
]


func _ready() -> void:
	_boss.defeated.connect(boss_defeated.emit)
	_boss.health_changed.connect(boss_health_changed.emit)
	_boss.battle_line_spoken.connect(battle_line_spoken.emit)
	for interactable: Interactable in _interactables:
		interactable.interacted.connect(_on_interacted.bind(interactable))
	$Checkpoint.activated.connect(checkpoint_activated.emit)
	$SupervisorBroadcast.triggered.connect(message_triggered.emit)
	queue_redraw()


func configure(player: Player, interaction_controller: InteractionController) -> void:
	for enemy: Enemy in _enemies:
		enemy.set_target(player)
	for interactable: Interactable in _interactables:
		interaction_controller.register(interactable)


func restore_run_state(run_state: RunState, interaction_controller: InteractionController) -> void:
	for interactable: Interactable in _interactables:
		if run_state.is_completed(interactable.interaction_id):
			interactable.restore_completed()
			interaction_controller.unregister(interactable)
	if run_state.is_completed(&"supervisor_broadcast"):
		$SupervisorBroadcast.restore_triggered()
	if run_state.is_completed(&"boss_defeated"):
		_boss.restore_defeated()
		hide_lamplighter(interaction_controller)
	if run_state.is_completed(&"return_route"):
		open_return_route()


func reset_respawnable_enemies() -> void:
	for enemy: Enemy in _respawnable_enemies:
		enemy.reset_enemy()


func open_return_route() -> void:
	_return_gate.visible = false
	_return_gate_collision.set_deferred("disabled", true)


func hide_lamplighter(interaction_controller: InteractionController) -> void:
	_lamplighter.visible = false
	_lamplighter.process_mode = Node.PROCESS_MODE_DISABLED
	interaction_controller.unregister(_lamplighter)


func apply_transition(
	transition: FlowTransition,
	interaction_controller: InteractionController
) -> void:
	if transition.hides_lamplighter:
		hide_lamplighter(interaction_controller)
	if transition.opens_return_route:
		open_return_route()


func get_primary_encounter() -> Enemy:
	return _boss


func _on_interacted(
	entry: DialogueEntry,
	interaction_id: StringName,
	source: Node
) -> void:
	interaction_requested.emit(entry, interaction_id, source)


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 3200.0, 720.0), Color("111820"))
	draw_rect(Rect2(0.0, 90.0, 1050.0, 580.0), Color("172832"))
	draw_rect(Rect2(1050.0, 90.0, 1050.0, 580.0), Color("20262f"))
	draw_rect(Rect2(2100.0, 90.0, 1100.0, 580.0), Color("281e25"))
	for pipe_y: float in [135.0, 180.0, 225.0]:
		draw_line(Vector2(0.0, pipe_y), Vector2(3200.0, pipe_y), Color("304550"), 8.0)
	for light_x: int in range(120, 3200, 280):
		draw_circle(Vector2(light_x, 112.0), 10.0, Color("6ed6ce"))
		draw_circle(Vector2(light_x, 112.0), 24.0, Color(0.3, 0.9, 0.82, 0.08))
