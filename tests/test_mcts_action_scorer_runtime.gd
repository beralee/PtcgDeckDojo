class_name TestMCTSActionScorerRuntime
extends TestBase

const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")


class FakeActionScorer extends RefCounted:
	var fixed_score: float = 1.0

	func score(_state_features: Array, _action_vector: Array) -> float:
		return fixed_score


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


func _make_gsm() -> GameStateMachine:
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

	var active_cd := _make_basic_card_data("Active", 120)
	active_cd.attacks = [{"name": "Zap", "cost": "C", "damage": "40", "text": "", "is_vstar_power": false}]
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Energy"), 0))
	gsm.game_state.players[0].active_pokemon = active_slot

	var target_slot := PokemonSlot.new()
	target_slot.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Defender", 100), 1))
	gsm.game_state.players[1].active_pokemon = target_slot

	return gsm


func test_mcts_action_scorer_only_applies_to_supported_kinds() -> String:
	var planner := MCTSPlannerScript.new()
	planner.action_scorer = FakeActionScorer.new()
	var supported_score: float = float(planner.call("_score_action_with_model", "play_trainer", [0.1, 0.2], {
		"action_vector": [0.3, 0.4],
	}))
	var unsupported_score: float = float(planner.call("_score_action_with_model", "play_basic_to_bench", [0.1, 0.2], {
		"action_vector": [0.3, 0.4],
	}))
	return run_checks([
		assert_true(supported_score > 0.0, "supported kinds should receive the learned action bonus during MCTS scoring"),
		assert_eq(unsupported_score, 0.0, "unsupported kinds should ignore the learned action bonus during MCTS scoring"),
	])
