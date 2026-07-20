class_name RoomDefinition
extends Resource

enum Kind {
	COMBAT,
	ELITE,
	BOSS,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.COMBAT
@export var enemy_count: int = 0
@export var arena_size: Vector2 = Vector2.ZERO
@export var projectile_pool_capacity: int = 0
@export var projectile_pool_can_grow: bool = false
@export var enemy_definitions: Array[EnemyDefinition] = []
@export var enemy_spawn_points: Array[Vector2] = []
@export var includes_grass: bool = false
@export var includes_river: bool = false
@export var includes_mud: bool = false
@export var includes_trees: bool = false
@export var grass_areas: Array[Rect2] = []
@export var river_areas: Array[Rect2] = []
@export var bridge_areas: Array[Rect2] = []
@export var mud_areas: Array[Rect2] = []
@export_range(0.1, 1.0) var mud_speed_multiplier: float = 0.62
@export var tree_positions: Array[Vector2] = []
@export var tree_radius: float = 42.0
@export var projectile_blocker_separation: float = 8.0
@export var expected_duration_seconds: float = 100.0
