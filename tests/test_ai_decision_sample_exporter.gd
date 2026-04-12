class_name TestAIDecisionSampleExporter
extends TestBase

const AIDecisionSampleExporterScript = preload("res://scripts/ai/AIDecisionSampleExporter.gd")
const AIDecisionTraceScript = preload("res://scripts/ai/AIDecisionTrace.gd")
const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const SelfPlayRunnerScript = preload("res://scripts/ai/SelfPlayRunner.gd")


func _make_basic_card_data(card_name: String, hp: int = 100) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _make_energy_card_data(card_name: String, energy_type: String = "L") -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return card


func _make_headless_mcts_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attack := {"name": "Zap", "cost": "C", "damage": "120", "text": "", "is_vstar_power": false}
	var active_slot := PokemonSlot.new()
	var attacker_cd := _make_basic_card_data("MCTS Attacker", 100)
	attacker_cd.attacks = [attack]
	active_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Energy"), 0))
	gsm.game_state.players[0].active_pokemon = active_slot

	var bench_basic := CardInstance.create(_make_basic_card_data("Bench Mon", 80), 0)
	gsm.game_state.players[0].hand = [bench_basic]

	var opp_slot := PokemonSlot.new()
	opp_slot.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Defender", 70), 1))
	opp_slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Opp Energy"), 1))
	gsm.game_state.players[1].active_pokemon = opp_slot

	for _i in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_basic_card_data("Prize"), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_basic_card_data("Prize"), 1))

	return gsm


func test_exporter_serializes_compact_decision_samples() -> String:
	var exporter = AIDecisionSampleExporterScript.new()
	exporter.base_dir = "user://test_outputs/decision_samples"
	exporter.start_game({
		"run_id": "run_test_001",
		"match_id": "match_test_001",
		"pipeline_name": "miraidon_focus_training",
		"deck_identity": "miraidon",
		"opponent_deck_identity": "gardevoir",
	})

	var trace := AIDecisionTraceScript.new()
	trace.turn_number = 3
	trace.phase = "MAIN"
	trace.player_index = 0
	trace.state_features = [0.1, 0.2, 0.3]
	trace.legal_actions = [
		{"kind": "play_trainer"},
		{"kind": "end_turn"},
	]
	trace.scored_actions = [
		{
			"kind": "play_trainer",
			"score": 120.0,
			"teacher_available": true,
			"teacher_baseline_value": 0.45,
			"teacher_post_value": 0.82,
			"teacher_value_delta": 0.37,
			"features": {
				"productive": true,
				"action_vector": [1.0, 0.0, 0.0],
			},
		},
		{
			"kind": "end_turn",
			"score": 0.0,
			"features": {
				"productive": true,
				"action_vector": [0.0, 0.0, 1.0],
			},
		},
	]
	trace.chosen_action = trace.scored_actions[0].duplicate(true)
	trace.reason_tags = ["trainer_line"]
	trace.used_mcts = false

	exporter.record_trace(trace)
	exporter.end_game(0)
	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var records: Array = parsed.get("records", [])
	var record: Dictionary = {} if records.is_empty() else records[0]
	var legal_actions: Array = record.get("legal_actions", [])
	var chosen_action: Dictionary = record.get("chosen_action", {})

	return run_checks([
		assert_true(FileAccess.file_exists(path), "Exporter should write a decision-sample file"),
		assert_eq(records.size(), 1, "Exporter should record one compact sample"),
		assert_eq(record.get("run_id", ""), "run_test_001", "Sample should preserve run metadata"),
		assert_eq(record.get("pipeline_name", ""), "miraidon_focus_training", "Sample should preserve pipeline metadata"),
		assert_eq(record.get("turn_number", -1), 3, "Sample should preserve turn metadata"),
		assert_eq(legal_actions.size(), 2, "Sample should preserve the legal action set"),
		assert_eq(chosen_action.get("kind", ""), "play_trainer", "Sample should preserve the chosen action"),
		assert_true(bool((legal_actions[0] as Dictionary).get("teacher_available", false)), "Exporter should preserve teacher annotations"),
		assert_eq(float((legal_actions[0] as Dictionary).get("teacher_post_value", 0.0)), 0.82, "Exporter should serialize teacher post-action value"),
		assert_true(float(record.get("result", -1.0)) > 0.5, "Winner-side sample should receive a positive result label"),
	])


