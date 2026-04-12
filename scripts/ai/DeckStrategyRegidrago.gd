class_name DeckStrategyRegidrago
extends "res://scripts/ai/DeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const REGIDRAGO_V := "Regidrago V"
const REGIDRAGO_VSTAR := "Regidrago VSTAR"
const TEAL_MASK_OGERPON_EX := "Teal Mask Ogerpon ex"
const GIRATINA_VSTAR := "Giratina VSTAR"
const DRAGAPULT_EX := "Dragapult ex"
const HISUIAN_GOODRA_VSTAR := "Hisuian Goodra VSTAR"
const HAXORUS := "Haxorus"
const RADIANT_CHARIZARD := "Radiant Charizard"
const SQUAWKABILLY_EX := "Squawkabilly ex"
const FEZANDIPITI_EX := "Fezandipiti ex"
const HAWLUCHA := "Hawlucha"
const MEW_EX := "Mew ex"
const CLEFFA := "Cleffa"

const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"
const ENERGY_SWITCH := "Energy Switch"
const EARTHEN_VESSEL := "Earthen Vessel"
const SUPER_ROD := "Super Rod"
const NIGHT_STRETCHER := "Night Stretcher"
const PRIME_CATCHER := "Prime Catcher"
const BOSSS_ORDERS := "Boss's Orders"
const PROFESSORS_RESEARCH := "Professor's Research"
const IONO := "Iono"
const CANCELING_COLOGNE := "Canceling Cologne"

const GRASS_ENERGY := "Grass Energy"
const FIRE_ENERGY := "Fire Energy"


func get_strategy_id() -> String:
	return "regidrago"


func get_signature_names() -> Array[String]:
	return [REGIDRAGO_V, REGIDRAGO_VSTAR, GIRATINA_VSTAR, TEAL_MASK_OGERPON_EX]


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
			return _score_use_ability(action.get("source_slot", null), player, phase)
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
		if name == REGIDRAGO_VSTAR:
			score += 820.0
		elif name == REGIDRAGO_V:
			score += 320.0
		elif name == TEAL_MASK_OGERPON_EX:
			score += 300.0
		elif name == SQUAWKABILLY_EX:
			score += 120.0
		score += float(slot.attached_energy.size()) * 74.0
		score += float(slot.get_remaining_hp()) * 0.06
	score += float(_dragon_fuel_count(player)) * 120.0
	if _best_regidrago_slot(player) != null and _attack_energy_gap(_best_regidrago_slot(player)) <= 0:
		score += 260.0
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
	if name in [GIRATINA_VSTAR, DRAGAPULT_EX, HISUIAN_GOODRA_VSTAR, HAXORUS]:
		return 240
	if name == REGIDRAGO_VSTAR:
		return 40
	if name == REGIDRAGO_V:
		return 25
	if name == TEAL_MASK_OGERPON_EX:
		return 70
	if name == RADIANT_CHARIZARD:
		return 90
	if card.card_data.is_energy():
		return 120
	if name == ULTRA_BALL:
		return 50
	return 130


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var priority := get_discard_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return priority
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if name == REGIDRAGO_V and _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) == 0:
		return 0
	if name == TEAL_MASK_OGERPON_EX and _count_named_on_field(player, TEAL_MASK_OGERPON_EX) == 0:
		return 20
	if name == GRASS_ENERGY and _count_energy_in_hand(player, "G") <= 1:
		return 60
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
	if item is PokemonSlot and step_id in ["assignment_target", "energy_assignment"]:
		return _assignment_target_score(item as PokemonSlot, context)
	if item is Dictionary and step_id == "copied_attack":
		return _copied_attack_score(item as Dictionary, context)
	return 0.0


func _setup_priority(name: String, player: PlayerState) -> float:
	if name == REGIDRAGO_V:
		return 380.0
	if name == TEAL_MASK_OGERPON_EX:
		return 300.0 if _count_named_in_hand(player, REGIDRAGO_V) > 0 else 260.0
	if name == SQUAWKABILLY_EX:
		return 200.0
	if name == MEW_EX:
		return 170.0
	if name == FEZANDIPITI_EX:
		return 150.0
	if name == CLEFFA:
		return 120.0
	return 100.0


func _score_play_basic(card: CardInstance, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null or player.is_bench_full():
		return 0.0
	var name := _card_name(card)
	if name == REGIDRAGO_V:
		if _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) >= 2:
			return 120.0
		return 360.0
	if name == TEAL_MASK_OGERPON_EX:
		if _count_named_on_field(player, TEAL_MASK_OGERPON_EX) >= 2:
			return 140.0
		return 320.0 if phase == "early" else 220.0
	if name == SQUAWKABILLY_EX:
		return 200.0 if phase == "early" else 70.0
	if name == MEW_EX:
		return 150.0 if phase == "early" else 60.0
	if name == FEZANDIPITI_EX:
		return 120.0
	if name == CLEFFA:
		return 130.0 if phase == "early" else 60.0
	return 80.0


