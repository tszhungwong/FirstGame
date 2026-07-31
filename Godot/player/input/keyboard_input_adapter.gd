class_name KeyboardInputAdapter
extends RefCounted

const PlayerCommandType := preload("res://player/input/player_command.gd")


func sample() -> PlayerCommandType:
	var command := PlayerCommandType.new()
	command.move_axis = Input.get_axis("move_left", "move_right")
	command.jump_pressed = Input.is_action_just_pressed("jump")
	command.jump_held = Input.is_action_pressed("jump")
	command.jump_released = Input.is_action_just_released("jump")
	command.dash_pressed = Input.is_action_just_pressed("dash")
	command.attack_pressed = Input.is_action_just_pressed("attack")
	command.skill_pressed = Input.is_action_just_pressed("skill")
	command.drop_pressed = Input.is_action_just_pressed("move_down")
	command.aim_up = Input.is_action_pressed("move_up")
	command.aim_down = Input.is_action_pressed("move_down")
	return command
