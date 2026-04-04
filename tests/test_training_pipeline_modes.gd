class_name TestTrainingPipelineModes
extends TestBase

const DeckBenchmarkCaseScript = preload("res://scripts/ai/DeckBenchmarkCase.gd")
const BenchmarkRunnerSceneScript = preload("res://scenes/tuner/BenchmarkRunner.gd")


func test_miraidon_focus_cases_only_cover_fixed_opponent_pool() -> String:
	var cases: Array = DeckBenchmarkCaseScript.make_miraidon_focus_cases()
	return run_checks([
		assert_eq(cases.size(), 2, "Miraidon focus should define exactly two pairings"),
		assert_eq(cases[0].get_pairing_name(), "miraidon_vs_gardevoir", "First Miraidon focus pairing should be Miraidon vs Gardevoir"),
		assert_eq(cases[1].get_pairing_name(), "miraidon_vs_charizard_ex", "Second Miraidon focus pairing should be Miraidon vs Charizard ex"),
		assert_eq(cases[0].match_count, 8, "Miraidon focus Gardevoir pairing should still advertise eight matches"),
		assert_eq(cases[1].match_count, 8, "Miraidon focus Charizard ex pairing should still advertise eight matches"),
	])


func test_training_deck_pairings_switch_to_miraidon_focus_pool() -> String:
	var pairings: Array[Array] = DeckBenchmarkCaseScript.get_training_deck_pairings(
		DeckBenchmarkCaseScript.PIPELINE_MIRAIDON_FOCUS
	)
	return run_checks([
		assert_eq(pairings.size(), 2, "Miraidon focus training should only schedule two pairings"),
		assert_eq(int((pairings[0] as Array)[0]), 575720, "First Miraidon focus training pairing should start with Miraidon"),
		assert_eq(int((pairings[0] as Array)[1]), 578647, "First Miraidon focus opponent should be Gardevoir"),
		assert_eq(int((pairings[1] as Array)[0]), 575720, "Second Miraidon focus training pairing should still start with Miraidon"),
		assert_eq(int((pairings[1] as Array)[1]), 575716, "Second Miraidon focus opponent should be Charizard ex"),
	])


func test_benchmark_runner_build_cases_switches_to_miraidon_focus_pipeline() -> String:
	var runner = BenchmarkRunnerSceneScript.new()
	var cases: Array = runner.build_pipeline_cases(DeckBenchmarkCaseScript.PIPELINE_MIRAIDON_FOCUS, {
		"agent_id": "trained-ai",
		"version_tag": "candidate",
	}, {
		"agent_id": "trained-ai",
		"version_tag": "baseline",
	})
	return run_checks([
		assert_eq(cases.size(), 2, "Miraidon focus pipeline should only benchmark two pairings"),
		assert_eq(cases[0].get_pairing_name(), "miraidon_vs_gardevoir", "Miraidon focus benchmark should include Miraidon vs Gardevoir"),
		assert_eq(cases[1].get_pairing_name(), "miraidon_vs_charizard_ex", "Miraidon focus benchmark should include Miraidon vs Charizard ex"),
		assert_eq(str(cases[0].comparison_mode), "version_regression", "Pipeline cases should remain version regression cases"),
		assert_eq(str(cases[1].comparison_mode), "version_regression", "Pipeline cases should remain version regression cases"),
	])
