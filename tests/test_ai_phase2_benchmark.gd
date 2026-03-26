class_name TestAIPhase2Benchmark
extends TestBase

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const DeckBenchmarkCaseScript = preload("res://scripts/ai/DeckBenchmarkCase.gd")
const BenchmarkEvaluatorScript = preload("res://scripts/ai/BenchmarkEvaluator.gd")


func _card_identity_signature(cards: Array) -> Array[String]:
	var signature: Array[String] = []
	for card_variant: Variant in cards:
		var card: CardInstance = card_variant if card_variant is CardInstance else null
		if card != null and card.card_data != null:
			signature.append("%s#%d" % [card.card_data.get_uid(), card.instance_id])
		else:
			signature.append("")
	return signature


func _setup_signature(gsm: GameStateMachine) -> Array[String]:
	return [
		"p0_hand=%s|p0_prizes=%s|p0_deck=%s" % [
			",".join(_card_identity_signature(gsm.game_state.players[0].hand)),
			",".join(_card_identity_signature(gsm.game_state.players[0].prizes)),
			",".join(_card_identity_signature(gsm.game_state.players[0].deck)),
		],
		"p1_hand=%s|p1_prizes=%s|p1_deck=%s" % [
			",".join(_card_identity_signature(gsm.game_state.players[1].hand)),
			",".join(_card_identity_signature(gsm.game_state.players[1].prizes)),
			",".join(_card_identity_signature(gsm.game_state.players[1].deck)),
		],
	]


func _clear_forced_shuffle_seed() -> void:
	var player_state := PlayerState.new()
	if player_state.has_method("clear_forced_shuffle_seed"):
		player_state.call("clear_forced_shuffle_seed")


func _make_gate_summary(identity_hit_rate: float, stalled: bool = false, cap_rate: float = 0.0) -> Dictionary:
	var evaluator := BenchmarkEvaluatorScript.new()
	var summary: Dictionary = evaluator.summarize_pairing([], "miraidon_vs_gardevoir")
	var identity_breakdown: Dictionary = summary.get("identity_event_breakdown", {})
	summary["total_matches"] = 8
	summary["wins_a"] = 4
	summary["wins_b"] = 4
	summary["win_rate_a"] = 0.5
	summary["win_rate_b"] = 0.5
	summary["average_turn_count"] = 22.0
	summary["avg_turn_count"] = 22.0
	summary["stall_rate"] = 0.0
	for event_key: Variant in identity_breakdown.keys():
		var event_summary: Dictionary = identity_breakdown.get(event_key, {})
		event_summary["applicable_matches"] = 8
		event_summary["hit_matches"] = int(round(identity_hit_rate * 8.0))
		event_summary["hit_rate"] = identity_hit_rate
		identity_breakdown[event_key] = event_summary
	summary["identity_event_breakdown"] = identity_breakdown
	summary["failure_breakdown"] = {}
	if stalled:
		summary["failure_breakdown"]["stalled_no_progress"] = 1
	summary["cap_termination_rate"] = cap_rate
	return summary


func test_deck_benchmark_case_pins_phase2_default_decks() -> String:
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	var resolved: Dictionary = benchmark_case.resolve_decks()
	return run_checks([
		assert_true(benchmark_case.has_method("resolve_decks"), "Benchmark case should resolve pinned decks"),
		assert_eq(resolved.get("deck_a_key", ""), "miraidon", "575720 should map to miraidon"),
		assert_eq(resolved.get("deck_b_key", ""), "gardevoir", "578647 should map to gardevoir"),
		assert_eq(benchmark_case.get_pairing_name(), "miraidon_vs_gardevoir", "Pinned decks should produce a stable pairing name"),
	])


func test_deck_benchmark_case_supports_version_regression_contract() -> String:
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.comparison_mode = "version_regression"
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "candidate-v2"}
	return run_checks([
		assert_true(benchmark_case.validate().is_empty(), "Version regression cases should validate with per-side agent configs"),
	])


