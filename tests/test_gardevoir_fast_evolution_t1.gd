class_name TestGardevoirFastEvolutionT1
extends TestBase

## 测试：沙奈朵固定卡序 578647，后攻时第1回合必须做出 2 只奇鲁莉安
##
## 策略（后攻 T1）：
## 1. 宝芬搜 2 只拉鲁拉丝到后备
## 2. 亚文搜物品+道具（备用加速）
## 3. 贴 1 超能量到前场（钥圈儿）
## 4. 贴进化碟到前场
## 5. TM 攻击 → 所有后备拉鲁拉丝进化为奇鲁莉安

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AIFixedDeckOrderRegistryScript = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const GARDEVOIR_DECK_ID := 578647
const OPPONENT_DECK_ID := 575720  # 密勒顿（任意对手都可）
const FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/578647.json"


func _make_ai_for_deck(player_index: int, deck_id: int) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var deck: DeckData = CardDatabase.get_deck(deck_id)
	if deck != null:
		var registry := DeckStrategyRegistryScript.new()
		registry.apply_strategy_for_deck(ai, deck)
	return ai


func _count_kirlia_on_bench(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_pokemon_name() == "奇鲁莉安":
			count += 1
	return count


func _describe_bench(player: PlayerState) -> String:
	var names: Array[String] = []
	if player.active_pokemon != null:
		names.append("active=%s" % player.active_pokemon.get_pokemon_name())
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		names.append("bench=%s" % slot.get_pokemon_name())
	return ", ".join(names)


func _run_one_full_turn(
	gsm: GameStateMachine,
	bridge: HeadlessMatchBridge,
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent,
	target_turn_for_player: int,
	target_player: int,
	max_steps: int = 300
) -> Dictionary:
	## 跑游戏直到 target_player 完成其第 target_turn_for_player 个回合（end_turn 后）
	var steps: int = 0
	var target_reached: bool = false
	var p1_started_turn: bool = false
	while steps < max_steps:
		if gsm.game_state.is_game_over():
			break
		# 检查目标回合结束（对方开始回合 = 己方回合结束）
		if gsm.game_state.phase == GameState.GamePhase.MAIN \
				and gsm.game_state.turn_number >= target_turn_for_player \
				and gsm.game_state.current_player_index != target_player \
				and p1_started_turn:
			target_reached = true
			break
		if gsm.game_state.phase == GameState.GamePhase.MAIN \
				and gsm.game_state.current_player_index == target_player:
			p1_started_turn = true

		var progressed: bool = false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				var owner: int = bridge.get_pending_prompt_owner()
				if owner == 0:
					progressed = player_0_ai.run_single_step(bridge, gsm)
				elif owner == 1:
					progressed = player_1_ai.run_single_step(bridge, gsm)
		else:
			var current: int = gsm.game_state.current_player_index
			if current == 0:
				progressed = player_0_ai.run_single_step(bridge, gsm)
			elif current == 1:
				progressed = player_1_ai.run_single_step(bridge, gsm)
		if not progressed:
			break
		steps += 1
	return {"target_reached": target_reached, "steps": steps}


func _run_fixed_order_scenario(seed_value: int) -> Dictionary:
	## 返回 {kirlia_count, board_desc, turn_info}
	var gardevoir_deck: DeckData = CardDatabase.get_deck(GARDEVOIR_DECK_ID)
	var opponent_deck: DeckData = CardDatabase.get_deck(OPPONENT_DECK_ID)
	var registry := AIFixedDeckOrderRegistryScript.new()
	var fixed_order: Array[Dictionary] = registry.load_fixed_order_from_path(FIXED_ORDER_PATH)

	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.set_deck_order_override(1, fixed_order)
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = seed_value
	var ps := PlayerState.new()
	if ps.has_method("set_forced_shuffle_seed"):
		ps.call("set_forced_shuffle_seed", seed_value)

	gsm.start_game(opponent_deck, gardevoir_deck, 0)

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	var player_0_ai := _make_ai_for_deck(0, OPPONENT_DECK_ID)
	var player_1_ai := _make_ai_for_deck(1, GARDEVOIR_DECK_ID)
	var outcome := _run_one_full_turn(gsm, bridge, player_0_ai, player_1_ai, 1, 1)

	var gardevoir_player: PlayerState = gsm.game_state.players[1]
	var kirlia_count: int = _count_kirlia_on_bench(gardevoir_player)
	var board_desc: String = _describe_bench(gardevoir_player)
	var turn_info: String = "turn=%d, target_reached=%s, steps=%d" % [
		gsm.game_state.turn_number,
		str(outcome.get("target_reached", false)),
		int(outcome.get("steps", 0)),
	]
	if is_instance_valid(bridge):
		bridge.free()
	return {"kirlia_count": kirlia_count, "board_desc": board_desc, "turn_info": turn_info, "seed": seed_value}


func test_going_second_t1_achieves_two_kirlia_via_tm_evolution() -> String:
	## 固定卡序 + 后攻 + seed=42 → T1 必须做出 2 只奇鲁莉安
	var r := _run_fixed_order_scenario(42)
	return assert_true(int(r["kirlia_count"]) >= 2,
		"后攻 T1 应做出至少 2 只奇鲁莉安 (seed=%d, got %d; %s; %s)" % [int(r["seed"]), int(r["kirlia_count"]), r["board_desc"], r["turn_info"]])


func test_going_second_t1_achieves_two_kirlia_multi_seed() -> String:
	## 强 AI 硬门槛：固定卡序后攻 T1 必做 2 奇鲁莉安 —— 多种子稳定
	## 该测试通过是允许合并迭代代码的必要条件
	var seeds: Array[int] = [42, 1337, 2026, 9999, 65535]
	var failures: Array[String] = []
	for s: int in seeds:
		var r := _run_fixed_order_scenario(s)
		if int(r["kirlia_count"]) < 2:
			failures.append("seed=%d kirlia=%d [%s | %s]" % [s, int(r["kirlia_count"]), r["board_desc"], r["turn_info"]])
	return assert_true(failures.is_empty(),
		"强 AI 固定卡序后攻 T1 在以下种子下未做出 2 奇鲁莉安: %s" % " ; ".join(failures))
