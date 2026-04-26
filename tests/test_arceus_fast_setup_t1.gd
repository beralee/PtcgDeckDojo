class_name TestArceusFastSetupT1
extends TestBase

## 强 AI 硬门槛：阿尔宙斯固定卡序 569061，后攻T2结束时（T1不能进化-真实TCG规则），
## Arceus VSTAR 必须已进化在场（卡组核心策略：T1 铺板 → T2 进化 + Star Birth + Trinity Nova）

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AIFixedDeckOrderRegistryScript = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const ARCEUS_DECK_ID := 569061
const OPPONENT_DECK_ID := 578647  # 沙奈朵
const FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/569061.json"

const ARCEUS_VSTAR_NAMES: Array[String] = ["阿尔宙斯VSTAR", "Arceus VSTAR"]


func _make_ai_for_deck(player_index: int, deck_id: int) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var deck: DeckData = CardDatabase.get_deck(deck_id)
	if deck != null:
		var registry := DeckStrategyRegistryScript.new()
		registry.apply_strategy_for_deck(ai, deck)
	return ai


func _has_arceus_vstar(player: PlayerState) -> bool:
	if player.active_pokemon != null:
		var name: String = player.active_pokemon.get_pokemon_name()
		if name in ARCEUS_VSTAR_NAMES:
			return true
	for s: PokemonSlot in player.bench:
		if s == null:
			continue
		if s.get_pokemon_name() in ARCEUS_VSTAR_NAMES:
			return true
	return false


func _describe_board(player: PlayerState) -> String:
	var parts: Array[String] = []
	if player.active_pokemon != null:
		parts.append("active=%s(E%d)" % [player.active_pokemon.get_pokemon_name(), player.active_pokemon.attached_energy.size()])
	for s: PokemonSlot in player.bench:
		if s != null:
			parts.append("bench=%s(E%d)" % [s.get_pokemon_name(), s.attached_energy.size()])
	return ", ".join(parts)


func _run_one_full_turn(
	gsm: GameStateMachine,
	bridge: HeadlessMatchBridge,
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent,
	target_turn: int,
	target_player: int,
	max_steps: int = 300
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
	var arc_deck: DeckData = CardDatabase.get_deck(ARCEUS_DECK_ID)
	var opp_deck: DeckData = CardDatabase.get_deck(OPPONENT_DECK_ID)
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

	gsm.start_game(opp_deck, arc_deck, 0)

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	var player_0_ai := _make_ai_for_deck(0, OPPONENT_DECK_ID)
	var player_1_ai := _make_ai_for_deck(1, ARCEUS_DECK_ID)
	# game turn 1 = P0, 2 = P1 第1回合(不能进化), 3 = P0, 4 = P1 第2回合(可进化)
	# 等到 game turn >= 4 的 P0 回合（即 P1 第2回合刚结束）
	var outcome := _run_one_full_turn(gsm, bridge, player_0_ai, player_1_ai, 4, 1)

	var arc_player: PlayerState = gsm.game_state.players[1]
	var has_vstar := _has_arceus_vstar(arc_player)
	var board := _describe_board(arc_player)
	if is_instance_valid(bridge):
		bridge.free()
	return {"has_arceus_vstar": has_vstar, "board": board, "seed": seed_value, "target_reached": bool(outcome.get("target_reached", false))}


func test_going_second_t2_arceus_vstar_evolved() -> String:
	## 单种子基础门槛（T2 因 T1 真实 TCG 规则不能进化）
	var r := _run_fixed_order_scenario(42)
	return assert_true(bool(r["has_arceus_vstar"]),
		"后攻 T2 Arceus VSTAR 应已进化在场 (seed=%d, board=%s)" % [int(r["seed"]), str(r["board"])])


func test_going_second_t2_arceus_vstar_multi_seed() -> String:
	## 强 AI 硬门槛：多种子稳定
	var seeds: Array[int] = [42, 1337, 2026, 9999, 65535]
	var failures: Array[String] = []
	for s: int in seeds:
		var r := _run_fixed_order_scenario(s)
		if not bool(r["has_arceus_vstar"]):
			failures.append("seed=%d [%s]" % [s, str(r["board"])])
	return assert_true(failures.is_empty(),
		"阿尔宙斯固定卡序后攻 T2 在以下种子下未进化 VSTAR: %s" % " ; ".join(failures))
