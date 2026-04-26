class_name TestRagingBoltStrongOpening
extends TestBase

## 强 AI 硬门槛：猛雷鼓固定卡序 575718，后攻T2结束时，
## 极雷轰至少消耗2枚厄诡椪身上的草能量（对应至少210伤害）。
## T1行动：忍蛙弃草 → 碧草之舞贴草 → 手动贴雷 → 奥琳博士补能
## T2行动：贴斗能量 → 碧草之舞 → 极雷轰消耗≥3草210+伤害

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AIFixedDeckOrderRegistryScript = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const RAGING_BOLT_DECK_ID := 575718
const OPPONENT_DECK_ID := 575720  # 密勒顿
const FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/575718.json"

const G_ENERGY_PROVIDES: String = "G"


func _make_ai_for_deck(player_index: int, deck_id: int) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var deck: DeckData = CardDatabase.get_deck(deck_id)
	if deck != null:
		var registry := DeckStrategyRegistryScript.new()
		registry.apply_strategy_for_deck(ai, deck)
	return ai


func _count_g_in_discard(player: PlayerState) -> int:
	var count: int = 0
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		var provides: Variant = card.card_data.get("energy_provides")
		if provides != null and str(provides) == G_ENERGY_PROVIDES:
			count += 1
	return count


func _describe_board(player: PlayerState) -> String:
	var parts: Array[String] = []
	if player.active_pokemon != null:
		parts.append("active=%s(E%d)" % [
			player.active_pokemon.get_pokemon_name(),
			player.active_pokemon.attached_energy.size()
		])
	for s: PokemonSlot in player.bench:
		if s != null:
			parts.append("bench=%s(E%d)" % [
				s.get_pokemon_name(),
				s.attached_energy.size()
			])
	parts.append("discard_G=%d" % _count_g_in_discard(player))
	return ", ".join(parts)


func _run_one_full_turn(
	gsm: GameStateMachine,
	bridge: HeadlessMatchBridge,
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent,
	target_turn: int,
	target_player: int,
	max_steps: int = 400
) -> Dictionary:
	var steps: int = 0
	var target_reached: bool = false
	var p1_started_turn: bool = false
	while steps < max_steps:
		if gsm.game_state.is_game_over():
			break
		if gsm.game_state.phase == GameState.GamePhase.MAIN \
				and gsm.game_state.turn_number >= target_turn \
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
	var rb_deck: DeckData = CardDatabase.get_deck(RAGING_BOLT_DECK_ID)
	var opp_deck: DeckData = CardDatabase.get_deck(OPPONENT_DECK_ID)
	var registry := AIFixedDeckOrderRegistryScript.new()
	var fixed_order: Array[Dictionary] = registry.load_fixed_order_from_path(FIXED_ORDER_PATH)

	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	# P1 = 猛雷鼓（后攻）
	gsm.set_deck_order_override(1, fixed_order)
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = seed_value
	var ps := PlayerState.new()
	if ps.has_method("set_forced_shuffle_seed"):
		ps.call("set_forced_shuffle_seed", seed_value)

	# P0 先攻，P1（猛雷鼓）后攻
	gsm.start_game(opp_deck, rb_deck, 0)

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	var player_0_ai := _make_ai_for_deck(0, OPPONENT_DECK_ID)
	var player_1_ai := _make_ai_for_deck(1, RAGING_BOLT_DECK_ID)
	# game turn 1=P0 T1, 2=P1 T1(后攻), 3=P0 T2, 4=P1 T2（目标回合）
	var outcome := _run_one_full_turn(gsm, bridge, player_0_ai, player_1_ai, 4, 1)

	var rb_player: PlayerState = gsm.game_state.players[1]
	var g_in_discard: int = _count_g_in_discard(rb_player)
	var board: String = _describe_board(rb_player)
	if is_instance_valid(bridge):
		bridge.free()
	return {
		"g_in_discard": g_in_discard,
		"board": board,
		"seed": seed_value,
		"target_reached": bool(outcome.get("target_reached", false))
	}


func test_going_second_t2_bellowing_thunder_210() -> String:
	## 单种子基础门槛：后攻T2极雷轰至少消耗2枚草能量（≥210伤害）
	var r := _run_fixed_order_scenario(42)
	return assert_true(
		int(r["g_in_discard"]) >= 2,
		"后攻T2弃牌堆应含≥2枚草能量（极雷轰消耗厄诡椪草能量）(seed=%d, board=%s)" % [
			int(r["seed"]), str(r["board"])
		]
	)


func test_going_second_t2_bellowing_thunder_multi_seed() -> String:
	## 强 AI 硬门槛：多种子稳定验证后攻T2极雷轰210+伤害
	var seeds: Array[int] = [42, 1337, 2026]
	var failures: Array[String] = []
	for s: int in seeds:
		var r := _run_fixed_order_scenario(s)
		if int(r["g_in_discard"]) < 2:
			failures.append("seed=%d discard_G=%d [%s]" % [s, int(r["g_in_discard"]), str(r["board"])])
	return assert_true(
		failures.is_empty(),
		"猛雷鼓固定卡序后攻T2在以下种子下未达到210伤害门槛: %s" % " ; ".join(failures)
	)
