class_name TestMiraidonFastSetupT1
extends TestBase

## 强 AI 硬门槛：密勒顿固定卡序 575720，后攻T1结束时，
## 至少 1 只闪电系攻击手（雷公V/密勒顿ex/铁手ex/皮卡丘）应有 ≥2 能量

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AIFixedDeckOrderRegistryScript = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const MIRAIDON_DECK_ID := 575720
const OPPONENT_DECK_ID := 578647  # 沙奈朵
const FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/575720.json"

const LIGHTNING_ATTACKERS: Array[String] = ["雷公V", "密勒顿ex", "铁手ex", "皮卡丘", "皮卡丘ex"]


func _make_ai_for_deck(player_index: int, deck_id: int) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var deck: DeckData = CardDatabase.get_deck(deck_id)
	if deck != null:
		var registry := DeckStrategyRegistryScript.new()
		registry.apply_strategy_for_deck(ai, deck)
	return ai


func _max_energy_on_lightning_attacker(player: PlayerState) -> Dictionary:
	## 返回 {max_energy, attacker_name}
	var best_count := 0
	var best_name := ""
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for s: PokemonSlot in player.bench:
		if s != null:
			slots.append(s)
	for slot: PokemonSlot in slots:
		var name: String = slot.get_pokemon_name()
		if name not in LIGHTNING_ATTACKERS:
			continue
		var ec := slot.attached_energy.size()
		if ec > best_count:
			best_count = ec
			best_name = name
	return {"max_energy": best_count, "attacker_name": best_name}


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
	var miraidon_deck: DeckData = CardDatabase.get_deck(MIRAIDON_DECK_ID)
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

	gsm.start_game(opponent_deck, miraidon_deck, 0)

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	var player_0_ai := _make_ai_for_deck(0, OPPONENT_DECK_ID)
	var player_1_ai := _make_ai_for_deck(1, MIRAIDON_DECK_ID)
	var outcome := _run_one_full_turn(gsm, bridge, player_0_ai, player_1_ai, 1, 1)

	var miraidon_player: PlayerState = gsm.game_state.players[1]
	var energy_info := _max_energy_on_lightning_attacker(miraidon_player)
	var board := _describe_board(miraidon_player)
	if is_instance_valid(bridge):
		bridge.free()
	return {
		"max_energy": int(energy_info["max_energy"]),
		"attacker_name": energy_info["attacker_name"],
		"board": board,
		"seed": seed_value,
		"target_reached": bool(outcome.get("target_reached", false)),
	}


func test_going_second_t1_lightning_attacker_has_at_least_2_energy() -> String:
	## 单种子基础门槛
	var r := _run_fixed_order_scenario(42)
	return assert_true(int(r["max_energy"]) >= 2,
		"后攻 T1 应有 ≥2 能量在闪电攻击手 (seed=%d, max_energy=%d, name=%s, board=%s)"
		% [int(r["seed"]), int(r["max_energy"]), str(r["attacker_name"]), str(r["board"])])


func test_going_second_t1_lightning_attacker_multi_seed() -> String:
	## 强 AI 硬门槛：多种子稳定（≥4/5 种子达成）
	var seeds: Array[int] = [42, 1337, 2026, 9999, 65535]
	var failures: Array[String] = []
	for s: int in seeds:
		var r := _run_fixed_order_scenario(s)
		if int(r["max_energy"]) < 2:
			failures.append("seed=%d max_e=%d on=%s [%s]" % [s, int(r["max_energy"]), str(r["attacker_name"]), str(r["board"])])
	return assert_true(failures.size() <= 1,
		"密勒顿固定卡序后攻 T1 至少 4/5 种子应达成 ≥2 能量；失败: %s" % " ; ".join(failures))
