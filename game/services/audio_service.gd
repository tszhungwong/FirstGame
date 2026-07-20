extends Node

signal cue_played(cue_id: StringName)

const SAMPLE_RATE := 22050
const CUE_DEFINITIONS := {
	&"ember_shot": {"frequency": 520.0, "duration": 0.07, "volume": 0.22, "wave": &"square", "bus": &"SFX"},
	&"dash": {"frequency": 220.0, "duration": 0.16, "volume": 0.26, "wave": &"sine", "bus": &"SFX"},
	&"ember_burst": {"frequency": 330.0, "duration": 0.24, "volume": 0.28, "wave": &"sine", "bus": &"SFX"},
	&"enemy_telegraph": {"frequency": 150.0, "duration": 0.28, "volume": 0.24, "wave": &"square", "bus": &"SFX"},
	&"player_hit": {"frequency": 105.0, "duration": 0.13, "volume": 0.27, "wave": &"square", "bus": &"SFX"},
	&"room_clear": {"frequency": 660.0, "duration": 0.34, "volume": 0.22, "wave": &"sine", "bus": &"UI"},
	&"reward_select": {"frequency": 880.0, "duration": 0.12, "volume": 0.20, "wave": &"sine", "bus": &"UI"},
}

var master_volume_db: float = 0.0
var _master_volume_linear: float = 1.0
var _muted: bool = false
var _streams: Dictionary = {}
var _players: Dictionary = {}
var _initialized: bool = false


func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	_ensure_bus(&"SFX")
	_ensure_bus(&"UI")
	for cue_id: StringName in CUE_DEFINITIONS:
		var definition: Dictionary = CUE_DEFINITIONS[cue_id]
		_streams[cue_id] = _make_procedural_stream(definition)
	for bus_name: StringName in [&"SFX", &"UI"]:
		var player := AudioStreamPlayer.new()
		player.name = "%sPlayer" % bus_name
		player.bus = bus_name
		add_child(player)
		_players[bus_name] = player
	_apply_master_state()


func has_cue(cue_id: StringName) -> bool:
	return _streams.has(cue_id)


func cue_duration_seconds(cue_id: StringName) -> float:
	var stream := _streams.get(cue_id) as AudioStreamWAV
	return stream.get_length() if stream != null else 0.0


func play_cue(cue_id: StringName) -> bool:
	if not _streams.has(cue_id):
		return false
	var definition: Dictionary = CUE_DEFINITIONS[cue_id]
	var bus_name := StringName(definition["bus"])
	var player := _players.get(bus_name) as AudioStreamPlayer
	if player == null:
		return false
	player.stream = _streams[cue_id]
	player.play()
	cue_played.emit(cue_id)
	return true


func stop_all() -> void:
	for player_value: Variant in _players.values():
		var player := player_value as AudioStreamPlayer
		if player != null:
			player.stop()
			player.stream = null


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
