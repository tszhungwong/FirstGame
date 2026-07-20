extends Node

const SANDBOX_PATH := "res://scenes/combat_sandbox.tscn"
const EMBER_DEFINITION_PATH := "res://data/mock_ember_vanguard.tres"
const ROOM_DEFINITION_PATH := "res://data/mock_forest_combat_room.tres"


func _ready() -> void:
	var ember_definition := load(EMBER_DEFINITION_PATH) as CharacterDefinition
	var room_definition := load(ROOM_DEFINITION_PATH) as RoomDefinition
	if not _combat_tuning_is_data_driven(ember_definition, room_definition):
		printerr("COMBAT_SMOKE_FAILED: collision or pool tuning is missing from typed resources")
		get_tree().quit(1)
		return

	var sandbox_scene := load(SANDBOX_PATH) as PackedScene
	if sandbox_scene == null:
		printerr("COMBAT_SMOKE_FAILED: sandbox scene did not load")
		get_tree().quit(1)
		return

	var sandbox := sandbox_scene.instantiate() as CombatSandbox
	add_child(sandbox)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ember := sandbox.get_node_or_null("Ember") as Ember
	var pool := sandbox.get_node_or_null("ProjectilePool") as ObjectPool
	var joystick := sandbox.get_node_or_null("CombatHud/HudRoot/VirtualJoystick") as VirtualJoystick
	var dash_button := sandbox.get_node_or_null("CombatHud/HudRoot/DashButton") as Button
	var skill_button := sandbox.get_node_or_null("CombatHud/HudRoot/SkillButton") as Button
	var health_label := sandbox.get_node_or_null("CombatHud/HudRoot/HealthLabel") as Label
	var enemy_label := sandbox.get_node_or_null("CombatHud/HudRoot/EnemyLabel") as Label
	var camera := sandbox.get_node_or_null("Ember/Camera") as Camera2D
	var archetypes: Dictionary[int, bool] = {}
	var enemies: Array[CombatEnemy] = []
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		var typed_enemy := enemy as CombatEnemy
		if typed_enemy == null:
			continue
		enemies.append(typed_enemy)
		var enemy_definition: EnemyDefinition = typed_enemy.definition
		if enemy_definition != null:
			archetypes[enemy_definition.archetype] = true
	if (
		ember == null
		or pool == null
		or joystick == null
		or dash_button == null
		or skill_button == null
		or health_label == null
		or enemy_label == null
		or camera == null
		or archetypes.size() < 3
		or not _runtime_tuning_matches_resources(ember, pool, room_definition)
	):
		printerr("COMBAT_SMOKE_FAILED: required combat actors are missing")
		get_tree().quit(1)
		return

	if not _require(camera.enabled, "camera is not enabled"):
		return
	if not _require(is_equal_approx(camera.position_smoothing_speed, ember_definition.camera_smoothing_speed), "camera tuning is not resource driven"):
		return
	var melee := _enemy_of_type(enemies, EnemyDefinition.Archetype.MELEE_CHASER)
	if not _require(melee != null, "melee enemy is missing"):
		return
	var shooter := _enemy_of_type(enemies, EnemyDefinition.Archetype.RANGED_SHOOTER)
	if not _require(shooter != null, "ranged enemy is missing"):
		return
	var charger := _enemy_of_type(enemies, EnemyDefinition.Archetype.TELEGRAPHED_CHARGER)
	if not _require(charger != null, "charger enemy is missing"):
		return
	var player_health: HealthComponent = ember.get_health_component()

	# Keep every actor live while proving each autonomous combat behavior.
	pool.release_all()
	_park_enemies_except(enemies, melee, room_definition.arena_size)
	melee.global_position = ember.global_position + Vector2(180.0, 0.0)
	var nearest_health_before: int = melee.health.current_health
	var other_health_before: Dictionary[int, int] = {}
	for enemy: CombatEnemy in enemies:
		if enemy != melee:
			other_health_before[enemy.get_instance_id()] = enemy.health.current_health
	if not _require(
		await _wait_until_enemy_damaged(melee, nearest_health_before, 45),
		"Ember automatic fire did not damage the nearest enemy"
	):
		return
	for enemy: CombatEnemy in enemies:
		if enemy == melee:
			continue
		if not _require(
			enemy.health.current_health == other_health_before[enemy.get_instance_id()],
			"Ember automatic fire targeted a farther enemy"
		):
			return

	pool.release_all()
	_park_enemies_except(enemies, shooter, room_definition.arena_size)
	shooter.global_position = ember.global_position + Vector2(700.0, 0.0)
	var shooter_start: Vector2 = shooter.global_position
	var shooter_distance_before: float = shooter.global_position.distance_to(ember.global_position)
	await _wait_physics_frames(8)
	if not _require(
		shooter.global_position.distance_to(shooter_start) > 1.0
		and shooter.global_position.distance_to(ember.global_position) < shooter_distance_before,
		"ranged enemy did not approach from outside its preferred range"
	):
		return
	pool.release_all()
	shooter.global_position = ember.global_position + Vector2(300.0, 0.0)
	var health_before_ranged_attack: int = player_health.current_health
	if not _require(
		await _wait_for_enemy_projectile_or_damage(pool, player_health, health_before_ranged_attack, 20),
		"ranged enemy did not fire an observable enemy projectile"
	):
		return

	pool.release_all()
	_park_enemies_except(enemies, charger, room_definition.arena_size)
	charger.global_position = ember.global_position + Vector2(300.0, 0.0)
	var charger_start: Vector2 = charger.global_position
	var charger_distance_before: float = charger.global_position.distance_to(ember.global_position)
	await _wait_physics_frames(6)
	if not _require(
		charger.global_position.distance_to(charger_start) < 1.0,
		"charger did not hold position during its telegraph"
	):
		return
	await _wait_physics_frames(ceili(charger.definition.telegraph_duration * 60.0) + 3)
	if not _require(
		charger.global_position.distance_to(charger_start) > 10.0
		and charger.global_position.distance_to(ember.global_position) < charger_distance_before,
		"charger did not transition from telegraph into forward charge movement"
	):
		return

	for enemy: CombatEnemy in enemies:
		if enemy != melee:
			enemy.set_physics_process(false)
	pool.release_all()
	var player_health_before: int = player_health.current_health
	melee.global_position = ember.global_position + Vector2(
		melee.definition.attack_range + melee.definition.contact_range_padding - 1.0,
		0.0
	)
	await _wait_physics_frames(3)
	if not _require(player_health.current_health < player_health_before, "enemy attack did not damage Ember"):
		return
	if not _require(health_label.text == "%d / %d" % [player_health.current_health, player_health.max_health], "health HUD did not react to damage"):
		return
	if not _require(enemy_label.text.contains("06"), "enemy-count HUD did not receive the cached target count"):
		return

	melee.set_physics_process(false)
	ember.set_physics_process(false)
	pool.release_all()
	var enemy_health_before: int = melee.health.current_health
	var damage_bullet: PooledBullet = pool.acquire()
	var damage_bullet_id: int = damage_bullet.get_instance_id()
	damage_bullet.initialize(melee.global_position, Vector2.RIGHT, 0.0, 0.25, 5, 5.5, true)
	await _wait_physics_frames(3)
	if not _require(melee.health.current_health < enemy_health_before, "player projectile did not damage an enemy"):
		return
	if not _require(pool.in_use_count() == 0, "collision projectile did not return to its pool"):
		return
	var reused_bullet: PooledBullet = pool.acquire()
	if not _require(reused_bullet.get_instance_id() == damage_bullet_id, "pool did not reuse the returned projectile"):
		return
	reused_bullet.initialize(Vector2(-500.0, -500.0), Vector2.RIGHT, 0.0, 0.02, 1, 5.5, true)
	await _wait_physics_frames(3)
	if not _require(pool.in_use_count() == 0, "expired projectile did not return to its pool"):
		return

	for enemy: CombatEnemy in enemies:
		enemy.global_position = room_definition.arena_size - Vector2(100.0, 100.0)
	ember.set_physics_process(true)
	var ember_start: Vector2 = ember.global_position
	var camera_start: Vector2 = camera.get_screen_center_position()
	await _touch_joystick(joystick, Vector2.RIGHT, 10)
	if not _require(ember.global_position.x > ember_start.x + 1.0, "injected joystick input did not move Ember"):
		return
	await _wait_physics_frames(8)
	if not _require(camera.get_screen_center_position().x > camera_start.x, "camera did not follow Ember movement"):
		return

	await _press_action_button(dash_button)
	await get_tree().physics_frame
	if not _require(ember.dash.remaining_cooldown > 0.0, "injected dash button did not start cooldown"):
		return
	if not _require(player_health.invulnerable, "dash did not grant invulnerability"):
		return
	await _wait_physics_frames(7)
	if not _require(dash_button.disabled and dash_button.text.contains("s"), "dash HUD did not react to cooldown"):
		return
	await _wait_physics_frames(ceili(ember.definition.dash_duration * 60.0) + 2)
	if not _require(not player_health.invulnerable, "dash invulnerability did not expire"):
		return
	if not _require(ember.dash.remaining_cooldown > 0.0, "dash cooldown expired too early"):
		return

	pool.release_all()
	await _press_action_button(skill_button)
	if not _require(ember.skill_cooldown_ratio() > 0.0, "injected skill button did not start cooldown"):
		return
	if not _require(pool.in_use_count() > 0, "active skill did not produce projectile activity"):
		return
	await _wait_physics_frames(7)
	if not _require(skill_button.disabled and skill_button.text.contains("s"), "skill HUD did not react to cooldown"):
		return
	pool.release_all()
	if not _require(pool.available_count() == room_definition.projectile_pool_capacity, "active projectiles did not return to pool"):
		return
	if not _require(is_instance_valid(ember) and ember.is_alive(), "Ember did not survive behavioral smoke"):
		return
	print("COMBAT_SMOKE_OK: nearest auto-fire, shooter fire, charger states, controls, damage, camera, and projectile reuse are observable")
	get_tree().quit(0)