func _score_evolve(card: CardInstance, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	if _card_name(card) != REGIDRAGO_VSTAR:
		return 100.0
	var best_drago := _best_regidrago_slot(player)
	if best_drago != null and _attack_energy_gap(best_drago) <= 1:
		return 950.0
	return 820.0 if phase != "late" else 760.0


func _score_trainer(card: CardInstance, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name == ULTRA_BALL:
		if _dragon_fuel_count(player) < 2 and _dragon_fuel_remaining(player) > 0:
			return 580.0
		if _count_named_on_field(player, REGIDRAGO_V) > 0 and _count_named_on_field(player, REGIDRAGO_VSTAR) == 0:
			return 460.0
		return 260.0
	if name == NEST_BALL:
		if _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) == 0:
			return 480.0
		if _count_named_on_field(player, TEAL_MASK_OGERPON_EX) == 0:
			return 420.0
		return 180.0
	if name == EARTHEN_VESSEL:
		return 420.0 if _count_energy_in_hand(player, "G") == 0 or _count_energy_in_hand(player, "R") == 0 else 200.0
	if name == ENERGY_SWITCH:
		return 360.0 if _has_energy_switch_line(player) else 140.0
	if name == NIGHT_STRETCHER or name == SUPER_ROD:
		return 260.0 if _dragon_fuel_count(player) == 0 or _count_named_in_discard(player, REGIDRAGO_V) > 0 else 130.0
	if name == PRIME_CATCHER or name == BOSSS_ORDERS:
		return 240.0 if phase == "late" else 150.0
	if name == PROFESSORS_RESEARCH:
		return 220.0 if phase == "early" or player.hand.size() <= 4 else 130.0
	if name == IONO:
		return 170.0
	if name == CANCELING_COLOGNE:
		return 120.0 if phase == "late" else 60.0
	return 90.0


func _score_attach(card: CardInstance, target_slot: PokemonSlot, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var source_name := _card_name(card)
	var slot_name := _slot_name(target_slot)
	if source_name == GRASS_ENERGY:
		if slot_name == TEAL_MASK_OGERPON_EX:
			return 420.0 if phase == "early" else 240.0
		if slot_name == REGIDRAGO_VSTAR or slot_name == REGIDRAGO_V:
			return 380.0 if phase != "early" or _best_ogerpon_slot(player) == null else 260.0
	if source_name == FIRE_ENERGY:
		if slot_name == REGIDRAGO_VSTAR or slot_name == REGIDRAGO_V:
			return 360.0
		if slot_name == TEAL_MASK_OGERPON_EX:
			return 150.0
	if card.card_data.is_energy():
		if slot_name == REGIDRAGO_VSTAR or slot_name == REGIDRAGO_V:
			return 320.0
		if slot_name == TEAL_MASK_OGERPON_EX:
			return 260.0
	return 90.0


func _score_use_ability(source_slot: PokemonSlot, player: PlayerState, phase: String) -> float:
	if source_slot == null:
		return 0.0
	var name := _slot_name(source_slot)
	if name == TEAL_MASK_OGERPON_EX:
		if _count_energy_in_hand(player, "G") > 0 and _attack_energy_gap(source_slot) > 0:
			return 600.0 if phase == "early" else 420.0
		return 180.0
	if name == FEZANDIPITI_EX:
		return 140.0
	if name == MEW_EX:
		return 120.0
	return 0.0


func _score_retreat(player: PlayerState, phase: String) -> float:
	if player == null or player.active_pokemon == null:
		return 0.0
	if _best_ready_bench(player) == null:
		return 0.0
	var active_name := _slot_name(player.active_pokemon)
	if active_name == TEAL_MASK_OGERPON_EX and phase != "late":
		return 220.0
	if active_name in [SQUAWKABILLY_EX, MEW_EX, CLEFFA]:
		return 260.0
	return 90.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int, phase: String) -> float:
	var score := 520.0 + float(action.get("projected_damage", 0))
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	if defender != null and int(action.get("projected_damage", 0)) >= defender.get_remaining_hp():
		score += 320.0
	if phase == "late":
		score += 40.0
	return score


func _search_score(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		if name == GIRATINA_VSTAR:
			return 110
		if name == DRAGAPULT_EX:
			return 102
		if name == REGIDRAGO_VSTAR:
			return 98
		if name == REGIDRAGO_V:
			return 96
		if name == TEAL_MASK_OGERPON_EX:
			return 88
		return 20
	var player: PlayerState = game_state.players[player_index]
	if name == REGIDRAGO_V and _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) == 0:
		return 160
	if name == REGIDRAGO_VSTAR and _count_named_on_field(player, REGIDRAGO_V) > 0 and _count_named_on_field(player, REGIDRAGO_VSTAR) == 0:
		return 170
	if name == TEAL_MASK_OGERPON_EX and _count_named_on_field(player, TEAL_MASK_OGERPON_EX) == 0:
		return 150
	if name == GIRATINA_VSTAR and _count_named_in_discard(player, GIRATINA_VSTAR) == 0:
		return 180
	if name == DRAGAPULT_EX and _count_named_in_discard(player, DRAGAPULT_EX) == 0:
		return 160
	if name == HISUIAN_GOODRA_VSTAR and _count_named_in_discard(player, HISUIAN_GOODRA_VSTAR) == 0:
		return 144
	if name == HAXORUS and _count_named_in_discard(player, HAXORUS) == 0:
		return 138
	return 20


func _assignment_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var source_card: CardInstance = context.get("source_card", null)
	var source_name := _card_name(source_card)
	var slot_name := _slot_name(slot)
	if source_name == GRASS_ENERGY:
		if slot_name == REGIDRAGO_VSTAR or slot_name == REGIDRAGO_V:
			return 440.0
		if slot_name == TEAL_MASK_OGERPON_EX:
			return 320.0
	if source_name == FIRE_ENERGY:
		if slot_name == REGIDRAGO_VSTAR or slot_name == REGIDRAGO_V:
			return 420.0
		if slot_name == TEAL_MASK_OGERPON_EX:
			return 180.0
	if slot_name == REGIDRAGO_VSTAR or slot_name == REGIDRAGO_V:
		return 360.0
	if slot_name == TEAL_MASK_OGERPON_EX:
		return 300.0
	return 90.0


func _copied_attack_score(option: Dictionary, context: Dictionary) -> float:
	var source_card: Variant = option.get("source_card", null)
	var attack: Dictionary = option.get("attack", {})
	if not (source_card is CardInstance):
		return 0.0
	var source_name := _card_name(source_card as CardInstance)
	var attack_name := str(attack.get("name", ""))
	var attack_damage := _parse_damage(str(attack.get("damage", "")))
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	var defender: PokemonSlot = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		defender = game_state.players[1 - player_index].active_pokemon
	var score := 200.0 + float(attack_damage)
	if source_name == GIRATINA_VSTAR or attack_name == "Lost Impact":
		score = 440.0 + float(attack_damage)
		if defender != null and attack_damage >= defender.get_remaining_hp():
			score += 260.0
	if source_name == DRAGAPULT_EX or attack_name == "Phantom Dive":
		score = 500.0 + float(attack_damage)
		if game_state != null and player_index >= 0 and player_index < game_state.players.size():
			var opp_bench_count := game_state.players[1 - player_index].bench.size()
			score += float(opp_bench_count) * 45.0
	if source_name == HAXORUS:
		score = 300.0 + float(attack_damage)
		if defender != null and _has_special_energy(defender):
			score += 520.0
	if source_name == HISUIAN_GOODRA_VSTAR or attack_name == "Rolling Iron":
		score = 360.0 + float(attack_damage)
		if defender != null and attack_damage < defender.get_remaining_hp():
			score += 80.0
	return score


func _detect_phase(game_state: GameState, player: PlayerState) -> String:
	if game_state.turn_number <= 2:
		return "early"
	if _best_regidrago_slot(player) != null and _count_named_on_field(player, REGIDRAGO_VSTAR) > 0:
		return "mid"
	if _best_ready_bench(player) != null:
		return "late"
	return "early"


func _best_regidrago_slot(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var slot_name := _slot_name(slot)
		if slot_name != REGIDRAGO_V and slot_name != REGIDRAGO_VSTAR:
			continue
		var score := float(slot.attached_energy.size()) * 60.0
		if slot_name == REGIDRAGO_VSTAR:
			score += 220.0
		if slot == player.active_pokemon:
			score += 40.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_ogerpon_slot(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) == TEAL_MASK_OGERPON_EX:
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


func _dragon_fuel_count(player: PlayerState) -> int:
	return (
		_count_named_in_discard(player, GIRATINA_VSTAR)
		+ _count_named_in_discard(player, DRAGAPULT_EX)
		+ _count_named_in_discard(player, HISUIAN_GOODRA_VSTAR)
		+ _count_named_in_discard(player, HAXORUS)
	)


func _dragon_fuel_remaining(player: PlayerState) -> int:
	var total := 0
	for card: CardInstance in player.deck:
		var name := _card_name(card)
		if name in [GIRATINA_VSTAR, DRAGAPULT_EX, HISUIAN_GOODRA_VSTAR, HAXORUS]:
			total += 1
	for card: CardInstance in player.hand:
		var hand_name := _card_name(card)
		if hand_name in [GIRATINA_VSTAR, DRAGAPULT_EX, HISUIAN_GOODRA_VSTAR, HAXORUS]:
			total += 1
	return total


func _count_energy_in_hand(player: PlayerState, energy_type: String) -> int:
	var count := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.energy_provides) == energy_type:
			count += 1
	return count


func _has_energy_switch_line(player: PlayerState) -> bool:
	var ogerpon := _best_ogerpon_slot(player)
	var drago := _best_regidrago_slot(player)
	return ogerpon != null and drago != null and ogerpon.attached_energy.size() > 0 and _attack_energy_gap(drago) > 0


func _has_special_energy(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.card_type) == "Special Energy":
			return true
	return false


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