func test_deck_benchmark_case_rejects_odd_seed_count_for_version_regression() -> String:
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.comparison_mode = "version_regression"
	benchmark_case.seed_set = [11, 29, 47]
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "candidate-v2"}
	return run_checks([
		assert_false(benchmark_case.validate().is_empty(), "Version regression should reject odd effective seed counts"),
	])


func test_deck_benchmark_case_validates_fresh_pinned_case_without_prior_resolve() -> String:
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	return run_checks([
		assert_true(benchmark_case.validate().is_empty(), "Fresh pinned cases should validate without calling resolve_decks first"),
		assert_eq(benchmark_case.match_count, 8, "Fresh valid cases should sync match_count from the default seed set"),
	])


func test_deck_benchmark_case_rejects_mismatched_shared_agent_configs() -> String:
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "candidate-v2"}
	return run_checks([
		assert_false(benchmark_case.validate().is_empty(), "shared_agent_mirror should reject mismatched configs"),
	])


func test_phase2_default_cases_are_exact_three_pinned_pairings() -> String:
	var cases: Array = DeckBenchmarkCaseScript.make_phase2_default_cases()
	return run_checks([
		assert_eq(cases.size(), 3, "Phase 2 should define exactly three default pairings"),
		assert_eq(cases[0].deck_a_id, 575720, "First default pairing should start with Miraidon"),
		assert_eq(cases[0].deck_a_key, "miraidon", "First default pairing should expose the Miraidon key"),
		assert_eq(cases[0].deck_b_id, 578647, "First default pairing should include Gardevoir"),
		assert_eq(cases[0].deck_b_key, "gardevoir", "First default pairing should expose the Gardevoir key"),
		assert_eq(cases[1].deck_a_id, 575720, "Second default pairing should keep Miraidon as deck A"),
		assert_eq(cases[1].deck_a_key, "miraidon", "Second default pairing should expose the Miraidon key"),
		assert_eq(cases[1].deck_b_id, 575716, "Second default pairing should include Charizard ex"),
		assert_eq(cases[1].deck_b_key, "charizard_ex", "Second default pairing should expose the Charizard ex key"),
		assert_eq(cases[2].deck_a_id, 578647, "Third default pairing should start with Gardevoir"),
		assert_eq(cases[2].deck_a_key, "gardevoir", "Third default pairing should expose the Gardevoir key"),
		assert_eq(cases[2].deck_b_id, 575716, "Third default pairing should include Charizard ex"),
		assert_eq(cases[2].deck_b_key, "charizard_ex", "Third default pairing should expose the Charizard ex key"),
		assert_eq(cases[0].match_count, 8, "First default pairing should advertise the full eight-match schedule"),
		assert_eq(cases[1].match_count, 8, "Second default pairing should advertise the full eight-match schedule"),
		assert_eq(cases[2].match_count, 8, "Third default pairing should advertise the full eight-match schedule"),
	])


func test_phase2_default_schedule_expands_to_eight_matches() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.seed_set = [11, 29, 47, 83]
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.resolve_decks()
	var schedule: Array[Dictionary] = runner.build_match_schedule(benchmark_case)
	var seed_counts := {
		11: 0,
		29: 0,
		47: 0,
		83: 0,
	}
	var seat_counts := {
		"deck_a_first": 0,
		"deck_b_first": 0,
	}
	for matchup: Dictionary in schedule:
		var seed: int = int(matchup.get("seed", -1))
		seed_counts[seed] = int(seed_counts.get(seed, 0)) + 1
		var seat_order: String = str(matchup.get("seat_order", ""))
		seat_counts[seat_order] = int(seat_counts.get(seat_order, 0)) + 1
	return run_checks([
		assert_eq(schedule.size(), 8, "Four seeds with two seat orders each should produce eight matches"),
		assert_eq(seed_counts[11], 2, "Seed 11 should appear twice"),
		assert_eq(seed_counts[29], 2, "Seed 29 should appear twice"),
		assert_eq(seed_counts[47], 2, "Seed 47 should appear twice"),
		assert_eq(seed_counts[83], 2, "Seed 83 should appear twice"),
		assert_eq(seat_counts["deck_a_first"], 4, "deck_a_first should cover half the schedule"),
		assert_eq(seat_counts["deck_b_first"], 4, "deck_b_first should cover half the schedule"),
	])


