class_name TestMCTSFailureDiagnostics
extends TestBase

const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")
const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const SelfPlayRunnerScript = preload("res://scripts/ai/SelfPlayRunner.gd")
const ArchiveScript = preload("res://scripts/ai/TrainingAnomalyArchive.gd")


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


func _make_supporter_card_data(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Supporter"
	return card


func _make_battle_gsm() -> GameStateMachine:
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

	var attacker_cd := _make_basic_card_data("Attacker", 100)
	attacker_cd.attacks = [{"name": "Zap", "cost": "C", "damage": "40", "text": "", "is_vstar_power": false}]
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Energy"), 0))
	gsm.game_state.players[0].active_pokemon = active_slot

	var opp_slot := PokemonSlot.new()
	opp_slot.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Defender", 100), 1))
	opp_slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Opp Energy"), 1))
	gsm.game_state.players[1].active_pokemon = opp_slot

	return gsm


func _make_anomaly_match(failure_reason: String) -> Dictionary:
	return {
		"winner_index": -1,
		"turn_count": 17,
		"steps": 41,
		"seed": 11,
		"deck_a_id": 575720,
		"deck_b_id": 578647,
		"agent_a_player_index": 0,
		"failure_reason": failure_reason,
		"terminated_by_cap": failure_reason == "action_cap_reached",
		"stalled": failure_reason == "stalled_no_progress",
		"generation": 3,
		"lane_id": "lane_03",
	}


func test_mcts_planner_classifies_supporter_used_rule_reject() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm()
	var supporter := CardInstance.create(_make_supporter_card_data("Arven"), 0)
	gsm.game_state.players[0].hand.append(supporter)
	gsm.game_state.supporter_used_this_turn = true
	var action := {
		"kind": "play_trainer",
		"card": supporter,
	}
	return run_checks([
		assert_eq(
			planner._classify_execution_failure(gsm, 0, action, action),
			"rule_reject_supporter_used",
			"Supporter reuse should be classified as a rule rejection"
		),
	])


func test_mcts_planner_classifies_attack_not_ready_rule_reject() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm()
	gsm.game_state.players[0].active_pokemon.attached_energy.clear()
	var action := {
		"kind": "attack",
		"attack_index": 0,
	}
	return run_checks([
		assert_eq(
			planner._classify_execution_failure(gsm, 0, action, action),
			"rule_reject_attack_not_ready",
			"Unavailable attacks should be classified as attack readiness rejects"
		),
	])


func test_mcts_planner_classifies_resolution_mismatch_before_rule_checks() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm()
	var action := {
		"kind": "use_ability",
		"ability_index": 0,
	}
	return run_checks([
		assert_eq(
			planner._classify_execution_failure(gsm, 0, action, {}),
			"action_resolution_mismatch",
			"Empty resolved actions should be classified as resolution mismatches"
		),
	])


func test_mcts_planner_classifies_headless_interaction_required() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm()
	var action := {
		"kind": "play_trainer",
		"requires_interaction": true,
	}
	return run_checks([
		assert_eq(
			planner._classify_execution_failure(gsm, 0, action, action),
			"headless_interaction_required",
			"Interactive actions should be classified separately from generic execution errors"
		),
	])


func test_mcts_planner_classifies_missing_action_reference() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm()
	var action := {
		"kind": "play_trainer",
		"card": null,
	}
	return run_checks([
		assert_eq(
			planner._classify_execution_failure(gsm, 0, action, action),
			"action_missing_reference",
			"Resolved actions missing required references should be surfaced explicitly"
		),
	])


func test_mcts_planner_classifies_trainer_effect_cannot_execute() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm()
	var arven := CardInstance.create(_make_supporter_card_data("Arven"), 0)
	arven.card_data.effect_id = "5bdbc985f9aa2e6f248b53f6f35d1d37"
	gsm.game_state.players[0].hand.append(arven)
	var action := {
		"kind": "play_trainer",
		"card": arven,
		"requires_interaction": false,
	}
	return run_checks([
		assert_eq(
			planner._classify_execution_failure(gsm, 0, action, action),
			"trainer_effect_cannot_execute",
			"Trainer effects that fail can_execute should be split from generic execution errors"
		),
	])


func test_mcts_planner_resolves_nested_target_context_for_clone() -> String:
	var planner := MCTSPlannerScript.new()
	var cloner := GameStateClonerScript.new()
	var gsm := _make_battle_gsm()
	var nest_ball := CardInstance.create(_make_supporter_card_data("Nest Ball"), 0)
	nest_ball.card_data.card_type = "Item"
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	gsm.game_state.players[0].hand.append(nest_ball)
	var deck_basic := CardInstance.create(_make_basic_card_data("Bench Basic", 70), 0)
	gsm.game_state.players[0].deck.append(deck_basic)
	var cloned_gsm: GameStateMachine = cloner.clone_gsm(gsm)
	var resolved: Dictionary = planner._resolve_action_for_gsm({
		"kind": "play_trainer",
		"card": nest_ball,
		"targets": [{
			"basic_pokemon": [deck_basic],
		}],
	}, cloned_gsm, 0)
	var resolved_targets: Array = resolved.get("targets", [])
	var resolved_ctx: Dictionary = {} if resolved_targets.is_empty() else resolved_targets[0]
	var resolved_cards: Array = resolved_ctx.get("basic_pokemon", [])
	var resolved_card: CardInstance = null if resolved_cards.is_empty() else resolved_cards[0]
	return run_checks([
		assert_false(resolved_targets.is_empty(), "resolved action should preserve headless target context"),
		assert_true(resolved_card != null, "resolved action should map nested card targets onto the cloned GSM"),
		assert_true(resolved_card in cloned_gsm.game_state.players[0].deck, "resolved nested target should point at the cloned deck card"),
		assert_eq(-1 if resolved_card == null else resolved_card.instance_id, deck_basic.instance_id, "resolved nested target should preserve the original instance id"),
	])


func test_self_play_match_entry_preserves_event_counters() -> String:
	var runner := SelfPlayRunnerScript.new()
	var entry: Dictionary = runner._build_match_entry({
		"winner_index": -1,
		"turn_count": 17,
		"steps": 41,
		"failure_reason": "stalled_no_progress",
		"terminated_by_cap": false,
		"stalled": true,
		"event_counters": {
			"mcts_failure_category_counts": {
				"rule_reject_supporter_used": 2,
			},
		},
	}, 11, 575720, 578647, 0)
	return run_checks([
		assert_true(entry.has("event_counters"), "match entries should preserve event_counters for anomaly analysis"),
		assert_eq(
			int(((entry.get("event_counters", {}) as Dictionary).get("mcts_failure_category_counts", {}) as Dictionary).get("rule_reject_supporter_used", 0)),
			2,
			"match entries should preserve nested MCTS failure counters"
		),
	])


func test_archive_aggregates_mcts_failure_categories_from_event_counters() -> String:
	var archive = ArchiveScript.new()
	var anomaly_match := _make_anomaly_match("stalled_no_progress")
	anomaly_match["event_counters"] = {
		"mcts_failure_category_counts": {
			"rule_reject_supporter_used": 2,
			"action_resolution_mismatch": 1,
		},
		"mcts_failure_kind_counts": {
			"play_trainer": 2,
			"use_ability": 1,
		},
		"mcts_failure_samples": [
			{
				"category": "rule_reject_supporter_used",
				"kind": "play_trainer",
				"turn_number": 4,
				"step_index": 12,
			},
			{
				"category": "action_resolution_mismatch",
				"kind": "use_ability",
				"turn_number": 5,
				"step_index": 18,
			},
		],
	}
	archive.record_matches("phase1_self_play", [anomaly_match], {"run_id": "run_02"})
	var summary: Dictionary = archive.build_summary()
	var category_counts: Dictionary = summary.get("mcts_failure_category_counts", {})
	var kind_counts: Dictionary = summary.get("mcts_failure_kind_counts", {})
	var category_samples: Dictionary = summary.get("mcts_failure_samples", {})
	var category_pairing_map: Dictionary = category_samples.get("rule_reject_supporter_used", {})
	var pairing_samples: Array = category_pairing_map.get("miraidon_vs_gardevoir", [])
	return run_checks([
		assert_eq(int(category_counts.get("rule_reject_supporter_used", 0)), 2, "summary should accumulate MCTS failure category counts"),
		assert_eq(int(category_counts.get("action_resolution_mismatch", 0)), 1, "summary should preserve distinct MCTS failure categories"),
		assert_eq(int(kind_counts.get("play_trainer", 0)), 2, "summary should accumulate MCTS failure action kinds"),
		assert_eq(int(kind_counts.get("use_ability", 0)), 1, "summary should preserve distinct MCTS failure kinds"),
		assert_eq(pairing_samples.size(), 1, "summary should retain representative MCTS failure samples by category and pairing"),
		assert_eq(str((pairing_samples[0] as Dictionary).get("kind", "")), "play_trainer", "MCTS failure samples should preserve the failed action kind"),
	])
