class_name ScenarioCatalog
extends RefCounted


const JSON_EXTENSION := ".json"
const DEFAULT_SCENARIOS_DIR := "res://tests/scenarios/fixtures"
const IGNORED_DIRECTORY_NAMES := {
	"review_queue": true,
}


static func list_scenario_files(root_dir: String = DEFAULT_SCENARIOS_DIR) -> Array[String]:
	var files: Array[String] = []
	_collect_json_files(root_dir, files)
	files.sort()
	return files


static func load_scenario(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"_error": "unable_to_open",
			"_path": path,
		}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var result: Dictionary = parsed
		result["_path"] = path
		return result
	return {
		"_error": "invalid_json_root",
		"_path": path,
	}


static func load_all(root_dir: String = DEFAULT_SCENARIOS_DIR) -> Array[Dictionary]:
	var scenarios: Array[Dictionary] = []
	for path: String in list_scenario_files(root_dir):
		scenarios.append(load_scenario(path))
	return scenarios


static func _collect_json_files(path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name in [".", ".."]:
			name = dir.get_next()
			continue
		var child_path := path.path_join(name)
		if dir.current_is_dir():
			if IGNORED_DIRECTORY_NAMES.has(name):
				name = dir.get_next()
				continue
			_collect_json_files(child_path, files)
		elif name.ends_with(JSON_EXTENSION):
			files.append(child_path)
		name = dir.get_next()
	dir.list_dir_end()
