class_name TestAITrainingTestRunner
extends TestBase


const AITrainingTestRunnerScript = preload("res://tests/AITrainingTestRunner.gd")
const AITrainingRunnerSceneScript = preload("res://tests/AITrainingRunnerScene.gd")


func test_parse_args_defaults_to_suite_mode() -> String:
	var parsed: Dictionary = AITrainingTestRunnerScript.parse_runner_args(PackedStringArray([
		"--suite=MiraidonStrategy, VSTAREngineStrategies",
	]))
	var selected_suites: Dictionary = parsed.get("selected_suites", {})
	return run_checks([
		assert_eq(str(parsed.get("mode", "")), "suite", "Without matchup flags the runner should stay in suite mode"),
		assert_true(selected_suites.has("miraidonstrategy"), "Suite mode should preserve selected suite filters"),
		assert_true(selected_suites.has("vstarenginestrategies"), "Suite mode should keep multiple selected suites"),
	])


func test_parse_args_supports_matchup_sweep_mode() -> String:
	var parsed: Dictionary = AITrainingTestRunnerScript.parse_runner_args(PackedStringArray([
		"--matchup-anchor-deck=575720",
		"--anchor-strategy-override=miraidon_baseline",
		"--tracked-value-net=user://tracked_value.json",
		"--tracked-action-scorer=user://tracked_action.json",
		"--anchor-value-net=user://anchor_value.json",
		"--anchor-action-scorer=user://anchor_action.json",
		"--tracked-decision-mode=rules_only",
		"--anchor-decision-mode=rules_plus_learned",
		"--games-per-matchup=10",
		"--seed-bases=13600,13700,13800",
		"--exclude-decks=575720,578647",
		"--max-steps=240",
		"--json-output=user://tmp_matchup_sweep.json",
	]))
	var excluded: Array = parsed.get("exclude_deck_ids", [])
	var seed_bases: Array = parsed.get("seed_bases", [])
	return run_checks([
		assert_eq(str(parsed.get("mode", "")), "matchup_sweep", "Anchor deck args should switch the runner into matchup sweep mode"),
		assert_eq(int(parsed.get("anchor_deck_id", -1)), 575720, "Anchor deck id should be parsed from args"),
		assert_eq(str(parsed.get("anchor_strategy_override", "")), "miraidon_baseline", "Matchup sweep should preserve the anchor strategy override"),
		assert_eq(str(parsed.get("tracked_value_net_path", "")), "user://tracked_value.json", "Tracked value net path should be parsed from args"),
		assert_eq(str(parsed.get("tracked_action_scorer_path", "")), "user://tracked_action.json", "Tracked action scorer path should be parsed from args"),
		assert_eq(str(parsed.get("anchor_value_net_path", "")), "user://anchor_value.json", "Anchor value net path should be parsed from args"),
		assert_eq(str(parsed.get("anchor_action_scorer_path", "")), "user://anchor_action.json", "Anchor action scorer path should be parsed from args"),
		assert_eq(str(parsed.get("tracked_decision_mode", "")), "rules_only", "Tracked runtime mode should be parsed from args"),
		assert_eq(str(parsed.get("anchor_decision_mode", "")), "rules_plus_learned", "Anchor runtime mode should be parsed from args"),
		assert_eq(int(parsed.get("games_per_matchup", -1)), 10, "Games per matchup should be parsed from args"),
		assert_eq(int(parsed.get("max_steps", -1)), 240, "Max steps should be overridable"),
		assert_eq(str(parsed.get("json_output", "")), "user://tmp_matchup_sweep.json", "JSON output path should be preserved"),
		assert_eq(seed_bases, [13600, 13700, 13800], "Explicit seed bases should be parsed as an ordered integer list"),
		assert_eq(excluded, [575720, 578647], "Excluded deck ids should preserve order and numeric parsing"),
	])


func test_parse_args_supports_miraidon_baseline_regression_mode() -> String:
	var parsed: Dictionary = AITrainingTestRunnerScript.parse_runner_args(PackedStringArray([
		"--mode=miraidon_baseline_regression",
		"--games-per-matchup=12",
		"--max-steps=240",
		"--json-output=user://tmp_miraidon_baseline.json",
	]))
	return run_checks([
		assert_eq(str(parsed.get("mode", "")), "miraidon_baseline_regression", "Explicit baseline mode should be preserved"),
		assert_eq(int(parsed.get("games_per_matchup", -1)), 12, "Baseline mode should still parse game count"),
		assert_eq(int(parsed.get("max_steps", -1)), 240, "Baseline mode should still parse max steps"),
		assert_eq(str(parsed.get("json_output", "")), "user://tmp_miraidon_baseline.json", "Baseline mode should preserve json output path"),
	])


