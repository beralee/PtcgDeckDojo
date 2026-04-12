extends Control

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const DeckBenchmarkCaseScript = preload("res://scripts/ai/DeckBenchmarkCase.gd")
const AgentVersionStoreScript = preload("res://scripts/ai/AgentVersionStore.gd")
const AIVersionRegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")
const TrainingRunRegistryScript = preload("res://scripts/ai/TrainingRunRegistry.gd")
const EvolutionEngineScript = preload("res://scripts/ai/EvolutionEngine.gd")
const TrainingAnomalyArchiveScript = preload("res://scripts/ai/TrainingAnomalyArchive.gd")

const DEFAULT_SUMMARY_OUTPUT := "user://benchmark_summary.json"
const DEFAULT_GATE_THRESHOLD := 0.55


func _ready() -> void:
	var args := parse_args(OS.get_cmdline_user_args())
	var summary := run_benchmark_from_args(args)
	_write_json(str(args.get("summary-output", DEFAULT_SUMMARY_OUTPUT)), _build_persisted_summary(summary))
	if DisplayServer.get_name() == "headless":
		call_deferred("_quit_with_summary", summary)


func parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for raw_arg: String in args:
		if not raw_arg.begins_with("--"):
			continue
		var arg := raw_arg.trim_prefix("--")
		var separator := arg.find("=")
		if separator == -1:
			parsed[arg] = true
			continue
		parsed[arg.substr(0, separator)] = arg.substr(separator + 1)
	return parsed


func run_benchmark_from_args(args: Dictionary) -> Dictionary:
	var candidate_agent_path := str(args.get("agent-a-config", ""))
	var baseline_agent_path := str(args.get("agent-b-config", ""))
	var candidate_config := _load_agent_config(candidate_agent_path)
	var baseline_config := _load_agent_config(baseline_agent_path)

	candidate_config["agent_id"] = str(args.get("agent-id", candidate_config.get("agent_id", "trained-ai")))
	baseline_config["agent_id"] = str(args.get("agent-id", baseline_config.get("agent_id", "trained-ai")))
	candidate_config["version_tag"] = str(args.get("version-a-tag", "candidate"))
	baseline_config["version_tag"] = str(args.get("version-b-tag", "current-best"))

	var candidate_value_net := str(args.get("value-net-a", candidate_config.get("value_net_path", "")))
	var baseline_value_net := str(args.get("value-net-b", baseline_config.get("value_net_path", "")))
	var candidate_action_scorer := str(args.get("action-scorer-a", candidate_config.get("action_scorer_path", "")))
	var baseline_action_scorer := str(args.get("action-scorer-b", baseline_config.get("action_scorer_path", "")))
	var candidate_interaction_scorer := str(args.get("interaction-scorer-a", candidate_config.get("interaction_scorer_path", "")))
	var baseline_interaction_scorer := str(args.get("interaction-scorer-b", baseline_config.get("interaction_scorer_path", "")))
	candidate_config["value_net_path"] = candidate_value_net
	baseline_config["value_net_path"] = baseline_value_net
	candidate_config["action_scorer_path"] = candidate_action_scorer
	baseline_config["action_scorer_path"] = baseline_action_scorer
	candidate_config["interaction_scorer_path"] = candidate_interaction_scorer
	baseline_config["interaction_scorer_path"] = baseline_interaction_scorer

	var runner := AIBenchmarkRunnerScript.new()
	var case_results: Array[Dictionary] = []
	var pipeline_name := str(args.get("pipeline-name", DeckBenchmarkCaseScript.PIPELINE_FIXED_THREE_DECK))
	var benchmark_seed_set := _parse_seed_set_arg(str(args.get("seed-set", "")))
	for benchmark_case: Variant in build_pipeline_cases(pipeline_name, candidate_config, baseline_config, benchmark_seed_set):
		if benchmark_case == null:
			continue
		var case_result: Dictionary = runner.run_and_summarize_case(benchmark_case)
		case_results.append({
			"pairing_name": benchmark_case.get_pairing_name(),
			"raw_result": case_result.get("raw_result", {}),
			"summary": case_result.get("summary", {}),
			"text_summary": str(case_result.get("text_summary", "")),
			"errors": case_result.get("errors", PackedStringArray()),
			"regression_gate_passed": bool(case_result.get("regression_gate_passed", false)),
		})

	var threshold := float(args.get("gate-threshold", DEFAULT_GATE_THRESHOLD))
	var summary := aggregate_case_results(case_results, threshold)
	summary["candidate_agent_config_path"] = candidate_agent_path
	summary["baseline_agent_config_path"] = baseline_agent_path
	summary["candidate_value_net_path"] = candidate_value_net
	summary["baseline_value_net_path"] = baseline_value_net
	summary["candidate_action_scorer_path"] = candidate_action_scorer
	summary["baseline_action_scorer_path"] = baseline_action_scorer
	summary["candidate_interaction_scorer_path"] = candidate_interaction_scorer
	summary["baseline_interaction_scorer_path"] = baseline_interaction_scorer
	summary["benchmark_seed_set"] = benchmark_seed_set if not benchmark_seed_set.is_empty() else DeckBenchmarkCaseScript.PHASE2_DEFAULT_SEED_SET.duplicate()
	summary["summary_output"] = str(args.get("summary-output", DEFAULT_SUMMARY_OUTPUT))
	var anomaly_summary := _build_anomaly_summary(case_results, args, summary)
	if not anomaly_summary.is_empty():
		summary["anomaly_summary"] = anomaly_summary
		summary["anomaly_summary_path"] = str(args.get("anomaly-output", ""))

	_publish_and_record(args, summary)
	return summary