func test_benchmark_runner_version_regression_flips_agent_versions_by_seat_order() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.comparison_mode = "version_regression"
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "candidate-v2"}
	benchmark_case.resolve_decks()
	var result: Dictionary = runner.run_benchmark_case(benchmark_case)
	var matches: Array = result.get("matches", [])
	var version_a_deck_counts := {
		575720: 0,
		578647: 0,
	}
	var version_b_deck_counts := {
		575720: 0,
		578647: 0,
	}
	var version_a_seat_counts := {
		0: 0,
		1: 0,
	}
	var version_b_seat_counts := {
		0: 0,
		1: 0,
	}
	for match_result: Dictionary in matches:
		var version_a_deck_id: int = int(match_result.get("version_a_deck_id", -1))
		var version_b_deck_id: int = int(match_result.get("version_b_deck_id", -1))
		var version_a_player_index: int = int(match_result.get("version_a_player_index", -1))
		var version_b_player_index: int = int(match_result.get("version_b_player_index", -1))
		version_a_deck_counts[version_a_deck_id] = int(version_a_deck_counts.get(version_a_deck_id, 0)) + 1
		version_b_deck_counts[version_b_deck_id] = int(version_b_deck_counts.get(version_b_deck_id, 0)) + 1
		version_a_seat_counts[version_a_player_index] = int(version_a_seat_counts.get(version_a_player_index, 0)) + 1
		version_b_seat_counts[version_b_player_index] = int(version_b_seat_counts.get(version_b_player_index, 0)) + 1
	var version_a_deck_seat_counts := {
		"575720@0": 0,
		"575720@1": 0,
		"578647@0": 0,
		"578647@1": 0,
	}
	var version_b_deck_seat_counts := {
		"575720@0": 0,
		"575720@1": 0,
		"578647@0": 0,
		"578647@1": 0,
	}
	for match_result: Dictionary in matches:
		var version_a_key := "%d@%d" % [
			int(match_result.get("version_a_deck_id", -1)),
			int(match_result.get("version_a_player_index", -1)),
		]
		var version_b_key := "%d@%d" % [
			int(match_result.get("version_b_deck_id", -1)),
			int(match_result.get("version_b_player_index", -1)),
		]
		version_a_deck_seat_counts[version_a_key] = int(version_a_deck_seat_counts.get(version_a_key, 0)) + 1
		version_b_deck_seat_counts[version_b_key] = int(version_b_deck_seat_counts.get(version_b_key, 0)) + 1
	return run_checks([
		assert_eq(matches.size(), 8, "Version regression cases should still use the eight-match Phase 2 schedule"),
		assert_eq(version_a_deck_counts[575720], 4, "Baseline version should pilot deck A in half the schedule"),
		assert_eq(version_a_deck_counts[578647], 4, "Baseline version should pilot deck B in half the schedule"),
		assert_eq(version_b_deck_counts[575720], 4, "Candidate version should pilot deck A in half the schedule"),
		assert_eq(version_b_deck_counts[578647], 4, "Candidate version should pilot deck B in half the schedule"),
		assert_eq(version_a_seat_counts[0], 4, "Baseline version should occupy player 0 in half the schedule"),
		assert_eq(version_a_seat_counts[1], 4, "Baseline version should occupy player 1 in half the schedule"),
		assert_eq(version_b_seat_counts[0], 4, "Candidate version should occupy player 0 in half the schedule"),
		assert_eq(version_b_seat_counts[1], 4, "Candidate version should occupy player 1 in half the schedule"),
		assert_eq(version_a_deck_seat_counts["575720@0"], 2, "Baseline version should see deck A in seat 0 twice"),
		assert_eq(version_a_deck_seat_counts["575720@1"], 2, "Baseline version should see deck A in seat 1 twice"),
		assert_eq(version_a_deck_seat_counts["578647@0"], 2, "Baseline version should see deck B in seat 0 twice"),
		assert_eq(version_a_deck_seat_counts["578647@1"], 2, "Baseline version should see deck B in seat 1 twice"),
		assert_eq(version_b_deck_seat_counts["575720@0"], 2, "Candidate version should see deck A in seat 0 twice"),
		assert_eq(version_b_deck_seat_counts["575720@1"], 2, "Candidate version should see deck A in seat 1 twice"),
		assert_eq(version_b_deck_seat_counts["578647@0"], 2, "Candidate version should see deck B in seat 0 twice"),
		assert_eq(version_b_deck_seat_counts["578647@1"], 2, "Candidate version should see deck B in seat 1 twice"),
	])


