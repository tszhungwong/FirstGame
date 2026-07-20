class_name LocalSaveBackend
extends RefCounted


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func write_bytes_flush(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	file.close()
	return true


func remove_file(path: String) -> Error:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func rename_file(source_path: String, destination_path: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(destination_path)
	)


func promote_temporary(source_path: String, destination_path: String) -> Error:
	return rename_file(source_path, destination_path)