func test_exporter_labels_non_winner_samples_as_loss() -> String:
	var exporter = AIDecisionSampleExporterScript.new()
	exporter.base_dir = "user://test_outputs/decision_samples"
	exporter.start_game({
		"run_id": "run_test_002",
		"match_id": "match_test_002",
		"pipeline_name": "miraidon_focus_training",
	})

	var trace := AIDecisionTraceScript.new()
	trace.turn_number = 5
	trace.phase = "MAIN"
	trace.player_index = 1
	trace.state_features = [0.5]
	trace.scored_actions = [{
		"kind": "attack",
		"score": 500.0,
		"features": {"action_vector": [0.0, 1.0]},
	}]
	trace.chosen_action = trace.scored_actions[0].duplicate(true)

	exporter.record_trace(trace)
	exporter.end_game(0)
	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var records: Array = parsed.get("records", [])
	var record: Dictionary = {} if records.is_empty() else records[0]

	return run_checks([
		assert_true(FileAccess.file_exists(path), "Exporter should write a decision-sample file"),
		assert_eq(record.get("result", -1.0), 0.0, "Non-winner-side sample should receive a loss label"),
		assert_eq(record.get("player_index", -1), 1, "Exporter should preserve the acting player index"),
	])


func test_headless_duel_can_record_decision_samples_via_exporter() -> String:
	var benchmark_runner = AIBenchmarkRunnerScript.new()
	var exporter = AIDecisionSampleExporterScript.new()
	exporter.base_dir = "user://test_outputs/decision_samples"
	exporter.start_game({
		"run_id": "run_test_003",
		"match_id": "match_test_003",
		"pipeline_name": "integration_smoke",
	})

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 1
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var ai0 = AIOpponentScript.new()
	ai0.configure(0, 1)
	var ai1 = AIOpponentScript.new()
	ai1.configure(1, 1)

	var result: Dictionary = benchmark_runner.run_headless_duel(ai0, ai1, gsm, 1, Callable(), exporter)
	exporter.end_game(result)
	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var records: Array = parsed.get("records", [])

	return run_checks([
		assert_true(FileAccess.file_exists(path), "Headless-duel integration should still write an exporter file"),
		assert_false(records.is_empty(), "Headless-duel integration should capture at least one decision trace"),
		assert_eq(int(records[0].get("turn_number", -1)), 1, "Recorded trace should preserve the duel turn number"),
	])


func test_mcts_choice_produces_trace_usable_by_exporter() -> String:
	var gsm := _make_headless_mcts_gsm()
	var ai0 = AIOpponentScript.new()
	ai0.configure(0, 1)
	ai0.use_mcts = true
	ai0.mcts_config = {
		"branch_factor": 2,
		"rollouts_per_sequence": 2,
		"rollout_max_steps": 10,
		"time_budget_ms": 250,
	}
	var exporter = AIDecisionSampleExporterScript.new()
	exporter.base_dir = "user://test_outputs/decision_samples"
	exporter.start_game({
		"run_id": "run_test_004",
		"match_id": "match_test_004",
		"pipeline_name": "mcts_trace_smoke",
	})
	var action: Dictionary = ai0.call("_choose_best_action", gsm)
	var trace = ai0.get_last_decision_trace()
	exporter.record_trace(trace)
	exporter.end_game(0)
	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var records: Array = parsed.get("records", [])
	var record: Dictionary = {} if records.is_empty() else records[0]

	return run_checks([
		assert_false(action.is_empty(), "MCTS smoke should still choose a concrete action"),
		assert_true(FileAccess.file_exists(path), "MCTS trace exporter should still write an exporter file"),
		assert_false(records.is_empty(), "MCTS decisions should also be exportable as training samples"),
		assert_true(bool(record.get("used_mcts", false)), "MCTS-sourced samples should preserve used_mcts=true"),
		assert_false((record.get("legal_actions", []) as Array).is_empty(), "MCTS samples should still include the legal action set"),
		assert_true(str((record.get("chosen_action", {}) as Dictionary).get("kind", "")) != "", "MCTS samples should preserve the chosen action"),
	])


