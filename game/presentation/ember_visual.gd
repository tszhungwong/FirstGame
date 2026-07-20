class_name EmberVisual
extends Node2D

const LayerScript = preload("res://presentation/ember_visual_layer.gd")

var _layers: Array[Node2D] = []


func _ready() -> void:
	if not _layers.is_empty():
		return
	_add_layer("RibbonLayer", LayerScript.Kind.RIBBON)
	_add_layer("BodyLayer", LayerScript.Kind.BODY)
	_add_layer("HairLayer", LayerScript.Kind.HAIR)
	_add_layer("WeaponLayer", LayerScript.Kind.WEAPON)


func set_state(facing: Vector2, alive: bool, concealed: bool, invulnerable: bool) -> void:
	for layer: Node2D in _layers:
		layer.set_state(facing, alive, concealed, invulnerable)


func uses_runtime_textures() -> bool:
	return false


func _add_layer(layer_name: String, kind: int) -> void:
	var layer: Node2D = LayerScript.new()
	layer.name = layer_name
	layer.configure(kind)
	add_child(layer)
	_layers.append(layer)