func test_player_state_forced_shuffle_seed_stabilizes_opening_hand_order() -> String:
	var deck_a := CardDatabase.get_deck(575720)
	var deck_b := CardDatabase.get_deck(578647)
	if deck_a == null or deck_b == null:
		return "Pinned benchmark decks must exist for deterministic shuffle coverage"

	var player_state := PlayerState.new()
	if not player_state.has_method("set_forced_shuffle_seed") or not player_state.has_method("clear_forced_shuffle_seed"):
		return run_checks([
			assert_true(false, "PlayerState should expose forced shuffle seed hooks"),
		])

	player_state.call("set_forced_shuffle_seed", 424242)
	var gsm_one := GameStateMachine.new()
	gsm_one.start_game(deck_a, deck_b, 0)
	var setup_signature_one := _setup_signature(gsm_one)
	_clear_forced_shuffle_seed()

	player_state.call("set_forced_shuffle_seed", 424242)
	var gsm_two := GameStateMachine.new()
	gsm_two.start_game(deck_a, deck_b, 0)
	var setup_signature_two := _setup_signature(gsm_two)
	_clear_forced_shuffle_seed()

	player_state.call("set_forced_shuffle_seed", 424243)
	var gsm_three := GameStateMachine.new()
	gsm_three.start_game(deck_a, deck_b, 0)
	var setup_signature_three := _setup_signature(gsm_three)
	_clear_forced_shuffle_seed()

	return run_checks([
		assert_eq(setup_signature_one, setup_signature_two, "The same benchmark seed should produce the same setup signature for both players"),
		assert_false(setup_signature_one == setup_signature_three, "A different benchmark seed should produce a different setup signature"),
	])


func test_benchmark_runner_returns_coherent_schedule_and_seed_metadata() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.resolve_decks()
	var result: Dictionary = runner.run_benchmark_case(benchmark_case)
	var matches: Array = result.get("matches", [])
	var seat_counts := {
		"deck_a_first": 0,
		"deck_b_first": 0,
	}
	var seed_counts := {
		11: 0,
		29: 0,
		47: 0,
		83: 0,
	}
	var identity_hits: Dictionary = {}
	for match_result: Dictionary in matches:
		var seed: int = int(match_result.get("seed", -1))
		seed_counts[seed] = int(seed_counts.get(seed, 0)) + 1
		var seat_order: String = str(match_result.get("seat_order", ""))
		seat_counts[seat_order] = int(seat_counts.get(seat_order, 0)) + 1
		if identity_hits.is_empty():
			identity_hits = match_result.get("identity_hits", {})
	return run_checks([
		assert_eq(result.get("seed_set", []), [11, 29, 47, 83], "Benchmark results should surface the fixed Phase 2 seed set"),
		assert_eq(result.get("match_count", -1), 8, "Benchmark results should report the actual eight-match schedule size"),
		assert_eq(benchmark_case.match_count, 8, "Benchmark case metadata should stay synchronized with the effective schedule size"),
		assert_eq(matches.size(), 8, "Benchmark results should carry all scheduled matches"),
		assert_eq(seed_counts[11], 2, "Seed 11 should appear twice in the raw match list"),
		assert_eq(seed_counts[29], 2, "Seed 29 should appear twice in the raw match list"),
		assert_eq(seed_counts[47], 2, "Seed 47 should appear twice in the raw match list"),
		assert_eq(seed_counts[83], 2, "Seed 83 should appear twice in the raw match list"),
		assert_eq(seat_counts["deck_a_first"], 4, "Half the matches should run with deck A first"),
		assert_eq(seat_counts["deck_b_first"], 4, "Half the matches should run with deck B first"),
		assert_true(identity_hits is Dictionary, "Raw match results should carry a flat identity_hits map"),
		assert_eq(identity_hits.size(), 9, "Identity hits should be flattened into the exact nine spec events"),
		assert_false(identity_hits.has("deck_a"), "Identity hits should not be nested under deck_a"),
		assert_false(identity_hits.has("deck_b"), "Identity hits should not be nested under deck_b"),
		assert_true(identity_hits.has("miraidon_bench_developed"), "Flat identity hits should expose the Miraidon event"),
		assert_true(identity_hits.has("electric_generator_resolved"), "Flat identity hits should expose the Electric Generator event"),
		assert_true(identity_hits.has("miraidon_attack_ready"), "Flat identity hits should expose the Miraidon attack event"),
		assert_true(identity_hits.has("gardevoir_stage2_online"), "Flat identity hits should expose the Gardevoir stage 2 event"),
		assert_true(identity_hits.has("psychic_embrace_resolved"), "Flat identity hits should expose the Psychic Embrace event"),
		assert_true(identity_hits.has("gardevoir_energy_loop_online"), "Flat identity hits should expose the Gardevoir energy loop event"),
		assert_true(identity_hits.has("charizard_stage2_online"), "Flat identity hits should expose the Charizard stage 2 event"),
		assert_true(identity_hits.has("charizard_evolution_support_used"), "Flat identity hits should expose the Charizard evolution support event"),
		assert_true(identity_hits.has("charizard_attack_ready"), "Flat identity hits should expose the Charizard attack event"),
	])


