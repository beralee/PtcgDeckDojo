class_name TestSuiteCatalog
extends RefCounted

const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")

const TEST_DIR := "res://tests"
const GROUP_FUNCTIONAL := "functional"
const GROUP_AI_TRAINING := "ai_training"

const AI_TRAINING_FILES := {
	"test_agent_version_store.gd": true,
	"test_ai_action_feature_encoder.gd": true,
	"test_ai_action_scorer_artifacts.gd": true,
	"test_ai_action_scorer_runtime.gd": true,
	"test_ai_baseline.gd": true,
	"test_ai_benchmark.gd": true,
	"test_ai_benchmark_action_scorer_paths.gd": true,
	"test_ai_decision_sample_exporter.gd": true,
	"test_ai_decision_trace.gd": true,
	"test_ai_feature_extractor.gd": true,
	"test_ai_headless_action_builder.gd": true,
	"test_ai_interaction_planner.gd": true,
	"test_ai_phase2_benchmark.gd": true,
	"test_ai_phase3_regression.gd": true,
	"test_ai_training_test_runner.gd": true,
	"test_action_cap_probe.gd": true,
	"test_ai_strategy_wiring.gd": true,
	"test_ai_strong_fixed_openings.gd": true,
	"test_deck_strategy_contract.gd": true,
	"test_deck_strategy_registry_expansion.gd": true,
	"test_ai_tool_actions.gd": true,
	"test_ai_version_registry.gd": true,
	"test_benchmark_evaluator.gd": true,
	"test_deck_identity_tracker.gd": true,
	"test_evolution_engine.gd": true,
	"test_gardevoir_value_net.gd": true,
	"test_gardevoir_miraidon_trace_regressions.gd": true,
	"test_gardevoir_shell_lock.gd": true,
	"test_gardevoir_strategy_churn.gd": true,
	"test_gardevoir_tm_setup_priority.gd": true,
	"test_gardevoir_fast_evolution_t1.gd": true,
	"test_miraidon_fast_setup_t1.gd": true,
	"test_arceus_fast_setup_t1.gd": true,
	"test_raging_bolt_strong_opening.gd": true,
	"test_charizard_strategy.gd": true,
	"test_charizard_ultra_ball_search_pick.gd": true,
	"test_dragapult_strategy.gd": true,
	"test_miraidon_strategy.gd": true,
	"test_water_lost_strategies.gd": true,
	"test_future_ancient_strategies.gd": true,
	"test_llm_interaction_bridge.gd": true,
	"test_llm_raging_bolt_duel_tool.gd": true,
	"test_blissey_tank_strategy.gd": true,
	"test_vstar_engine_strategies.gd": true,
	"test_game_state_cloner.gd": true,
	"test_headless_match_bridge.gd": true,
	"test_headless_heavy_baton_prompt.gd": true,
	"test_mcts_action_resolution.gd": true,
	"test_mcts_action_scorer_runtime.gd": true,
	"test_mcts_failure_diagnostics.gd": true,
	"test_mcts_planner.gd": true,
	"test_neural_net_inference.gd": true,
	"test_rollout_simulator.gd": true,
	"test_self_play_data_exporter.gd": true,
	"test_self_play_runner.gd": true,
	"test_state_encoder.gd": true,
	"test_training_anomaly_archive.gd": true,
	"test_training_pipeline_modes.gd": true,
	"test_training_run_registry.gd": true,
	"test_tuner_runner_args.gd": true,
}

const TOKEN_OVERRIDES := {
	"ai": "AI",
	"ui": "UI",
	"mcts": "MCTS",
	"zenmux": "ZenMux",
}


static func all_suites() -> Array[Dictionary]:
	var suites: Array[Dictionary] = []
	for file_name: String in _discover_test_files():
		suites.append(_build_suite_entry(file_name))
	return suites


static func get_suites(selected_groups: Dictionary = {}) -> Array[Dictionary]:
	if selected_groups.is_empty():
		return all_suites()

	var filtered: Array[Dictionary] = []
	for suite: Dictionary in all_suites():
		if TestSuiteFilterScript.should_run_any_group(selected_groups, suite.get("groups", [])):
			filtered.append(suite)
	return filtered


static func get_suites_for_group(group_name: String) -> Array[Dictionary]:
	var selected := {TestSuiteFilterScript.normalize_group_name(group_name): true}
	return get_suites(selected)


static func get_suite_names_for_group(group_name: String) -> Array[String]:
	var names: Array[String] = []
	for suite: Dictionary in get_suites_for_group(group_name):
		names.append(str(suite.get("name", "")))
	return names


static func has_suite_path(script_path: String) -> bool:
	for suite: Dictionary in all_suites():
		if str(suite.get("path", "")) == script_path:
			return true
	return false


static func _discover_test_files() -> Array[String]:
	var files: Array[String] = []
	_collect_test_files(TEST_DIR, "", files)
	files.sort()
	return files


static func _build_suite_entry(relative_path: String) -> Dictionary:
	return {
		"name": _suite_name_for_file(relative_path),
		"path": "%s/%s" % [TEST_DIR, relative_path],
		"groups": _groups_for_file(relative_path),
	}


static func _groups_for_file(relative_path: String) -> Array[String]:
	var file_name := relative_path.get_file()
	if bool(AI_TRAINING_FILES.get(file_name, false)):
		return [GROUP_AI_TRAINING]
	return [GROUP_FUNCTIONAL]


static func _suite_name_for_file(relative_path: String) -> String:
	var stem := relative_path.get_file().trim_prefix("test_").trim_suffix(".gd")
	var parts: Array[String] = []
	for token: String in stem.split("_", false):
		var lower := token.to_lower()
		if TOKEN_OVERRIDES.has(lower):
			parts.append(TOKEN_OVERRIDES[lower])
		elif token.is_valid_int():
			parts.append(token)
		elif token.length() > 0:
			parts.append(token.substr(0, 1).to_upper() + token.substr(1))
	return "".join(parts)


static func _collect_test_files(root_dir: String, relative_dir: String, files: Array[String]) -> void:
	var dir_path := root_dir if relative_dir == "" else "%s/%s" % [root_dir, relative_dir]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry in [".", ".."]:
			entry = dir.get_next()
			continue
		var child_relative := entry if relative_dir == "" else "%s/%s" % [relative_dir, entry]
		if dir.current_is_dir():
			_collect_test_files(root_dir, child_relative, files)
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			files.append(child_relative)
		entry = dir.get_next()
	dir.list_dir_end()
