extends GutTest

const BULLET_SCENE = preload("res://combat/projectiles/pooled_bullet.tscn")


func test_reuses_released_instances_without_growing_when_exhausted() -> void:
	var pool := add_child_autofree(ObjectPool.new()) as ObjectPool
	pool.configure(BULLET_SCENE, 2, false, 5.5)

	var first: PooledBullet = pool.acquire()
	var second: PooledBullet = pool.acquire()
	assert_not_null(first)
	assert_not_null(second)
	assert_null(pool.acquire())
	pool.release(first)
	assert_false(first.visible)
	assert_eq(first.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_same(pool.acquire(), first)


func test_preallocated_collision_bullets_start_fully_despawned() -> void:
	var pool := add_child_autofree(ObjectPool.new()) as ObjectPool
	pool.configure(BULLET_SCENE, 1, false, 5.5)
	var bullet := pool.get_child(0) as PooledBullet

	assert_not_null(bullet)
	assert_eq(bullet.collision_mask, 0)
	assert_eq(bullet.collision_radius, 5.5)
	assert_eq(bullet.direction, Vector2.ZERO)
	assert_eq(bullet.remaining_lifetime, 0.0)
	assert_eq(bullet.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(bullet.visible)
