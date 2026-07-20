extends GutTest

const DASH_COMPONENT_PATH := "res://combat/components/dash_component.gd"
const HEALTH_COMPONENT = preload("res://combat/components/health_component.gd")


func test_dash_grants_temporary_invulnerability_and_respects_cooldown() -> void:
	var dash_script := load(DASH_COMPONENT_PATH) as GDScript
	assert_not_null(dash_script)
	if dash_script == null:
		return

	var health: Node = autofree(HEALTH_COMPONENT.new())
	health.max_health = 20
	health.reset()
	var dash: Node = autofree(dash_script.new())
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
