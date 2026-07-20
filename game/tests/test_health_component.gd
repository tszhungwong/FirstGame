extends GutTest

func test_damage_clamps_at_zero_and_emits_death_once() -> void:
	var health := autofree(HealthComponent.new()) as HealthComponent
	health.max_health = 10
	health.reset()
	watch_signals(health)

	assert_eq(health.take_damage(14), 10)
	assert_eq(health.current_health, 0)
	assert_signal_emit_count(health, "died", 1)
	assert_eq(health.take_damage(2), 0)
	assert_signal_emit_count(health, "died", 1)
