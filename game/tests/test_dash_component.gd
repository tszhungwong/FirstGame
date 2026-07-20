extends GutTest

func test_dash_grants_temporary_invulnerability_and_respects_cooldown() -> void:
	var health := autofree(HealthComponent.new()) as HealthComponent
	health.max_health = 20
	health.reset()
	var dash := autofree(DashComponent.new()) as DashComponent
	dash.cooldown = 1.5
	dash.duration = 0.2
	dash.health_component = health

	assert_true(dash.try_start())
	assert_true(health.invulnerable)
	assert_eq(health.take_damage(4), 0)
	assert_eq(health.current_health, 20)
	assert_false(dash.try_start())
	dash.advance(0.2)
	assert_false(health.invulnerable)
	assert_eq(health.take_damage(4), 4)
	dash.advance(1.3)
	assert_true(dash.try_start())


func test_zero_duration_dash_never_leaves_health_invulnerable() -> void:
	var health := autofree(HealthComponent.new()) as HealthComponent
	health.max_health = 20
	health.reset()
	var dash := autofree(DashComponent.new()) as DashComponent
	dash.cooldown = 1.0
	dash.duration = 0.0
	dash.health_component = health

	assert_true(dash.try_start())
	assert_false(dash.is_dashing())
	assert_false(health.invulnerable)
	assert_eq(health.take_damage(4), 4)
