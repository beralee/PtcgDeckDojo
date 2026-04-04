class_name TestTrainingRunRegistry
extends TestBase

const RegistryScript = preload("res://scripts/ai/TrainingRunRegistry.gd")
const TEST_BASE_DIR := "user://training_runs_test"


func _cleanup() -> void:
	var dir_path := ProjectSettings.globalize_path(TEST_BASE_DIR)
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	_remove_dir_recursive(dir_path)
	DirAccess.remove_absolute(dir_path)


func _remove_dir_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var child_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_remove_dir_recursive(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)

		file_name = dir.get_next()
	dir.list_dir_end()


func test_start_run_creates_metadata_with_run_id() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = TEST_BASE_DIR
	var run: Dictionary = registry.start_run("fixed_three_deck_training")
	var run_id := str(run.get("run_id", ""))
	var run_path := ProjectSettings.globalize_path(TEST_BASE_DIR).path_join(run_id).path_join("run.json")
	var result := run_checks([
		assert_true(run_id.begins_with("run_"), "run_id should be generated automatically"),
		assert_eq(run.get("pipeline_name", ""), "fixed_three_deck_training", "pipeline name should be recorded"),
		assert_eq(run.get("status", ""), "running", "new runs should start as running"),
		assert_true(str(run.get("created_at", "")) != "", "created_at should be recorded"),
		assert_true(FileAccess.file_exists(run_path), "run should be written to user://training_runs_test/<run_id>/run.json"),
		assert_eq(registry.get_run(run_id).get("pipeline_name", ""), "fixed_three_deck_training", "saved run should be readable"),
	])
	_cleanup()
	return result


func test_start_run_generates_unique_ids_for_rapid_calls() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = TEST_BASE_DIR
	var first_run: Dictionary = registry.start_run("fixed_three_deck_training")
	var second_run: Dictionary = registry.start_run("fixed_three_deck_training")
	var first_run_id := str(first_run.get("run_id", ""))
	var second_run_id := str(second_run.get("run_id", ""))
	var result := run_checks([
		assert_true(first_run_id != "", "first run_id should not be empty"),
		assert_true(second_run_id != "", "second run_id should not be empty"),
		assert_true(first_run_id != second_run_id, "rapid runs should not collide on run_id"),
		assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(TEST_BASE_DIR).path_join(first_run_id).path_join("run.json")), "first run should persist"),
		assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(TEST_BASE_DIR).path_join(second_run_id).path_join("run.json")), "second run should persist"),
	])
	_cleanup()
	return result


func test_mark_run_completed_persists_published_version() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = TEST_BASE_DIR
	var run: Dictionary = registry.start_run("fixed_three_deck_training")
	var run_id := str(run.get("run_id", ""))
	var completed := registry.complete_run(run_id, {
		"published_version_id": "AI-20260328-01",
		"status": "published",
	})
	var persisted := registry.get_run(run_id)
	var result := run_checks([
		assert_eq(completed.get("published_version_id", ""), "AI-20260328-01", "published version should be recorded"),
		assert_eq(completed.get("status", ""), "published", "status should update to published"),
		assert_true(str(completed.get("completed_at", "")) != "", "completed_at should be written"),
		assert_eq(persisted.get("published_version_id", ""), "AI-20260328-01", "persisted record should keep published version"),
		assert_eq(persisted.get("status", ""), "published", "persisted record should keep published status"),
		assert_eq(persisted.get("completed_at", ""), completed.get("completed_at", ""), "completed_at should persist to disk"),
	])
	_cleanup()
	return result


func test_get_run_returns_empty_dictionary_for_invalid_json() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = TEST_BASE_DIR
	var run_id := "run_invalid_json"
	var run_dir := ProjectSettings.globalize_path(TEST_BASE_DIR).path_join(run_id)
	var create_error := DirAccess.make_dir_recursive_absolute(run_dir)
	var run_file := FileAccess.open(run_dir.path_join("run.json"), FileAccess.WRITE)
	if run_file != null:
		run_file.store_string("{invalid json")
		run_file.close()

	var loaded := registry.get_run(run_id)
	var result := run_checks([
		assert_true(create_error == OK, "test run directory should be created"),
		assert_true(run_file != null, "invalid json fixture should be written"),
		assert_eq(loaded, {}, "invalid json should return an empty record"),
	])
	_cleanup()
	return result


