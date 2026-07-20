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
@export var includes_grass: bool = false
@export var includes_river: bool = false
@export var includes_mud: bool = false
@export var includes_trees: bool = false