func build_pipeline_cases(
	pipeline_name: String,
	candidate_config: Dictionary,
	baseline_config: Dictionary,
	benchmark_seed_set: Array = []
) -> Array:
	var cases: Array = DeckBenchmarkCaseScript.make_phase2_cases_for_pipeline(pipeline_name, benchmark_seed_set)
	for benchmark_case: Variant in cases:
		benchmark_case.comparison_mode = "version_regression"
		benchmark_case.agent_a_config = candidate_config.duplicate(true)
		benchmark_case.agent_b_config = baseline_config.duplicate(true)
	return cases


func _parse_seed_set_arg(raw_seed_set: String) -> Array:
	var parsed: Array = []
	for chunk: String in raw_seed_set.split(","):
		var token := chunk.strip_edges()
		if token == "":
			continue
		if token.is_valid_int():
			parsed.append(int(token))
	return parsed


func aggregate_case_results(case_results: Array, gate_threshold: float = DEFAULT_GATE_THRESHOLD) -> Dictionary:
	var total_matches := 0
	var version_a_wins := 0
	var version_b_wins := 0
	var timeouts := 0
	var failures := 0
	var all_cases_passed := true
	var pairing_results: Array[Dictionary] = []

	for case_variant: Variant in case_results:
		if not case_variant is Dictionary:
			continue
		var case_result: Dictionary = case_variant
		var summary: Dictionary = case_result.get("summary", {})
		var total_case_matches := int(summary.get("total_matches", 0))
		total_matches += total_case_matches
		version_a_wins += int(summary.get("version_a_wins", 0))
		version_b_wins += int(summary.get("version_b_wins", 0))
		timeouts += int(round(float(summary.get("cap_termination_rate", 0.0)) * float(total_case_matches)))
		failures += _count_case_failures(case_result)

		var errors_variant: Variant = case_result.get("errors", PackedStringArray())
		var errors: Array[String] = []
		if errors_variant is PackedStringArray:
			for entry: String in errors_variant:
				errors.append(entry)
		elif errors_variant is Array:
			for entry_variant: Variant in errors_variant:
				errors.append(str(entry_variant))
		var pairing_gate_passed: bool = bool(case_result.get("regression_gate_passed", false)) and errors.is_empty()
		if not pairing_gate_passed:
			all_cases_passed = false

		pairing_results.append({
			"pairing_name": str(case_result.get("pairing_name", "")),
			"summary": summary.duplicate(true),
			"text_summary": str(case_result.get("text_summary", "")),
			"errors": errors,
			"gate_passed": pairing_gate_passed,
		})

	var version_a_win_rate := 0.0 if total_matches <= 0 else float(version_a_wins) / float(total_matches)
	var version_b_win_rate := 0.0 if total_matches <= 0 else float(version_b_wins) / float(total_matches)
	var gate_passed := all_cases_passed and total_matches > 0 and version_a_win_rate >= gate_threshold
	return {
		"pairing_results": pairing_results,
		"total_matches": total_matches,
		"version_a_wins": version_a_wins,
		"version_b_wins": version_b_wins,
		"version_a_win_rate": version_a_win_rate,
		"version_b_win_rate": version_b_win_rate,
		"win_rate_vs_current_best": version_a_win_rate,
		"gate_threshold": gate_threshold,
		"all_cases_passed": all_cases_passed,
		"gate_passed": gate_passed,
		"timeouts": timeouts,
		"failures": failures,
	}


