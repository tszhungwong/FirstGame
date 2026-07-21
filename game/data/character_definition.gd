class_name CharacterDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_health: int = 1
@export var move_speed: float = 0.0
@export var collision_radius: float = 0.0
@export var collision_height: float = 0.0
@export var arena_inset: float = 0.0
@export var projectile_spawn_offset: float = 0.0
@export var camera_smoothing_speed: float = 0.0
@export var starting_weapon: WeaponDefinition
@export var dash_cooldown: float = 0.0
@export var minimum_dash_cooldown: float = 0.0
@export var dash_duration: float = 0.0
@export var dash_speed_multiplier: float = 1.0
@export var active_skill_cooldown: float = 0.0
@export var active_skill_projectiles: int = 1
