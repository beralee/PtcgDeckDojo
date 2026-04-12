class_name DeckStrategyFutureBox
extends "res://scripts/ai/DeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const IRON_CROWN_EX: Array[String] = ["Iron Crown ex", "铁头壳ex"]
const IRON_HANDS_EX: Array[String] = ["Iron Hands ex", "铁臂膀ex"]
const IRON_LEAVES_EX: Array[String] = ["Iron Leaves ex", "铁斑叶ex"]
const MIRAIDON: Array[String] = ["Miraidon", "密勒顿"]
const IRON_BUNDLE: Array[String] = ["Iron Bundle", "铁包袱"]

const TECHNO_RADAR: Array[String] = ["Techno Radar", "高科技雷达"]
const FUTURE_BOOSTER: Array[String] = ["Future Booster Energy Capsule", "驱劲能量 未来"]
const ELECTRIC_GENERATOR: Array[String] = ["Electric Generator", "电气发生器"]
const ARVEN: Array[String] = ["Arven", "派帕"]
const BOSSS_ORDERS: Array[String] = ["Boss's Orders", "老板的指令"]
const PRIME_CATCHER: Array[String] = ["Prime Catcher", "顶尖捕捉器"]
const PROFESSORS_RESEARCH: Array[String] = ["Professor's Research", "博士的研究"]
const IONO: Array[String] = ["Iono", "奇树"]
const SUPER_ROD: Array[String] = ["Super Rod", "厉害钓竿"]


func get_strategy_id() -> String:
	return "future_box"


func get_signature_names() -> Array[String]:
	return ["Iron Crown ex", "Iron Hands ex", "Techno Radar"]


func get_state_encoder_class() -> GDScript:
	return StateEncoderScript


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"max_actions_per_turn": 8,
		"rollouts_per_sequence": 0,
		"time_budget_ms": 2500,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if not _is_basic_pokemon(card):
			continue
		basics.append({"index": i, "priority": _setup_priority(str(card.card_data.name))})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	var active_index: int = int(basics[0].get("index", -1))
	var bench_indices: Array[int] = []
	for entry: Dictionary in basics:
		var index: int = int(entry.get("index", -1))
		if index == active_index:
			continue
		bench_indices.append(index)
		if bench_indices.size() >= 5:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_bench_basic(action.get("card"))
		"attach_energy":
			return _score_attach_energy(action.get("card"), action.get("target_slot"))
		"attach_tool":
			return _score_attach_tool(action.get("card"), action.get("target_slot"))
		"play_trainer":
			return _score_trainer(action.get("card"), game_state, player_index)
		"use_ability":
			return _score_ability(action.get("source_slot"), player)
		"attack", "granted_attack":
			return _score_attack(action)
		"retreat":
			return _score_retreat(player)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	return score_action_absolute(action, game_state, player_index) - _estimate_heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score := 0.0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		if cd.is_future_pokemon():
			score += 70.0
		if _slot_matches(slot, IRON_CROWN_EX):
			score += 150.0
		elif _slot_matches(slot, IRON_HANDS_EX):
			score += 180.0
		elif _slot_matches(slot, IRON_LEAVES_EX):
			score += 120.0
		elif _slot_matches(slot, MIRAIDON):
			score += 90.0
		if _attack_energy_gap(slot) <= 1 and (_slot_matches(slot, IRON_HANDS_EX) or _slot_matches(slot, IRON_LEAVES_EX)):
			score += 90.0
		if _card_matches(slot.attached_tool, FUTURE_BOOSTER):
			score += 60.0
	if _count_energy_in_deck(player, "L") > 0:
		score += 25.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached: int = slot.attached_energy.size() + extra_context
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		var attack_damage: int = _parse_damage_value(str(attack.get("damage", "0")))
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, attack_damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = str(card.card_data.name)
	if _matches_name(name, IRON_CROWN_EX) or _matches_name(name, MIRAIDON):
		return 170
	if card.card_data.card_type == "Basic Energy":
		return 80
	if _matches_name(name, TECHNO_RADAR) or _matches_name(name, FUTURE_BOOSTER) or _matches_name(name, ELECTRIC_GENERATOR):
		return 15
	return 90


