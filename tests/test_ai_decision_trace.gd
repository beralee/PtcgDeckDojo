class_name TestAIDecisionTrace
extends TestBase

const AIDecisionTraceScript = preload("res://scripts/ai/AIDecisionTrace.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


class EndTurnStubBattleScene extends Control:
	var end_turn_calls: int = 0

	func _on_end_turn(_action_player_index: int = -1) -> void:
		end_turn_calls += 1


func _make_player_state(player_index: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = player_index
	return player


func _make_ai_manual_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 7
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	return gsm


func test_ai_decision_trace_stores_structured_fields() -> String:
	var trace := AIDecisionTraceScript.new()
	trace.turn_number = 3
	trace.player_index = 1
	trace.legal_actions = [{"kind": "attach_energy"}]
	trace.scored_actions = [{"kind": "attach_energy", "score": 240.0}]
	trace.chosen_action = {"kind": "attach_energy", "score": 240.0, "reason_tags": ["active_attach"]}
	trace.reason_tags = ["active_attach"]
	var serialized = trace.to_dictionary()

	return run_checks([
		assert_eq(trace.turn_number, 3, "Trace should preserve the turn number"),
		assert_eq(trace.player_index, 1, "Trace should preserve the player index"),
		assert_eq(trace.legal_actions.size(), 1, "Trace should preserve legal actions"),
		assert_eq(trace.scored_actions.size(), 1, "Trace should preserve scored actions"),
		assert_eq(trace.chosen_action.get("kind", ""), "attach_energy", "Trace should preserve the chosen action"),
		assert_eq(trace.chosen_action.get("score", -1.0), 240.0, "Trace should preserve the chosen action score"),
		assert_eq(trace.reason_tags, ["active_attach"], "Trace should preserve reason tags"),
		assert_eq(serialized.get("turn_number", -1), 3, "Serialized trace should preserve the turn number"),
		assert_eq(serialized.get("player_index", -1), 1, "Serialized trace should preserve the player index"),
		assert_eq(serialized.get("legal_actions", []).size(), 1, "Serialized trace should preserve legal actions"),
		assert_eq(serialized.get("scored_actions", []).size(), 1, "Serialized trace should preserve scored actions"),
		assert_eq(serialized.get("chosen_action", {}).get("kind", ""), "attach_energy", "Serialized trace should preserve the chosen action"),
		assert_eq(serialized.get("chosen_action", {}).get("score", -1.0), 240.0, "Serialized trace should preserve the chosen action score"),
		assert_eq(serialized.get("reason_tags", []), ["active_attach"], "Serialized trace should preserve reason tags"),
	])


func test_ai_opponent_records_last_decision_trace_for_one_step() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(0, 1)
	var gsm := _make_ai_manual_gsm()
	var battle_scene := EndTurnStubBattleScene.new()

	var handled := ai.run_single_step(battle_scene, gsm)
	var trace = ai.get_last_decision_trace()

	return run_checks([
		assert_true(handled, "AI should complete a simple decision step"),
		assert_not_null(trace, "AI should expose the last decision trace after a step"),
		assert_eq(trace.turn_number, 7, "Trace should capture the game turn number"),
		assert_eq(trace.player_index, 0, "Trace should capture the AI player index"),
		assert_eq(trace.legal_actions.size(), 1, "Trace should capture the legal action list"),
		assert_eq(trace.scored_actions.size(), 1, "Trace should capture the scored action list"),
		assert_eq(trace.chosen_action.get("kind", ""), "end_turn", "Trace should capture the chosen action"),
		assert_eq(trace.chosen_action.get("score", -1.0), 0.0, "Trace should capture the chosen action score"),
		assert_eq(trace.reason_tags, [], "Trace should default to an empty reason tag list"),
		assert_eq(battle_scene.end_turn_calls, 1, "AI should execute the end turn action through the battle scene"),
	])


func test_ai_opponent_returns_isolated_decision_trace_copy() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(0, 1)
	var gsm := _make_ai_manual_gsm()
	var battle_scene := EndTurnStubBattleScene.new()

	var handled := ai.run_single_step(battle_scene, gsm)
	var trace_a = ai.get_last_decision_trace()
	trace_a.turn_number = 99
	trace_a.reason_tags.append("mutated")
	trace_a.chosen_action["score"] = 999.0
	var trace_b = ai.get_last_decision_trace()

	return run_checks([
		assert_true(handled, "AI should complete a simple decision step"),
		assert_eq(trace_b.turn_number, 7, "Returned trace copies should not let callers mutate the AI-owned turn number"),
		assert_eq(trace_b.reason_tags, [], "Returned trace copies should not let callers mutate the AI-owned reason tags"),
		assert_eq(trace_b.chosen_action.get("score", -1.0), 0.0, "Returned trace copies should not let callers mutate the AI-owned chosen action"),
	])