func _count_case_failures(case_result: Dictionary) -> int:
	var summary: Dictionary = case_result.get("summary", {})
	var failure_breakdown: Dictionary = summary.get("failure_breakdown", {})
	var failure_count := 0
	for value: Variant in failure_breakdown.values():
		failure_count += int(value)
	if failure_count > 0:
		return failure_count
	var errors_variant: Variant = case_result.get("errors", PackedStringArray())
	if errors_variant is PackedStringArray:
		return 1 if not (errors_variant as PackedStringArray).is_empty() else 0
	if errors_variant is Array:
		return 1 if not (errors_variant as Array).is_empty() else 0
	return 0


func _load_agent_config(path: String) -> Dictionary:
	if path == "":
		return EvolutionEngineScript.get_default_config().duplicate(true)
	var store := AgentVersionStoreScript.new()
	var loaded := store.load_version(path)
	if loaded.is_empty():
		return EvolutionEngineScript.get_default_config().duplicate(true)
	return loaded.duplicate(true)


func _publish_and_record(args: Dictionary, summary: Dictionary) -> void:
	var run_id := str(args.get("run-id", ""))
	if run_id == "":
		return

	var run_registry := TrainingRunRegistryScript.new()
	if args.has("run-registry-dir"):
		run_registry.base_dir = str(args.get("run-registry-dir", run_registry.base_dir))
	var run_record := run_registry.create_run(run_id, str(args.get("pipeline-name", "fixed_three_deck_training")), {
		"run_dir": str(args.get("run-dir", "")),
		"lane_recipe_id": str(args.get("lane-recipe-id", "")),
		"parent_approved_baseline_id": str(args.get("baseline-version-id", "")),
		"baseline_source": str(args.get("baseline-source", "")),
		"baseline_version_id": str(args.get("baseline-version-id", "")),
		"baseline_display_name": str(args.get("baseline-display-name", "")),
		"baseline_agent_config_path": str(summary.get("baseline_agent_config_path", str(args.get("baseline-agent-config", "")))),
		"baseline_value_net_path": str(summary.get("baseline_value_net_path", str(args.get("baseline-value-net", "")))),
		"baseline_action_scorer_path": str(summary.get("baseline_action_scorer_path", str(args.get("baseline-action-scorer", "")))),
		"baseline_interaction_scorer_path": str(summary.get("baseline_interaction_scorer_path", str(args.get("baseline-interaction-scorer", "")))),
		"candidate_agent_config_path": str(summary.get("candidate_agent_config_path", "")),
		"candidate_value_net_path": str(summary.get("candidate_value_net_path", "")),
		"candidate_action_scorer_path": str(summary.get("candidate_action_scorer_path", "")),
		"candidate_interaction_scorer_path": str(summary.get("candidate_interaction_scorer_path", "")),
		"benchmark_quality_summary": _build_version_benchmark_summary(summary),
	})
	if run_record.is_empty():
		return

	var patch := {
		"benchmark_summary_path": str(args.get("summary-output", DEFAULT_SUMMARY_OUTPUT)),
		"benchmark_summary": _build_version_benchmark_summary(summary),
		"benchmark_gate_passed": bool(summary.get("gate_passed", false)),
		"benchmark_decision": "benchmark_failed",
		"status": "benchmark_failed",
	}
	patch.merge(_build_anomaly_run_patch(summary), true)

	if bool(summary.get("gate_passed", false)):
		var version_registry := AIVersionRegistryScript.new()
		if args.has("version-registry-dir"):
			version_registry.base_dir = str(args.get("version-registry-dir", version_registry.base_dir))
		var version_id := str(args.get("publish-version-id", ""))
		if version_id == "":
			version_id = version_registry.generate_version_id(str(args.get("version-date", "")))
		var display_name := str(args.get("publish-display-name", ""))
		if display_name == "":
			display_name = version_id
		var version_record := {
			"version_id": version_id,
			"display_name": display_name,
			"agent_config_path": str(summary.get("candidate_agent_config_path", "")),
			"value_net_path": str(summary.get("candidate_value_net_path", "")),
			"action_scorer_path": str(summary.get("candidate_action_scorer_path", "")),
			"interaction_scorer_path": str(summary.get("candidate_interaction_scorer_path", "")),
			"source_run_id": run_id,
			"lane_recipe_id": str(args.get("lane-recipe-id", "")),
			"parent_approved_baseline_id": str(args.get("baseline-version-id", "")),
			"parent_baseline_version_id": str(args.get("baseline-version-id", "")),
			"parent_baseline_agent_config_path": str(summary.get("baseline_agent_config_path", "")),
			"parent_baseline_value_net_path": str(summary.get("baseline_value_net_path", "")),
			"parent_baseline_action_scorer_path": str(summary.get("baseline_action_scorer_path", "")),
			"parent_baseline_interaction_scorer_path": str(summary.get("baseline_interaction_scorer_path", "")),
			"benchmark_summary": _build_version_benchmark_summary(summary),
			"benchmark_quality_summary": _build_version_benchmark_summary(summary),
		}
		if version_registry.publish_playable_version(version_record):
			patch["status"] = "published"
			patch["benchmark_decision"] = "published"
			patch["published_version_id"] = version_id
			patch["published_version_record"] = version_record
		else:
			patch["status"] = "publish_failed"
			patch["benchmark_decision"] = "publish_failed"

	run_registry.complete_run(run_id, patch)


