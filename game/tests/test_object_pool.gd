extends GutTest

const OBJECT_POOL_PATH := "res://combat/projectiles/object_pool.gd"


func test_reuses_released_instances_without_growing_when_exhausted() -> void:
	var pool_script := load(OBJECT_POOL_PATH) as GDScript
	assert_not_null(pool_script)
	if pool_script == null:
		return

	var source := Node2D.new()
	var packed := PackedScene.new()
	assert_eq(packed.pack(source), OK)
	source.free()
	var pool: Node = add_child_autofree(pool_script.new())
	pool.configure(packed, 2, false)

	var first: Node = pool.acquire()
	var second: Node = pool.acquire()
	assert_not_null(first)
	assert_not_null(second)
	assert_null(pool.acquire())
	pool.release(first)
	assert_false(first.visible)
	assert_eq(first.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_same(pool.acquire(), first)