func test_phase2_default_suite_still_has_exactly_three_pinned_pairings() -> String:
	var cases: Array = DeckBenchmarkCaseScript.make_phase2_default_cases()
	return run_checks([
		assert_eq(cases.size(), 3, "Phase 2 should keep exactly three pinned pairings"),
		assert_eq(cases[0].get_pairing_name(), "miraidon_vs_gardevoir", "First pinned pairing should remain Miraidon vs Gardevoir"),
		assert_eq(cases[1].get_pairing_name(), "miraidon_vs_charizard_ex", "Second pinned pairing should remain Miraidon vs Charizard ex"),
		assert_eq(cases[2].get_pairing_name(), "gardevoir_vs_charizard_ex", "Third pinned pairing should remain Gardevoir vs Charizard ex"),
	])


func test_phase2_default_schedule_size_remains_eight_per_pairing() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var cases: Array = DeckBenchmarkCaseScript.make_phase2_default_cases()
	var schedule_sizes: Array[int] = []
	for benchmark_case_variant: Variant in cases:
		var benchmark_case = benchmark_case_variant
		var schedule: Array[Dictionary] = runner.build_match_schedule(benchmark_case)
		schedule_sizes.append(schedule.size())
	return run_checks([
		assert_eq(schedule_sizes.size(), 3, "There should still be three default pairings"),
		assert_eq(schedule_sizes[0], 8, "Miraidon vs Gardevoir should still expand to eight matches"),
		assert_eq(schedule_sizes[1], 8, "Miraidon vs Charizard ex should still expand to eight matches"),
		assert_eq(schedule_sizes[2], 8, "Gardevoir vs Charizard ex should still expand to eight matches"),
	])


func test_phase2_regression_gate_fails_on_zero_identity_hit_rate() -> String:
	var summary := _make_gate_summary(1.0)
	var identity_breakdown: Dictionary = summary.get("identity_event_breakdown", {})
	var electric_generator: Dictionary = identity_breakdown.get("electric_generator_resolved", {})
	electric_generator["hit_rate"] = 0.0
	electric_generator["hit_matches"] = 0
	identity_breakdown["electric_generator_resolved"] = electric_generator
	summary["identity_event_breakdown"] = identity_breakdown
	return run_checks([
		assert_false(AIBenchmarkRunnerScript.passes_phase2_regression_gate(summary), "Zero identity hit rate should fail the Phase 2 regression gate"),
	])


func test_phase2_regression_gate_fails_on_stalled_no_progress_and_caps() -> String:
	var summary := _make_gate_summary(1.0, true, 0.25)
	return run_checks([
		assert_false(AIBenchmarkRunnerScript.passes_phase2_regression_gate(summary), "Stalled matches or capped matches should fail the Phase 2 regression gate"),
	])


