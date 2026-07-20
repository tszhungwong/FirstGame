extends GutTest

func test_applies_configured_damage_to_health() -> void:
	var health := autofree(HealthComponent.new()) as HealthComponent
	health.max_health = 20
	health.reset()
	var damage := autofree(DamageComponent.new()) as DamageComponent
	damage.amount = 7

	assert_eq(damage.apply_to(health), 7)
	assert_eq(health.current_health, 13)