func _build_version_benchmark_summary(summary: Dictionary) -> Dictionary:
	return {
		"win_rate_vs_current_best": float(summary.get("win_rate_vs_current_best", 0.0)),
		"total_matches": int(summary.get("total_matches", 0)),
		"timeouts": int(summary.get("timeouts", 0)),
		"failures": int(summary.get("failures", 0)),
	}


func _build_anomaly_summary(case_results: Array, args: Dictionary, summary: Dictionary) -> Dictionary:
	var summaries: Array = []
	var phase1_input_path := str(args.get("phase1-anomaly-input", ""))
	var phase1_summary := TrainingAnomalyArchiveScript.read_summary(phase1_input_path)
	if not phase1_summary.is_empty():
		summaries.append(phase1_summary)

	var phase3_archive = TrainingAnomalyArchiveScript.new()
	for case_variant: Variant in case_results:
		if not case_variant is Dictionary:
			continue
		var case_result: Dictionary = case_variant
		var raw_result: Dictionary = case_result.get("raw_result", {})
		var matches_variant: Variant = raw_result.get("matches", [])
		var matches: Array = matches_variant if matches_variant is Array else []
		phase3_archive.record_matches("phase3_benchmark", matches, {
			"run_id": str(args.get("run-id", "")),
			"lane_id": str(args.get("lane-id", args.get("lane-recipe-id", ""))),
			"pairing": str(case_result.get("pairing_name", "")),
			"baseline_source": str(args.get("baseline-source", "")),
			"candidate_agent_config_path": str(summary.get("candidate_agent_config_path", "")),
			"candidate_value_net_path": str(summary.get("candidate_value_net_path", "")),
			"candidate_action_scorer_path": str(summary.get("candidate_action_scorer_path", "")),
			"candidate_interaction_scorer_path": str(summary.get("candidate_interaction_scorer_path", "")),
			"baseline_agent_config_path": str(summary.get("baseline_agent_config_path", "")),
			"baseline_value_net_path": str(summary.get("baseline_value_net_path", "")),
			"baseline_action_scorer_path": str(summary.get("baseline_action_scorer_path", "")),
			"baseline_interaction_scorer_path": str(summary.get("baseline_interaction_scorer_path", "")),
		})
	var phase3_summary := phase3_archive.build_summary()
	if int(phase3_summary.get("total_anomalies", 0)) > 0:
		summaries.append(phase3_summary)

	if summaries.is_empty():
		return {}
	var merged: Dictionary = TrainingAnomalyArchiveScript.merge_summaries(summaries)
	var anomaly_output_path := str(args.get("anomaly-output", ""))
	if anomaly_output_path != "":
		TrainingAnomalyArchiveScript.write_summary_to_path(anomaly_output_path, merged)
	return merged


