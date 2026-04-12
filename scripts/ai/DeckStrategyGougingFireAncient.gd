class_name DeckStrategyGougingFireAncient
extends "res://scripts/ai/DeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const GOUGING_FIRE_EX: Array[String] = ["Gouging Fire ex", "破空焰ex"]
const ROARING_MOON_EX: Array[String] = ["Roaring Moon ex", "轰鸣月ex"]
const ENTEI_V: Array[String] = ["Entei V", "炎帝V"]
const MOLTRES: Array[String] = ["Moltres", "火焰鸟"]
const MUNKIDORI: Array[String] = ["Munkidori", "愿增猿"]

const SADA: Array[String] = ["Professor Sada's Vitality", "奥琳博士的气魄"]
const MAGMA_BASIN: Array[String] = ["Magma Basin", "熔岩瀑布之渊"]
const ENERGY_SWITCH: Array[String] = ["Energy Switch", "能量转移"]
const DARK_PATCH: Array[String] = ["Dark Patch", "暗黑补丁"]
const ULTRA_BALL: Array[String] = ["Ultra Ball", "高级球"]
const EARTHEN_VESSEL: Array[String] = ["Earthen Vessel", "大地容器"]
const BRAVERY_CHARM: Array[String] = ["Bravery Charm", "勇气护符"]
const FOREST_SEAL_STONE: Array[String] = ["Forest Seal Stone", "森林封印石"]
const PROFESSORS_RESEARCH: Array[String] = ["Professor's Research", "博士的研究"]


func get_strategy_id() -> String:
	return "gouging_fire_ancient"


func get_signature_names() -> Array[String]:
	return ["Gouging Fire ex", "Professor Sada's Vitality", "Magma Basin"]


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
		"time_budget_ms": 2400,
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
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_bench_basic(action.get("card"))
		"attach_energy":
			return _score_attach_energy(action.get("card"), action.get("target_slot"))
		"attach_tool":
			return _score_attach_tool(action.get("card"), action.get("target_slot"))
		"use_ability":
			return _score_ability(action.get("source_slot"), game_state, player_index)
		"play_trainer":
			return _score_trainer(action.get("card"), game_state, player_index)
		"attack", "granted_attack":
			return _score_attack(action)
		"retreat":
			return 100.0
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
		if slot == null or slot.get_card_data() == null:
			continue
		if _slot_matches(slot, GOUGING_FIRE_EX):
			score += 260.0
			score += float(slot.count_energy_of_type("R")) * 70.0
		elif _slot_matches(slot, ENTEI_V):
			score += 150.0
		elif _slot_matches(slot, ROARING_MOON_EX):
			score += 130.0
		elif slot.get_card_data().is_ancient_pokemon():
			score += 70.0
	if game_state.stadium_card != null and _card_matches(game_state.stadium_card, MAGMA_BASIN):
		score += 140.0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and str(card.card_data.energy_provides) == "R":
			score += 18.0
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
	if _matches_name(name, GOUGING_FIRE_EX):
		return 5
	if card.card_data.card_type == "Basic Energy":
		if str(card.card_data.energy_provides) == "R":
			return 220
		if str(card.card_data.energy_provides) == "D":
			return 180
		return 120
	if _matches_name(name, SADA):
		return 10
	if _matches_name(name, MAGMA_BASIN) or _matches_name(name, ENERGY_SWITCH):
		return 25
	return 90


func get_discard_priority_contextual(card: CardInstance, _game_state: GameState, _player_index: int) -> int:
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if _card_matches(card, GOUGING_FIRE_EX):
		return 100
	if _card_matches(card, ENTEI_V):
		return 88
	if _card_matches(card, ROARING_MOON_EX):
		return 84
	return 20


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_pokemon", "search_cards"]:
			return float(get_search_priority(card))
		if step_id in ["discard_cards", "discard_card", "discard_energy"]:
			return float(get_discard_priority_contextual(card, context.get("game_state"), int(context.get("player_index", -1))))
		return 40.0
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		return _score_assignment_target(slot, context)
	return 0.0


func _score_bench_basic(card: CardInstance) -> float:
	if card == null or card.card_data == null:
		return 0.0
	return float(_setup_priority(str(card.card_data.name)) * 3)


func _score_attach_energy(card: CardInstance, target_slot: PokemonSlot) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var energy_type: String = str(card.card_data.energy_provides)
	var gap: int = _attack_energy_gap(target_slot)
	if _slot_matches(target_slot, GOUGING_FIRE_EX) and energy_type == "R":
		if gap == 1:
			return 460.0
		if gap == 2:
			return 350.0
		return 250.0
	if _slot_matches(target_slot, ROARING_MOON_EX) and energy_type == "D":
		return 300.0 if gap > 0 else 180.0
	if _slot_matches(target_slot, ENTEI_V) and energy_type == "R":
		return 280.0
	return 50.0


