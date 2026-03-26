class_name TestRolloutSimulator
extends TestBase

const RolloutSimulatorScript = preload("res://scripts/ai/RolloutSimulator.gd")
const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


func _make_basic_card_data(name: String, hp: int = 60) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _make_energy_card_data(name: String, energy_type: String = "L") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return card


func _make_simple_battle_gsm() -> GameStateMachine:
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
	var attack_cd := _make_basic_card_data("Attacker", 60)
	attack_cd.attacks = [{"name": "Hit", "cost": "C", "damage": "30", "text": "", "is_vstar_power": false}]
	for pi: int in 2:
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(CardInstance.create(attack_cd, pi))
		slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Energy"), pi))
		gsm.game_state.players[pi].active_pokemon = slot
		for _i in 6:
			gsm.game_state.players[pi].prizes.append(CardInstance.create(_make_basic_card_data("Prize"), pi))
		for _i in 10:
			gsm.game_state.players[pi].deck.append(CardInstance.create(_make_basic_card_data("Deck Card"), pi))
	return gsm


func test_rollout_returns_terminal_result() -> String:
	var sim := RolloutSimulatorScript.new()
	var gsm := _make_simple_battle_gsm()
	var result: Dictionary = sim.run_rollout(gsm, 0, 200)
	return run_checks([
		assert_true(result.has("winner_index"), "Rollout 结果应包含 winner_index"),
		assert_true(result.has("steps"), "Rollout 结果应包含 steps"),
		assert_true(result.has("completed"), "Rollout 结果应包含 completed"),
		assert_true(int(result.get("steps", 0)) > 0, "Rollout 应执行至少一步"),
	])


func test_rollout_respects_max_steps() -> String:
	var sim := RolloutSimulatorScript.new()
	var gsm := _make_simple_battle_gsm()
	var result: Dictionary = sim.run_rollout(gsm, 0, 5)
	return run_checks([
		assert_true(int(result.get("steps", 0)) <= 5, "Rollout 应在 max_steps 内终止"),
	])


func test_rollout_does_not_modify_original_gsm() -> String:
	var sim := RolloutSimulatorScript.new()
	var gsm := _make_simple_battle_gsm()
	var original_turn: int = gsm.game_state.turn_number
	var original_hp: int = gsm.game_state.players[0].active_pokemon.damage_counters
	sim.run_rollout(gsm, 0, 50)
	return run_checks([
		assert_eq(gsm.game_state.turn_number, original_turn, "Rollout 不应修改原始 turn_number"),
		assert_eq(gsm.game_state.players[0].active_pokemon.damage_counters, original_hp, "Rollout 不应修改原始伤害"),
	])
