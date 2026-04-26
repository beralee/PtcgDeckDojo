class_name ScenarioReviewQueueHydrator
extends RefCounted


const ScenarioRunnerScript = preload("res://tests/scenarios/ScenarioRunner.gd")

const REVIEW_QUEUE_DIRNAME := "review_queue"
const PENDING_DIRNAME := "pending"
const JSON_EXTENSION := ".json"


func hydrate_review_queue(review_queue_dir: String, scenarios_root: String, runtime_mode: String = "rules_only", overwrite: bool = false) -> Dictionary:
	var request_files: Array[String] = _list_pending_request_files(review_queue_dir)
	var hydrated: Array[Dictionary] = []
	var skipped: Array[Dictionary] = []
	var errors: Array[Dictionary] = []

	for request_path: String in request_files:
		var result: Dictionary = hydrate_request(request_path, scenarios_root, runtime_mode, overwrite)
		var status: String = str(result.get("status", ""))
		match status:
			"hydrated":
				hydrated.append(result)
			"skipped":
				skipped.append(result)
			_:
				errors.append(result)

	return {
		"review_queue_dir": review_queue_dir,
		"scenarios_root": scenarios_root,
		"runtime_mode": runtime_mode,
		"hydrated": hydrated,
		"skipped": skipped,
		"errors": errors,
		"hydrated_count": hydrated.size(),
		"skipped_count": skipped.size(),
		"error_count": errors.size(),
	}


func hydrate_request(request_path: String, scenarios_root: String, runtime_mode: String = "rules_only", overwrite: bool = false) -> Dictionary:
	var request_payload: Dictionary = _load_json_dict(request_path)
	if request_payload.is_empty():
		return {
			"status": "error",
			"request_path": request_path,
			"reason": "invalid_request_json",
		}

	if not overwrite and _already_hydrated(request_payload):
		return {
			"status": "skipped",
			"request_path": request_path,
			"reason": "already_hydrated",
		}

	var scenario_relative_path: String = str(request_payload.get("scenario_path", ""))
	if scenario_relative_path == "":
		return {
			"status": "error",
			"request_path": request_path,
			"reason": "missing_scenario_path",
		}

	var scenario_path: String = scenarios_root.path_join(scenario_relative_path)
	if not FileAccess.file_exists(scenario_path):
		return {
			"status": "error",
			"request_path": request_path,
			"scenario_path": scenario_path,
			"reason": "scenario_not_found",
		}

	var runner = ScenarioRunnerScript.new()
	var verdict: Dictionary = runner.run_scenario(scenario_path, runtime_mode)
	request_payload["status"] = "pending_review"
	request_payload["ai_end_state"] = verdict.get("ai_end_state", {})
	request_payload["diff"] = verdict.get("diff", [])
	request_payload["runner_verdict"] = {
		"status": str(verdict.get("status", "")),
		"reason": str(verdict.get("reason", "")),
		"matched_alternative_id": str(verdict.get("matched_alternative_id", "")),
		"dominant": bool(verdict.get("dominant", false)),
		"runtime_mode": str(verdict.get("runtime_mode", runtime_mode)),
		"runtime_result": verdict.get("runtime_result", {}),
		"errors": verdict.get("errors", []),
		"scenario_path": str(verdict.get("scenario_path", scenario_path)),
	}

	var file := FileAccess.open(request_path, FileAccess.WRITE)
	if file == null:
		return {
			"status": "error",
			"request_path": request_path,
			"scenario_path": scenario_path,
			"reason": "unable_to_open_for_write",
		}
	file.store_string(JSON.stringify(request_payload, "\t") + "\n")

	return {
		"status": "hydrated",
		"request_path": request_path,
		"scenario_path": scenario_path,
		"verdict_status": str(verdict.get("status", "")),
	}


func _list_pending_request_files(review_queue_dir: String) -> Array[String]:
	var pending_dir: String = review_queue_dir.path_join(PENDING_DIRNAME)
	var files: Array[String] = []
	_collect_json_files(pending_dir, files)
	files.sort()
	return files


func _collect_json_files(dir_path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name in [".", ".."]:
			name = dir.get_next()
			continue
		var child_path := dir_path.path_join(name)
		if dir.current_is_dir():
			_collect_json_files(child_path, files)
		elif name.ends_with(JSON_EXTENSION):
			files.append(child_path)
		name = dir.get_next()
	dir.list_dir_end()


func _load_json_dict(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _already_hydrated(request_payload: Dictionary) -> bool:
	var runner_verdict: Variant = request_payload.get("runner_verdict", {})
	if runner_verdict is Dictionary and not (runner_verdict as Dictionary).is_empty():
		return true
	var ai_end_state: Variant = request_payload.get("ai_end_state", {})
	var diff: Variant = request_payload.get("diff", [])
	var has_ai_end_state: bool = ai_end_state is Dictionary and not (ai_end_state as Dictionary).is_empty()
	var has_diff: bool = diff is Array and not (diff as Array).is_empty()
	return has_ai_end_state or has_diff