func get_discard_priority_contextual(card: CardInstance, _game_state: GameState, _player_index: int) -> int:
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = str(card.card_data.name)
	if _matches_name(name, IRON_HANDS_EX):
		return 100
	if _matches_name(name, IRON_CROWN_EX):
		return 96
	if _matches_name(name, MIRAIDON):
		return 92
	if _matches_name(name, IRON_LEAVES_EX):
		return 88
	if _matches_name(name, IRON_BUNDLE):
		return 72
	return 15


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if card.card_data == null:
			return 0.0
		if step_id in ["search_future_pokemon", "search_pokemon", "search_cards"]:
			return float(get_search_priority(card))
		if step_id in ["discard_cards", "discard_card", "discard_energy"]:
			return float(get_discard_priority_contextual(card, context.get("game_state"), int(context.get("player_index", -1))))
		if card.card_data.card_type == "Pokemon":
			return float(get_search_priority(card))
		if _card_matches(card, FUTURE_BOOSTER):
			return 280.0
		if _card_matches(card, TECHNO_RADAR):
			return 320.0
		return 40.0
	if item is PokemonSlot:
		return _score_assignment_target(item as PokemonSlot)
	return 0.0


func actionable_attacker(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, IRON_HANDS_EX) or _slot_matches(slot, IRON_LEAVES_EX):
			return slot
	return player.active_pokemon


func _score_bench_basic(card: CardInstance) -> float:
	if card == null or card.card_data == null:
		return 0.0
	return float(_setup_priority(str(card.card_data.name)) * 3)


func _score_attach_energy(card: CardInstance, target_slot: PokemonSlot) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var name: String = str(target_slot.get_pokemon_name())
	var energy_type: String = str(card.card_data.energy_provides)
	var gap: int = _attack_energy_gap(target_slot)
	if energy_type == "L":
		if _matches_name(name, IRON_HANDS_EX):
			if gap == 1:
				return 460.0
			if gap == 2:
				return 360.0
			return 240.0
		if _matches_name(name, MIRAIDON):
			return 280.0
		if _is_future_slot(target_slot):
			return 220.0
		return 60.0
	if energy_type == "G" and _matches_name(name, IRON_LEAVES_EX):
		return 300.0 if gap > 0 else 140.0
	return 40.0


func _score_attach_tool(card: CardInstance, target_slot: PokemonSlot) -> float:
	if card == null or target_slot == null:
		return 0.0
	if not _card_matches(card, FUTURE_BOOSTER):
		return 40.0
	if not _is_future_slot(target_slot):
		return -120.0
	if _slot_matches(target_slot, IRON_HANDS_EX) or _slot_matches(target_slot, IRON_LEAVES_EX):
		return 340.0
	if _slot_matches(target_slot, MIRAIDON):
		return 260.0
	return 220.0


