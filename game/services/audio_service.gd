extends Node

signal cue_played(cue_id: StringName)

const AUDIO_TUNING_PATH := "res://data/mock_audio_tuning.tres"

@export var audio_tuning: AudioTuningDefinition = preload(AUDIO_TUNING_PATH)
var master_volume_db: float = 0.0
var _master_volume_linear: float = 1.0
var _muted: bool = false
var _streams: Dictionary = {}
var _cue_definitions: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _telegraph_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _voice_cues: Dictionary[int, StringName] = {}
var _next_sfx_voice: int = 0
var _initialized: bool = false
var _shutting_down: bool = false
var _root_window: Window


func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	_root_window = get_tree().root
	if is_instance_valid(_root_window):
		_root_window.close_requested.connect(_on_root_close_requested)
	if audio_tuning == null:
		push_error("AudioService requires an AudioTuningDefinition resource")
		return
	_ensure_bus(audio_tuning.sfx_bus)
	_ensure_bus(audio_tuning.ui_bus)
	for definition: AudioCueDefinition in audio_tuning.cue_definitions:
		if definition == null or definition.id.is_empty():
			continue
		_cue_definitions[definition.id] = definition
		_streams[definition.id] = _make_procedural_stream(definition)
	for voice_index: int in audio_tuning.sfx_voice_count:
		_sfx_players.append(_create_player("SfxVoice%02d" % (voice_index + 1), audio_tuning.sfx_bus))
	_telegraph_player = _create_player("TelegraphPlayer", audio_tuning.sfx_bus)
	_telegraph_player.volume_db = audio_tuning.telegraph_volume_db
	_ui_player = _create_player("UiPlayer", audio_tuning.ui_bus)
	_apply_master_state()


func _exit_tree() -> void:
	if is_instance_valid(_root_window) and _root_window.close_requested.is_connected(_on_root_close_requested):
		_root_window.close_requested.disconnect(_on_root_close_requested)
	begin_shutdown()


func has_cue(cue_id: StringName) -> bool:
	return _streams.has(cue_id)


func cue_duration_seconds(cue_id: StringName) -> float:
	var stream := _streams.get(cue_id) as AudioStreamWAV
	return stream.get_length() if stream != null else 0.0


func play_cue(cue_id: StringName) -> bool:
	if _shutting_down or not _streams.has(cue_id):
		return false
	var definition := _cue_definitions.get(cue_id) as AudioCueDefinition
	if definition == null:
		return false
	var player: AudioStreamPlayer
	match definition.channel:
		AudioCueDefinition.Channel.TELEGRAPH:
			player = _telegraph_player
		AudioCueDefinition.Channel.UI:
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
	if _shutting_down:
		return
	_shutting_down = true
	stop_all()
	_streams.clear()
	_cue_definitions.clear()


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


func _on_root_close_requested() -> void:
	begin_shutdown()


func _make_procedural_stream(definition: AudioCueDefinition) -> AudioStreamWAV:
	var frame_count := maxi(1, roundi(definition.duration * audio_tuning.sample_rate))
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for frame: int in frame_count:
		var progress := float(frame) / float(frame_count)
		var phase := TAU * definition.frequency * float(frame) / float(audio_tuning.sample_rate)
		var oscillator := sin(phase)
		if definition.waveform == "square":
			oscillator = 1.0 if oscillator >= 0.0 else -1.0
		var envelope := (1.0 - progress) * minf(progress * 20.0, 1.0)
		data.encode_s16(frame * 2, int(clampf(oscillator * envelope * definition.volume, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = audio_tuning.sample_rate
	stream.stereo = false
	stream.data = data
	return stream
