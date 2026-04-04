class_name BattleAdviceSessionStore
extends RefCounted


func create_or_load_session(match_dir: String, player_view_index: int) -> Dictionary:
	var session_path := _advice_dir(match_dir).path_join("session.json")
	var existing := _read_json_or_empty(session_path)
	if not existing.is_empty():
		return existing

	var now := Time.get_datetime_string_from_system()
	var session := {
		"session_id": _make_session_id(match_dir),
		"created_at": now,
		"updated_at": now,
		"request_count": 0,
		"next_request_index": 1,
		"last_synced_event_index": 0,
		"last_synced_turn_number": 0,
		"last_advice_summary": "",
		"last_player_view_index": player_view_index,
		"latest_attempt_status": "idle",
		"latest_attempt_request_index": 1,
		"latest_success_request_index": 1,
	}
	_write_json(session_path, session)
	return session


func read_session(match_dir: String) -> Dictionary:
	return _read_json_or_empty(_advice_dir(match_dir).path_join("session.json"))


func write_session(match_dir: String, session: Dictionary) -> bool:
	return _write_json(_advice_dir(match_dir).path_join("session.json"), session)


func write_latest_attempt(match_dir: String, attempt: Dictionary) -> bool:
	var request_index := int(attempt.get("request_index", 0))
	var session := _load_or_create_session(match_dir, int(attempt.get("player_view_index", 0)))
	var now := Time.get_datetime_string_from_system()
	var session_path := _advice_dir(match_dir).path_join("session.json")
	var attempt_path := _advice_dir(match_dir).path_join("latest_advice.json")

	session["updated_at"] = now
	session["latest_attempt_status"] = String(attempt.get("status", "idle"))
	session["latest_attempt_request_index"] = request_index if request_index > 0 else int(session.get("latest_attempt_request_index", 1))
	session["request_count"] = maxi(int(session.get("request_count", 0)), request_index)
	session["next_request_index"] = maxi(int(session.get("next_request_index", 1)), request_index + 1 if request_index > 0 else 1)

	if not _write_json(attempt_path, attempt):
		return false
	return _write_json(session_path, session)


func write_latest_success(match_dir: String, success: Dictionary) -> bool:
	var request_index := int(success.get("request_index", 0))
	var session := _load_or_create_session(match_dir, int(success.get("player_view_index", 0)))
	var now := Time.get_datetime_string_from_system()
	var session_path := _advice_dir(match_dir).path_join("session.json")
	var advice_path := _advice_dir(match_dir).path_join("latest_advice.json")
	var success_path := _advice_dir(match_dir).path_join("latest_success.json")

	session["updated_at"] = now
	session["latest_attempt_status"] = String(success.get("status", "completed"))
	session["latest_attempt_request_index"] = request_index if request_index > 0 else int(session.get("latest_attempt_request_index", 1))
	session["latest_success_request_index"] = request_index if request_index > 0 else int(session.get("latest_success_request_index", 1))
	session["request_count"] = maxi(int(session.get("request_count", 0)), request_index)
	session["next_request_index"] = maxi(int(session.get("next_request_index", 1)), request_index + 1 if request_index > 0 else 1)

	if not _write_json(advice_path, success):
		return false
	if not _write_json(success_path, success):
		return false
	return _write_json(session_path, session)


func read_latest_success(match_dir: String) -> Dictionary:
	return _read_json_or_empty(_advice_dir(match_dir).path_join("latest_success.json"))


func write_request_debug_artifact(match_dir: String, request_index: int, artifact_kind: String, payload: Dictionary) -> bool:
	return _write_json(_advice_dir(match_dir).path_join(_request_artifact_filename(request_index, artifact_kind)), payload)


func read_request_debug_artifact(match_dir: String, request_index: int, artifact_kind: String) -> Dictionary:
	return _read_json_or_empty(_advice_dir(match_dir).path_join(_request_artifact_filename(request_index, artifact_kind)))


func _load_or_create_session(match_dir: String, player_view_index: int) -> Dictionary:
	var session_path := _advice_dir(match_dir).path_join("session.json")
	var existing := _read_json_or_empty(session_path)
	if not existing.is_empty():
		return existing
	return create_or_load_session(match_dir, player_view_index)


func _advice_dir(match_dir: String) -> String:
	return match_dir.path_join("advice")


func _make_session_id(match_dir: String) -> String:
	return match_dir.sha256_text().substr(0, 16)


func _request_artifact_filename(request_index: int, artifact_kind: String) -> String:
	return "advice_%s_%d.json" % [artifact_kind, request_index]


func write_raw_session_for_test(match_dir: String, raw_text: String) -> bool:
	var path := _advice_dir(match_dir).path_join("session.json")
	var global_path := ProjectSettings.globalize_path(path)
	var dir_path := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(dir_path)
		if mkdir_error != OK:
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(raw_text)
	file.close()
	return true


func _write_json(path: String, payload: Dictionary) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	var dir_path := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(dir_path)
		if mkdir_error != OK:
			return false

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _read_json_or_empty(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}
