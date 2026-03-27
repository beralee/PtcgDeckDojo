class_name AgentVersionStore
extends RefCounted

## Agent 版本持久化：将 agent config 序列化为 JSON，管理版本谱系。

var base_dir: String = "user://ai_agents"


func save_version(config: Dictionary, metadata: Dictionary) -> String:
	_ensure_dir_exists()
	var generation: int = int(metadata.get("generation", 0))
	var timestamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var version_id := "v%03d_%s" % [generation, timestamp]
	var file_name := "agent_%s.json" % version_id

	var data := {
		"version": version_id,
		"generation": generation,
		"parent_version": str(metadata.get("parent_version", "")),
		"win_rate_vs_parent": float(metadata.get("win_rate_vs_parent", 0.0)),
		"timestamp": Time.get_datetime_string_from_system(),
		"heuristic_weights": config.get("heuristic_weights", {}),
		"mcts_config": config.get("mcts_config", {}),
	}

	var full_path := base_dir.path_join(file_name)
	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		print("[AgentVersionStore] 无法写入: %s" % full_path)
		return ""
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("[AgentVersionStore] 已保存: %s" % full_path)
	return full_path


func load_version(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	return data if data is Dictionary else {}


func load_latest() -> Dictionary:
	var versions := list_versions()
	if versions.is_empty():
		return {}
	return versions[versions.size() - 1]


func list_versions() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and file_name.begins_with("agent_"):
			var full_path := base_dir.path_join(file_name)
			var data := load_version(full_path)
			if not data.is_empty():
				results.append(data)
		file_name = dir.get_next()
	dir.list_dir_end()
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("generation", 0)) < int(b.get("generation", 0))
	)
	return results


func _ensure_dir_exists() -> void:
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
