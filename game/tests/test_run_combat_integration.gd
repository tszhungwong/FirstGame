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
