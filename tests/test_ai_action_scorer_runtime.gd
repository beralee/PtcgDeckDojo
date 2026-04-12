class_name TestAIActionScorerRuntime
extends TestBase

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIActionScorerScript = preload("res://scripts/ai/AIActionScorer.gd")


class FakeActionScorer extends RefCounted:
	var last_features: Array = []
	var fixed_score: float = 1.0

	func predict(features: Array) -> float:
		last_features = features.duplicate(true)
		return fixed_score

	func score(state_features: Array, action_vector: Array) -> float:
		last_features = state_features.duplicate(true)
		last_features.append_array(action_vector)
		return fixed_score


func test_action_scorer_inference_combines_state_and_action_vectors() -> String:
	var scorer = AIActionScorerScript.new()
	var fake_model := FakeActionScorer.new()
	scorer.set("_model", fake_model)
	scorer.set("_loaded", true)
	var score: float = scorer.score([1.0, 2.0], [3.0, 4.0, 5.0])
	return run_checks([
		assert_eq(fake_model.last_features, [1.0, 2.0, 3.0, 4.0, 5.0], "action scorer should concatenate state and action features before inference"),
		assert_eq(score, 1.0, "action scorer should return the underlying inference score"),
	])


func test_ai_opponent_applies_action_scorer_to_comprehensive_supported_kinds() -> String:
	var ai = AIOpponentScript.new()
	var fake_model := FakeActionScorer.new()
	ai.set("_action_scorer", fake_model)
	var supported_score: float = float(ai.call("_score_action_with_action_scorer", "play_trainer", [0.1, 0.2], {
		"action_vector": [0.3, 0.4],
	}))
	var supported_bench_score: float = float(ai.call("_score_action_with_action_scorer", "play_basic_to_bench", [0.1, 0.2], {
		"action_vector": [0.3, 0.4],
	}))
	var unsupported_score: float = float(ai.call("_score_action_with_action_scorer", "setup_active", [0.1, 0.2], {
		"action_vector": [0.3, 0.4],
	}))
	return run_checks([
		assert_true(supported_score > 0.0, "supported action kinds should receive a learned action score"),
		assert_true(supported_bench_score > 0.0, "expanded action coverage should include play_basic_to_bench"),
		assert_eq(unsupported_score, 0.0, "unsupported action kinds should ignore the learned action score"),
	])
