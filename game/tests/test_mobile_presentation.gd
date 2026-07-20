extends GutTest

const EMBER_VISUAL_PATH := "res://presentation/ember_visual.gd"
const PERFORMANCE_OVERLAY_PATH := "res://combat/ui/performance_overlay.gd"


func test_ember_visual_has_independent_programmatic_layers() -> void:
	var visual_script: GDScript = load(EMBER_VISUAL_PATH) as GDScript
	assert_not_null(visual_script)
	if visual_script == null:
		return
	var visual: Node = add_child_autofree(visual_script.new())
	await get_tree().process_frame

	assert_not_null(visual.get_node_or_null("RibbonLayer"))
	assert_not_null(visual.get_node_or_null("BodyLayer"))
	assert_not_null(visual.get_node_or_null("HairLayer"))
	assert_not_null(visual.get_node_or_null("WeaponLayer"))
	assert_true(visual.uses_runtime_textures() == false)


func test_performance_overlay_samples_on_timer_instead_of_process() -> void:
	var overlay_script: GDScript = load(PERFORMANCE_OVERLAY_PATH) as GDScript
	assert_not_null(overlay_script)
	if overlay_script == null:
		return
	var overlay: Control = add_child_autofree(overlay_script.new()) as Control
	await get_tree().process_frame
	var timer := overlay.get_node_or_null("SampleTimer") as Timer

	assert_not_null(timer)
	assert_true(timer.wait_time >= 0.25)
	assert_false(overlay.is_processing())
	overlay.refresh_metrics()
	var text := (overlay.get_node("Metrics") as Label).text
	assert_true(text.contains("FPS"))
	assert_true(text.contains("MEM"))
	assert_true(text.contains("ENM"))
	assert_true(text.contains("PRJ"))
