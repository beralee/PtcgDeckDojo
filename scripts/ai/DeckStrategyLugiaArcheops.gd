class_name DeckStrategyLugiaArcheops
extends "res://scripts/ai/DeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const LUGIA_V := "Lugia V"
const LUGIA_VSTAR := "Lugia VSTAR"
const ARCHEOPS := "Archeops"
const MINCCINO := "Minccino"
const CINCCINO := "Cinccino"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const IRON_HANDS_EX := "Iron Hands ex"
const BLOODMOON_URSALUNA_EX := "Bloodmoon Ursaluna ex"
const WELLSPRING_OGERPON_EX := "Wellspring Mask Ogerpon ex"
const CORNERSTONE_OGERPON_EX := "Cornerstone Mask Ogerpon ex"

const ULTRA_BALL := "Ultra Ball"
const CAPTURING_AROMA := "Capturing Aroma"
const GREAT_BALL := "Great Ball"
const PROFESSORS_RESEARCH := "Professor's Research"
const IONO := "Iono"
const BOSSS_ORDERS := "Boss's Orders"
const THORTON := "Thorton"
const JACQ := "Jacq"
const CARMINE := "Carmine"

const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"
const GIFT_ENERGY := "Gift Energy"
const JET_ENERGY := "Jet Energy"
const MIST_ENERGY := "Mist Energy"
const V_GUARD_ENERGY := "V Guard Energy"
const LEGACY_ENERGY := "Legacy Energy"


func get_strategy_id() -> String:
	return "lugia_archeops"


func get_signature_names() -> Array[String]:
	return [LUGIA_V, LUGIA_VSTAR, ARCHEOPS]


func get_state_encoder_class() -> GDScript:
	return StateEncoderScript


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"time_budget_ms": 2100,
		"rollouts_per_sequence": 0,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or not card.is_basic_pokemon():
			continue
		basics.append({"index": i, "score": _setup_priority(_card_name(card), player)})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var active_index: int = int(basics[0].get("index", -1))
	var bench_indices: Array[int] = []
	for entry: Dictionary in basics:
		var idx: int = int(entry.get("index", -1))
		if idx == active_index:
			continue
		bench_indices.append(idx)
		if bench_indices.size() >= 5:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_play_basic(action.get("card", null), player, phase)
		"evolve":
			return _score_evolve(action.get("card", null), player, phase)
		"play_trainer":
			return _score_trainer(action.get("card", null), player, phase)
		"attach_energy":
			return _score_attach(action.get("card", null), action.get("target_slot", null), player, phase)
		"use_ability":
			return _score_use_ability(action.get("source_slot", null), game_state, player, phase)
		"retreat":
			return _score_retreat(player, phase)
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index, phase)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(action, context.get("game_state", null), int(context.get("player_index", -1)))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		var name := _slot_name(slot)
		if name == LUGIA_VSTAR:
			score += 820.0
		elif name == LUGIA_V:
			score += 340.0
		elif name == ARCHEOPS:
			score += 390.0
		elif name == CINCCINO:
			score += 240.0
		elif name == MINCCINO:
			score += 140.0
		elif name == IRON_HANDS_EX:
			score += 230.0
		elif name == BLOODMOON_URSALUNA_EX:
			score += 210.0
		score += float(slot.attached_energy.size()) * 54.0
		score += float(slot.get_remaining_hp()) * 0.06
	score += float(_count_named_on_field(player, ARCHEOPS)) * 150.0
	score += float(_count_named_in_discard(player, ARCHEOPS)) * 70.0
	if _best_lugia_slot(player) != null and _attack_energy_gap(_best_lugia_slot(player)) <= 0:
		score += 220.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached := slot.attached_energy.size() + extra_context
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		var damage: int = _parse_damage(str(attack.get("damage", "0")))
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if name == ARCHEOPS:
		return 260
	if name == MINCCINO:
		return 90
	if name == THORTON or name == JACQ:
		return 170
	if card.card_data.card_type == "Special Energy":
		return 135
	if card.card_data.is_energy():
		return 80
	return 120


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var priority := get_discard_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return priority
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if name == ARCHEOPS and _count_named_in_discard(player, ARCHEOPS) >= 2:
		return 120
	if name == LUGIA_VSTAR and _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
		return 10
	if card.card_data.card_type == "Special Energy" and _count_total_special_energy(player) <= 3:
		return 70
	return priority