func _build_anomaly_run_patch(summary: Dictionary) -> Dictionary:
	var anomaly_summary: Dictionary = summary.get("anomaly_summary", {})
	if anomaly_summary.is_empty():
		return {}
	var failure_counts: Dictionary = anomaly_summary.get("failure_reason_counts", {})
	return {
		"anomaly_summary_path": str(summary.get("anomaly_summary_path", "")),
		"anomaly_summary": anomaly_summary.duplicate(true),
		"anomaly_count": int(anomaly_summary.get("total_anomalies", 0)),
		"anomaly_failure_counts": failure_counts.duplicate(true),
		"has_stalled_anomalies": int(failure_counts.get("stalled_no_progress", 0)) > 0,
		"has_cap_anomalies": int(failure_counts.get("action_cap_reached", 0)) > 0,
	}


func _build_persisted_summary(summary: Dictionary) -> Dictionary:
	var persisted := summary.duplicate(true)
	var anomaly_summary: Dictionary = persisted.get("anomaly_summary", {})
	if not anomaly_summary.is_empty():
		persisted["anomaly_summary"] = _build_anomaly_summary_digest(anomaly_summary)
	return persisted


func _build_anomaly_summary_digest(anomaly_summary: Dictionary) -> Dictionary:
	return {
		"schema_version": int(anomaly_summary.get("schema_version", 0)),
		"total_anomalies": int(anomaly_summary.get("total_anomalies", 0)),
		"sample_limit_per_group": int(anomaly_summary.get("sample_limit_per_group", 0)),
		"updated_at": str(anomaly_summary.get("updated_at", "")),
		"phase_counts": (anomaly_summary.get("phase_counts", {}) as Dictionary).duplicate(true),
		"failure_reason_counts": (anomaly_summary.get("failure_reason_counts", {}) as Dictionary).duplicate(true),
		"mcts_failure_category_counts": (anomaly_summary.get("mcts_failure_category_counts", {}) as Dictionary).duplicate(true),
		"mcts_failure_kind_counts": (anomaly_summary.get("mcts_failure_kind_counts", {}) as Dictionary).duplicate(true),
		"pairing_counts": (anomaly_summary.get("pairing_counts", {}) as Dictionary).duplicate(true),
		"lane_counts": (anomaly_summary.get("lane_counts", {}) as Dictionary).duplicate(true),
		"generation_counts": (anomaly_summary.get("generation_counts", {}) as Dictionary).duplicate(true),
	}


func _write_json(path: String, payload: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir_path := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("BenchmarkRunner: failed to write summary to %s" % path)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()


func _quit_with_summary(summary: Dictionary) -> void:
	get_tree().quit(0 if bool(summary.get("gate_passed", false)) else 1)
