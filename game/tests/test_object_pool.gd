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


func test_stale_deferred_return_cannot_release_a_reacquired_bullet() -> void:
	var pool := add_child_autofree(ObjectPool.new()) as ObjectPool
	pool.configure(BULLET_SCENE, 1, false, 5.5)
	var first_lease: PooledBullet = pool.acquire()
	first_lease.initialize(Vector2.ZERO, Vector2.RIGHT, 100.0, 0.01, 3, 5.5, true)
	first_lease._physics_process(0.02)

	pool.release(first_lease)
	var second_lease: PooledBullet = pool.acquire()
	second_lease.initialize(Vector2.ZERO, Vector2.RIGHT, 100.0, 1.0, 3, 5.5, true)
	await get_tree().process_frame

	assert_same(second_lease, first_lease)
	assert_eq(pool.in_use_count(), 1, "the stale return must not release the current lease")
	assert_eq(pool.available_count(), 0)
	assert_true(second_lease.visible)
	assert_eq(second_lease.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(second_lease.collision_mask, 2)
