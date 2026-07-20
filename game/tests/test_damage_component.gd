extends GutTest

const DAMAGE_COMPONENT_PATH := "res://combat/components/damage_component.gd"
const HEALTH_COMPONENT = preload("res://combat/components/health_component.gd")


func test_applies_configured_damage_to_health() -> void:
	var damage_script := load(DAMAGE_COMPONENT_PATH) as GDScript
	assert_not_null(damage_script)
	if damage_script == null:
		return

	var health: Node = autofree(HEALTH_COMPONENT.new())
	health.max_health = 20
	health.reset()
	var damage: Node = autofree(damage_script.new())
	damage.amount = 7

	assert_eq(damage.apply_to(health), 7)
	assert_eq(health.current_health, 13)
