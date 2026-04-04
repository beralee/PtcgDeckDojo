class_name BattleReviewArtifactStore
extends RefCounted


func write_review(match_dir: String, review: Dictionary) -> bool:
	return _write_json(_review_dir(match_dir).path_join("review.json"), review)


func read_review(match_dir: String) -> Dictionary:
	return _read_json_or_empty(_review_dir(match_dir).path_join("review.json"))


func write_stage_debug(match_dir: String, filename: String, payload: Dictionary) -> bool:
	return _write_json(_review_dir(match_dir).path_join(filename), payload)


func _review_dir(match_dir: String) -> String:
	return match_dir.path_join("review")


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
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
