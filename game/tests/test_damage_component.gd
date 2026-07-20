extends GutTest

func test_applies_configured_damage_to_health() -> void:
	var health := autofree(HealthComponent.new()) as HealthComponent
	health.max_health = 20
	health.reset()
	var damage := autofree(DamageComponent.new()) as DamageComponent
	damage.amount = 7

	assert_eq(damage.apply_to(health), 7)
	assert_eq(health.current_health, 13)


func test_combat_boundaries_use_concrete_types_instead_of_dynamic_calls() -> void:
	var expected_contracts: Dictionary[String, Array] = {
		"res://combat/components/damage_component.gd": ["apply_to(health: HealthComponent)"],
		"res://combat/components/dash_component.gd": ["var health_component: HealthComponent"],
		"res://combat/projectiles/object_pool.gd": [
			"var _available: Array[PooledBullet]",
			"func acquire() -> PooledBullet:",
			"func release(instance: PooledBullet)",
		],
		"res://combat/projectiles/pooled_bullet.gd": ["var _damage: DamageComponent"],
		"res://combat/actors/ember.gd": [
			"var projectile_pool: ObjectPool",
			"var health: HealthComponent",
			"var dash: DashComponent",
		],
		"res://combat/actors/enemy.gd": [
			"var target: Ember",
			"var projectile_pool: ObjectPool",
			"var health: HealthComponent",
		],
		"res://combat/combat_sandbox.gd": [
			"var _projectile_pool: ObjectPool",
			"var _ember: Ember",
		],
		"res://combat/ui/combat_hud.gd": ["var ember: Ember"],
	}
	for path: String in expected_contracts:
		var source := FileAccess.get_file_as_string(path)
		for contract: String in expected_contracts[path]:
			assert_string_contains(source, contract, "%s should declare %s" % [path, contract])
