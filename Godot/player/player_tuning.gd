class_name PlayerTuning
extends Resource

@export_category("Vitals")
@export var max_health := 5
@export var max_memory_energy := 100
@export var invulnerability_duration := 0.65

@export_category("Movement")
@export var move_speed := 240.0
@export var gravity := 1400.0
@export var jump_velocity := -580.0
@export_range(0.1, 1.0) var jump_cut_multiplier := 0.45
@export var jump_hold_duration := 0.20
@export_range(0.1, 1.0) var jump_hold_gravity_multiplier := 0.42
@export var dash_speed := 620.0
@export var dash_duration := 0.12
@export var dash_cooldown := 0.35
@export var platform_drop_duration := 0.18
@export var wall_slide_speed := 105.0
@export var wall_jump_horizontal_speed := 320.0
@export var wall_jump_control_lock := 0.12

@export_category("Combat")
@export var basic_attack_damage := 10
@export var basic_attack_memory_gain := 12
@export var basic_attack_size := Vector2(58.0, 34.0)
@export var basic_attack_reach := 38.0
@export var basic_attack_knockback := 180.0
@export var basic_attack_color := Color(0.32, 0.91, 1.0, 0.38)
@export var basic_attack_visual_duration := 0.09
@export var downward_attack_rebound_velocity := -359.6
@export var skill_damage := 20
@export var skill_memory_cost := 25
@export var skill_size := Vector2(92.0, 44.0)
@export var skill_reach := 54.0
@export var skill_knockback := 260.0
@export var skill_color := Color(0.55, 0.95, 1.0, 0.5)
@export var skill_visual_duration := 0.14
@export var upward_skill_velocity := -330.0
@export var downward_skill_velocity := 360.0
@export var hit_stop_duration := 0.035
@export var basic_attack_move_lock := 0.12
@export var skill_move_lock := 0.18
