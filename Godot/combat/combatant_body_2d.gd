class_name CombatantBody2D
extends CharacterBody2D

const DamageRequestType := preload("res://combat/damage_request.gd")


func apply_damage(_request: DamageRequestType) -> bool:
	push_error("CombatantBody2D.apply_damage must be implemented by the combatant")
	return false
