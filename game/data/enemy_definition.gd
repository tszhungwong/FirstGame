class_name EnemyDefinition
extends Resource

enum Archetype {
	MELEE_CHASER,
	RANGED_SHOOTER,
	TELEGRAPHED_CHARGER,
	BOSS,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var archetype: Archetype = Archetype.MELEE_CHASER
@export var max_health: int = 1
@export var move_speed: float = 0.0
@export var collision_radius: float = 0.0
@export var arena_inset: float = 0.0
@export var contact_damage: int = 0
@export var attack_range: float = 0.0
@export var contact_range_padding: float = 0.0
@export var attack_cooldown: float = 0.0
@export var projectile_speed: float = 0.0
@export var projectile_lifetime: float = 0.0
@export var projectile_collision_radius: float = 0.0
@export var projectile_spawn_offset: float = 0.0
@export var ranged_approach_ratio: float = 0.0
@export var ranged_retreat_ratio: float = 0.0
@export_range(0.01, 1.0) var concealment_detection_factor: float = 1.0
@export var telegraph_duration: float = 0.0
@export var charge_speed: float = 0.0
@export var charge_duration: float = 0.0
@export var charge_hit_range: float = 0.0
