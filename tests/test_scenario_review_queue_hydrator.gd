class_name TestScenarioReviewQueueHydrator
extends TestBase


const HydratorScript = preload("res://scripts/tools/scenario_review/ScenarioReviewQueueHydrator.gd")

const TEST_ROOT := "user://test_scenario_review_queue_hydrator"
const SOURCE_SCENARIO_FIXTURE := "res://tests/scenarios/fixtures/e2e_valid_scenario.json"


func before_each() -> void:
	_clear_root()


func after_each() -> void:
	_clear_root()


func test_hydrate_review_queue_populates_runner_verdict_for_pending_request() -> String:
	var scenarios_root := TEST_ROOT.path_join("scenarios")
	var review_queue_root := TEST_ROOT.path_join("review_queue")
	var scenario_path := scenarios_root.path_join("deck_569061").path_join("e2e_valid_scenario.json")
	var request_path := review_queue_root.path_join("pending").path_join("e2e_valid_scenario.json")

	_write_text(scenario_path, FileAccess.get_file_as_string(SOURCE_SCENARIO_FIXTURE))
	_write_json(request_path, {
		"review_request_id": "e2e_valid_scenario",
		"scenario_id": "e2e_valid_scenario",
		"status": "pending_review",
		"expected_end_state": {},
		"ai_end_state": {},
		"diff": [],
		"llm_suggestion": {
			"resolution": "",
			"confidence": 0.0,
			"reason": "",
		},
		"human_resolution": "",
		"scenario_path": "deck_569061/e2e_valid_scenario.json",
	})

	var hydrator = HydratorScript.new()
	var report: Dictionary = hydrator.hydrate_review_queue(review_queue_root, scenarios_root)
	var hydrated_request: Dictionary = _read_json(request_path)
	var runner_verdict: Dictionary = hydrated_request.get("runner_verdict", {})

	return run_checks([
		assert_eq(int(report.get("hydrated_count", -1)), 1, "Hydrator should update one pending request"),
		assert_eq(int(report.get("error_count", -1)), 0, "Hydrator should not emit errors for a valid fixture"),
		assert_eq(str(hydrated_request.get("status", "")), "pending_review", "Hydrator should preserve pending review status"),
		assert_eq(str(runner_verdict.get("status", "")), "PASS", "Hydrator should attach the runner verdict status"),
		assert_true(not (hydrated_request.get("ai_end_state", {}) as Dictionary).is_empty(), "Hydrator should attach ai_end_state"),
		assert_eq(int((runner_verdict.get("runtime_result", {}) as Dictionary).get("steps", -1)), 1, "Hydrator should preserve runtime step count from the runner"),
	])


func test_hydrate_review_queue_skips_already_hydrated_requests_without_overwrite() -> String:
	var scenarios_root := TEST_ROOT.path_join("scenarios")
	var review_queue_root := TEST_ROOT.path_join("review_queue")
	var scenario_path := scenarios_root.path_join("deck_569061").path_join("e2e_valid_scenario.json")
	var request_path := review_queue_root.path_join("pending").path_join("e2e_valid_scenario.json")

	_write_text(scenario_path, FileAccess.get_file_as_string(SOURCE_SCENARIO_FIXTURE))
	_write_json(request_path, {
		"review_request_id": "e2e_valid_scenario",
		"scenario_id": "e2e_valid_scenario",
		"status": "pending_review",
		"expected_end_state": {},
		"ai_end_state": {
			"sentinel": true,
		},
		"diff": [],
		"runner_verdict": {
			"status": "PASS",
		},
		"scenario_path": "deck_569061/e2e_valid_scenario.json",
	})

	var hydrator = HydratorScript.new()
	var report: Dictionary = hydrator.hydrate_review_queue(review_queue_root, scenarios_root)
	var hydrated_request: Dictionary = _read_json(request_path)

	return run_checks([
		assert_eq(int(report.get("hydrated_count", -1)), 0, "Hydrator should not overwrite existing requests by default"),
		assert_eq(int(report.get("skipped_count", -1)), 1, "Hydrator should report the pre-hydrated request as skipped"),
		assert_true(bool((hydrated_request.get("ai_end_state", {}) as Dictionary).get("sentinel", false)), "Hydrator should leave existing hydrated content untouched without overwrite"),
	])


func _write_text(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)


func _write_json(path: String, payload: Dictionary) -> void:
	_write_text(path, JSON.stringify(payload, "\t") + "\n")


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


func _clear_root() -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return
	_remove_children(absolute_root)
	DirAccess.remove_absolute(absolute_root)


func _remove_children(dir_path: String) -> void:
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
			_remove_children(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		name = dir.get_next()
	dir.list_dir_end()