func _score_trainer(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	var player: PlayerState = game_state.players[player_index]
	if _matches_name(name, TECHNO_RADAR):
		return 470.0 if _count_future_pokemon_in_deck(player) > 0 else 90.0
	if _matches_name(name, ELECTRIC_GENERATOR):
		return 500.0 if _count_energy_in_deck(player, "L") > 0 else 120.0
	if _matches_name(name, ARVEN):
		return 340.0
	if _matches_name(name, PRIME_CATCHER) or _matches_name(name, BOSSS_ORDERS):
		return 320.0 if _can_project_ko(actionable_attacker(player), game_state, player_index) else 220.0
	if _matches_name(name, IONO):
		return 190.0
	if _matches_name(name, SUPER_ROD):
		return 190.0 if _has_future_in_discard(player) else 90.0
	if _matches_name(name, PROFESSORS_RESEARCH):
		return 140.0
	return 70.0


func _score_ability(source_slot: PokemonSlot, player: PlayerState) -> float:
	if source_slot == null or source_slot.get_card_data() == null:
		return 0.0
	if _slot_matches(source_slot, MIRAIDON):
		return 420.0 if _count_future_targets_needing_setup(player) > 0 else 180.0
	if _slot_matches(source_slot, IRON_CROWN_EX):
		return 200.0
	return 80.0


func _score_attack(action: Dictionary) -> float:
	var projected_damage: int = int(action.get("projected_damage", 0))
	if bool(action.get("projected_knockout", false)):
		return 900.0
	if projected_damage >= 160:
		return 760.0
	if projected_damage >= 100:
		return 620.0
	return 480.0


func _score_retreat(player: PlayerState) -> float:
	if player == null or player.active_pokemon == null:
		return 0.0
	if _slot_matches(player.active_pokemon, IRON_CROWN_EX) and _has_ready_future_attacker_on_bench(player):
		return 260.0
	return 80.0


func _score_assignment_target(slot: PokemonSlot) -> float:
	if slot == null or slot.get_card_data() == null:
		return 0.0
	if _slot_matches(slot, IRON_HANDS_EX):
		return 320.0 - float(_attack_energy_gap(slot) * 40)
	if _slot_matches(slot, IRON_LEAVES_EX):
		return 260.0 - float(_attack_energy_gap(slot) * 30)
	if _slot_matches(slot, MIRAIDON):
		return 220.0
	if _slot_matches(slot, IRON_CROWN_EX):
		return 180.0
	return 40.0


func _setup_priority(name: String) -> int:
	if _matches_name(name, IRON_HANDS_EX):
		return 95
	if _matches_name(name, MIRAIDON):
		return 88
	if _matches_name(name, IRON_LEAVES_EX):
		return 84
	if _matches_name(name, IRON_CROWN_EX):
		return 72
	if _matches_name(name, IRON_BUNDLE):
		return 64
	return 30


func _estimate_heuristic_base(kind: String) -> float:
	match kind:
		"attack", "granted_attack":
			return 500.0
		"attach_energy":
			return 220.0
		"attach_tool":
			return 160.0
		"play_basic_to_bench":
			return 180.0
		"play_trainer":
			return 110.0
		"use_ability":
			return 160.0
		"retreat":
			return 90.0
	return 10.0


func _can_project_ko(slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if slot == null or game_state == null:
		return false
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var damage: int = int(predict_attacker_damage(slot).get("damage", 0))
	var opponent_active: PokemonSlot = game_state.players[opponent_index].active_pokemon
	return opponent_active != null and damage >= opponent_active.get_remaining_hp() and damage > 0


func _count_future_pokemon_in_deck(player: PlayerState) -> int:
	var count := 0
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and card.card_data.is_future_pokemon():
			count += 1
	return count


func _count_future_targets_needing_setup(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and _is_future_slot(slot) and _attack_energy_gap(slot) > 0:
			count += 1
	return count


func _count_energy_in_deck(player: PlayerState, energy_type: String) -> int:
	var count := 0
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and str(card.card_data.energy_provides) == energy_type:
			count += 1
	return count


func _has_future_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.is_future_pokemon():
			return true
	return false


func _has_ready_future_attacker_on_bench(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.bench:
		if slot != null and _is_future_slot(slot) and _attack_energy_gap(slot) <= 1:
			return true
	return false


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 999
	var attached: int = slot.attached_energy.size()
	var min_gap := 999
	for attack: Dictionary in slot.get_card_data().attacks:
		var gap: int = maxi(0, str(attack.get("cost", "")).length() - attached)
		min_gap = mini(min_gap, gap)
	return min_gap


func _is_basic_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Pokemon" and str(card.card_data.stage) == "Basic"


func _is_future_slot(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_card_data() != null and slot.get_card_data().is_future_pokemon()


func _slot_matches(slot: PokemonSlot, aliases: Array[String]) -> bool:
	return slot != null and _matches_name(str(slot.get_pokemon_name()), aliases)


func _card_matches(card: CardInstance, aliases: Array[String]) -> bool:
	return card != null and card.card_data != null and _matches_name(str(card.card_data.name), aliases)


func _matches_name(name: String, aliases: Array[String]) -> bool:
	for alias: String in aliases:
		if name == alias:
			return true
	return false


func _parse_damage_value(damage_text: String) -> int:
	var digits := ""
	for i: int in damage_text.length():
		var ch := damage_text[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0
