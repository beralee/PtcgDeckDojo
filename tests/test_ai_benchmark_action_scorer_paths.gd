class_name TestAIBenchmarkActionScorerPaths
extends TestBase

const BenchmarkRunnerSceneScript = preload("res://scenes/tuner/BenchmarkRunner.gd")
const AIVersionRegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")
const TrainingRunRegistryScript = preload("res://scripts/ai/TrainingRunRegistry.gd")

const TEST_VERSION_BASE_DIR := "user://benchmark_action_scorer_versions_test"
const TEST_RUN_BASE_DIR := "user://benchmark_action_scorer_runs_test"


func _cleanup_tree(base_dir: String) -> void:
	var dir_path := ProjectSettings.globalize_path(base_dir)
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


func test_publish_and_record_persists_candidate_and_baseline_action_scorers() -> String:
	_cleanup_tree(TEST_VERSION_BASE_DIR)
	_cleanup_tree(TEST_RUN_BASE_DIR)
	var version_registry := AIVersionRegistryScript.new()
	version_registry.base_dir = TEST_VERSION_BASE_DIR
	version_registry.publish_playable_version({
		"version_id": "AI-20260330-01",
		"display_name": "approved best",
		"agent_config_path": "user://ai_agents/approved.json",
		"value_net_path": "user://ai_models/approved_value.json",
		"action_scorer_path": "user://ai_models/approved_action.json",
	})
	var runner = BenchmarkRunnerSceneScript.new()
	runner.call("_publish_and_record", {
		"run-id": "run_action_failed",
		"pipeline-name": "miraidon_focus_training",
		"run-dir": "user://training_data/runs/run_action_failed",
		"summary-output": "user://training_data/runs/run_action_failed/benchmark/summary.json",
		"run-registry-dir": TEST_RUN_BASE_DIR,
		"version-registry-dir": TEST_VERSION_BASE_DIR,
		"baseline-version-id": "AI-20260330-01",
		"baseline-agent-config": "user://ai_agents/approved.json",
		"baseline-value-net": "user://ai_models/approved_value.json",
		"baseline-action-scorer": "user://ai_models/approved_action.json",
	}, {
		"candidate_agent_config_path": "user://ai_agents/candidate.json",
		"candidate_value_net_path": "user://ai_models/candidate_value.json",
		"candidate_action_scorer_path": "user://ai_models/candidate_action.json",
		"baseline_agent_config_path": "user://ai_agents/approved.json",
		"baseline_value_net_path": "user://ai_models/approved_value.json",
		"baseline_action_scorer_path": "user://ai_models/approved_action.json",
		"gate_passed": false,
		"win_rate_vs_current_best": 0.41,
		"total_matches": 16,
		"timeouts": 0,
		"failures": 0,
	})
	var run_registry := TrainingRunRegistryScript.new()
	run_registry.base_dir = TEST_RUN_BASE_DIR
	var run_record := run_registry.get_run("run_action_failed")
	var result := run_checks([
		assert_eq(str(run_record.get("candidate_action_scorer_path", "")), "user://ai_models/candidate_action.json", "run records should persist candidate action scorer paths"),
		assert_eq(str(run_record.get("baseline_action_scorer_path", "")), "user://ai_models/approved_action.json", "run records should persist baseline action scorer paths"),
	])
	_cleanup_tree(TEST_VERSION_BASE_DIR)
	_cleanup_tree(TEST_RUN_BASE_DIR)
	return result


func test_publish_and_record_promotes_action_scorer_into_version_registry() -> String:
	_cleanup_tree(TEST_VERSION_BASE_DIR)
	_cleanup_tree(TEST_RUN_BASE_DIR)
	var version_registry := AIVersionRegistryScript.new()
	version_registry.base_dir = TEST_VERSION_BASE_DIR
	version_registry.publish_playable_version({
		"version_id": "AI-20260330-01",
		"display_name": "approved best",
		"agent_config_path": "user://ai_agents/approved.json",
		"value_net_path": "user://ai_models/approved_value.json",
		"action_scorer_path": "user://ai_models/approved_action.json",
	})
	var runner = BenchmarkRunnerSceneScript.new()
	runner.call("_publish_and_record", {
		"run-id": "run_action_passed",
		"pipeline-name": "miraidon_focus_training",
		"run-dir": "user://training_data/runs/run_action_passed",
		"summary-output": "user://training_data/runs/run_action_passed/benchmark/summary.json",
		"run-registry-dir": TEST_RUN_BASE_DIR,
		"version-registry-dir": TEST_VERSION_BASE_DIR,
		"publish-version-id": "AI-20260330-02",
		"publish-display-name": "candidate promoted",
		"baseline-version-id": "AI-20260330-01",
		"baseline-agent-config": "user://ai_agents/approved.json",
		"baseline-value-net": "user://ai_models/approved_value.json",
		"baseline-action-scorer": "user://ai_models/approved_action.json",
	}, {
		"candidate_agent_config_path": "user://ai_agents/candidate.json",
		"candidate_value_net_path": "user://ai_models/candidate_value.json",
		"candidate_action_scorer_path": "user://ai_models/candidate_action.json",
		"baseline_agent_config_path": "user://ai_agents/approved.json",
		"baseline_value_net_path": "user://ai_models/approved_value.json",
		"baseline_action_scorer_path": "user://ai_models/approved_action.json",
		"gate_passed": true,
		"win_rate_vs_current_best": 0.58,
		"total_matches": 16,
		"timeouts": 0,
		"failures": 0,
	})
	var latest := version_registry.get_latest_playable_version()
	var run_registry := TrainingRunRegistryScript.new()
	run_registry.base_dir = TEST_RUN_BASE_DIR
	var run_record := run_registry.get_run("run_action_passed")
	var result := run_checks([
		assert_eq(str(latest.get("action_scorer_path", "")), "user://ai_models/candidate_action.json", "published versions should persist action scorer paths"),
		assert_eq(str(latest.get("parent_baseline_action_scorer_path", "")), "user://ai_models/approved_action.json", "published versions should preserve baseline action scorer provenance"),
		assert_eq(str(run_record.get("candidate_action_scorer_path", "")), "user://ai_models/candidate_action.json", "published run records should persist candidate action scorer paths"),
	])
	_cleanup_tree(TEST_VERSION_BASE_DIR)
	_cleanup_tree(TEST_RUN_BASE_DIR)
	return result
