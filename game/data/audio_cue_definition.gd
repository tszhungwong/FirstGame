class_name AudioCueDefinition
extends Resource

enum Channel {
	SFX,
	TELEGRAPH,
	UI,
}

@export var id: StringName = &""
@export var frequency: float = 0.0
@export var duration: float = 0.0
@export var volume: float = 0.0
@export_enum("sine", "square") var waveform: String = "sine"
@export var channel: Channel = Channel.SFX