func test_resolve_matchup_sweep_deck_ids_filters_anchor_and_excludes() -> String:
	var deck_ids: Array[int] = AITrainingTestRunnerScript.resolve_matchup_sweep_deck_ids({
		"anchor_deck_id": 575720,
		"exclude_deck_ids": [575720, 578647],
		"explicit_deck_ids": [],
	})
	return run_checks([
		assert_eq(deck_ids.size(), 17, "Bundled deck sweep should keep the 17 non-anchor, non-gardevoir decks"),
		assert_false(deck_ids.has(575720), "Anchor deck should not appear in the sweep list"),
		assert_false(deck_ids.has(578647), "Excluded deck ids should be removed from the sweep list"),
		assert_true(deck_ids.has(575716), "Other bundled decks should remain in the sweep list"),
		assert_true(deck_ids.has(582754), "The last bundled deck should remain in the sweep list"),
	])


func test_resolve_seed_bases_prefers_explicit_list_over_seed_base() -> String:
	var explicit_seed_bases: Array[int] = AITrainingTestRunnerScript.resolve_seed_bases({
		"seed_base": 9000,
		"seed_bases": [13600, 13700, 13800],
	})
	var fallback_seed_bases: Array[int] = AITrainingTestRunnerScript.resolve_seed_bases({
		"seed_base": 9100,
	})
	return run_checks([
		assert_eq(explicit_seed_bases, [13600, 13700, 13800], "Explicit seed lists should override the legacy single seed base"),
		assert_eq(fallback_seed_bases, [9100], "Legacy single-seed mode should still normalize into a one-item seed list"),
	])


func test_runner_scene_matchup_ai_resolves_strategy_from_deck_data() -> String:
	var scene = AITrainingRunnerSceneScript.new()
	var ai = scene._make_matchup_ai(0, 575720)
	var strategy = ai._deck_strategy if ai != null else null
	return run_checks([
		assert_not_null(ai, "matchup runner should create an AI opponent"),
		assert_not_null(strategy, "matchup runner should inject a deck strategy for bundled decks"),
		assert_eq(str(strategy.call("get_strategy_id")), "miraidon", "matchup runner should resolve strategy from deck data for the selected deck"),
	])


func test_runner_scene_can_build_miraidon_baseline_ai_without_touching_registry_default() -> String:
	var scene = AITrainingRunnerSceneScript.new()
	var ai = scene._make_matchup_ai(1, 575720, "miraidon_baseline")
	var strategy = ai._deck_strategy if ai != null else null
	return run_checks([
		assert_not_null(ai, "baseline regression runner should create an AI opponent"),
		assert_not_null(strategy, "baseline regression runner should inject the baseline strategy"),
		assert_eq(str(strategy.call("get_strategy_id")), "miraidon_baseline", "baseline override should select the frozen Miraidon baseline strategy"),
	])


func test_runner_scene_can_build_charizard_baseline_ai_without_touching_registry_default() -> String:
	var scene = AITrainingRunnerSceneScript.new()
	var ai = scene._make_matchup_ai(0, 575716, "charizard_ex_baseline")
	var strategy = ai._deck_strategy if ai != null else null
	return run_checks([
		assert_not_null(ai, "baseline override should still create an AI opponent"),
		assert_not_null(strategy, "baseline override should inject the frozen Charizard strategy"),
		assert_eq(str(strategy.call("get_strategy_id")), "charizard_ex_baseline", "Charizard baseline override should select the frozen baseline strategy"),
	])


func test_runner_scene_can_apply_explicit_artifact_overrides() -> String:
	var scene = AITrainingRunnerSceneScript.new()
	var base_dir := "user://test_outputs/ai_training_runner"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var value_net_path := base_dir.path_join("tracked_value.json")
	var action_scorer_path := base_dir.path_join("tracked_action.json")
	var value_file := FileAccess.open(value_net_path, FileAccess.WRITE)
	if value_file != null:
		value_file.store_string(JSON.stringify({"layers": []}))
		value_file.close()
	var action_file := FileAccess.open(action_scorer_path, FileAccess.WRITE)
	if action_file != null:
		action_file.store_string(JSON.stringify({"layers": []}))
		action_file.close()
	var ai = scene._make_matchup_ai(0, 575720, "", {
		"value_net_path": value_net_path,
		"action_scorer_path": action_scorer_path,
		"decision_mode": "rules_only",
	})
	return run_checks([
		assert_not_null(ai, "artifact override path should still build an AI opponent"),
		assert_eq(str(ai.value_net_path), value_net_path, "artifact override should set explicit value net path"),
		assert_eq(str(ai.action_scorer_path), action_scorer_path, "artifact override should set explicit action scorer path"),
		assert_eq(str(ai.decision_runtime_mode), "rules_only", "artifact override should allow explicit runtime decision mode selection"),
		assert_true(bool(ai.use_mcts), "explicit value net should force MCTS mode so the trained model is actually used"),
	])


