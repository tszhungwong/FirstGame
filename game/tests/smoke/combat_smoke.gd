extends Node

const SANDBOX_PATH := "res://scenes/combat_sandbox.tscn"


func _ready() -> void:
	var sandbox_scene := load(SANDBOX_PATH) as PackedScene
	if sandbox_scene == null:
		printerr("COMBAT_SMOKE_FAILED: sandbox scene did not load")
		get_tree().quit(1)
		return

	var sandbox: Node = sandbox_scene.instantiate()
	add_child(sandbox)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ember: Node = sandbox.get_node_or_null("Ember")
	var pool: Node = sandbox.get_node_or_null("ProjectilePool")
	var joystick: Node = sandbox.get_node_or_null("CombatHud/HudRoot/VirtualJoystick")
	var dash_button: Node = sandbox.get_node_or_null("CombatHud/HudRoot/DashButton")
	var skill_button: Node = sandbox.get_node_or_null("CombatHud/HudRoot/SkillButton")
	var camera: Node = sandbox.get_node_or_null("Ember/Camera")
	var archetypes: Dictionary[int, bool] = {}
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy_definition: EnemyDefinition = enemy.get("definition") as EnemyDefinition
		if enemy_definition != null:
			archetypes[enemy_definition.archetype] = true
	if (
		ember == null
		or pool == null
		or joystick == null
		or dash_button == null
		or skill_button == null
		or camera == null
		or archetypes.size() < 3
	):
		printerr("COMBAT_SMOKE_FAILED: required combat actors are missing")
		get_tree().quit(1)
		return

	ember.call("request_dash")
	ember.call("request_active_skill")
	for _frame: int in 120:
		await get_tree().physics_frame
	if not is_instance_valid(ember) or not ember.call("is_alive"):
		printerr("COMBAT_SMOKE_FAILED: ember did not survive the smoke interval")
		get_tree().quit(1)
		return
	print("COMBAT_SMOKE_OK: ember, enemies, pool, dash, and active skill are live")
	get_tree().quit(0)
