extends GutTest

const ASSET_REGISTRY_PATH := "res://data/asset_registry.tres"


func test_asset_registry_exposes_the_seeded_typed_definitions() -> void:
	var registry := load(ASSET_REGISTRY_PATH)

	assert_not_null(registry)
	assert_eq(registry.characters.size(), 1)
	assert_eq(registry.weapons.size(), 1)
	assert_eq(registry.enemies.size(), 5)
	assert_eq(registry.upgrades.size(), 10)
	assert_eq(registry.rooms.size(), 6)


func test_seeded_character_references_a_weapon_definition() -> void:
	var registry := load(ASSET_REGISTRY_PATH)

	assert_not_null(registry)
	assert_not_null(registry.characters[0].starting_weapon)
	assert_eq(registry.characters[0].starting_weapon.id, &"ember_rifle")
