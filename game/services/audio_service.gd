extends Node

signal cue_played(cue_id: StringName)

const SAMPLE_RATE := 22050
const SFX_VOICE_COUNT := 6
const CUE_DEFINITIONS := {
	&"ember_shot": {"frequency": 520.0, "duration": 0.07, "volume": 0.22, "wave": &"square", "channel": &"sfx"},
	&"dash": {"frequency": 220.0, "duration": 0.16, "volume": 0.26, "wave": &"sine", "channel": &"sfx"},
	&"ember_burst": {"frequency": 330.0, "duration": 0.24, "volume": 0.28, "wave": &"sine", "channel": &"sfx"},
	&"enemy_telegraph": {"frequency": 150.0, "duration": 0.28, "volume": 0.24, "wave": &"square", "channel": &"telegraph"},
	&"player_hit": {"frequency": 105.0, "duration": 0.13, "volume": 0.27, "wave": &"square", "channel": &"sfx"},
	&"room_clear": {"frequency": 660.0, "duration": 0.34, "volume": 0.22, "wave": &"sine", "channel": &"ui"},
	&"reward_select": {"frequency": 880.0, "duration": 0.12, "volume": 0.20, "wave": &"sine", "channel": &"ui"},
}

var master_volume_db: float = 0.0
var _master_volume_linear: float = 1.0
var _muted: bool = false
var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _telegraph_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _voice_cues: Dictionary[int, StringName] = {}
var _next_sfx_voice: int = 0
var _initialized: bool = false
var _shutting_down: bool = false


func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	_ensure_bus(&"SFX")
	_ensure_bus(&"UI")
	for cue_id: StringName in CUE_DEFINITIONS:
		var definition: Dictionary = CUE_DEFINITIONS[cue_id]
		_streams[cue_id] = _make_procedural_stream(definition)
	for voice_index: int in SFX_VOICE_COUNT:
		_sfx_players.append(_create_player("SfxVoice%02d" % (voice_index + 1), &"SFX"))
	_telegraph_player = _create_player("TelegraphPlayer", &"SFX")
	_telegraph_player.volume_db = 2.0
	_ui_player = _create_player("UiPlayer", &"UI")
	_apply_master_state()


func has_cue(cue_id: StringName) -> bool:
	return _streams.has(cue_id)


func cue_duration_seconds(cue_id: StringName) -> float:
	var stream := _streams.get(cue_id) as AudioStreamWAV
	return stream.get_length() if stream != null else 0.0


func play_cue(cue_id: StringName) -> bool:
	if _shutting_down or not _streams.has(cue_id):
		return false
	var definition: Dictionary = CUE_DEFINITIONS[cue_id]
	var channel := StringName(definition["channel"])
	var player: AudioStreamPlayer
	match channel:
		&"telegraph":
			player = _telegraph_player
		&"ui":
			player = _ui_player
		_:
			player = _acquire_sfx_voice()
	if player == null:
		return false
	player.stream = _streams[cue_id]
	_voice_cues[player.get_instance_id()] = cue_id
	player.play()
	cue_played.emit(cue_id)
	return true


func stop_all() -> void:
	for player: AudioStreamPlayer in _all_players():
		player.stop()
		player.stream = null
	_voice_cues.clear()


func begin_shutdown() -> void:
	_shutting_down = true
	stop_all()
	_streams.clear()


func active_cue_count(cue_id: StringName) -> int:
	var count := 0
	for player: AudioStreamPlayer in _all_players():
		if player.playing and _voice_cues.get(player.get_instance_id(), &"") == cue_id:
			count += 1
	return count


func active_voice_count() -> int:
	var count := 0
	for player: AudioStreamPlayer in _all_players():
		if player.playing:
			count += 1
	return count


func is_telegraph_playing() -> bool:
	return is_instance_valid(_telegraph_player) and _telegraph_player.playing


func set_master_volume_linear(value: float) -> void:
	_master_volume_linear = clampf(value, 0.0, 1.0)
	master_volume_db = linear_to_db(_master_volume_linear) if _master_volume_linear > 0.0 else -80.0
	_apply_master_state()


func master_volume_linear() -> float:
	return _master_volume_linear


func set_muted(value: bool) -> void:
	_muted = value
	_apply_master_state()


func is_muted() -> bool:
	return _muted


func _apply_master_state() -> void:
	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index < 0:
		return
	AudioServer.set_bus_volume_db(master_index, master_volume_db)
	AudioServer.set_bus_mute(master_index, _muted)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _create_player(player_name: String, bus_name: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	player.finished.connect(_on_player_finished.bind(player))
	add_child(player)
	return player


func _acquire_sfx_voice() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player
	var player := _sfx_players[_next_sfx_voice]
	_next_sfx_voice = (_next_sfx_voice + 1) % _sfx_players.size()
	return player


func _all_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = _sfx_players.duplicate()
	if is_instance_valid(_telegraph_player):
		result.append(_telegraph_player)
	if is_instance_valid(_ui_player):
		result.append(_ui_player)
	return result


func _on_player_finished(player: AudioStreamPlayer) -> void:
	_voice_cues.erase(player.get_instance_id())


func _make_procedural_stream(definition: Dictionary) -> AudioStreamWAV:
	var duration := float(definition["duration"])
	var frame_count := maxi(1, roundi(duration * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var frequency := float(definition["frequency"])
	var volume := float(definition["volume"])
	var wave := StringName(definition["wave"])
	for frame: int in frame_count:
		var progress := float(frame) / float(frame_count)
		var phase := TAU * frequency * float(frame) / float(SAMPLE_RATE)
		var oscillator := sin(phase)
		if wave == &"square":
			oscillator = 1.0 if oscillator >= 0.0 else -1.0
		var envelope := (1.0 - progress) * minf(progress * 20.0, 1.0)
		data.encode_s16(frame * 2, int(clampf(oscillator * envelope * volume, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
