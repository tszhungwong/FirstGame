class_name RunController
extends Node

signal state_changed(state: State)
signal room_started(index: int, room: RoomDefinition)
signal reward_offered(choices: Array[UpgradeDefinition])
signal upgrade_applied(upgrade: UpgradeDefinition, stacks: int)
signal run_finished(won: bool)

enum State { IDLE, COMBAT, REWARD, WON, LOST, PAUSED }

const ROOM_PATHS: Array[String] = [
	"res://data/mock_forest_room_01.tres",
	"res://data/mock_forest_room_02.tres",
	"res://data/mock_forest_room_03.tres",
	"res://data/mock_forest_elite_room.tres",
	"res://data/mock_forest_room_05.tres",
	"res://data/mock_forest_boss_room.tres",
]
const UPGRADE_PATHS: Array[String] = [
	"res://data/mock_upgrade_rapid_embers.tres",
	"res://data/mock_upgrade_split_cinders.tres",
	"res://data/mock_upgrade_thorn_piercer.tres",
	"res://data/mock_upgrade_bark_ricochet.tres",
	"res://data/mock_upgrade_wildfire.tres",
	"res://data/mock_upgrade_lingering_flame.tres",
	"res://data/mock_upgrade_fleet_ash.tres",
	"res://data/mock_upgrade_heavy_rounds.tres",
	"res://data/mock_upgrade_hot_barrel.tres",
	"res://data/mock_upgrade_ember_velocity.tres",
]
const CHARACTER_PATH := "res://data/mock_ember_vanguard.tres"

var state: State = State.IDLE
var current_room_index: int = 0
var run_seed: int = 0
var rooms: Array[RoomDefinition] = []
var upgrades: Array[UpgradeDefinition] = []
var current_reward_choices: Array[UpgradeDefinition] = []
var upgrade_stacks: Dictionary = {}
var combat_stats: RuntimeCombatStats
var _rng := RandomNumberGenerator.new()
var _state_before_pause: State = State.IDLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_content()


func start_run(seed_value: int) -> void:
	_load_content()
	run_seed = seed_value
	_rng.seed = seed_value
	current_room_index = 0
	upgrade_stacks.clear()
	current_reward_choices.clear()
	combat_stats = RuntimeCombatStats.from_definitions(load(CHARACTER_PATH) as CharacterDefinition)
	_set_state(State.COMBAT)
	room_started.emit(current_room_index, current_room())


func restore_run(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	_load_content()
	run_seed = int(snapshot.get("seed", 0))
	_rng.seed = run_seed
	current_room_index = clampi(int(snapshot.get("room_index", 0)), 0, rooms.size() - 1)
	upgrade_stacks.clear()
	current_reward_choices.clear()
	combat_stats = RuntimeCombatStats.from_definitions(load(CHARACTER_PATH) as CharacterDefinition)
	var saved_stacks: Dictionary = snapshot.get("upgrade_stacks", {})
	for upgrade: UpgradeDefinition in upgrades:
		var saved_count := int(saved_stacks.get(upgrade.id, saved_stacks.get(String(upgrade.id), 0)))
		for _stack: int in mini(saved_count, upgrade.max_stacks):
			_apply_upgrade(upgrade)
	var saved_state := int(snapshot.get("state", State.COMBAT)) as State
	if saved_state == State.REWARD:
		for raw_id: Variant in snapshot.get("reward_choices", []):
			var upgrade := _find_upgrade(StringName(str(raw_id)))
			if upgrade != null:
				current_reward_choices.append(upgrade)
		if current_reward_choices.size() != 3:
			current_reward_choices = _draw_reward_choices()
		_set_state(State.REWARD)
		reward_offered.emit(current_reward_choices)
	else:
		_set_state(State.COMBAT)
		room_started.emit(current_room_index, current_room())
	return true


func room_count() -> int:
	_load_content()
	return rooms.size()


func current_room() -> RoomDefinition:
	return rooms[current_room_index] if current_room_index >= 0 and current_room_index < rooms.size() else null


func room_kind_at(index: int) -> RoomDefinition.Kind:
	_load_content()
	return rooms[index].kind


func complete_room() -> void:
	if state != State.COMBAT:
		return
	if current_room_index == rooms.size() - 1:
		_set_state(State.WON)
		run_finished.emit(true)
		return
	current_reward_choices = _draw_reward_choices()
	_set_state(State.REWARD)
	reward_offered.emit(current_reward_choices)


func choose_upgrade(id: StringName) -> bool:
	if state != State.REWARD:
		return false
	for upgrade: UpgradeDefinition in current_reward_choices:
		if upgrade.id == id:
			_apply_upgrade(upgrade)
			current_reward_choices.clear()
			current_room_index += 1
			_set_state(State.COMBAT)
			room_started.emit(current_room_index, current_room())
			return true
	return false


func grant_upgrade_for_test(id: StringName) -> bool:
	_load_content()
	for upgrade: UpgradeDefinition in upgrades:
		if upgrade.id == id:
			return _apply_upgrade(upgrade)
	return false


func reward_choice_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for choice: UpgradeDefinition in current_reward_choices:
		ids.append(choice.id)
	return ids


func player_defeated() -> void:
	if state in [State.COMBAT, State.REWARD, State.PAUSED]:
		_set_state(State.LOST)
		run_finished.emit(false)


func set_paused(paused: bool) -> void:
	if paused and state in [State.COMBAT, State.REWARD]:
		_state_before_pause = state
		_set_state(State.PAUSED)
		get_tree().paused = true
	elif not paused and state == State.PAUSED:
		get_tree().paused = false
		_set_state(_state_before_pause)


func serialize_active_run() -> Dictionary:
	if state in [State.IDLE, State.WON, State.LOST]:
		return {}
	var active_state := _state_before_pause if state == State.PAUSED else state
	return {
		"seed": run_seed,
		"room_index": current_room_index,
		"upgrade_stacks": upgrade_stacks.duplicate(true),
		"state": active_state,
		"reward_choices": reward_choice_ids(),
	}


func _load_content() -> void:
	if rooms.is_empty():
		for path: String in ROOM_PATHS:
			rooms.append(load(path) as RoomDefinition)
	if upgrades.is_empty():
		for path: String in UPGRADE_PATHS:
			upgrades.append(load(path) as UpgradeDefinition)


func _draw_reward_choices() -> Array[UpgradeDefinition]:
	_rng.seed = run_seed + (current_room_index + 1) * 7919
	var eligible: Array[UpgradeDefinition] = []
	for upgrade: UpgradeDefinition in upgrades:
		if int(upgrade_stacks.get(upgrade.id, 0)) < upgrade.max_stacks:
			eligible.append(upgrade)
	var result: Array[UpgradeDefinition] = []
	while result.size() < 3 and not eligible.is_empty():
		var selected_index := _rng.randi_range(0, eligible.size() - 1)
		result.append(eligible.pop_at(selected_index))
	return result


func _find_upgrade(id: StringName) -> UpgradeDefinition:
	for upgrade: UpgradeDefinition in upgrades:
		if upgrade.id == id:
			return upgrade
	return null


func _apply_upgrade(upgrade: UpgradeDefinition) -> bool:
	var stacks := int(upgrade_stacks.get(upgrade.id, 0))
	if stacks >= upgrade.max_stacks:
		return false
	upgrade_stacks[upgrade.id] = stacks + 1
	combat_stats.apply_upgrade(upgrade)
	upgrade_applied.emit(upgrade, stacks + 1)
	return true


func _set_state(next_state: State) -> void:
	state = next_state
	state_changed.emit(state)