func _enemy_of_type(enemies: Array[CombatEnemy], archetype: EnemyDefinition.Archetype) -> CombatEnemy:
	for enemy: CombatEnemy in enemies:
		if enemy.definition.archetype == archetype:
			return enemy
	return null


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in frame_count:
		await get_tree().physics_frame


func _wait_until_enemy_damaged(enemy: CombatEnemy, starting_health: int, frame_limit: int) -> bool:
	for _frame: int in frame_limit:
		await get_tree().physics_frame
		if enemy.health.current_health < starting_health:
			return true
	return false


func _wait_for_enemy_projectile_or_damage(
	pool: ObjectPool,
	health: HealthComponent,
	starting_health: int,
	frame_limit: int
) -> bool:
	for _frame: int in frame_limit:
		await get_tree().physics_frame
		if health.current_health < starting_health or _has_active_enemy_projectile(pool):
			return true
	return false


func _has_active_enemy_projectile(pool: ObjectPool) -> bool:
	for child: Node in pool.get_children():
		var bullet := child as PooledBullet
		if bullet != null and bullet.visible and not bullet.from_player and bullet.collision_mask == 1:
			return true
	return false


func _park_enemies_except(
	enemies: Array[CombatEnemy],
	active_enemy: CombatEnemy,
	arena_size: Vector2
) -> void:
	var parking_positions: Array[Vector2] = [
		Vector2(80.0, 80.0),
		Vector2(arena_size.x - 80.0, 80.0),
		Vector2(80.0, arena_size.y - 80.0),
		arena_size - Vector2(80.0, 80.0),
	]
	var parking_index: int = 0
	for enemy: CombatEnemy in enemies:
		if enemy == active_enemy:
			continue
		enemy.global_position = parking_positions[parking_index % parking_positions.size()]
		parking_index += 1


