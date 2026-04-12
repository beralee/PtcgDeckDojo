class_name TestTrainingPipelineModes
extends TestBase

const DeckBenchmarkCaseScript = preload("res://scripts/ai/DeckBenchmarkCase.gd")
const BenchmarkRunnerSceneScript = preload("res://scenes/tuner/BenchmarkRunner.gd")


func test_miraidon_focus_cases_only_cover_fixed_opponent_pool() -> String:
	var cases: Array = DeckBenchmarkCaseScript.make_miraidon_focus_cases()
	return run_checks([
		assert_eq(cases.size(), 3, "Miraidon focus should define exactly three pairings"),
		assert_eq(cases[0].get_pairing_name(), "miraidon_vs_gardevoir", "First Miraidon focus pairing should be Miraidon vs Gardevoir"),
		assert_eq(cases[1].get_pairing_name(), "miraidon_vs_charizard_ex", "Second Miraidon focus pairing should be Miraidon vs Charizard ex"),
		assert_eq(cases[2].get_pairing_name(), "miraidon_vs_arceus_giratina", "Third Miraidon focus pairing should be Miraidon vs Arceus Giratina"),
		assert_eq(cases[0].match_count, 8, "Miraidon focus Gardevoir pairing should still advertise eight matches"),
		assert_eq(cases[1].match_count, 8, "Miraidon focus Charizard ex pairing should still advertise eight matches"),
		assert_eq(cases[2].match_count, 8, "Miraidon focus Arceus Giratina pairing should still advertise eight matches"),
	])


func test_training_deck_pairings_switch_to_miraidon_focus_pool() -> String:
	var pairings: Array[Array] = DeckBenchmarkCaseScript.get_training_deck_pairings(
		DeckBenchmarkCaseScript.PIPELINE_MIRAIDON_FOCUS
	)
	return run_checks([
		assert_eq(pairings.size(), 3, "Miraidon focus training should schedule three pairings"),
		assert_eq(int((pairings[0] as Array)[0]), 575720, "First Miraidon focus training pairing should start with Miraidon"),
		assert_eq(int((pairings[0] as Array)[1]), 578647, "First Miraidon focus opponent should be Gardevoir"),
		assert_eq(int((pairings[1] as Array)[0]), 575720, "Second Miraidon focus training pairing should still start with Miraidon"),
		assert_eq(int((pairings[1] as Array)[1]), 575716, "Second Miraidon focus opponent should be Charizard ex"),
		assert_eq(int((pairings[2] as Array)[0]), 575720, "Third Miraidon focus training pairing should still start with Miraidon"),
		assert_eq(int((pairings[2] as Array)[1]), 569061, "Third Miraidon focus opponent should be Arceus Giratina"),
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
		assert_eq(cases.size(), 3, "Miraidon focus pipeline should benchmark three pairings"),
		assert_eq(cases[0].get_pairing_name(), "miraidon_vs_gardevoir", "Miraidon focus benchmark should include Miraidon vs Gardevoir"),
		assert_eq(cases[1].get_pairing_name(), "miraidon_vs_charizard_ex", "Miraidon focus benchmark should include Miraidon vs Charizard ex"),
		assert_eq(cases[2].get_pairing_name(), "miraidon_vs_arceus_giratina", "Miraidon focus benchmark should include Miraidon vs Arceus Giratina"),
		assert_eq(str(cases[0].comparison_mode), "version_regression", "Pipeline cases should remain version regression cases"),
		assert_eq(str(cases[1].comparison_mode), "version_regression", "Pipeline cases should remain version regression cases"),
		assert_eq(str(cases[2].comparison_mode), "version_regression", "Pipeline cases should remain version regression cases"),
	])


