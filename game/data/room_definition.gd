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
