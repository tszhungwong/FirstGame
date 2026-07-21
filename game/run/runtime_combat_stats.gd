class_name RuntimeCombatStats
extends Resource

var damage: int = 0
var fire_rate: float = 0.0
var projectile_speed: float = 0.0
var projectile_lifetime: float = 0.0
var projectile_collision_radius: float = 0.0
var multishot: int = 1
var penetration: int = 0
var ricochet: int = 0
var burn_damage: int = 0
var burn_duration: float = 0.0
var dash_cooldown: float = 0.0
var minimum_dash_cooldown: float = 0.0


static func from_definitions(character: CharacterDefinition) -> RuntimeCombatStats:
	var stats := RuntimeCombatStats.new()
	var weapon := character.starting_weapon
	stats.damage = weapon.damage
	stats.fire_rate = weapon.fire_rate
	stats.projectile_speed = weapon.projectile_speed
	stats.projectile_lifetime = weapon.projectile_lifetime
	stats.projectile_collision_radius = weapon.projectile_collision_radius
	stats.dash_cooldown = character.dash_cooldown
	stats.minimum_dash_cooldown = character.minimum_dash_cooldown
	return stats


func apply_upgrade(upgrade: UpgradeDefinition) -> void:
	match upgrade.modifier_key:
		&"fire_rate":
			fire_rate *= 1.0 + upgrade.modifier_amount
		&"damage":
			damage += roundi(upgrade.modifier_amount)
		&"multishot":
			multishot += roundi(upgrade.modifier_amount)
		&"penetration":
			penetration += roundi(upgrade.modifier_amount)
		&"ricochet":
			ricochet += roundi(upgrade.modifier_amount)
		&"burn_damage":
			burn_damage += roundi(upgrade.modifier_amount)
			burn_duration = maxf(burn_duration, upgrade.minimum_burn_duration)
		&"burn_duration":
			burn_duration += upgrade.modifier_amount
		&"dash_cooldown":
			dash_cooldown = maxf(minimum_dash_cooldown, dash_cooldown * (1.0 - upgrade.modifier_amount))
		&"projectile_speed":
			projectile_speed *= 1.0 + upgrade.modifier_amount