func test_gardevoir_mirror_cases_allow_mirror_regression_gate() -> String:
	var cases: Array = DeckBenchmarkCaseScript.make_phase2_cases_for_pipeline(
		DeckBenchmarkCaseScript.PIPELINE_GARDEVOIR_MIRROR
	)
	var validation_errors: PackedStringArray = cases[0].validate() if not cases.is_empty() else PackedStringArray()
	return run_checks([
		assert_eq(cases.size(), 1, "Gardevoir mirror pipeline should define exactly one pairing"),
		assert_eq(cases[0].get_pairing_name(), "gardevoir_vs_gardevoir", "Gardevoir mirror pairing should stay on the same deck"),
		assert_eq(int(cases[0].deck_a_id), 578647, "Mirror benchmark should pin deck A to Gardevoir"),
		assert_eq(int(cases[0].deck_b_id), 578647, "Mirror benchmark should pin deck B to Gardevoir"),
		assert_true(bool(cases[0].allow_mirror_pairing), "Mirror benchmark cases should explicitly allow identical deck ids"),
		assert_eq(validation_errors.size(), 0, "Mirror benchmark cases should validate cleanly"),
	])


func test_benchmark_runner_build_cases_switches_to_gardevoir_mirror_pipeline() -> String:
	var runner = BenchmarkRunnerSceneScript.new()
	var cases: Array = runner.build_pipeline_cases(DeckBenchmarkCaseScript.PIPELINE_GARDEVOIR_MIRROR, {
		"agent_id": "trained-ai",
		"version_tag": "candidate",
	}, {
		"agent_id": "trained-ai",
		"version_tag": "baseline",
	})
	return run_checks([
		assert_eq(cases.size(), 1, "Gardevoir mirror pipeline should only benchmark one pairing"),
		assert_eq(cases[0].get_pairing_name(), "gardevoir_vs_gardevoir", "Mirror benchmark should stay on Gardevoir"),
		assert_eq(str(cases[0].comparison_mode), "version_regression", "Mirror pipeline should remain version regression"),
		assert_true(bool(cases[0].allow_mirror_pairing), "Benchmark runner should preserve the mirror allowance flag"),
	])


func test_benchmark_runner_build_cases_accepts_seed_override() -> String:
	var runner = BenchmarkRunnerSceneScript.new()
	var override_seed_set: Array = [11, 29, 47, 83, 101, 149]
	var cases: Array = runner.build_pipeline_cases(
		DeckBenchmarkCaseScript.PIPELINE_MIRAIDON_FOCUS,
		{
			"agent_id": "trained-ai",
			"version_tag": "candidate",
		},
		{
			"agent_id": "trained-ai",
			"version_tag": "baseline",
		},
		override_seed_set
	)
	return run_checks([
		assert_eq(cases.size(), 3, "Seed override should not change the selected pipeline pairings"),
		assert_eq(cases[0].get_effective_seed_set(), override_seed_set, "First benchmark case should preserve the explicit seed override"),
		assert_eq(cases[1].get_effective_seed_set(), override_seed_set, "Second benchmark case should preserve the explicit seed override"),
		assert_eq(cases[2].get_effective_seed_set(), override_seed_set, "Third benchmark case should preserve the explicit seed override"),
		assert_eq(cases[0].match_count, 12, "Six seeds should expand to twelve regression matches"),
		assert_eq(cases[1].match_count, 12, "Six seeds should expand to twelve regression matches"),
		assert_eq(cases[2].match_count, 12, "Six seeds should expand to twelve regression matches"),
	])


func test_gardevoir_focus_cases_cover_three_cross_matchups() -> String:
	var cases: Array = DeckBenchmarkCaseScript.make_gardevoir_focus_cases()
	return run_checks([
		assert_eq(cases.size(), 3, "Gardevoir focus should define exactly three pairings"),
		assert_eq(cases[0].get_pairing_name(), "gardevoir_vs_miraidon", "First Gardevoir focus pairing should be Gardevoir vs Miraidon"),
		assert_eq(cases[1].get_pairing_name(), "gardevoir_vs_charizard_ex", "Second Gardevoir focus pairing should be Gardevoir vs Charizard ex"),
		assert_eq(cases[2].get_pairing_name(), "gardevoir_vs_arceus_giratina", "Third Gardevoir focus pairing should be Gardevoir vs Arceus Giratina"),
	])
