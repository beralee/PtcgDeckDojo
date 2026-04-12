class_name TestAIActionScorerArtifacts
extends TestBase

const RunRegistryScript = preload("res://scripts/ai/TrainingRunRegistry.gd")
const VersionRegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")
const TEST_RUN_BASE_DIR := "user://training_runs_action_scorer_test"
const TEST_VERSION_BASE_DIR := "user://ai_versions_action_scorer_test"


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


func test_training_run_registry_persists_action_scorer_path() -> String:
	_cleanup_tree(TEST_RUN_BASE_DIR)
	var registry := RunRegistryScript.new()
	registry.base_dir = TEST_RUN_BASE_DIR
	registry.create_run("run_action_scorer", "miraidon_focus_training", {
		"candidate_agent_config_path": "user://ai_agents/candidate.json",
		"candidate_value_net_path": "user://ai_models/value_net_candidate.json",
		"candidate_action_scorer_path": "user://ai_models/action_scorer_candidate.json",
		"candidate_interaction_scorer_path": "user://ai_models/interaction_scorer_candidate.json",
	})
	var loaded := registry.get_run("run_action_scorer")
	var result := run_checks([
		assert_eq(str(loaded.get("candidate_action_scorer_path", "")), "user://ai_models/action_scorer_candidate.json", "run registry should persist candidate action scorer artifacts"),
		assert_eq(str(loaded.get("candidate_interaction_scorer_path", "")), "user://ai_models/interaction_scorer_candidate.json", "run registry should persist candidate interaction scorer artifacts"),
	])
	_cleanup_tree(TEST_RUN_BASE_DIR)
	return result


func test_ai_version_registry_preserves_action_scorer_artifacts() -> String:
	_cleanup_tree(TEST_VERSION_BASE_DIR)
	var registry := VersionRegistryScript.new()
	registry.base_dir = TEST_VERSION_BASE_DIR
	registry.publish_playable_version({
		"version_id": "AI-action-01",
		"display_name": "action scorer smoke",
		"agent_config_path": "user://ai_agents/agent.json",
		"value_net_path": "user://ai_models/value_net.json",
		"action_scorer_path": "user://ai_models/action_scorer.json",
		"interaction_scorer_path": "user://ai_models/interaction_scorer.json",
	})
	var loaded := registry.get_version("AI-action-01")
	var latest := registry.get_latest_approved_artifacts()
	var result := run_checks([
		assert_eq(str(loaded.get("action_scorer_path", "")), "user://ai_models/action_scorer.json", "version registry should persist action scorer artifacts"),
		assert_eq(str(latest.get("action_scorer_path", "")), "user://ai_models/action_scorer.json", "approved artifact lookup should expose action scorer artifacts"),
		assert_eq(str(loaded.get("interaction_scorer_path", "")), "user://ai_models/interaction_scorer.json", "version registry should persist interaction scorer artifacts"),
		assert_eq(str(latest.get("interaction_scorer_path", "")), "user://ai_models/interaction_scorer.json", "approved artifact lookup should expose interaction scorer artifacts"),
	])
	_cleanup_tree(TEST_VERSION_BASE_DIR)
	return result
