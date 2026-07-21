class_name AudioTuningDefinition
extends Resource

@export var sample_rate: int = 0
@export var sfx_voice_count: int = 0
@export var sfx_bus: StringName = &""
@export var telegraph_bus: StringName = &""
@export var ui_bus: StringName = &""
@export var telegraph_gain_db: float = 0.0
@export var cue_definitions: Array[AudioCueDefinition] = []
