class_name DeckDiscussionSessionStore
extends RefCounted

const ROOT_PATH := "user://deck_discussions"
const MAX_MESSAGES := 24

var _memory_sessions: Dictionary = {}


func create_or_load_session(deck_id: int) -> Dictionary:
	var path := _session_path(deck_id)
	var existing := _read_json_or_empty(path)
	if not existing.is_empty():
		_memory_sessions[deck_id] = existing.duplicate(true)
		return existing
	if _memory_sessions.has(deck_id):
		return (_memory_sessions[deck_id] as Dictionary).duplicate(true)
	var now := Time.get_datetime_string_from_system()
	var session := {
		"deck_id": deck_id,
		"created_at": now,
		"updated_at": now,
		"messages": [],
	}
	_memory_sessions[deck_id] = session.duplicate(true)
	_write_json(path, session)
	return session


func load_messages(deck_id: int) -> Array[Dictionary]:
	var session := create_or_load_session(deck_id)
	var messages_variant: Variant = session.get("messages", [])
	var result: Array[Dictionary] = []
	if messages_variant is Array:
		for item: Variant in messages_variant:
			if item is Dictionary:
				result.append(item)
	return result


func append_turn(deck_id: int, role: String, content: String, metadata: Dictionary = {}) -> bool:
	var session := create_or_load_session(deck_id)
	var messages := load_messages(deck_id)
	var entry := {
		"role": role,
		"content": content,
		"created_at": Time.get_datetime_string_from_system(),
		"metadata": metadata.duplicate(true),
	}
	messages.append(entry)
	while messages.size() > MAX_MESSAGES:
		messages.remove_at(0)
	session["messages"] = messages
	session["updated_at"] = Time.get_datetime_string_from_system()
	_memory_sessions[deck_id] = session.duplicate(true)
	return _write_json(_session_path(deck_id), session)


func clear_session(deck_id: int) -> bool:
	_memory_sessions.erase(deck_id)
	var path := _session_path(deck_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return true


func session_path_for_test(deck_id: int) -> String:
	return _session_path(deck_id)


func _session_path(deck_id: int) -> String:
	return "%s/%d/session.json" % [ROOT_PATH, deck_id]


func _write_json(path: String, payload: Dictionary) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	var dir_path := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(dir_path)
		if mkdir_error != OK:
			return false
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _read_json_or_empty(path: String) -> Dictionary:
	var global_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(global_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
