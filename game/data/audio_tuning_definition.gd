class_name AudioTuningDefinition
extends Resource

@export var sample_rate: int = 22050
@export var sfx_voice_count: int = 6
@export var sfx_bus: StringName = &"SFX"
@export var ui_bus: StringName = &"UI"
@export var telegraph_volume_db: float = 2.0
@export var cue_definitions: Array[AudioCueDefinition] = []
