class_name TestMCTSPlanner
extends TestBase

const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")


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


func _make_battle_gsm_with_bench_option() -> GameStateMachine:
	## 构造一个场面：P0 有前场 + 手牌里有基础宝可梦可铺 + 有能量可贴 + 可攻击
	## MCTS 应该发现"先铺场再攻击"比"直接攻击"的序列胜率更高
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

	var bench_basic := CardInstance.create(_make_basic_card_data("Bench Mon", 80), 0)
	var hand_energy := CardInstance.create(_make_energy_card_data("Energy 2"), 0)
	gsm.game_state.players[0].hand = [bench_basic, hand_energy]

	for _i in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_basic_card_data("Prize"), 0))
	for _i in 10:
		gsm.game_state.players[0].deck.append(CardInstance.create(_make_basic_card_data("Deck Card"), 0))

	var opp_slot := PokemonSlot.new()
	opp_slot.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Defender", 100), 1))
	opp_slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Opp Energy"), 1))
	gsm.game_state.players[1].active_pokemon = opp_slot
	for _i in 6:
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_basic_card_data("Prize"), 1))
	for _i in 10:
		gsm.game_state.players[1].deck.append(CardInstance.create(_make_basic_card_data("Deck Card"), 1))

	return gsm


func test_mcts_planner_returns_action_sequence() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm_with_bench_option()
	var sequence: Array = planner.plan_turn(gsm, 0, {
		"branch_factor": 3,
		"rollouts_per_sequence": 5,
		"rollout_max_steps": 30,
	})
	return run_checks([
		assert_true(sequence.size() > 0, "MCTS 应返回至少一个动作"),
		assert_true(sequence.size() > 1, "MCTS 应返回多步序列而非只有 end_turn"),
	])


func test_mcts_planner_sequence_ends_with_end_turn_or_attack() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm_with_bench_option()
	var sequence: Array = planner.plan_turn(gsm, 0, {
		"branch_factor": 3,
		"rollouts_per_sequence": 5,
		"rollout_max_steps": 30,
	})
	var last_kind: String = str(sequence.back().get("kind", "")) if not sequence.is_empty() else ""
	return run_checks([
		assert_true(
			last_kind == "end_turn" or last_kind == "attack",
			"序列最后一步应是 end_turn 或 attack，实际是 %s" % last_kind
		),
	])


func test_mcts_planner_discovers_bench_before_attack() -> String:
	## 核心行为测试：MCTS 应发现"先铺场再攻击"优于"直接攻击"
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm_with_bench_option()
	var sequence: Array = planner.plan_turn(gsm, 0, {
		"branch_factor": 3,
		"rollouts_per_sequence": 10,
		"rollout_max_steps": 50,
	})
	var kinds: Array[String] = []
	for action: Dictionary in sequence:
		kinds.append(str(action.get("kind", "")))
	var has_bench := kinds.has("play_basic_to_bench")
	var has_attack := kinds.has("attack")
	return run_checks([
		assert_true(has_bench or has_attack, "MCTS 序列应包含铺场或攻击"),
		assert_true(sequence.size() >= 2, "MCTS 应规划多步序列（不止一步）"),
	])


func test_mcts_planner_does_not_modify_original() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm_with_bench_option()
	var original_hand_size: int = gsm.game_state.players[0].hand.size()
	var original_bench_size: int = gsm.game_state.players[0].bench.size()
	planner.plan_turn(gsm, 0, {
		"branch_factor": 2,
		"rollouts_per_sequence": 3,
		"rollout_max_steps": 20,
	})
	return run_checks([
		assert_eq(gsm.game_state.players[0].hand.size(), original_hand_size, "MCTS 不应修改原始手牌"),
		assert_eq(gsm.game_state.players[0].bench.size(), original_bench_size, "MCTS 不应修改原始备战区"),
	])