func test_self_play_runner_can_export_action_training_samples() -> String:
	var self_play_runner = SelfPlayRunnerScript.new()
	var meta: Dictionary = self_play_runner._build_decision_meta(
		"self_play_11_a0",
		575720,
		578647,
		"miraidon_focus_training"
	)

	return run_checks([
		assert_eq(str(meta.get("match_id", "")), "self_play_11_a0", "Self-play metadata should preserve match id"),
		assert_eq(str(meta.get("run_id", "")), "self_play_11_a0", "Self-play metadata should use the match id as run id"),
		assert_eq(str(meta.get("pipeline_name", "")), "miraidon_focus_training", "Self-play metadata should preserve pipeline name"),
		assert_eq(str(meta.get("deck_identity", "")), "575720", "Self-play metadata should preserve the acting deck identity"),
		assert_eq(str(meta.get("opponent_deck_identity", "")), "578647", "Self-play metadata should preserve the opponent deck identity"),
	])


func test_exporter_serializes_interaction_decision_records() -> String:
	var exporter = AIDecisionSampleExporterScript.new()
	exporter.base_dir = "user://test_outputs/decision_samples"
	exporter.start_game({
		"run_id": "run_test_interaction",
		"match_id": "match_test_interaction",
		"pipeline_name": "gardevoir_interaction_training",
		"deck_identity": "578647",
		"opponent_deck_identity": "575720",
	})
	exporter.record_interaction_decision({
		"player_index": 0,
		"turn_number": 4,
		"state_features": [0.1, 0.2],
		"step_id": "embrace_target",
		"step_type": "card_selection",
		"resolution_kind": "dialog",
		"candidates": [
			{
				"index": 0,
				"chosen": true,
				"item_name": "Kirlia",
				"strategy_score": 8.0,
				"interaction_vector": [1.0, 0.0],
			},
			{
				"index": 1,
				"chosen": false,
				"item_name": "Drifloon",
				"strategy_score": 4.0,
				"interaction_vector": [0.0, 1.0],
			},
		],
	})
	exporter.end_game(0)
	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var interaction_records: Array = parsed.get("interaction_records", [])
	var record: Dictionary = {} if interaction_records.is_empty() else interaction_records[0]
	var candidates: Array = record.get("candidates", [])
	return run_checks([
		assert_true(FileAccess.file_exists(path), "Exporter should write the interaction training file"),
		assert_eq(interaction_records.size(), 1, "Exporter should preserve one interaction record"),
		assert_eq(int(record.get("turn_number", -1)), 4, "Interaction records should preserve turn metadata"),
		assert_true(float(record.get("result", -1.0)) > 0.5, "Interaction records should receive winner labels"),
		assert_eq(candidates.size(), 2, "Interaction records should preserve candidate sets"),
		assert_true(bool((candidates[0] as Dictionary).get("chosen", false)), "Chosen candidate flag should survive serialization"),
	])


func test_self_play_match_ids_stay_unique_across_nearby_pairings() -> String:
	var self_play_runner = SelfPlayRunnerScript.new()
	var left := str(self_play_runner._build_self_play_match_id(1276720, "a0", 578647, 575716))
	var right := str(self_play_runner._build_self_play_match_id(1276720, "a0", 578647, 575720))

	return run_checks([
		assert_true(left != right, "Nearby opponent ids should not generate colliding self-play match ids"),
		assert_true(left.find("578647_vs_575716") >= 0, "Match id should encode the exact pairing"),
		assert_true(right.find("578647_vs_575720") >= 0, "Match id should encode the exact pairing"),
	])