func _touch_joystick(joystick: VirtualJoystick, direction: Vector2, touch_index: int) -> void:
	var press := InputEventScreenTouch.new()
	press.index = touch_index
	press.position = joystick.size * 0.5 + direction.normalized() * joystick.radius * 0.75
	press.pressed = true
	joystick._gui_input(press)
	await _wait_physics_frames(5)
	var release := InputEventScreenTouch.new()
	release.index = touch_index
	release.position = press.position
	release.pressed = false
	joystick._gui_input(release)
	await get_tree().physics_frame


func _press_action_button(button: Button) -> void:
	button.pressed.emit()
	await get_tree().process_frame


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	printerr("COMBAT_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
	return false


func _combat_tuning_is_data_driven(character: CharacterDefinition, room: RoomDefinition) -> bool:
	var character_fields: Array[StringName] = [
		&"collision_radius",
		&"collision_height",
		&"arena_inset",
		&"projectile_spawn_offset",
		&"camera_smoothing_speed",
	]
	for field: StringName in character_fields:
		if not _has_positive_property(character, field):
			return false
	var room_fields: Array[StringName] = [
		&"projectile_pool_capacity",
	]
	for field: StringName in room_fields:
		if not _has_positive_property(room, field):
			return false
	if not _has_property(room, &"projectile_pool_can_grow"):
		return false
	if not _has_positive_property(character.starting_weapon, &"projectile_collision_radius"):
		return false
	var enemy_fields: Array[StringName] = [
		&"collision_radius",
		&"arena_inset",
		&"contact_range_padding",
		&"projectile_spawn_offset",
		&"projectile_collision_radius",
		&"ranged_approach_ratio",
		&"ranged_retreat_ratio",
		&"charge_hit_range",
	]
	for enemy_definition: EnemyDefinition in room.enemy_definitions:
		for field: StringName in enemy_fields:
			if not _has_positive_property(enemy_definition, field):
				return false
	return true


func _has_positive_property(resource: Resource, property_name: StringName) -> bool:
	return _has_property(resource, property_name) and float(resource.get(property_name)) > 0.0


func _has_property(resource: Resource, property_name: StringName) -> bool:
	for property: Dictionary in resource.get_property_list():
		if property.name == property_name:
			return true
	return false


func _runtime_tuning_matches_resources(ember: Ember, pool: ObjectPool, room: RoomDefinition) -> bool:
	if pool.available_count() + pool.in_use_count() != room.projectile_pool_capacity:
		printerr("COMBAT_SMOKE_DIAGNOSTIC: pool capacity mismatch")
		return false
	if pool.can_grow != room.projectile_pool_can_grow:
		printerr("COMBAT_SMOKE_DIAGNOSTIC: pool growth policy mismatch")
		return false
	var ember_collision := _find_collision_shape(ember)
	if ember_collision == null or not ember_collision.shape is CapsuleShape2D:
		printerr("COMBAT_SMOKE_DIAGNOSTIC: Ember collision missing")
		return false
	var ember_shape := ember_collision.shape as CapsuleShape2D
	var character: CharacterDefinition = ember.definition
	if not is_equal_approx(ember_shape.radius, character.collision_radius):
		printerr("COMBAT_SMOKE_DIAGNOSTIC: Ember radius mismatch")
		return false
	if not is_equal_approx(ember_shape.height, character.collision_height):
		printerr("COMBAT_SMOKE_DIAGNOSTIC: Ember height mismatch")
		return false
	var first_bullet := pool.get_child(0) as PooledBullet
	var bullet_collision := _find_collision_shape(first_bullet)
	if bullet_collision == null or not bullet_collision.shape is CircleShape2D:
		printerr("COMBAT_SMOKE_DIAGNOSTIC: bullet collision missing")
		return false
	if not is_equal_approx((bullet_collision.shape as CircleShape2D).radius, ember.definition.starting_weapon.projectile_collision_radius):
		printerr("COMBAT_SMOKE_DIAGNOSTIC: bullet radius mismatch")
		return false
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as CombatEnemy
		if enemy == null:
			return false
		var collision := _find_collision_shape(enemy)
		var definition: EnemyDefinition = enemy.definition
		if collision == null or not collision.shape is CircleShape2D or definition == null:
			printerr("COMBAT_SMOKE_DIAGNOSTIC: enemy collision missing")
			return false
		if not is_equal_approx((collision.shape as CircleShape2D).radius, definition.collision_radius):
			printerr("COMBAT_SMOKE_DIAGNOSTIC: enemy radius mismatch")
			return false
	return true


func _find_collision_shape(parent: Node) -> CollisionShape2D:
	for child: Node in parent.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null
