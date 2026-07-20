class_name CombatSandbox
extends Node2D

const BULLET_SCENE = preload("res://combat/projectiles/pooled_bullet.tscn")
const EMBER_DEFINITION_PATH := "res://data/mock_ember_vanguard.tres"
const ROOM_DEFINITION_PATH := "res://data/mock_forest_combat_room.tres"

var _arena_rect: Rect2
var _projectile_pool: ObjectPool
var _ember: Ember
var _ember_definition: CharacterDefinition
var _room_definition: RoomDefinition


func _ready() -> void:
	_ember_definition = load(EMBER_DEFINITION_PATH) as CharacterDefinition
	_room_definition = load(ROOM_DEFINITION_PATH) as RoomDefinition
	_arena_rect = Rect2(Vector2.ZERO, _room_definition.arena_size)
	_projectile_pool = ObjectPool.new()
	_projectile_pool.name = "ProjectilePool"
	add_child(_projectile_pool)
	_projectile_pool.configure(
		BULLET_SCENE,
		_room_definition.projectile_pool_capacity,
		_room_definition.projectile_pool_can_grow,
		_ember_definition.starting_weapon.projectile_collision_radius
	)

	_ember = Ember.new()
	_ember.name = "Ember"
	_ember.configure(_ember_definition, _projectile_pool, _arena_rect)
	_ember.global_position = _arena_rect.get_center()
	add_child(_ember)

	_spawn_enemies()
	var hud := CombatHud.new()
	hud.name = "CombatHud"
	hud.configure(_ember)
	add_child(hud)
	queue_redraw()


func _spawn_enemies() -> void:
	var spawn_count: int = mini(
		_room_definition.enemy_count,
		mini(_room_definition.enemy_definitions.size(), _room_definition.enemy_spawn_points.size())
	)
	for index: int in spawn_count:
		var enemy := CombatEnemy.new()
		var enemy_definition: EnemyDefinition = _room_definition.enemy_definitions[index]
		enemy.name = "Enemy%02d" % (index + 1)
		enemy.configure(
			enemy_definition,
			_ember,
			_projectile_pool,
			_arena_rect
		)
		enemy.global_position = _room_definition.enemy_spawn_points[index]
		add_child(enemy)
		_ember.register_enemy(enemy)
		enemy.defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(enemy: CombatEnemy) -> void:
	_ember.unregister_enemy(enemy)


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
	for marker: Vector2 in _room_definition.enemy_spawn_points:
		draw_arc(marker, 32.0, 0.0, TAU, 28, Color(0.93, 0.53, 0.34, 0.18), 2.0)
