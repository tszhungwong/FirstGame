class_name PlayerVisualState
extends RefCounted

var velocity := Vector2.ZERO
var facing_direction := 1.0
var is_grounded := false
var is_on_wall := false
var is_dashing := false


func _init(
	current_velocity := Vector2.ZERO,
	current_facing := 1.0,
	grounded := false,
	on_wall := false,
	dashing := false
) -> void:
	velocity = current_velocity
	facing_direction = current_facing
	is_grounded = grounded
	is_on_wall = on_wall
	is_dashing = dashing