func test_phase2_regression_gate_passes_on_healthy_summary() -> String:
	var summary := _make_gate_summary(0.75, false, 0.0)
	var identity_breakdown: Dictionary = summary.get("identity_event_breakdown", {})
	var charizard_attack: Dictionary = identity_breakdown.get("charizard_attack_ready", {})
	charizard_attack["applicable_matches"] = 0
	charizard_attack["hit_matches"] = 0
	charizard_attack["hit_rate"] = 0.0
	identity_breakdown["charizard_attack_ready"] = charizard_attack
	summary["identity_event_breakdown"] = identity_breakdown
	return run_checks([
		assert_true(AIBenchmarkRunnerScript.passes_phase2_regression_gate(summary), "Healthy summaries should pass the Phase 2 regression gate"),
	])


func test_phase2_regression_gate_fails_when_pairing_event_is_marked_non_applicable() -> String:
	var summary := _make_gate_summary(0.75, false, 0.0)
	var identity_breakdown: Dictionary = summary.get("identity_event_breakdown", {})
	var miraidon_event: Dictionary = identity_breakdown.get("electric_generator_resolved", {})
	miraidon_event["applicable_matches"] = 0
	miraidon_event["hit_matches"] = 0
	miraidon_event["hit_rate"] = 0.0
	identity_breakdown["electric_generator_resolved"] = miraidon_event
	summary["identity_event_breakdown"] = identity_breakdown
	return run_checks([
		assert_false(AIBenchmarkRunnerScript.passes_phase2_regression_gate(summary), "Pairing events cannot be marked non-applicable without failing the regression gate"),
	])


func test_raw_match_result_starts_with_flat_identity_hits_schema() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var raw_result: Dictionary = runner.call("_make_raw_match_result", null, 0)
	var identity_hits: Dictionary = raw_result.get("identity_hits", {})
	return run_checks([
		assert_true(identity_hits is Dictionary, "Raw match results should initialize identity_hits as a dictionary"),
		assert_eq(identity_hits.size(), 9, "Raw match results should start with the exact nine-key identity schema"),
		assert_true(identity_hits.has("miraidon_bench_developed"), "Raw identity schema should include the Miraidon bench event"),
		assert_true(identity_hits.has("electric_generator_resolved"), "Raw identity schema should include the Electric Generator event"),
		assert_true(identity_hits.has("miraidon_attack_ready"), "Raw identity schema should include the Miraidon attack event"),
		assert_true(identity_hits.has("gardevoir_stage2_online"), "Raw identity schema should include the Gardevoir stage 2 event"),
		assert_true(identity_hits.has("psychic_embrace_resolved"), "Raw identity schema should include the Psychic Embrace event"),
		assert_true(identity_hits.has("gardevoir_energy_loop_online"), "Raw identity schema should include the Gardevoir energy loop event"),
		assert_true(identity_hits.has("charizard_stage2_online"), "Raw identity schema should include the Charizard stage 2 event"),
		assert_true(identity_hits.has("charizard_evolution_support_used"), "Raw identity schema should include the Charizard evolution support event"),
		assert_true(identity_hits.has("charizard_attack_ready"), "Raw identity schema should include the Charizard attack event"),
	])


func test_run_smoke_match_normalizes_identity_hits_schema() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var agent := AIOpponent.new()
	agent.configure(0, 1)
	var step_runner := func(_next_agent, _state):
		return {
			"winner_index": 0,
			"failure_reason": "normal_game_end",
			"identity_hits": {
				"deck_a": {"electric_generator_resolved": true},
				"miraidon_attack_ready": true,
			},
		}
	var result: Dictionary = runner.run_smoke_match(agent, step_runner, 4, {})
	var identity_hits: Dictionary = result.get("identity_hits", {})
	return run_checks([
		assert_eq(identity_hits.size(), 9, "Smoke results should preserve the flat nine-key identity schema"),
		assert_false(identity_hits.has("deck_a"), "Smoke results should drop nested identity shapes"),
		assert_true(bool(identity_hits.get("miraidon_attack_ready", false)), "Smoke results should retain valid flat identity keys"),
		assert_false(bool(identity_hits.get("electric_generator_resolved", false)), "Smoke results should ignore malformed nested identity keys instead of nesting them"),
	])


