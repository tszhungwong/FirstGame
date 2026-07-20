class_name RunGame
extends Node2D

const BULLET_SCENE = preload("res://combat/projectiles/pooled_bullet.tscn")
const EMBER_PATH := "res://data/mock_ember_vanguard.tres"

var controller: RunController
var ember: Ember
var projectile_pool: ObjectPool
var forest_rules: ForestRoomRules
var _room_root: Node2D
var _reward_panel: PanelContainer
var _end_panel: PanelContainer
var _end_label: Label
var _room_label: Label
var _pause_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	controller = RunController.new()
	controller.name = "RunController"
	add_child(controller)
	controller.room_started.connect(_start_room)
	controller.reward_offered.connect(_show_rewards)
	controller.run_finished.connect(_finish_run)
	_build_ui()
	if GameSession.is_run_active and not GameSession.active_run_snapshot.is_empty():
		controller.restore_run(GameSession.active_run_snapshot)
	else:
		var seed_value := int(Time.get_unix_time_from_system())
		GameSession.begin_run(seed_value)
		controller.start_run(seed_value)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if controller != null and controller.state in [RunController.State.COMBAT, RunController.State.REWARD]:
			controller.set_paused(true)
			_pause_button.text = "RESUME"
			GameSession.update_run(controller.serialize_active_run())


func _start_room(index: int, room: RoomDefinition) -> void:
	_clear_room()
	_room_root = Node2D.new()
	_room_root.name = "Room%02d" % (index + 1)
	add_child(_room_root)
	forest_rules = ForestRoomRules.new(room)
	projectile_pool = ObjectPool.new()
	projectile_pool.name = "ProjectilePool"
	_room_root.add_child(projectile_pool)
	var character := load(EMBER_PATH) as CharacterDefinition
	projectile_pool.configure(BULLET_SCENE, room.projectile_pool_capacity, room.projectile_pool_can_grow, character.starting_weapon.projectile_collision_radius)
	projectile_pool.configure_forest_rules(forest_rules)
	projectile_pool.process_mode = Node.PROCESS_MODE_INHERIT
	ember = Ember.new()
	ember.name = "Ember"
	ember.configure(character, projectile_pool, Rect2(Vector2.ZERO, room.arena_size), controller.combat_stats, forest_rules)
	ember.global_position = Vector2(260.0, room.arena_size.y * 0.5)
	_room_root.add_child(ember)
	if controller.room_entry_health >= 0:
		ember.health.restore_current_health(controller.room_entry_health)
	controller.set_room_entry_health(ember.health.current_health)
	ember.defeated.connect(controller.player_defeated)
	_spawn_enemies(room)
	var hud := CombatHud.new()
	hud.name = "CombatHud"
	hud.configure(ember)
	_room_root.add_child(hud)
	_room_label.text = "ROOM %d / %d   %s" % [index + 1, controller.room_count(), room.display_name.to_upper()]
	_reward_panel.visible = false
	GameSession.update_run(controller.serialize_active_run())
	queue_redraw()


func _spawn_enemies(room: RoomDefinition) -> void:
	var count := mini(room.enemy_count, mini(room.enemy_definitions.size(), room.enemy_spawn_points.size()))
	for index: int in count:
		var enemy := CombatEnemy.new()
		enemy.name = "Enemy%02d" % (index + 1)
		enemy.configure(room.enemy_definitions[index], ember, projectile_pool, Rect2(Vector2.ZERO, room.arena_size), forest_rules)
		enemy.global_position = room.enemy_spawn_points[index]
		_room_root.add_child(enemy)
		ember.register_enemy(enemy)
		enemy.defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(enemy: CombatEnemy) -> void:
	ember.unregister_enemy(enemy)
	if ember.enemy_count() == 0:
		controller.set_room_entry_health(ember.health.current_health)
		controller.complete_room.call_deferred()


