class_name PerformanceOverlay
extends PanelContainer

const SAMPLE_INTERVAL_SECONDS := 0.5
const Palette = preload("res://presentation/game_palette.gd")

var ember: Ember
var projectile_pool: ObjectPool
var _metrics: Label


func configure(player: Ember, pool: ObjectPool) -> void:
	ember = player
	projectile_pool = pool


func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_metrics = Label.new()
	_metrics.name = "Metrics"
	_metrics.add_theme_font_size_override("font_size", 12)
	_metrics.add_theme_color_override("font_color", Palette.JADE_LIGHT)
	add_child(_metrics)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.INK, 0.78)
	style.border_color = Color(Palette.JADE_GLOW, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	add_theme_stylebox_override("panel", style)
	var timer := Timer.new()
	timer.name = "SampleTimer"
	timer.wait_time = SAMPLE_INTERVAL_SECONDS
	timer.autostart = true
	timer.timeout.connect(refresh_metrics)
	add_child(timer)
	refresh_metrics()


func refresh_metrics() -> void:
	if _metrics == null:
		return
	var fps := roundi(Performance.get_monitor(Performance.TIME_FPS))
	var memory_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var enemy_count := ember.enemy_count() if is_instance_valid(ember) else get_tree().get_nodes_in_group("enemies").size()
	var projectile_count := projectile_pool.in_use_count() if is_instance_valid(projectile_pool) else 0
	_metrics.text = "FPS %03d  MEM %4.1f MB\nENM %02d   PRJ %02d" % [fps, memory_mb, enemy_count, projectile_count]
