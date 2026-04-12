class_name DeckStrategyDialgaMetang
extends "res://scripts/ai/DeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const BELDUM := "Beldum"
const METANG := "Metang"
const DIALGA_V := "Origin Forme Dialga V"
const DIALGA_VSTAR := "Origin Forme Dialga VSTAR"
const RADIANT_GRENINJA := "Radiant Greninja"
const ZAMAZENTA := "Zamazenta"
const MEW_EX := "Mew ex"

const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"
const BUDDY_POFFIN := "Buddy-Buddy Poffin"
const PROFESSORS_RESEARCH := "Professor's Research"
const IONO := "Iono"
const BOSSS_ORDERS := "Boss's Orders"
const SUPER_ROD := "Super Rod"
const POKEGEAR := "Pok\u00e9gear 3.0"

const METAL_ENERGY := "Metal Energy"


func get_strategy_id() -> String:
	return "dialga_metang"


func get_signature_names() -> Array[String]:
	return [BELDUM, METANG, DIALGA_VSTAR, DIALGA_V]


func get_state_encoder_class() -> GDScript:
	return StateEncoderScript


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"time_budget_ms": 2200,
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
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_play_basic(action.get("card", null), player)
		"evolve":
			return _score_evolve(action.get("card", null), game_state, player)
		"play_trainer":
			return _score_trainer(action.get("card", null), game_state, player, player_index)
		"attach_energy":
			return _score_attach(action.get("card", null), action.get("target_slot", null), game_state, player)
		"use_ability":
			return _score_use_ability(action.get("source_slot", null), game_state, player)
		"retreat":
			return _score_retreat(game_state, player)
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index)
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
		if name == DIALGA_VSTAR:
			score += 820.0
			score += float(slot.attached_energy.size()) * 95.0
		elif name == DIALGA_V:
			score += 320.0
			score += float(slot.attached_energy.size()) * 70.0
		elif name == METANG:
			score += 440.0
		elif name == BELDUM:
			score += 180.0
		elif name == RADIANT_GRENINJA:
			score += 120.0
		elif name == ZAMAZENTA:
			score += 110.0
		score += float(slot.get_remaining_hp()) * 0.08
	score += float(_count_named_on_field(player, METANG)) * 70.0
	score += float(_count_named_in_hand(player, METAL_ENERGY)) * 12.0
	if _best_dialga_slot(player) != null and _attack_energy_gap(_best_dialga_slot(player)) <= 1:
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
	if name == BELDUM:
		return 15
	if name == METANG:
		return 10
	if name == DIALGA_V or name == DIALGA_VSTAR:
		return 18
	if card.card_data.is_energy():
		return 160
	if name == BOSSS_ORDERS:
		return 150
	if name == POKEGEAR:
		return 120
	return 80


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var priority: int = get_discard_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return priority
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if name == BELDUM and _count_named_on_field(player, BELDUM) == 0 and _count_named_on_field(player, METANG) == 0:
		return 0
	if name == DIALGA_VSTAR and _count_named_on_field(player, DIALGA_VSTAR) == 0 and _count_named_on_field(player, DIALGA_V) > 0:
		return 10
	if card.card_data.is_energy() and _count_named_in_hand(player, METAL_ENERGY) <= 2:
		return 110
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
		return _assignment_target_score(item as PokemonSlot, context.get("source_card", null))
	return 0.0


func _setup_priority(name: String, player: PlayerState) -> float:
	if name == BELDUM:
		return 360.0
	if name == DIALGA_V:
		return 320.0 if _count_named_in_hand(player, BELDUM) > 0 else 300.0
	if name == RADIANT_GRENINJA:
		return 220.0
	if name == ZAMAZENTA:
		return 180.0
	if name == MEW_EX:
		return 140.0
	return 100.0


