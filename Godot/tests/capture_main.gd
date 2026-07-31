extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	if game_scene == null:
		push_error("Unable to load main game scene for capture")
		quit(1)
		return
	root.add_child(game_scene.instantiate())
	for _frame in range(12):
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("res://tests/main_scene_capture.png")
	quit(0 if error == OK else 1)
