class_name BattleLearningPoolStore
extends RefCounted


const LEARNING_DIR := "learning"
const REQUEST_FILENAME := "learning_request.json"


func read_learning_request(match_dir: String) -> Dictionary:
	return _read_json_or_empty(_request_path(match_dir))


func is_marked_for_learning(match_dir: String) -> bool:
	return not read_learning_request(match_dir).is_empty()


func mark_match_for_learning(match_dir: String, payload: Dictionary = {}) -> bool:
	if match_dir.strip_edges() == "":
		return false
	var request: Dictionary = read_learning_request(match_dir)
	if request.is_empty():
		request = {
			"version": 1,
			"status": "marked",
			"source": "manual_post_match_button",
			"both_players": true,
			"marked_at_unix": Time.get_unix_time_from_system(),
		}
	else:
		request["status"] = "marked"
		request["both_players"] = true
	for key: Variant in payload.keys():
		request[key] = payload[key]
	return _write_json(_request_path(match_dir), request)


func _request_path(match_dir: String) -> String:
	return match_dir.path_join(LEARNING_DIR).path_join(REQUEST_FILENAME)


func _write_json(path: String, payload: Dictionary) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	var parent_dir := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(parent_dir)
		if mkdir_error != OK:
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _read_json_or_empty(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
