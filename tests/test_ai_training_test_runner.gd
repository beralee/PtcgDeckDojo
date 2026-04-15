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
		"--games-per-matchup=10",
		"--exclude-decks=575720,578647",
		"--max-steps=240",
		"--json-output=user://tmp_matchup_sweep.json",
	]))
	var excluded: Array = parsed.get("exclude_deck_ids", [])
	return run_checks([
		assert_eq(str(parsed.get("mode", "")), "matchup_sweep", "Anchor deck args should switch the runner into matchup sweep mode"),
		assert_eq(int(parsed.get("anchor_deck_id", -1)), 575720, "Anchor deck id should be parsed from args"),
		assert_eq(str(parsed.get("anchor_strategy_override", "")), "miraidon_baseline", "Matchup sweep should preserve the anchor strategy override"),
		assert_eq(str(parsed.get("tracked_value_net_path", "")), "user://tracked_value.json", "Tracked value net path should be parsed from args"),
		assert_eq(str(parsed.get("tracked_action_scorer_path", "")), "user://tracked_action.json", "Tracked action scorer path should be parsed from args"),
		assert_eq(str(parsed.get("anchor_value_net_path", "")), "user://anchor_value.json", "Anchor value net path should be parsed from args"),
		assert_eq(str(parsed.get("anchor_action_scorer_path", "")), "user://anchor_action.json", "Anchor action scorer path should be parsed from args"),
		assert_eq(int(parsed.get("games_per_matchup", -1)), 10, "Games per matchup should be parsed from args"),
		assert_eq(int(parsed.get("max_steps", -1)), 240, "Max steps should be overridable"),
		assert_eq(str(parsed.get("json_output", "")), "user://tmp_matchup_sweep.json", "JSON output path should be preserved"),
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
	})
	return run_checks([
		assert_not_null(ai, "artifact override path should still build an AI opponent"),
		assert_eq(str(ai.value_net_path), value_net_path, "artifact override should set explicit value net path"),
		assert_eq(str(ai.action_scorer_path), action_scorer_path, "artifact override should set explicit action scorer path"),
		assert_true(bool(ai.use_mcts), "explicit value net should force MCTS mode so the trained model is actually used"),
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
