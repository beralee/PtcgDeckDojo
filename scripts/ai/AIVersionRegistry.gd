class_name AIVersionRegistry
extends RefCounted

var base_dir: String = "user://ai_versions"
const INDEX_FILE := "index.json"


func save_version(record: Dictionary) -> bool:
	var version_id := str(record.get("version_id", ""))
	if version_id.is_empty():
		return false

	_ensure_dir_exists()
	var index_data: Variant = _load_index()
	if index_data == null:
		return false

	var index: Dictionary = index_data
	var version_record := record.duplicate(true)
	if str(version_record.get("created_at", "")).is_empty():
		version_record["created_at"] = Time.get_datetime_string_from_system()
	version_record["save_order"] = _next_save_order(index)

	index[version_id] = version_record
	return _save_index(index)


func publish_playable_version(record: Dictionary) -> bool:
	var published_record := record.duplicate(true)
	published_record["status"] = "playable"
	return save_version(published_record)


func generate_version_id(date_prefix: String = "") -> String:
	var normalized_date := date_prefix.strip_edges()
	if normalized_date.is_empty():
		normalized_date = Time.get_datetime_string_from_system().substr(0, 10).replace("-", "")

	var next_index := 1
	var index_data: Variant = _load_index()
	if index_data is Dictionary:
		for version_key: Variant in (index_data as Dictionary).keys():
			var version_id := str(version_key)
			var parts := version_id.split("-")
			if parts.size() != 3:
				continue
			if parts[0] != "AI" or parts[1] != normalized_date:
				continue
			next_index = maxi(next_index, int(parts[2]) + 1)

	return "AI-%s-%02d" % [normalized_date, next_index]


func get_version(version_id: String) -> Dictionary:
	var index_data: Variant = _load_index()
	if index_data == null:
		return {}
	return ((index_data as Dictionary).get(version_id, {}) as Dictionary).duplicate(true)


func list_playable_versions() -> Array[Dictionary]:
	var versions: Array[Dictionary] = []
	var index_data: Variant = _load_index()
	if index_data == null:
		return versions

	for value: Variant in (index_data as Dictionary).values():
		if value is Dictionary and str((value as Dictionary).get("status", "")) == "playable":
			versions.append((value as Dictionary).duplicate(true))

	versions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_created_at := str(a.get("created_at", ""))
		var b_created_at := str(b.get("created_at", ""))
		if a_created_at == b_created_at:
			var a_save_order := int(a.get("save_order", 0))
			var b_save_order := int(b.get("save_order", 0))
			if a_save_order != b_save_order:
				return a_save_order < b_save_order
			return str(a.get("version_id", "")) < str(b.get("version_id", ""))
		return a_created_at < b_created_at
	)
	return versions


func list_playable_versions_for_strategy(strategy_id: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for version: Dictionary in list_playable_versions():
		if _is_version_compatible_with_strategy(version, strategy_id):
			filtered.append(version)
	return filtered


func get_latest_playable_version() -> Dictionary:
	var versions := list_playable_versions()
	return {} if versions.is_empty() else versions.back().duplicate(true)


func get_latest_playable_version_for_strategy(strategy_id: String) -> Dictionary:
	var versions := list_playable_versions_for_strategy(strategy_id)
	return {} if versions.is_empty() else versions.back().duplicate(true)


func get_latest_approved_version() -> Dictionary:
	return get_latest_playable_version()


func get_latest_approved_artifacts() -> Dictionary:
	var latest := get_latest_approved_version()
	if latest.is_empty():
		return {}
	return {
		"version_id": str(latest.get("version_id", "")),
		"display_name": str(latest.get("display_name", "")),
		"status": str(latest.get("status", "")),
		"agent_config_path": str(latest.get("agent_config_path", "")),
		"value_net_path": str(latest.get("value_net_path", "")),
		"action_scorer_path": str(latest.get("action_scorer_path", "")),
		"interaction_scorer_path": str(latest.get("interaction_scorer_path", "")),
		"source_run_id": str(latest.get("source_run_id", "")),
		"lane_recipe_id": str(latest.get("lane_recipe_id", "")),
		"parent_approved_baseline_id": str(latest.get("parent_approved_baseline_id", "")),
		"benchmark_summary": (latest.get("benchmark_summary", {}) as Dictionary).duplicate(true),
		"benchmark_quality_summary": (latest.get("benchmark_quality_summary", latest.get("benchmark_summary", {})) as Dictionary).duplicate(true),
	}


func _load_index() -> Variant:
	var index_path := _index_path()
	if not FileAccess.file_exists(index_path):
		return {}

	var file := FileAccess.open(index_path, FileAccess.READ)
	if file == null:
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return null

	var data: Variant = json.data
	return data if data is Dictionary else null


func _save_index(index: Dictionary) -> bool:
	_ensure_dir_exists()
	var file := FileAccess.open(_index_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(index, "  "))
	file.close()
	return true


func _ensure_dir_exists() -> void:
	var global_dir := ProjectSettings.globalize_path(base_dir)
	if not DirAccess.dir_exists_absolute(global_dir):
		DirAccess.make_dir_recursive_absolute(global_dir)


func _index_path() -> String:
	return base_dir.path_join(INDEX_FILE)


func _next_save_order(index: Dictionary) -> int:
	var next_order := 0
	for value: Variant in index.values():
		if value is Dictionary:
			next_order = maxi(next_order, int((value as Dictionary).get("save_order", 0)))
	return next_order + 1


func _is_version_compatible_with_strategy(version: Dictionary, strategy_id: String) -> bool:
	var compatible_strategy_id := str(version.get("compatible_strategy_id", ""))
	if compatible_strategy_id == "":
		return true
	if strategy_id == "":
		return false
	return compatible_strategy_id == strategy_id