func get_search_priority(card: CardInstance) -> int:
	return _search_score(card, null, -1)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_pokemon", "search_cards", "search_item"]:
			return float(_search_score(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id in ["discard_card", "discard_cards"]:
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id == "summon_targets":
			return _summon_target_score(card)
	if item is PokemonSlot and step_id in ["assignment_target", "energy_assignment"]:
		return _assignment_target_score(item as PokemonSlot, context)
	return 0.0


func _setup_priority(name: String, player: PlayerState) -> float:
	if name == LUGIA_V:
		return 380.0
	if name == MINCCINO:
		return 240.0
	if name == IRON_HANDS_EX:
		return 180.0 if _count_named_in_hand(player, LUGIA_V) > 0 else 150.0
	if name == LUMINEON_V:
		return 150.0
	if name == FEZANDIPITI_EX:
		return 130.0
	if name == WELLSPRING_OGERPON_EX or name == CORNERSTONE_OGERPON_EX:
		return 120.0
	return 100.0


func _score_play_basic(card: CardInstance, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null or player.is_bench_full():
		return 0.0
	var name := _card_name(card)
	if name == LUGIA_V:
		if _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) >= 2:
			return 140.0
		return 360.0
	if name == MINCCINO:
		return 250.0 if _count_named_on_field(player, MINCCINO) + _count_named_on_field(player, CINCCINO) == 0 else 130.0
	if name == IRON_HANDS_EX:
		return 180.0 if phase != "early" else 140.0
	if name == BLOODMOON_URSALUNA_EX:
		return 170.0 if phase == "late" else 80.0
	if name == LUMINEON_V:
		return 140.0 if phase == "early" else 70.0
	if name == FEZANDIPITI_EX:
		return 110.0
	if name == WELLSPRING_OGERPON_EX or name == CORNERSTONE_OGERPON_EX:
		return 120.0 if phase == "late" else 70.0
	return 80.0


func _score_evolve(card: CardInstance, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name == LUGIA_VSTAR:
		if _count_named_in_discard(player, ARCHEOPS) >= 1:
			return 950.0
		return 820.0
	if name == CINCCINO:
		return 340.0 if phase != "early" else 220.0
	return 100.0


func _score_trainer(card: CardInstance, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name == ULTRA_BALL:
		if _count_named_in_discard(player, ARCHEOPS) < 2 and (_has_card_named(player.deck, ARCHEOPS) or _count_named_in_hand(player, ARCHEOPS) > 0):
			return 560.0
		if _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
			return 440.0
		return 240.0
	if name == CAPTURING_AROMA:
		if _count_named_on_field(player, LUGIA_V) == 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
			return 360.0
		if _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
			return 380.0
		if _count_named_in_discard(player, ARCHEOPS) < 2:
			return 320.0
		return 160.0
	if name == GREAT_BALL:
		return 210.0 if phase == "early" else 110.0
	if name == PROFESSORS_RESEARCH:
		return 220.0 if player.hand.size() <= 4 or _count_named_in_discard(player, ARCHEOPS) < 2 else 130.0
	if name == IONO:
		return 170.0
	if name == BOSSS_ORDERS:
		return 220.0 if phase == "late" else 120.0
	if name == CARMINE:
		return 190.0 if phase == "early" else 80.0
	if name == JACQ:
		return 230.0 if _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0 else 110.0
	return 90.0


func _score_attach(card: CardInstance, target_slot: PokemonSlot, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var source_name := _card_name(card)
	var target_name := _slot_name(target_slot)
	if source_name == DOUBLE_TURBO_ENERGY:
		if target_name == LUGIA_V or target_name == LUGIA_VSTAR:
			return 420.0 if _attack_energy_gap(target_slot) > 0 else 90.0
		if target_name == CINCCINO or target_name == BLOODMOON_URSALUNA_EX:
			return 320.0 if phase != "early" else 180.0
	if source_name == JET_ENERGY:
		if target_name == LUGIA_V or target_name == LUGIA_VSTAR:
			return 360.0 if phase == "early" else 170.0
		if target_name == IRON_HANDS_EX or target_name == WELLSPRING_OGERPON_EX:
			return 300.0 if phase != "early" else 170.0
	if source_name == GIFT_ENERGY:
		if target_name == LUGIA_VSTAR or target_name == LUGIA_V:
			return 340.0
		if target_name == CINCCINO:
			return 260.0
	if source_name == MIST_ENERGY or source_name == V_GUARD_ENERGY:
		if target_name == LUGIA_VSTAR or target_name == LUGIA_V:
			return 320.0
		if target_name == IRON_HANDS_EX:
			return 200.0
	if source_name == LEGACY_ENERGY:
		if target_name in [IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, LUGIA_VSTAR]:
			return 360.0
	if card.card_data.is_energy():
		if target_name == LUGIA_V or target_name == LUGIA_VSTAR:
			return 320.0
		if target_name == IRON_HANDS_EX or target_name == CINCCINO:
			return 260.0
	return 90.0


func _score_use_ability(source_slot: PokemonSlot, game_state: GameState, player: PlayerState, phase: String) -> float:
	if source_slot == null:
		return 0.0
	var name := _slot_name(source_slot)
	if name == LUGIA_VSTAR:
		var archeops_in_discard := _count_named_in_discard(player, ARCHEOPS)
		if archeops_in_discard >= 2:
			return 760.0
		if archeops_in_discard == 1:
			return 620.0
		return 180.0
	if name == ARCHEOPS:
		var best_target := _best_special_energy_target(player)
		if best_target == null:
			return 140.0
		var gap := _attack_energy_gap(best_target)
		if gap > 0:
			return 640.0 - float(gap) * 40.0
		return 220.0
	if name == FEZANDIPITI_EX:
		return 130.0
	return 0.0


func _score_retreat(player: PlayerState, phase: String) -> float:
	if player == null or player.active_pokemon == null:
		return 0.0
	if _best_ready_bench(player) == null:
		return 0.0
	var active_name := _slot_name(player.active_pokemon)
	if active_name == MINCCINO:
		return 260.0
	if active_name == LUMINEON_V:
		return 220.0
	if active_name == LUGIA_V and phase == "late":
		return 180.0
	return 90.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int, phase: String) -> float:
	var score := 500.0 + float(action.get("projected_damage", 0))
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	if defender != null and int(action.get("projected_damage", 0)) >= defender.get_remaining_hp():
		score += 300.0
	if phase == "late":
		score += 40.0
	return score


func _search_score(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		if name == ARCHEOPS:
			return 115
		if name == LUGIA_VSTAR:
			return 110
		if name == LUGIA_V:
			return 100
		if name == CINCCINO:
			return 80
		return 20
	var player: PlayerState = game_state.players[player_index]
	if name == ARCHEOPS and _count_named_in_discard(player, ARCHEOPS) < 2:
		return 160
	if name == LUGIA_V and _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) == 0:
		return 150
	if name == LUGIA_VSTAR and _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
		return 170
	if name == MINCCINO and _count_named_on_field(player, MINCCINO) + _count_named_on_field(player, CINCCINO) == 0:
		return 110
	if name == IRON_HANDS_EX and _count_named_on_field(player, ARCHEOPS) > 0:
		return 120
	if name == BLOODMOON_URSALUNA_EX and _detect_phase(game_state, player) == "late":
		return 130
	return 20


func _summon_target_score(card: CardInstance) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name == ARCHEOPS:
		return 520.0
	if name == MINCCINO or name == CINCCINO:
		return 160.0
	return 60.0


func _assignment_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var source_card: CardInstance = context.get("source_card", null)
	var source_name := _card_name(source_card)
	var slot_name := _slot_name(slot)
	if source_name == DOUBLE_TURBO_ENERGY:
		if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
			return 430.0
		if slot_name == CINCCINO or slot_name == BLOODMOON_URSALUNA_EX:
			return 360.0
	if source_name == JET_ENERGY:
		if slot_name == IRON_HANDS_EX or slot_name == WELLSPRING_OGERPON_EX:
			return 380.0
		if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
			return 320.0
	if source_name == LEGACY_ENERGY:
		if slot_name == IRON_HANDS_EX or slot_name == BLOODMOON_URSALUNA_EX:
			return 420.0
		if slot_name == LUGIA_VSTAR:
			return 360.0
	if source_name == GIFT_ENERGY:
		if slot_name == CINCCINO:
			return 340.0
		if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
			return 320.0
	if source_name == MIST_ENERGY or source_name == V_GUARD_ENERGY:
		if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
			return 350.0
		if slot_name == IRON_HANDS_EX:
			return 220.0
	if slot_name == IRON_HANDS_EX:
		return 330.0
	if slot_name == CINCCINO:
		return 300.0
	if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
		return 280.0
	if slot_name == BLOODMOON_URSALUNA_EX:
		return 260.0
	return 90.0


func _detect_phase(game_state: GameState, player: PlayerState) -> String:
	if game_state.turn_number <= 2:
		return "early"
	if _count_named_on_field(player, ARCHEOPS) >= 2:
		return "mid"
	if _best_ready_bench(player) != null:
		return "late"
	return "early"


func _best_lugia_slot(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var slot_name := _slot_name(slot)
		if slot_name != LUGIA_V and slot_name != LUGIA_VSTAR:
			continue
		var score := float(slot.attached_energy.size()) * 44.0
		if slot_name == LUGIA_VSTAR:
			score += 220.0
		if slot == player.active_pokemon:
			score += 40.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_special_energy_target(player: PlayerState) -> PokemonSlot:
	var preferred: Array[String] = [IRON_HANDS_EX, CINCCINO, LUGIA_VSTAR, BLOODMOON_URSALUNA_EX, LUGIA_V]
	for target_name: String in preferred:
		for slot: PokemonSlot in _all_slots(player):
			if _slot_name(slot) == target_name and _attack_energy_gap(slot) > 0:
				return slot
	return null


func _best_ready_bench(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in player.bench:
		if slot != null and _attack_energy_gap(slot) <= 0 and _best_attack_damage(slot) > 0:
			return slot
	return null


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	var min_gap := 99
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		min_gap = mini(min_gap, maxi(0, cost.length() - slot.attached_energy.size()))
	return min_gap


func _best_attack_damage(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	var best := 0
	for attack: Dictionary in slot.get_card_data().attacks:
		best = maxi(best, _parse_damage(str(attack.get("damage", "0"))))
	return best


func _count_total_special_energy(player: PlayerState) -> int:
	var total := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Special Energy":
			total += 1
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Special Energy":
			total += 1
	return total


func _all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _count_named_on_field(player: PlayerState, target_name: String) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is(slot, [target_name]):
			count += 1
	return count


func _count_named_in_hand(player: PlayerState, target_name: String) -> int:
	var count := 0
	for card: CardInstance in player.hand:
		if _card_name(card) == target_name:
			count += 1
	return count


func _count_named_in_discard(player: PlayerState, target_name: String) -> int:
	var count := 0
	for card: CardInstance in player.discard_pile:
		if _card_name(card) == target_name:
			count += 1
	return count


func _has_card_named(cards: Array, target_name: String) -> bool:
	for item: Variant in cards:
		if item is CardInstance and _card_name(item as CardInstance) == target_name:
			return true
	return false


func _card_name(card: Variant) -> String:
	if not (card is CardInstance):
		return ""
	var inst := card as CardInstance
	if inst.card_data == null:
		return ""
	if str(inst.card_data.name_en) != "":
		return str(inst.card_data.name_en)
	return str(inst.card_data.name)


func _parse_damage(text: String) -> int:
	var digits := ""
	for i: int in text.length():
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0
