class_name DialogueSequence
extends Resource

@export var entries: Array[DialogueEntry] = []


func is_empty() -> bool:
	return entries.is_empty()


func text_key_at(index: int) -> StringName:
	return entry_at(index).text_key


func entry_at(index: int) -> DialogueEntry:
	assert(not entries.is_empty(), "DialogueSequence has no entries")
	return entries[clampi(index, 0, entries.size() - 1)]