func _show_rewards(choices: Array[UpgradeDefinition]) -> void:
	_freeze_combat()
	_reward_panel.visible = true
	var list := _reward_panel.get_node("Choices") as VBoxContainer
	for child: Node in list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "CLEAR — CHOOSE ONE UPGRADE"
	title.add_theme_font_size_override("font_size", 25)
	list.add_child(title)
	for choice: UpgradeDefinition in choices:
		var button := Button.new()
		button.text = "%s\n%s" % [choice.display_name, choice.description]
		button.custom_minimum_size = Vector2(480.0, 78.0)
		button.pressed.connect(_choose_reward.bind(choice.id))
		list.add_child(button)
	GameSession.update_run(controller.serialize_active_run())


func _choose_reward(id: StringName) -> void:
	controller.choose_upgrade(id)


func _finish_run(won: bool) -> void:
	get_tree().paused = false
	_freeze_combat()
	GameSession.finish_run(won, controller.current_room_index + 1)
	_end_panel.visible = true
	_end_label.text = "FOREST RESTORED" if won else "EMBER EXTINGUISHED"


func _toggle_pause() -> void:
	var should_pause := controller.state != RunController.State.PAUSED
	controller.set_paused(should_pause)
	_pause_button.text = "RESUME" if should_pause else "PAUSE"


func _clear_room() -> void:
	if is_instance_valid(_room_root):
		_room_root.queue_free()


func _freeze_combat() -> void:
	if is_instance_valid(ember):
		ember.set_physics_process(false)
		if ember.health != null:
			ember.health.invulnerable = true
	if is_instance_valid(_room_root):
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if _room_root.is_ancestor_of(node):
				node.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(projectile_pool):
		projectile_pool.release_all()
		projectile_pool.process_mode = Node.PROCESS_MODE_DISABLED


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RunUi"
	add_child(layer)
	_room_label = Label.new()
	_room_label.position = Vector2(430.0, 24.0)
	_room_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_room_label)
	_pause_button = Button.new()
	_pause_button.text = "PAUSE"
	_pause_button.position = Vector2(1150.0, 22.0)
	_pause_button.size = Vector2(100.0, 42.0)
	_pause_button.pressed.connect(_toggle_pause)
	layer.add_child(_pause_button)
	_reward_panel = PanelContainer.new()
	_reward_panel.name = "RewardPanel"
	_reward_panel.position = Vector2(390.0, 150.0)
	_reward_panel.size = Vector2(500.0, 440.0)
	_reward_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var choices := VBoxContainer.new()
	choices.name = "Choices"
	choices.add_theme_constant_override("separation", 14)
	_reward_panel.add_child(choices)
	_reward_panel.visible = false
	layer.add_child(_reward_panel)
	_end_panel = PanelContainer.new()
	_end_panel.position = Vector2(340.0, 210.0)
	_end_panel.size = Vector2(600.0, 280.0)
	_end_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 38)
	_end_panel.add_child(_end_label)
	_end_panel.visible = false
	layer.add_child(_end_panel)


func _draw() -> void:
	if controller == null or controller.current_room() == null:
		return
	var room := controller.current_room()
	draw_rect(Rect2(Vector2.ZERO, room.arena_size), Color("142521"), true)
	for mud: Rect2 in room.mud_areas:
		draw_rect(mud, Color("554933"), true)
	for river: Rect2 in room.river_areas:
		draw_rect(river, Color("245b68"), true)
	for bridge: Rect2 in room.bridge_areas:
		draw_rect(bridge, Color("9a7447"), true)
	for grass: Rect2 in room.grass_areas:
		draw_rect(grass, Color(0.18, 0.43, 0.25, 0.72), true)
	for tree: Vector2 in room.tree_positions:
		draw_circle(tree, room.tree_radius, Color("273e2b"))
		draw_circle(tree, room.tree_radius * 0.42, Color("68472f"))
	draw_rect(Rect2(Vector2.ZERO, room.arena_size), Color("779382"), false, 8.0)
