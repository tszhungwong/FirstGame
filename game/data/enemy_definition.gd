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
@export var contact_damage: int = 0
@export var attack_range: float = 0.0