## 版本回归原始结果应保留版本元数据和 comparison_mode
func test_version_regression_raw_results_preserve_version_metadata() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.comparison_mode = "version_regression"
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "candidate-v2"}
	benchmark_case.seed_set = [11, 29]
	benchmark_case.resolve_decks()
	var result: Dictionary = runner.run_benchmark_case(benchmark_case)
	var matches: Array = result.get("matches", [])
	var all_have_comparison_mode := true
	var all_have_version_a_config := true
	var all_have_version_b_config := true
	var all_have_version_a_player_index := true
	var version_a_tags: Array[String] = []
	var version_b_tags: Array[String] = []
	for match_result: Variant in matches:
		if not match_result is Dictionary:
			continue
		var m: Dictionary = match_result
		if str(m.get("comparison_mode", "")) != "version_regression":
			all_have_comparison_mode = false
		var va_config: Variant = m.get("version_a_agent_config", {})
		var vb_config: Variant = m.get("version_b_agent_config", {})
		if not va_config is Dictionary or str((va_config as Dictionary).get("version_tag", "")) == "":
			all_have_version_a_config = false
		else:
			version_a_tags.append(str((va_config as Dictionary).get("version_tag", "")))
		if not vb_config is Dictionary or str((vb_config as Dictionary).get("version_tag", "")) == "":
			all_have_version_b_config = false
		else:
			version_b_tags.append(str((vb_config as Dictionary).get("version_tag", "")))
		if not m.has("version_a_player_index"):
			all_have_version_a_player_index = false
	var all_va_baseline := true
	for tag: String in version_a_tags:
		if tag != "baseline-v1":
			all_va_baseline = false
	var all_vb_candidate := true
	for tag: String in version_b_tags:
		if tag != "candidate-v2":
			all_vb_candidate = false
	return run_checks([
		assert_eq(matches.size(), 4, "2 seeds should produce 4 matches"),
		assert_true(all_have_comparison_mode, "所有原始结果应包含 comparison_mode=version_regression"),
		assert_true(all_have_version_a_config, "所有原始结果应包含 version_a_agent_config"),
		assert_true(all_have_version_b_config, "所有原始结果应包含 version_b_agent_config"),
		assert_true(all_have_version_a_player_index, "所有原始结果应包含 version_a_player_index"),
		assert_true(all_va_baseline, "version_a 标签应始终为 baseline-v1"),
		assert_true(all_vb_candidate, "version_b 标签应始终为 candidate-v2"),
	])


## run_and_summarize_case 应为版本回归模式提供版本汇总
func test_run_and_summarize_version_regression_includes_version_summary() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.deck_a_id = 575720
	benchmark_case.deck_b_id = 578647
	benchmark_case.comparison_mode = "version_regression"
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "candidate-v2"}
	benchmark_case.seed_set = [11, 29]
	benchmark_case.resolve_decks()
	var result: Dictionary = runner.run_and_summarize_case(benchmark_case)
	var summary: Dictionary = result.get("summary", {})
	var text_summary: String = str(result.get("text_summary", ""))
	return run_checks([
		assert_true(summary.has("version_a_wins"), "run_and_summarize 的版本回归汇总应包含 version_a_wins"),
		assert_true(summary.has("version_b_wins"), "run_and_summarize 的版本回归汇总应包含 version_b_wins"),
		assert_true(summary.has("version_a_win_rate"), "run_and_summarize 的版本回归汇总应包含 version_a_win_rate"),
		assert_true(summary.has("version_b_win_rate"), "run_and_summarize 的版本回归汇总应包含 version_b_win_rate"),
		assert_str_contains(text_summary, "baseline-v1", "版本回归文本汇总应包含 baseline-v1"),
		assert_str_contains(text_summary, "candidate-v2", "版本回归文本汇总应包含 candidate-v2"),
	])