func _score_play_basic(card: CardInstance, player: PlayerState) -> float:
	if card == null or card.card_data == null or player.is_bench_full():
		return 0.0
	var name := _card_name(card)
	if name == BELDUM:
		if _count_named_on_field(player, BELDUM) + _count_named_on_field(player, METANG) >= 2:
			return 150.0
		return 360.0
	if name == DIALGA_V:
		if _count_named_on_field(player, DIALGA_V) + _count_named_on_field(player, DIALGA_VSTAR) >= 2:
			return 120.0
		return 320.0
	if name == RADIANT_GRENINJA:
		return 230.0 if _count_named_on_field(player, RADIANT_GRENINJA) == 0 else 40.0
	if name == ZAMAZENTA:
		return 170.0 if _count_named_on_field(player, ZAMAZENTA) == 0 else 50.0
	return 80.0


func _score_evolve(card: CardInstance, game_state: GameState, player: PlayerState) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name == METANG:
		if _count_named_on_field(player, METANG) == 0:
			return 700.0
		return 560.0
	if name == DIALGA_VSTAR:
		var best_dialga := _best_dialga_slot(player)
		if best_dialga != null and _attack_energy_gap(best_dialga) <= 2:
			return 920.0
		return 780.0
	return 100.0


func _score_trainer(card: CardInstance, game_state: GameState, player: PlayerState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name == BUDDY_POFFIN:
		if _count_named_on_field(player, BELDUM) + _count_named_on_field(player, METANG) == 0:
			return 460.0
		return 180.0
	if name == NEST_BALL:
		if _count_named_on_field(player, BELDUM) + _count_named_on_field(player, METANG) == 0:
			return 420.0
		if _count_named_on_field(player, DIALGA_V) + _count_named_on_field(player, DIALGA_VSTAR) == 0:
			return 360.0
		return 180.0
	if name == ULTRA_BALL:
		if _count_named_on_field(player, DIALGA_V) + _count_named_on_field(player, DIALGA_VSTAR) == 0:
			return 520.0
		if _count_named_on_field(player, METANG) == 0 and _count_named_on_field(player, BELDUM) > 0:
			return 500.0
		if _count_named_on_field(player, DIALGA_V) > 0 and _count_named_on_field(player, DIALGA_VSTAR) == 0:
			return 460.0
		return 260.0
	if name == SUPER_ROD:
		if _count_named_in_discard(player, BELDUM) + _count_named_in_discard(player, DIALGA_V) > 0:
			return 260.0
		return 90.0
	if name == BOSSS_ORDERS:
		var active_slot := player.active_pokemon
		var opponent := game_state.players[1 - player_index].active_pokemon if game_state != null else null
		if active_slot != null and opponent != null and _best_attack_damage(active_slot) >= opponent.get_remaining_hp():
			return 600.0
		return 130.0
	if name == PROFESSORS_RESEARCH:
		return 240.0 if player.hand.size() <= 4 else 140.0
	if name == IONO:
		return 230.0 if player.hand.size() <= 3 else 150.0
	if name == POKEGEAR:
		return 140.0 if player.hand.size() <= 4 else 70.0
	return 90.0


func _score_attach(card: CardInstance, target_slot: PokemonSlot, game_state: GameState, player: PlayerState) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	if not card.card_data.is_energy():
		return 0.0
	var name := _slot_name(target_slot)
	var gap := _attack_energy_gap(target_slot)
	if name == DIALGA_VSTAR:
		if gap == 1:
			return 520.0
		if gap == 2:
			return 430.0
		return 320.0
	if name == DIALGA_V:
		if target_slot == player.active_pokemon:
			return 420.0
		return 360.0
	if name == RADIANT_GRENINJA and _count_named_in_hand(player, METAL_ENERGY) >= 1:
		return 170.0
	if name == ZAMAZENTA and _best_dialga_slot(player) == null:
		return 200.0
	if name == METANG and _best_dialga_slot(player) == null and _count_named_on_field(player, DIALGA_V) == 0:
		return 140.0
	return 70.0


func _score_use_ability(source_slot: PokemonSlot, game_state: GameState, player: PlayerState) -> float:
	if source_slot == null:
		return 0.0
	var name := _slot_name(source_slot)
	if name == METANG:
		var best_dialga := _best_dialga_slot(player)
		if best_dialga == null:
			return 220.0
		var gap := _attack_energy_gap(best_dialga)
		if gap >= 90:
			return 220.0
		if gap > 0:
			return 620.0 - float(gap) * 60.0
		return 260.0
	if name == RADIANT_GRENINJA and _count_named_in_hand(player, METAL_ENERGY) >= 1:
		return 260.0
	if name == MEW_EX:
		return 120.0
	return 0.0


func _score_retreat(game_state: GameState, player: PlayerState) -> float:
	if game_state == null or player.active_pokemon == null:
		return 0.0
	var best_bench := _best_attacking_bench(player)
	if best_bench == null:
		return 0.0
	if _slot_name(player.active_pokemon) == BELDUM and _can_attack_now(best_bench):
		return 280.0
	if _slot_name(player.active_pokemon) == METANG and _can_attack_now(best_bench):
		return 220.0
	return 80.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := 480.0 + float(action.get("projected_damage", 0))
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	if defender != null and int(action.get("projected_damage", 0)) >= defender.get_remaining_hp():
		score += 260.0
	var active := game_state.players[player_index].active_pokemon
	if active != null and _slot_name(active) == DIALGA_VSTAR and _attack_energy_gap(active) <= 0:
		score += 140.0
	return score


func _search_score(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		if name == METANG:
			return 110
		if name == DIALGA_VSTAR:
			return 100
		if name == DIALGA_V:
			return 90
		if name == BELDUM:
			return 80
		return 20
	var player: PlayerState = game_state.players[player_index]
	if name == BELDUM and _count_named_on_field(player, BELDUM) + _count_named_on_field(player, METANG) == 0:
		return 130
	if name == DIALGA_V and _count_named_on_field(player, DIALGA_V) + _count_named_on_field(player, DIALGA_VSTAR) == 0:
		return 125
	if name == DIALGA_VSTAR and _count_named_on_field(player, DIALGA_V) > 0 and _count_named_on_field(player, DIALGA_VSTAR) == 0:
		return 140
	if name == METANG and _count_named_on_field(player, BELDUM) > 0 and _count_named_on_field(player, METANG) == 0:
		return 150
	if name == RADIANT_GRENINJA and _count_named_on_field(player, RADIANT_GRENINJA) == 0:
		return 90
	if name == ZAMAZENTA and _count_named_on_field(player, ZAMAZENTA) == 0:
		return 70
	return 20


func _assignment_target_score(slot: PokemonSlot, source_card: Variant) -> float:
	if slot == null:
		return 0.0
	var source_name := _card_name(source_card) if source_card is CardInstance else ""
	var slot_name := _slot_name(slot)
	if source_name == METAL_ENERGY:
		if slot_name == DIALGA_VSTAR:
			return 420.0
		if slot_name == DIALGA_V:
			return 360.0
	if slot_name == DIALGA_VSTAR:
		return 380.0
	if slot_name == DIALGA_V:
		return 320.0
	if slot_name == ZAMAZENTA:
		return 190.0
	return 90.0


func _best_dialga_slot(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var slot_name := _slot_name(slot)
		if slot_name != DIALGA_V and slot_name != DIALGA_VSTAR:
			continue
		var score := 0.0
		if slot_name == DIALGA_VSTAR:
			score += 200.0
		score += float(slot.attached_energy.size()) * 50.0
		if slot == player.active_pokemon:
			score += 40.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_attacking_bench(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in player.bench:
		if slot != null and _can_attack_now(slot):
			return slot
	return null


func _can_attack_now(slot: PokemonSlot) -> bool:
	return slot != null and _best_attack_damage(slot) > 0 and _attack_energy_gap(slot) <= 0


func _best_attack_damage(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	var best := 0
	for attack: Dictionary in slot.get_card_data().attacks:
		best = maxi(best, _parse_damage(str(attack.get("damage", "0"))))
	return best


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	var min_gap := 99
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		min_gap = mini(min_gap, maxi(0, cost.length() - slot.attached_energy.size()))
	return min_gap


func _card_name(card: Variant) -> String:
	if not (card is CardInstance):
		return ""
	var inst := card as CardInstance
	if inst.card_data == null:
		return ""
	if str(inst.card_data.name_en) != "":
		return str(inst.card_data.name_en)
	return str(inst.card_data.name)


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


func _parse_damage(text: String) -> int:
	var digits := ""
	for i: int in text.length():
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0