func test_create_run_uses_caller_supplied_run_id_and_metadata() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = TEST_BASE_DIR
	var created := registry.create_run("run_manual_publish", "fixed_three_deck_training", {
		"run_dir": "D:/tmp/run_manual_publish",
		"status": "benchmarking",
	})
	var persisted := registry.get_run("run_manual_publish")
	var result := run_checks([
		assert_eq(str(created.get("run_id", "")), "run_manual_publish", "create_run should preserve the caller-supplied run id"),
		assert_eq(str(created.get("status", "")), "benchmarking", "create_run should merge metadata into the run record"),
		assert_eq(str(persisted.get("run_dir", "")), "D:/tmp/run_manual_publish", "create_run should persist metadata to disk"),
	])
	_cleanup()
	return result


func test_create_run_persists_baseline_and_candidate_artifacts() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = TEST_BASE_DIR
	var created := registry.create_run("run_with_artifacts", "fixed_three_deck_training", {
		"baseline_version_id": "AI-20260329-01",
		"baseline_agent_config_path": "user://ai_agents/approved.json",
		"baseline_value_net_path": "user://ai_models/approved.json",
		"candidate_agent_config_path": "user://ai_agents/candidate.json",
		"candidate_value_net_path": "user://ai_models/candidate.json",
		"candidate_action_scorer_path": "user://ai_models/action_scorer_candidate.json",
	})
	var persisted := registry.get_run("run_with_artifacts")
	var result := run_checks([
		assert_eq(str(created.get("baseline_version_id", "")), "AI-20260329-01", "create_run should persist the parent approved baseline id"),
		assert_eq(str(created.get("baseline_agent_config_path", "")), "user://ai_agents/approved.json", "create_run should persist the baseline agent config path"),
		assert_eq(str(created.get("baseline_value_net_path", "")), "user://ai_models/approved.json", "create_run should persist the baseline value net path"),
		assert_eq(str(persisted.get("candidate_agent_config_path", "")), "user://ai_agents/candidate.json", "create_run should persist the candidate agent path"),
		assert_eq(str(persisted.get("candidate_value_net_path", "")), "user://ai_models/candidate.json", "create_run should persist the candidate value path"),
		assert_eq(str(persisted.get("candidate_action_scorer_path", "")), "user://ai_models/action_scorer_candidate.json", "create_run should persist the candidate action scorer path"),
	])
	_cleanup()
	return result


func test_complete_run_distinguishes_benchmark_failed_from_published() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = TEST_BASE_DIR
	var failed := registry.create_run("run_failed_gate", "fixed_three_deck_training", {})
	var published := registry.create_run("run_published_gate", "fixed_three_deck_training", {})
	var failed_record := registry.complete_run(str(failed.get("run_id", "")), {
		"status": "benchmark_failed",
		"benchmark_gate_passed": false,
		"benchmark_summary_path": "user://training_runs_test/run_failed_gate/summary.json",
	})
	var published_record := registry.complete_run(str(published.get("run_id", "")), {
		"status": "published",
		"benchmark_gate_passed": true,
		"published_version_id": "AI-20260329-02",
	})
	var result := run_checks([
		assert_eq(str(failed_record.get("status", "")), "benchmark_failed", "failed benchmark runs should keep a distinct status"),
		assert_false(bool(failed_record.get("benchmark_gate_passed", true)), "failed benchmark runs should record benchmark_gate_passed=false"),
		assert_eq(str(published_record.get("status", "")), "published", "published runs should keep published status"),
		assert_true(bool(published_record.get("benchmark_gate_passed", false)), "published runs should record benchmark_gate_passed=true"),
		assert_eq(str(published_record.get("published_version_id", "")), "AI-20260329-02", "published runs should keep the published version id"),
	])
	_cleanup()
	return result
