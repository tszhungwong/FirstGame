extends GutTest

const BULLET_SCENE = preload("res://combat/projectiles/pooled_bullet.tscn")


func test_upgrade_build_changes_projectiles_fired_by_ember() -> void:
	var fixture := Node2D.new()
	add_child_autofree(fixture)
	var pool := ObjectPool.new()
	fixture.add_child(pool)
	pool.configure(BULLET_SCENE, 8, false, 5.5)
	var character := load("res://data/mock_ember_vanguard.tres") as CharacterDefinition
	var stats := RuntimeCombatStats.from_definitions(character)
	for path: String in [
		"res://data/mock_upgrade_split_cinders.tres",
		"res://data/mock_upgrade_thorn_piercer.tres",
		"res://data/mock_upgrade_bark_ricochet.tres",
		"res://data/mock_upgrade_wildfire.tres",
	]:
		stats.apply_upgrade(load(path) as UpgradeDefinition)
	var ember := Ember.new()
	ember.configure(character, pool, Rect2(Vector2.ZERO, Vector2(2200.0, 1200.0)), stats)
	fixture.add_child(ember)
	ember._shoot(Vector2.RIGHT)

	assert_eq(pool.in_use_count(), 2)
	for child: Node in pool.get_children():
		var bullet := child as PooledBullet
		if bullet != null and bullet.visible:
			assert_eq(bullet.penetration_remaining, 1)
			assert_eq(bullet.ricochet_remaining, 1)
			assert_gt(bullet.burn_damage, 0)


func test_boss_enters_telegraph_before_charging() -> void:
	var fixture := Node2D.new()
	add_child_autofree(fixture)
	var pool := ObjectPool.new()
	fixture.add_child(pool)
	pool.configure(BULLET_SCENE, 8, true, 5.5)
	var character := load("res://data/mock_ember_vanguard.tres") as CharacterDefinition
	var ember := Ember.new()
	ember.configure(character, pool, Rect2(Vector2.ZERO, Vector2(2200.0, 1200.0)))
	ember.global_position = Vector2(900.0, 600.0)
	fixture.add_child(ember)
	var boss := CombatEnemy.new()
	boss.configure(load("res://data/mock_forest_boss.tres") as EnemyDefinition, ember, pool, Rect2(Vector2.ZERO, Vector2(2200.0, 1200.0)))
	boss.global_position = Vector2(1350.0, 600.0)
	fixture.add_child(boss)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(boss.is_telegraphing())
	assert_eq(boss.velocity, Vector2.ZERO)


func test_ricochet_stays_on_near_side_of_tree_and_river() -> void:
	var room := load("res://data/mock_forest_combat_room.tres") as RoomDefinition
	var rules := ForestRoomRules.new(room)
	var fixture := Node2D.new()
	add_child_autofree(fixture)
	var pool := ObjectPool.new()
	fixture.add_child(pool)
	pool.configure(BULLET_SCENE, 2, false, 5.5)
	pool.configure_forest_rules(rules)
	var tree := room.tree_positions[0]
	var bullet := pool.acquire()
	bullet.set_physics_process(false)
	bullet.initialize(tree - Vector2(100.0, 0.0), Vector2.RIGHT, 1000.0, 2.0, 5, 5.5, true, {"ricochet": 1})
	bullet._physics_process(0.2)
	assert_lt(bullet.global_position.x, tree.x - room.tree_radius)
	assert_eq(bullet.direction, Vector2.LEFT)

	pool.release_all()
	var river := room.river_areas[0]
	var blocked_y := river.position.y + 140.0
	bullet = pool.acquire()
	bullet.set_physics_process(false)
	bullet.initialize(Vector2(river.position.x - 80.0, blocked_y), Vector2.RIGHT, 1000.0, 2.0, 5, 5.5, true, {"ricochet": 1})
	bullet._physics_process(0.3)
	assert_lt(bullet.global_position.x, river.position.x - room.projectile_blocker_separation)
	assert_eq(bullet.direction, Vector2.LEFT)


func test_mud_slows_real_enemy_displacement() -> void:
	var room := load("res://data/mock_forest_combat_room.tres") as RoomDefinition
	var rules := ForestRoomRules.new(room)
	var fixture := Node2D.new()
	add_child_autofree(fixture)
	var pool := ObjectPool.new()
	fixture.add_child(pool)
	pool.configure(BULLET_SCENE, 4, true, 5.5)
	var character := load("res://data/mock_ember_vanguard.tres") as CharacterDefinition
	var ember := Ember.new()
	ember.configure(character, pool, Rect2(Vector2.ZERO, room.arena_size))
	ember.global_position = Vector2(1900.0, 600.0)
	fixture.add_child(ember)
	ember.set_physics_process(false)
	var definition := load("res://data/mock_forest_chaser.tres") as EnemyDefinition
	var normal_enemy := CombatEnemy.new()
	normal_enemy.configure(definition, ember, pool, Rect2(Vector2.ZERO, room.arena_size), rules)
	normal_enemy.global_position = Vector2(720.0, 500.0)
	fixture.add_child(normal_enemy)
	var mud_enemy := CombatEnemy.new()
	mud_enemy.configure(definition, ember, pool, Rect2(Vector2.ZERO, room.arena_size), rules)
	mud_enemy.global_position = room.mud_areas[0].get_center()
	fixture.add_child(mud_enemy)
	var normal_start := normal_enemy.global_position
	var mud_start := mud_enemy.global_position
	for _frame: int in 10:
		await get_tree().physics_frame

	assert_gt(normal_enemy.global_position.distance_to(normal_start), mud_enemy.global_position.distance_to(mud_start))