func _score_attach_tool(card: CardInstance, target_slot: PokemonSlot) -> float:
	if card == null or target_slot == null:
		return 0.0
	if _card_matches(card, BRAVERY_CHARM):
		if _slot_matches(target_slot, GOUGING_FIRE_EX):
			return 240.0
		if _slot_matches(target_slot, ENTEI_V):
			return 220.0
	if _card_matches(card, FOREST_SEAL_STONE) and (_slot_matches(target_slot, ENTEI_V) or _slot_matches(target_slot, ROARING_MOON_EX)):
		return 260.0
	return 50.0


func _score_trainer(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	var player: PlayerState = game_state.players[player_index]
	if _matches_name(name, SADA):
		return 490.0 if _count_basic_energy_in_discard(player) >= 2 and _count_ancient_targets(player) >= 1 else 260.0
	if _matches_name(name, MAGMA_BASIN):
		return 420.0 if _count_fire_energy_in_discard(player) >= 1 else 220.0
	if _matches_name(name, ENERGY_SWITCH):
		return 330.0
	if _matches_name(name, DARK_PATCH):
		return 260.0 if _count_dark_energy_in_discard(player) >= 1 else 120.0
	if _matches_name(name, ULTRA_BALL):
		return 260.0
	if _matches_name(name, EARTHEN_VESSEL):
		return 250.0
	if name == "Secret Box":
		return 320.0
	if name == "Boss's Orders":
		return 380.0 if _opponent_has_low_hp_support(game_state, player_index) else 210.0
	if _matches_name(name, PROFESSORS_RESEARCH):
		return 150.0
	return 90.0


func _score_ability(source_slot: PokemonSlot, game_state: GameState, player_index: int) -> float:
	if source_slot == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if _slot_matches(source_slot, ENTEI_V):
		if source_slot != player.active_pokemon:
			return 0.0
		return 320.0 if player.hand.size() <= 5 else 240.0
	return 0.0


func _score_attack(action: Dictionary) -> float:
	var projected_damage: int = int(action.get("projected_damage", 0))
	if bool(action.get("projected_knockout", false)):
		return 920.0
	if projected_damage >= 240:
		return 820.0
	if projected_damage >= 160:
		return 700.0
	return 520.0


func _setup_priority(name: String) -> int:
	if _matches_name(name, GOUGING_FIRE_EX):
		return 100
	if _matches_name(name, ENTEI_V):
		return 88
	if _matches_name(name, MOLTRES):
		return 82
	if _matches_name(name, ROARING_MOON_EX):
		return 78
	if _matches_name(name, MUNKIDORI):
		return 68
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
		"retreat":
			return 90.0
	return 10.0


func _count_basic_energy_in_discard(player: PlayerState) -> int:
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			count += 1
	return count


func _count_fire_energy_in_discard(player: PlayerState) -> int:
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and str(card.card_data.energy_provides) == "R":
			count += 1
	return count


func _count_dark_energy_in_discard(player: PlayerState) -> int:
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and str(card.card_data.energy_provides) == "D":
			count += 1
	return count


func _count_ancient_targets(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_card_data() != null and slot.get_card_data().is_ancient_pokemon():
			count += 1
	return count


func _score_assignment_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var source_card: CardInstance = context.get("source_card", null)
	if source_card != null and source_card.card_data != null:
		var energy_type: String = str(source_card.card_data.energy_provides)
		if energy_type == "R":
			if _slot_matches(slot, GOUGING_FIRE_EX):
				return 420.0 if _attack_energy_gap(slot) <= 1 else 360.0
			if _slot_matches(slot, ENTEI_V):
				return 280.0
			if _matches_name(str(slot.get_pokemon_name()), MOLTRES):
				return 220.0
			if _slot_matches(slot, ROARING_MOON_EX):
				return 150.0
		elif energy_type == "D":
			if _slot_matches(slot, ROARING_MOON_EX):
				return 400.0 if _attack_energy_gap(slot) > 0 else 320.0
			if _matches_name(str(slot.get_pokemon_name()), MUNKIDORI):
				return 260.0 if not _slot_has_energy_type(slot, "D") else 180.0
			if _slot_matches(slot, GOUGING_FIRE_EX):
				return 140.0
	if _slot_matches(slot, GOUGING_FIRE_EX):
		return 320.0
	if _slot_matches(slot, ROARING_MOON_EX):
		return 240.0
	if _slot_matches(slot, ENTEI_V):
		return 180.0
	return 60.0


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


func _slot_has_energy_type(slot: PokemonSlot, energy_type: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.energy_provides) == energy_type:
			return true
	return false


func _opponent_has_low_hp_support(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for slot: PokemonSlot in game_state.players[1 - player_index].bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= 180:
			return true
	return false
