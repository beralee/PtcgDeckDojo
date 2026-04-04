class_name TestSelfPlayRunner
extends TestBase

const SelfPlayRunnerScript = preload("res://scripts/ai/SelfPlayRunner.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")


func _make_default_agent_config() -> Dictionary:
	return {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
	}


func test_same_config_produces_near_even_win_rate() -> String:
	var runner := SelfPlayRunnerScript.new()
	var config := _make_default_agent_config()
	var result: Dictionary = runner.run_batch(
		config,
		config,
		[[575720, 578647]],
		[11, 29],
		200
	)
	var total: int = int(result.get("total_matches", 0))
	var a_wr: float = float(result.get("agent_a_win_rate", 0.0))
	return run_checks([
		assert_true(total > 0, "self-play should complete at least one match"),
		assert_eq(total, 4, "one pairing x two seeds x mirrored seats should produce four matches"),
		assert_true(a_wr >= 0.0 and a_wr <= 1.0, "win rate should stay within [0, 1]"),
	])


func test_result_structure_is_complete() -> String:
	var runner := SelfPlayRunnerScript.new()
	var config := _make_default_agent_config()
	var result: Dictionary = runner.run_batch(
		config,
		config,
		[[575720, 578647]],
		[11],
		200
	)
	return run_checks([
		assert_true(result.has("total_matches"), "result should include total_matches"),
		assert_true(result.has("agent_a_wins"), "result should include agent_a_wins"),
		assert_true(result.has("agent_b_wins"), "result should include agent_b_wins"),
		assert_true(result.has("draws"), "result should include draws"),
		assert_true(result.has("agent_a_win_rate"), "result should include agent_a_win_rate"),
		assert_true(result.has("match_results"), "result should include match_results"),
	])


func test_match_results_contain_per_match_details() -> String:
	var runner := SelfPlayRunnerScript.new()
	var config := _make_default_agent_config()
	var result: Dictionary = runner.run_batch(
		config,
		config,
		[[575720, 578647]],
		[11],
		200
	)
	var match_results: Array = result.get("match_results", [])
	if match_results.is_empty():
		return "match_results should not be empty"
	var first_match: Dictionary = match_results[0]
	return run_checks([
		assert_true(first_match.has("winner_index"), "per-match result should include winner_index"),
		assert_true(first_match.has("seed"), "per-match result should include seed"),
		assert_true(first_match.has("deck_a_id"), "per-match result should include deck_a_id"),
	])


func test_mcts_config_applied_when_present() -> String:
	var runner := SelfPlayRunnerScript.new()
	var config := {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
		"mcts_config": {
			"branch_factor": 2,
			"rollouts_per_sequence": 3,
			"rollout_max_steps": 20,
			"time_budget_ms": 1000,
		},
	}
	var result: Dictionary = runner.run_batch(
		config,
		_make_default_agent_config(),
		[[575720, 578647]],
		[11],
		200
	)
	return run_checks([
		assert_true(int(result.get("total_matches", 0)) > 0, "MCTS-enabled self-play should complete matches"),
	])
