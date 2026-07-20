class_name CombatSandbox
extends Node2D

const OBJECT_POOL = preload("res://combat/projectiles/object_pool.gd")
const BULLET_SCENE = preload("res://combat/projectiles/pooled_bullet.tscn")
const EMBER_ACTOR = preload("res://combat/actors/ember.gd")
const ENEMY_ACTOR = preload("res://combat/actors/enemy.gd")
const COMBAT_HUD = preload("res://combat/ui/combat_hud.gd")
const EMBER_DEFINITION = preload("res://data/mock_ember_vanguard.tres")
const ROOM_DEFINITION = preload("res://data/mock_forest_combat_room.tres")

var _arena_rect: Rect2
var _projectile_pool: Node
var _ember: CharacterBody2D


func _ready() -> void:
	_arena_rect = Rect2(Vector2.ZERO, ROOM_DEFINITION.arena_size)
	_projectile_pool = OBJECT_POOL.new()
	_projectile_pool.name = "ProjectilePool"
	add_child(_projectile_pool)
	_projectile_pool.call("configure", BULLET_SCENE, 48, true)

	_ember = EMBER_ACTOR.new() as CharacterBody2D
	_ember.name = "Ember"
	_ember.call("configure", EMBER_DEFINITION, _projectile_pool, _arena_rect)
	_ember.global_position = _arena_rect.get_center()
	add_child(_ember)

	_spawn_enemies()
	var hud: CanvasLayer = COMBAT_HUD.new()
	hud.name = "CombatHud"
	hud.call("configure", _ember)
	add_child(hud)
	queue_redraw()


func _spawn_enemies() -> void:
	var spawn_count: int = mini(
		ROOM_DEFINITION.enemy_count,
		mini(ROOM_DEFINITION.enemy_definitions.size(), ROOM_DEFINITION.enemy_spawn_points.size())
	)
	for index: int in spawn_count:
		var enemy := ENEMY_ACTOR.new() as CharacterBody2D
		enemy.name = "Enemy%02d" % (index + 1)
		enemy.call(
			"configure",
			ROOM_DEFINITION.enemy_definitions[index],
			_ember,
			_projectile_pool,
			_arena_rect
		)
		enemy.global_position = ROOM_DEFINITION.enemy_spawn_points[index]
		add_child(enemy)


func _draw() -> void:
	draw_rect(_arena_rect, Color("182225"), true)
	draw_rect(_arena_rect, Color("53686a"), false, 8.0)
	var grid_color := Color(0.26, 0.37, 0.38, 0.28)
	var x: float = _arena_rect.position.x
	while x <= _arena_rect.end.x:
		draw_line(Vector2(x, _arena_rect.position.y), Vector2(x, _arena_rect.end.y), grid_color, 1.0)
		x += 100.0
	var y: float = _arena_rect.position.y
	while y <= _arena_rect.end.y:
		draw_line(Vector2(_arena_rect.position.x, y), Vector2(_arena_rect.end.x, y), grid_color, 1.0)
		y += 100.0
	for marker: Vector2 in ROOM_DEFINITION.enemy_spawn_points:
		draw_arc(marker, 32.0, 0.0, TAU, 28, Color(0.93, 0.53, 0.34, 0.18), 2.0)