func test_action_cap_probe_uses_explicit_artifact_overrides_for_both_sides() -> String:
	var scene = AITrainingRunnerSceneScript.new()
	var base_dir := "user://test_outputs/ai_training_runner/probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var tracked_value_net_path := base_dir.path_join("tracked_value.json")
	var anchor_action_scorer_path := base_dir.path_join("anchor_action.json")
	var tracked_value_file := FileAccess.open(tracked_value_net_path, FileAccess.WRITE)
	if tracked_value_file != null:
		tracked_value_file.store_string(JSON.stringify({"layers": []}))
		tracked_value_file.close()
	var anchor_action_file := FileAccess.open(anchor_action_scorer_path, FileAccess.WRITE)
	if anchor_action_file != null:
		anchor_action_file.store_string(JSON.stringify({"layers": []}))
		anchor_action_file.close()
	var probe_pair := scene._build_probe_ai_pair(
		CardDatabase.get_deck(569061),
		CardDatabase.get_deck(575720),
		1,
		"",
		{
			"tracked_value_net_path": tracked_value_net_path,
			"tracked_decision_mode": "rules_only",
			"anchor_action_scorer_path": anchor_action_scorer_path,
			"anchor_decision_mode": "heuristic_only",
		}
	)
	var player_0_ai = probe_pair.get("player_0_ai", null)
	var player_1_ai = probe_pair.get("player_1_ai", null)
	return run_checks([
		assert_not_null(player_0_ai, "probe builder should create the anchor-side AI"),
		assert_not_null(player_1_ai, "probe builder should create the tracked-side AI"),
		assert_eq(str(player_0_ai.action_scorer_path), anchor_action_scorer_path, "probe builder should pass anchor artifacts to the anchor-side AI"),
		assert_eq(str(player_0_ai.decision_runtime_mode), "heuristic_only", "probe builder should preserve anchor runtime mode"),
		assert_eq(str(player_1_ai.value_net_path), tracked_value_net_path, "probe builder should pass tracked artifacts to the tracked-side AI"),
		assert_eq(str(player_1_ai.decision_runtime_mode), "rules_only", "probe builder should preserve tracked runtime mode"),
		assert_true(bool(player_1_ai.use_mcts), "tracked probe AI should enable MCTS when a value net override is supplied"),
	])


func test_run_matchup_for_deck_can_override_anchor_with_miraidon_baseline() -> String:
	var scene = AITrainingRunnerSceneScript.new()
	var benchmark_runner = preload("res://scripts/ai/AIBenchmarkRunner.gd").new()
	var arceus: DeckData = CardDatabase.get_deck(569061)
	var miraidon: DeckData = CardDatabase.get_deck(575720)
	var summary := scene._run_matchup_for_deck(
		benchmark_runner,
		arceus,
		miraidon,
		0,
		1,
		40,
		9000,
		"",
		"miraidon_baseline"
	)
	return run_checks([
		assert_eq(int(summary.get("games", 0)), 1, "Focused matchup summary should preserve requested game count"),
		assert_eq(str(summary.get("anchor_strategy_override", "")), "miraidon_baseline", "Matchup summary should record the anchor override used"),
	])


func test_runner_scene_aggregates_seed_summaries_with_mean_and_sigma() -> String:
	var scene = AITrainingRunnerSceneScript.new()
	var aggregate: Dictionary = scene._aggregate_seed_summaries([
		{"games": 100, "wins": 24, "losses": 76, "draws": 0, "win_rate": 0.24, "avg_turns": 18.0, "failure_reason_counts": {"deck_out": 1}, "games_detail": []},
		{"games": 100, "wins": 45, "losses": 55, "draws": 0, "win_rate": 0.45, "avg_turns": 19.0, "failure_reason_counts": {"deck_out": 2}, "games_detail": []},
		{"games": 100, "wins": 35, "losses": 65, "draws": 0, "win_rate": 0.35, "avg_turns": 20.0, "failure_reason_counts": {"normal_game_end": 3}, "games_detail": []},
	])
	return run_checks([
		assert_eq(int(aggregate.get("games", 0)), 300, "Aggregate summaries should sum total games across all seed buckets"),
		assert_eq(int(aggregate.get("wins", 0)), 104, "Aggregate summaries should sum wins across all seed buckets"),
		assert_true(absf(float(aggregate.get("win_rate_mean", 0.0)) - 0.3466667) < 0.0001, "Aggregate summaries should report the mean win rate across seed buckets"),
		assert_true(float(aggregate.get("win_rate_stdev", 0.0)) > 0.08, "Aggregate summaries should expose a non-trivial win-rate spread when seeds disagree strongly"),
		assert_eq(int((aggregate.get("failure_reason_counts", {}) as Dictionary).get("deck_out", 0)), 3, "Aggregate summaries should roll up failure counts across seed buckets"),
	])
