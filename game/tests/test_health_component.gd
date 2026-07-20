extends GutTest

const HEALTH_COMPONENT_PATH := "res://combat/components/health_component.gd"


func test_damage_clamps_at_zero_and_emits_death_once() -> void:
	var health_script := load(HEALTH_COMPONENT_PATH) as GDScript
	assert_not_null(health_script)
	if health_script == null:
		return

	var health: Node = autofree(health_script.new())
	health.max_health = 10
	health.reset()
	watch_signals(health)

	assert_eq(health.take_damage(14), 10)
	assert_eq(health.current_health, 0)
	assert_signal_emit_count(health, "died", 1)
	assert_eq(health.take_damage(2), 0)
	assert_signal_emit_count(health, "died", 1)
