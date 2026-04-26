class_name DeckStrategyDragapultCharizard
extends "res://scripts/ai/DeckStrategyBase.gd"


const STRATEGY_ID := "dragapult_charizard"
const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const DragapultCharizardStateEncoderScript = preload("res://scripts/ai/DragapultCharizardStateEncoder.gd")

var _value_net: RefCounted = null
var _encoder_class: GDScript = DragapultCharizardStateEncoderScript

const DREEPY := "Dreepy"
const DRAKLOAK := "Drakloak"
const DRAGAPULT_EX := "Dragapult ex"
const CHARMANDER := "Charmander"
const CHARMELEON := "Charmeleon"
const CHARIZARD_EX := "Charizard ex"
const ROTOM_V := "Rotom V"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const RADIANT_ALAKAZAM := "Radiant Alakazam"
const MANAPHY := "Manaphy"

const ARVEN := "Arven"
const IONO := "Iono"
const BOSSS_ORDERS := "Boss's Orders"
const TURO := "Professor Turo's Scenario"
const LANCE := "Lance"
const RARE_CANDY := "Rare Candy"
const TM_EVOLUTION := "Technical Machine: Evolution"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"
const SUPER_ROD := "Super Rod"
const NIGHT_STRETCHER := "Night Stretcher"
const ENERGY_SEARCH := "Energy Search"
const COUNTER_CATCHER := "Counter Catcher"
const LOST_VACUUM := "Lost Vacuum"
const UNFAIR_STAMP := "Unfair Stamp"
const FOREST_SEAL_STONE := "Forest Seal Stone"
const TEMPLE_OF_SINNOH := "Temple of Sinnoh"

const SEARCH_PRIORITY := {
	DRAGAPULT_EX: 100,
	DRAKLOAK: 92,
	DREEPY: 86,
	CHARIZARD_EX: 78,
	CHARMELEON: 68,
	CHARMANDER: 62,
	ROTOM_V: 38,
	LUMINEON_V: 30,
	FEZANDIPITI_EX: 26,
	RADIANT_ALAKAZAM: 20,
	MANAPHY: 18,
}


func get_strategy_id() -> String:
	return STRATEGY_ID


func get_signature_names() -> Array[String]:
	return [DRAGAPULT_EX, DRAKLOAK, DREEPY, CHARIZARD_EX, CHARMANDER]


func get_state_encoder_class() -> GDScript:
	return _encoder_class


func load_value_net(path: String) -> bool:
	var net := NeuralNetInferenceScript.new()
	if net.load_weights(path):
		_value_net = net
		return true
	_value_net = null
	return false


func get_value_net() -> RefCounted:
	return _value_net


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 4,
		"time_budget_ms": 1200,
		"rollouts_per_sequence": 0,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[int] = []
	for i: int in range(player.hand.size()):
		var card: CardInstance = player.hand[i]
		if card != null and card.is_basic_pokemon():
			basics.append(i)
	if basics.is_empty():
		return {}

	var active_index := basics[0]
	var best_score := -INF
	for hand_index: int in basics:
		var score: float = _opening_priority(_hand_name(player, hand_index), player)
		if score > best_score:
			best_score = score
			active_index = hand_index

	var bench_entries: Array[Dictionary] = []
	for hand_index: int in basics:
		if hand_index == active_index:
			continue
		var bench_score: float = _bench_priority(_hand_name(player, hand_index), player)
		if bench_score <= 0.0:
			continue
		bench_entries.append({
			"index": hand_index,
			"score": bench_score,
		})
	bench_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	var bench_indices: Array[int] = []
	for entry: Dictionary in bench_entries:
		if bench_indices.size() >= 5:
			break
		bench_indices.append(int(entry.get("index", -1)))
	return {
		"active_hand_index": active_index,
		"bench_hand_indices": bench_indices,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_basic_to_bench(action, game_state, player_index)
		"evolve":
			return _score_evolve(action, game_state, player_index)
		"play_trainer":
			return _score_trainer(action, game_state, player_index)
		"attach_energy":
			return _score_attach_energy(action, game_state, player_index)
		"attach_tool":
			return _score_attach_tool(action, game_state, player_index)
		"use_ability":
			return _score_use_ability(action, game_state, player_index)
		"retreat":
			return _score_retreat(action, player, game_state)
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(action, context.get("game_state", null), int(context.get("player_index", -1))) - _estimate_heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		if slot == null or slot.get_top_card() == null:
			continue
		match _slot_name(slot):
			DRAGAPULT_EX:
				score += 920.0
				if _can_slot_attack(slot):
					score += 150.0
			DRAKLOAK:
				score += 300.0
			DREEPY:
				score += 150.0
			CHARIZARD_EX:
				score += 760.0
			CHARMELEON:
				score += 240.0
			CHARMANDER:
				score += 130.0
			ROTOM_V:
				score += 90.0 if _count_name(player, DRAGAPULT_EX) == 0 else 35.0
			LUMINEON_V:
				score += 75.0
			FEZANDIPITI_EX:
				score += 120.0
			RADIANT_ALAKAZAM:
				score += 85.0
			MANAPHY:
				score += 45.0
		score += float(slot.attached_energy.size()) * 22.0
	if _count_name(player, DRAGAPULT_EX) > 0 and _count_name(player, CHARIZARD_EX) > 0:
		score += 220.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var card_data := slot.get_card_data()
	if card_data == null or card_data.attacks.is_empty():
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached := slot.attached_energy.size() + extra_context
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in card_data.attacks:
		if attached >= str(attack.get("cost", "")).length():
			can_attack = true
			best_damage = maxi(best_damage, _parse_damage_text(str(attack.get("damage", "0"))))
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if name in [DRAGAPULT_EX, DRAKLOAK, CHARIZARD_EX, CHARMELEON]:
		return 5
	if name in [DREEPY, CHARMANDER]:
		return 12
	if name in [TM_EVOLUTION, RARE_CANDY]:
		return 18
	if card.card_data.is_energy():
		return 100
	return 60


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if player.bench.size() >= 5 and name in [NEST_BALL, BUDDY_BUDDY_POFFIN]:
		return 220
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	return int(SEARCH_PRIORITY.get(_card_name(card), 20))


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if card.card_data == null:
			return 0.0
		if step_id == "stage2_card":
			return _score_stage2_card(card, context)
		if step_id == "search_cards":
			return _score_search_card(card, context)
		if step_id == "search_item":
			return _score_search_item(card, context)
		if step_id == "search_tool":
			return _score_search_tool(card, context)
		if step_id in ["search_pokemon", "bench_pokemon", "basic_pokemon", "buddy_poffin_pokemon"]:
			return _score_search_pokemon(card, context)
		if step_id in ["discard_card", "discard_cards", "discard_energy"]:
			var game_state: GameState = context.get("game_state", null)
			var player_index := int(context.get("player_index", -1))
			return float(get_discard_priority_contextual(card, game_state, player_index))
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id == "target_pokemon" and context.has("stage2_card"):
			return _score_stage2_target(slot, context)
		if step_id == "energy_assignments":
			return _score_charizard_energy_target(slot, context)
		if step_id in ["attach_energy_target", "energy_target", "assignment_target"]:
			if _is_charizard_energy_assignment_context(context):
				return _score_charizard_energy_target(slot, context)
			return _score_energy_target(slot, context)
		if step_id in ["send_out", "pivot_target", "self_switch_target"]:
			return _score_handoff_target(slot, step_id, context)
	return 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		return _score_handoff_target(item as PokemonSlot, str(step.get("id", "")), context)
	return score_interaction_target(item, step, context)


func _score_basic_to_bench(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if _should_shutdown_extra_setup(player, game_state):
		match name:
			DREEPY, CHARMANDER:
				return 20.0 if _count_name(player, name) == 0 else -10.0
			ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM, MANAPHY:
				return -20.0
		return 0.0
	match name:
		DREEPY:
			return 360.0 if _count_name(player, DREEPY) == 0 else 220.0
		CHARMANDER:
			return 340.0 if _count_name(player, CHARMANDER) == 0 else 200.0
		ROTOM_V:
			return 220.0 if _count_name(player, DRAGAPULT_EX) == 0 and _count_name(player, ROTOM_V) == 0 else 70.0
	return 60.0


func _score_evolve(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match _card_name(card):
		DRAGAPULT_EX:
			if _should_prioritize_direct_charizard_line(player, game_state, player_index):
				return 760.0 if _count_name(player, DRAGAPULT_EX) == 0 else 680.0
			return 860.0 if _count_name(player, DRAGAPULT_EX) == 0 else 740.0
		CHARIZARD_EX:
			return 900.0 if _should_prioritize_direct_charizard_line(player, game_state, player_index) else (740.0 if _count_name(player, CHARIZARD_EX) == 0 else 620.0)
		DRAKLOAK:
			return 520.0
		CHARMELEON:
			return 560.0 if _should_prioritize_direct_charizard_line(player, game_state, player_index) else 420.0
	return 120.0


func _score_trainer(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var name := _card_name(action.get("card"))
	if _should_shutdown_extra_setup(player, game_state):
		match name:
			BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL, LANCE:
				return 20.0
			ARVEN:
				return 120.0 if _deck_has(player, COUNTER_CATCHER) and _player_is_behind_in_prizes(game_state, player_index) else 40.0
			ENERGY_SEARCH:
				return 40.0 if _needs_dragapult_energy(player) else -10.0
	match name:
		ARVEN:
			return _score_arven(player, game_state, player_index)
		LANCE:
			return 360.0 if _count_name(player, DREEPY) == 0 or _count_name(player, DRAKLOAK) == 0 or _count_name(player, DRAGAPULT_EX) == 0 else 120.0
		RARE_CANDY:
			return 440.0 if (_has_hand_card(player, CHARIZARD_EX) or _deck_has(player, CHARIZARD_EX)) and _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) > 0 else 120.0
		BUDDY_BUDDY_POFFIN:
			return 340.0 if player.bench.size() < 5 and (_count_name(player, DREEPY) == 0 or _count_name(player, CHARMANDER) == 0) else 180.0
		NEST_BALL, ULTRA_BALL:
			return 260.0 if player.bench.size() < 5 else 150.0
		COUNTER_CATCHER:
			if _player_is_behind_in_prizes(game_state, player_index):
				if _can_attack_soon(player):
					return 420.0
				return 20.0 if _is_opening_setup_window(player, game_state) else 130.0
			return 10.0
		BOSSS_ORDERS:
			if _can_take_bench_prize(game_state, player_index):
				return 380.0
			if not _can_immediately_convert_gust(player):
				if not _two_lane_pressure_online(player):
					return -20.0
				if game_state != null and int(game_state.turn_number) <= 6:
					return -20.0
				if _should_suppress_opening_gust(player, game_state):
					return -20.0
				return 20.0
			if not _can_attack_soon(player) and not _two_lane_pressure_online(player):
				return -20.0
			if game_state != null and int(game_state.turn_number) <= 5:
				return 20.0
			if _should_suppress_opening_gust(player, game_state):
				return 20.0
			if _is_opening_setup_window(player, game_state) and not _can_attack_soon(player):
				return 20.0
			return 150.0
		IONO:
			return 300.0 if opponent.prizes.size() <= 3 else 120.0
		ENERGY_SEARCH:
			return 300.0 if _needs_dragapult_energy(player) else 100.0
		SUPER_ROD, NIGHT_STRETCHER:
			return 260.0 if _has_core_piece_in_discard(player) else 20.0
		TURO:
			return 240.0 if player.active_pokemon != null and _is_rule_box(player.active_pokemon) and player.active_pokemon.damage_counters >= 180 and _has_better_pivot(player) else 90.0
		TEMPLE_OF_SINNOH:
			return 100.0
		LOST_VACUUM:
			if _is_dead_lost_vacuum_action(action, game_state, player_index):
				return -80.0
			return 120.0 if game_state.stadium_card != null else 10.0
		UNFAIR_STAMP:
			return 260.0 if _player_is_behind_in_prizes(game_state, player_index) and opponent.prizes.size() <= 3 else 100.0
	return 70.0


func _score_attach_energy(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var target_slot: PokemonSlot = action.get("target_slot")
	var card: CardInstance = action.get("card")
	if target_slot == null or card == null or card.card_data == null:
		return 0.0
	var energy_type := str(card.card_data.energy_provides)
	var player: PlayerState = game_state.players[player_index]
	if energy_type == "R":
		return _fire_attach_score(target_slot, player, game_state.turn_number, game_state)
	if energy_type == "P":
		return _psychic_attach_score(target_slot, player)
	return 40.0


func _score_attach_tool(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	var target_slot: PokemonSlot = action.get("target_slot")
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	match _card_name(card):
		TM_EVOLUTION:
			var target_name := _slot_name(target_slot)
			if target_name not in [DREEPY, CHARMANDER]:
				return -40.0 if _is_late_charizard_conversion_window(game_state.players[player_index], game_state) else -20.0
			if target_slot != game_state.players[player_index].active_pokemon:
				return -20.0
			if _is_late_charizard_conversion_window(game_state.players[player_index], game_state):
				return -20.0
			if _has_tm_targets(game_state.players[player_index]):
				return 420.0
			return -20.0
		FOREST_SEAL_STONE:
			if _slot_name(target_slot) not in [ROTOM_V, LUMINEON_V]:
				return -40.0
			return 340.0 if _count_name(game_state.players[player_index], DRAGAPULT_EX) == 0 and _count_name(game_state.players[player_index], CHARIZARD_EX) == 0 else 100.0
	return 60.0


func _score_use_ability(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var source_slot: PokemonSlot = action.get("source_slot")
	if source_slot == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match _slot_name(source_slot):
		CHARIZARD_EX:
			return _score_infernal_reign_ability(player, game_state, player_index)
		DRAKLOAK:
			return 420.0
		ROTOM_V:
			if _is_late_charizard_conversion_window(player, game_state):
				return -20.0
			if _should_shutdown_extra_setup(player, game_state):
				return -20.0
			return 340.0 if _count_name(player, DRAGAPULT_EX) == 0 and player.hand.size() <= 5 else 90.0
		LUMINEON_V:
			if _should_shutdown_extra_setup(player, game_state):
				return 20.0 if not _has_supporter_in_hand(player) else -10.0
			return 280.0 if not _has_supporter_in_hand(player) else 100.0
		FEZANDIPITI_EX:
			if _should_shutdown_extra_setup(player, game_state):
				return -10.0 if player.hand.size() >= 4 else 60.0
			return 220.0 if player.hand.size() <= 3 else 100.0
	return 0.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var active := player.active_pokemon
	if active == null:
		return 0.0
	var opponent_active := game_state.players[1 - player_index].active_pokemon
	var attack_name := str(action.get("attack_name", ""))
	var projected_damage := int(action.get("projected_damage", 0))
	if projected_damage <= 0:
		projected_damage = int(predict_attacker_damage(active).get("damage", 0))
	var score := 180.0 + float(projected_damage)
	var misses_active_ko := opponent_active == null or projected_damage < opponent_active.get_remaining_hp()
	if _slot_name(active) == DRAGAPULT_EX and misses_active_ko and _should_finish_charizard_before_first_dragapult_attack(player, game_state):
		score -= 620.0
	if _slot_name(active) == DRAGAPULT_EX and _can_slot_use_attack(active, "Phantom Dive"):
		if attack_name == "Phantom Dive":
			score += 320.0
		else:
			score -= 220.0
	if opponent_active != null and projected_damage >= opponent_active.get_remaining_hp():
		score += 420.0
	if _slot_name(active) == DRAGAPULT_EX and (attack_name == "Phantom Dive" or projected_damage >= 200):
		score += 240.0
	if _slot_name(active) == CHARIZARD_EX:
		score += 160.0
		score += 20.0 * float(6 - game_state.players[1 - player_index].prizes.size())
	return score


func _score_search_item(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return float(get_search_priority(card))
	if _should_shutdown_extra_setup(player, game_state):
		match name:
			BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL:
				return 20.0
			ENERGY_SEARCH:
				return 40.0 if _needs_dragapult_energy(player) else -10.0
	match name:
		TM_EVOLUTION:
			return 560.0 if _has_tm_targets(player) else 180.0
		RARE_CANDY:
			if _should_finish_charizard_before_first_dragapult_attack(player, game_state):
				return 620.0
			return 480.0 if (_has_hand_card(player, CHARIZARD_EX) or _deck_has(player, CHARIZARD_EX)) and _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) > 0 else 120.0
		BUDDY_BUDDY_POFFIN:
			return 420.0 if _count_name(player, DREEPY) == 0 or _count_name(player, CHARMANDER) == 0 else 170.0
		ULTRA_BALL:
			return 360.0 if _count_name(player, DRAGAPULT_EX) == 0 or _count_name(player, CHARIZARD_EX) == 0 else 180.0
		NEST_BALL:
			return 320.0 if _count_name(player, DREEPY) == 0 or _count_name(player, CHARMANDER) == 0 else 150.0
		ENERGY_SEARCH:
			return 340.0 if _needs_dragapult_energy(player) else 100.0
		COUNTER_CATCHER:
			return 400.0 if game_state != null and _player_is_behind_in_prizes(game_state, player_index) else 120.0
		SUPER_ROD, NIGHT_STRETCHER:
			return 320.0 if _has_core_piece_in_discard(player) else 20.0
	return 80.0


func _score_search_card(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null:
		return float(get_search_priority(card))
	var card_type := str(card.card_data.card_type)
	match card_type:
		"Pokemon":
			return _score_search_pokemon(card, context)
		"Tool":
			return _score_search_tool(card, context)
		"Item", "Stadium":
			return _score_trainer({"card": card}, game_state, player_index)
		"Supporter":
			return _score_search_supporter(card, context)
		"Basic Energy", "Special Energy":
			return 260.0 if _needs_dragapult_energy(player) else 50.0
	return float(get_search_priority(card))


func _score_stage2_card(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	return _score_search_pokemon(card, context)


func _selected_stage2_from_context(context: Dictionary) -> CardInstance:
	var selected_raw: Variant = context.get("stage2_card", [])
	if selected_raw is Array and not (selected_raw as Array).is_empty():
		var first_item: Variant = (selected_raw as Array)[0]
		if first_item is CardInstance:
			return first_item as CardInstance
	if selected_raw is CardInstance:
		return selected_raw as CardInstance
	return null


func _score_stage2_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var selected_stage2 := _selected_stage2_from_context(context)
	if selected_stage2 == null:
		return 0.0
	var slot_name := _slot_name(slot)
	match _card_name(selected_stage2):
		DRAGAPULT_EX:
			if slot_name == DREEPY:
				return 980.0
			if slot_name == DRAKLOAK:
				return 920.0
		CHARIZARD_EX:
			if slot_name == CHARMANDER:
				return 980.0
			if slot_name == CHARMELEON:
				return 920.0
	return 0.0


func _score_search_supporter(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null:
		return 80.0
	var score := _score_trainer({"card": card}, game_state, player_index)
	if _card_name(card) == ARVEN and _count_name(player, CHARIZARD_EX) > 0 and _dragapult_lane_online(player):
		score = maxf(120.0, score - 260.0)
	return score


func _score_search_tool(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if _should_shutdown_extra_setup(player, game_state) and _card_name(card) == FOREST_SEAL_STONE:
		return 40.0
	match _card_name(card):
		TM_EVOLUTION:
			return 560.0 if _has_tm_targets(player) else 180.0
		FOREST_SEAL_STONE:
			if not _has_usable_forest_seal_target(player):
				return 20.0
			return 340.0 if _count_name(player, DRAGAPULT_EX) == 0 and _has_live_forest_seal_target(player) else 100.0
	return 90.0


func _score_search_pokemon(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return float(get_search_priority(card))
	if _should_shutdown_extra_setup(player, game_state):
		match name:
			DREEPY, CHARMANDER:
				return 80.0 if _count_name(player, name) == 0 else 10.0
			ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM, MANAPHY:
				return -20.0
	if _should_finish_charizard_before_first_dragapult_attack(player, game_state):
		if name == CHARIZARD_EX and _has_live_charizard_finish_target(player):
			return 980.0
		if name == CHARMELEON and _count_name(player, CHARMANDER) > 0 and not _has_hand_card(player, CHARIZARD_EX):
			return 820.0
	if _should_force_dragapult_opening_owner(player, game_state, player_index):
		if name == DREEPY and _count_name(player, DREEPY) == 0:
			return 940.0
		if name == DRAGAPULT_EX and _count_name(player, DRAKLOAK) > 0:
			return 900.0
		if name == CHARIZARD_EX:
			return 420.0
	var dragapult_pressure := 0
	if _count_name(player, DRAKLOAK) > 0:
		dragapult_pressure += 2
	elif _count_name(player, DREEPY) > 0:
		dragapult_pressure += 1
	if _count_name(player, DRAGAPULT_EX) > 0:
		dragapult_pressure += 3

	var charizard_pressure := 0
	if _count_name(player, CHARMELEON) > 0:
		charizard_pressure += 2
	elif _count_name(player, CHARMANDER) > 0:
		charizard_pressure += 1
	if _count_name(player, CHARIZARD_EX) > 0:
		charizard_pressure += 3

	if _should_prioritize_direct_charizard_line(player, game_state, player_index):
		if name == CHARIZARD_EX and _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) > 0:
			return 940.0
		if name == CHARMELEON and _count_name(player, CHARMANDER) > 0:
			return 760.0
		if name == CHARMANDER and _count_name(player, CHARMANDER) == 0:
			return 700.0

	if name == DRAGAPULT_EX and dragapult_pressure >= charizard_pressure and _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) > 0:
		return 860.0
	if name == CHARIZARD_EX and charizard_pressure > dragapult_pressure and _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) > 0:
		return 860.0
	if name == DRAKLOAK and _count_name(player, DREEPY) > 0:
		return 720.0
	if name == CHARMELEON and _count_name(player, CHARMANDER) > 0:
		return 650.0
	if name == DREEPY and _count_name(player, DREEPY) == 0:
		if _count_name(player, DRAKLOAK) > 0 and _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) + _count_name(player, CHARIZARD_EX) == 0:
			return 580.0
		return 620.0
	if name == CHARMANDER and _count_name(player, CHARMANDER) == 0:
		if _count_name(player, DRAKLOAK) > 0 and _count_name(player, CHARMELEON) + _count_name(player, CHARIZARD_EX) == 0:
			return 660.0
		return 600.0
	return float(get_search_priority(card))


func _score_energy_target(slot: PokemonSlot, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null:
		return 0.0
	return _psychic_attach_score(slot, player)


func _score_infernal_reign_ability(player: PlayerState, game_state: GameState, player_index: int) -> float:
	if player == null:
		return 0.0
	if _count_fire_energy_in_deck(player) == 0:
		return -20.0
	var best_target_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		best_target_score = maxf(best_target_score, _score_charizard_energy_target(slot, {
			"game_state": game_state,
			"player_index": player_index,
			"source_slot": _first_slot_named(player, CHARIZARD_EX),
		}))
	if best_target_score >= 500.0:
		return 560.0
	if best_target_score >= 320.0:
		return 500.0
	if _count_name(player, DRAGAPULT_EX) == 0:
		return 400.0
	return 260.0


func _score_charizard_energy_target(slot: PokemonSlot, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null or slot == null or slot.get_top_card() == null:
		return 0.0
	var base := _fire_attach_score(slot, player, int(game_state.turn_number) if game_state != null else 0, game_state)
	var name := _slot_name(slot)
	var live_charizard := _first_slot_named(player, CHARIZARD_EX)
	var live_charizard_gap := _attack_gap_after_pending(live_charizard, context, 0)
	var target_attack_gap_current := _attack_gap_after_pending(slot, context, 0)
	var target_attack_gap_after := _attack_gap_after_pending(slot, context, 1)
	var target_retreat_gap_after := _retreat_gap_after_pending(slot, context, 1)
	var benched_charizard := _best_benched_charizard_slot(player)
	var benched_charizard_current_gap := _attack_gap_after_pending(benched_charizard, context, 0)
	if name in [DREEPY, DRAKLOAK] and live_charizard != null and live_charizard_gap > 0:
		base = minf(base, 80.0)
	elif name == DRAGAPULT_EX and live_charizard != null and live_charizard_gap > 0 and target_attack_gap_after > 0:
		base = minf(base, 180.0)
	if slot == player.active_pokemon and _is_transition_pivot_active(slot):
		if benched_charizard != null and benched_charizard_current_gap == 0 and target_retreat_gap_after == 0:
			return maxf(base, 580.0)
		if benched_charizard != null and benched_charizard_current_gap <= 1 and target_retreat_gap_after == 0:
			return maxf(base, 220.0)
	match name:
		CHARIZARD_EX:
			if target_attack_gap_after == 0:
				return maxf(base, 620.0)
			if target_attack_gap_after == 1:
				return maxf(base, 520.0)
			if target_attack_gap_current == 0:
				return maxf(base, 160.0)
		ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, MANAPHY:
			if not (slot == player.active_pokemon and _is_transition_pivot_active(slot)):
				base = minf(base, 40.0)
	return base


func _score_send_out(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var score := float(slot.get_remaining_hp()) * 0.6 - float(_retreat_gap(slot)) * 25.0
	if _can_slot_attack(slot):
		score += 280.0
	match _slot_name(slot):
		DRAGAPULT_EX:
			score += 220.0
		CHARIZARD_EX:
			score += 180.0
		DRAKLOAK:
			score += 90.0
		ROTOM_V, LUMINEON_V:
			score -= 80.0
	return score


func _score_handoff_target(slot: PokemonSlot, step_id: String, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var base := _score_send_out(slot)
	if step_id == "send_out":
		return base
	if step_id == "self_switch_target":
		var game_state: GameState = context.get("game_state", null)
		var player_index := int(context.get("player_index", -1))
		var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
		if player == null or player.active_pokemon == null:
			return base
		if not _is_transition_pivot_active(player.active_pokemon):
			return base
		if _slot_name(slot) == DRAGAPULT_EX and _can_slot_attack(slot):
			return base + 220.0
		if _slot_name(slot) == CHARIZARD_EX and _can_slot_attack(slot):
			return base + 200.0
	return base


func _opening_priority(name: String, _player: PlayerState) -> float:
	match name:
		DREEPY:
			return 330.0
		ROTOM_V:
			return 290.0
		CHARMANDER:
			return 280.0
	return 90.0


func _bench_priority(name: String, _player: PlayerState) -> float:
	match name:
		CHARMANDER:
			return 520.0
		DREEPY:
			return 500.0
		ROTOM_V:
			return 220.0
	return 0.0


func _score_arven(player: PlayerState, game_state: GameState, player_index: int) -> float:
	var item_value := 120.0
	if _should_prioritize_direct_charizard_line(player, game_state, player_index):
		if _deck_has(player, RARE_CANDY):
			item_value = maxf(item_value, 420.0)
		if _deck_has(player, ULTRA_BALL):
			item_value = maxf(item_value, 320.0)
	if _deck_has(player, TM_EVOLUTION) and _has_tm_targets(player):
		item_value = maxf(item_value, 360.0)
	if _deck_has(player, RARE_CANDY) and (_count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) > 0):
		item_value = maxf(item_value, 280.0)
	if _deck_has(player, ENERGY_SEARCH) and _needs_dragapult_energy(player):
		item_value = maxf(item_value, 220.0)
	if _deck_has(player, COUNTER_CATCHER) and _player_is_behind_in_prizes(game_state, player_index):
		item_value = maxf(item_value, 240.0)

	var tool_value := 70.0
	if _deck_has(player, FOREST_SEAL_STONE) and _has_usable_forest_seal_target(player):
		tool_value = maxf(tool_value, 240.0)
	return maxf(item_value + tool_value, 190.0)


func _fire_attach_score(slot: PokemonSlot, player: PlayerState, turn: int, game_state: GameState = null) -> float:
	var pivot_to_charizard := _should_pivot_fire_to_charizard(player, turn)
	var late_charizard_conversion := _is_late_charizard_conversion_window(player, game_state)
	match _slot_name(slot):
		DRAGAPULT_EX:
			if pivot_to_charizard:
				return 160.0
			return 420.0
		DRAKLOAK, DREEPY:
			if late_charizard_conversion:
				return 120.0 if _attack_gap(slot) <= 1 else 80.0
			if pivot_to_charizard:
				return 120.0 if _attack_gap(slot) > 1 else 80.0
			return 380.0 if _count_name(player, CHARIZARD_EX) == 0 else 340.0
		CHARIZARD_EX:
			if late_charizard_conversion:
				return 520.0 if _attack_gap(slot) <= 1 else 420.0
			if pivot_to_charizard:
				return 500.0 if _attack_gap(slot) <= 1 else 420.0
			return 260.0 if turn >= 4 else 180.0
		CHARMELEON, CHARMANDER:
			if late_charizard_conversion:
				return 360.0
			if pivot_to_charizard:
				return 360.0
			return 220.0 if turn >= 4 else 140.0
	return 60.0


func _psychic_attach_score(slot: PokemonSlot, player: PlayerState) -> float:
	match _slot_name(slot):
		DRAGAPULT_EX:
			return 460.0
		DRAKLOAK, DREEPY:
			return 420.0 if _count_name(player, CHARIZARD_EX) == 0 else 360.0
		CHARIZARD_EX:
			return 180.0
		CHARMANDER, CHARMELEON:
			return 120.0
	return 60.0


func _score_retreat(action: Dictionary, player: PlayerState, game_state: GameState = null) -> float:
	if player.active_pokemon == null:
		return 0.0
	var active := player.active_pokemon
	var active_name := _slot_name(active)
	var target_slot: PokemonSlot = action.get("bench_target")
	if target_slot != null and target_slot.get_top_card() != null:
		var target_name := _slot_name(target_slot)
		if _is_late_charizard_conversion_window(player, game_state):
			if target_name == CHARIZARD_EX and (_can_slot_attack(target_slot) or _attack_gap(target_slot) <= 1):
				return 320.0
			if target_name in [ROTOM_V, LUMINEON_V]:
				return -40.0
			if target_name in [DREEPY, DRAKLOAK, CHARMANDER]:
				return 20.0
		if game_state != null and int(game_state.turn_number) <= 3 \
				and target_name in [ROTOM_V, LUMINEON_V, MANAPHY] \
				and not _can_slot_attack(target_slot) \
				and active_name in [DREEPY, DRAKLOAK, CHARMANDER, CHARMELEON] \
				and _attack_gap(active) <= 1:
			return -20.0
		if _can_slot_attack(target_slot):
			return 280.0 if target_name in [DRAGAPULT_EX, CHARIZARD_EX] else 220.0
	if active_name in [ROTOM_V, LUMINEON_V, MANAPHY]:
		return 220.0 if not player.bench.is_empty() else 70.0
	if not _can_slot_attack(active) and _has_better_pivot(player):
		if active_name in [DREEPY, DRAKLOAK, CHARMANDER, CHARMELEON]:
			return 240.0
		if active_name in [DRAGAPULT_EX, CHARIZARD_EX]:
			return 180.0
	return 20.0


func _needs_dragapult_energy(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) in [DREEPY, DRAKLOAK, DRAGAPULT_EX] and _attack_gap(slot) > 0:
			return true
	return false


func _dragapult_lane_online(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) == DRAGAPULT_EX and _can_slot_attack(slot):
			return true
	return false


func _two_lane_pressure_online(player: PlayerState) -> bool:
	if player == null:
		return false
	return _dragapult_lane_online(player) and _count_name(player, CHARIZARD_EX) > 0


func _should_pivot_fire_to_charizard(player: PlayerState, turn: int) -> bool:
	if player == null or not _dragapult_lane_online(player):
		return false
	if _count_name(player, CHARIZARD_EX) > 0:
		return true
	if turn < 4:
		return false
	return _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) > 0


func _should_prioritize_direct_charizard_line(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null or game_state == null:
		return false
	if _count_name(player, CHARIZARD_EX) > 0:
		return false
	if _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) == 0:
		return false
	var opponent := _opponent(game_state, player_index)
	if opponent == null or not _has_lightning_pressure(opponent):
		return false
	if _has_hand_card(player, CHARIZARD_EX):
		return true
	if int(game_state.turn_number) <= 3 and _count_name(player, DRAGAPULT_EX) == 0:
		return true
	if _player_is_behind_in_prizes(game_state, player_index):
		return true
	return _has_convertible_two_prize_bench_target(opponent)


func _should_force_dragapult_opening_owner(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null or game_state == null:
		return false
	if _count_name(player, DRAGAPULT_EX) + _count_name(player, DRAKLOAK) + _count_name(player, DREEPY) > 0:
		return false
	if _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) + _count_name(player, CHARIZARD_EX) == 0:
		return false
	if _count_name(player, CHARMELEON) > 0 or _count_name(player, CHARIZARD_EX) > 0:
		return false
	if _should_prioritize_direct_charizard_line(player, game_state, player_index):
		return false
	if _has_live_charizard_finish_target(player):
		return false
	return true


func _should_finish_charizard_before_first_dragapult_attack(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null or game_state == null:
		return false
	if int(game_state.turn_number) > 5:
		return false
	if _count_name(player, CHARIZARD_EX) > 0:
		return false
	if _count_name(player, DRAGAPULT_EX) == 0:
		return false
	if player.active_pokemon == null or _slot_name(player.active_pokemon) != DRAGAPULT_EX:
		return false
	if not _can_slot_use_attack(player.active_pokemon, "Phantom Dive"):
		return false
	return _has_live_charizard_finish_target(player)


func _has_live_charizard_finish_target(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_name(player, CHARIZARD_EX) > 0:
		return false
	if _count_name(player, CHARMELEON) > 0:
		return _has_hand_card(player, CHARIZARD_EX) or _deck_has(player, CHARIZARD_EX)
	if _count_name(player, CHARMANDER) == 0:
		return false
	if not _has_hand_card(player, RARE_CANDY):
		return false
	return _has_hand_card(player, CHARIZARD_EX) or _deck_has(player, CHARIZARD_EX)


func _count_fire_energy_in_deck(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.energy_provides) == "R":
			count += 1
	return count


func _should_suppress_opening_gust(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _can_attack_soon(player):
		return false
	if game_state == null:
		return _count_name(player, DRAGAPULT_EX) + _count_name(player, CHARIZARD_EX) == 0
	if int(game_state.turn_number) <= 5:
		return true
	return _count_name(player, DRAGAPULT_EX) + _count_name(player, CHARIZARD_EX) == 0


func _is_dead_lost_vacuum_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var targets_variant: Variant = action.get("targets", [])
	if not (targets_variant is Array) or (targets_variant as Array).is_empty():
		return game_state.stadium_card == null
	var payload_variant: Variant = (targets_variant as Array)[0]
	if not (payload_variant is Dictionary):
		return false
	var payload := payload_variant as Dictionary
	var vacuum_targets: Array = payload.get("lost_vacuum_target", [])
	var discard_cards: Array = payload.get("discard_cards", [])
	var hits_external_value := game_state.stadium_card != null and game_state.stadium_card in vacuum_targets
	var only_self_targets := not vacuum_targets.is_empty()
	for item: Variant in vacuum_targets:
		if item == game_state.stadium_card:
			continue
		if item is CardInstance and _is_player_attached_card(player, item as CardInstance):
			continue
		only_self_targets = false
		break
	if hits_external_value:
		return false
	var discarding_core_stage2 := false
	for item: Variant in discard_cards:
		if not (item is CardInstance):
			continue
		if _card_name(item as CardInstance) in [DRAGAPULT_EX, CHARIZARD_EX]:
			discarding_core_stage2 = true
			break
	if only_self_targets and discarding_core_stage2:
		return true
	if only_self_targets and not _can_attack_soon(player) and not _two_lane_pressure_online(player):
		return true
	if only_self_targets and _should_suppress_opening_gust(player, game_state):
		return true
	return false


func _should_shutdown_extra_setup(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if not _two_lane_pressure_online(player):
		return false
	if game_state != null and int(game_state.turn_number) < 5 and player.hand.size() <= 5:
		return false
	return true


func _is_opening_setup_window(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _count_name(player, DRAGAPULT_EX) > 0 or _count_name(player, CHARIZARD_EX) > 0:
		return false
	if game_state != null and int(game_state.turn_number) > 4:
		return false
	return true


func _has_tm_targets(player: PlayerState) -> bool:
	return _count_name(player, DREEPY) > 0 and _count_name(player, CHARMANDER) > 0


func _has_live_forest_seal_target(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_name(player, ROTOM_V) > 0 or _count_name(player, LUMINEON_V) > 0


func _has_usable_forest_seal_target(player: PlayerState) -> bool:
	if player == null:
		return false
	return _has_live_forest_seal_target(player) or _has_hand_card(player, ROTOM_V) or _has_hand_card(player, LUMINEON_V)


func _has_supporter_in_hand(player: PlayerState) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Supporter":
			return true
	return false


func _has_core_piece_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		var name := _card_name(card)
		if name in [DRAGAPULT_EX, DRAKLOAK, DREEPY, CHARIZARD_EX, CHARMANDER]:
			return true
	return false


func _has_better_pivot(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.bench:
		if slot != null and slot.get_top_card() != null and (_can_slot_attack(slot) or _slot_name(slot) in [DRAGAPULT_EX, CHARIZARD_EX]):
			return true
	return false


func _player_is_behind_in_prizes(game_state: GameState, player_index: int) -> bool:
	return game_state.players[player_index].prizes.size() > game_state.players[1 - player_index].prizes.size()


func _opponent(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null:
		return null
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return null
	return game_state.players[opponent_index]


func _is_player_attached_card(player: PlayerState, card: CardInstance) -> bool:
	if player == null or card == null:
		return false
	var target_name := _card_name(card)
	for slot: PokemonSlot in _all_slots(player):
		if slot == null:
			continue
		if card == slot.attached_tool:
			return true
		if slot.attached_tool != null and slot.attached_tool.instance_id == card.instance_id \
				and _card_name(slot.attached_tool) == target_name:
			return true
		for attached: CardInstance in slot.attached_energy:
			if attached == card:
				return true
			if attached != null and attached.instance_id == card.instance_id \
					and _card_name(attached) == target_name:
				return true
	return false


func _has_lightning_pressure(opponent: PlayerState) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_slots(opponent):
		if slot == null or slot.get_card_data() == null:
			continue
		if str(slot.get_card_data().energy_type) == "L" and _is_rule_box(slot):
			return true
	return false


func _has_convertible_two_prize_bench_target(opponent: PlayerState) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in opponent.bench:
		if _is_two_prize_target(slot) and slot.get_remaining_hp() <= 210:
			return true
	return false


func _is_two_prize_target(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_prize_count() >= 2


func _can_attack_soon(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _can_slot_attack(slot) or _attack_gap(slot) <= 1:
			return true
	return false


func _can_immediately_convert_gust(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _can_slot_attack(player.active_pokemon):
		return true
	if _retreat_gap(player.active_pokemon) > 0:
		return false
	for slot: PokemonSlot in player.bench:
		if slot != null and slot.get_top_card() != null and _can_slot_attack(slot):
			return true
	return false


func _can_take_bench_prize(game_state: GameState, player_index: int) -> bool:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var active := player.active_pokemon
	if active == null:
		return false
	var predicted_damage := int(predict_attacker_damage(active).get("damage", 0))
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.get_top_card() != null and predicted_damage >= slot.get_remaining_hp():
			return true
	return false


func _pending_assignment_count(slot: PokemonSlot, context: Dictionary) -> int:
	if slot == null:
		return 0
	var pending_assignment_counts: Variant = context.get("pending_assignment_counts", {})
	if not (pending_assignment_counts is Dictionary):
		return 0
	return int((pending_assignment_counts as Dictionary).get(int(slot.get_instance_id()), 0))


func _attack_gap_after_pending(slot: PokemonSlot, context: Dictionary, additional_energy: int = 0) -> int:
	if slot == null:
		return 99
	return maxi(0, _attack_gap(slot) - _pending_assignment_count(slot, context) - additional_energy)


func _is_late_charizard_conversion_window(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null or game_state == null:
		return false
	if int(game_state.turn_number) < 6:
		return false
	if _count_name(player, DRAGAPULT_EX) + _count_name(player, DRAKLOAK) + _count_name(player, DREEPY) == 0:
		return false
	var best_charizard_gap := 99
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) != CHARIZARD_EX:
			continue
		best_charizard_gap = mini(best_charizard_gap, _attack_gap(slot))
	return best_charizard_gap <= 1


func _retreat_gap_after_pending(slot: PokemonSlot, context: Dictionary, additional_energy: int = 0) -> int:
	if slot == null:
		return 99
	return maxi(0, _retreat_gap(slot) - _pending_assignment_count(slot, context) - additional_energy)


func _best_benched_charizard_slot(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best_slot: PokemonSlot = null
	var best_gap := 99
	for slot: PokemonSlot in player.bench:
		if _slot_name(slot) != CHARIZARD_EX:
			continue
		var gap := _attack_gap(slot)
		if gap < best_gap:
			best_gap = gap
			best_slot = slot
	return best_slot


func _first_slot_named(player: PlayerState, target_name: String) -> PokemonSlot:
	if player == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) == target_name:
			return slot
	return null


func _is_transition_pivot_active(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_top_card() == null:
		return false
	return _slot_name(slot) in [ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, MANAPHY]


func _is_charizard_energy_assignment_context(context: Dictionary) -> bool:
	var source_slot: Variant = context.get("source_slot", null)
	if source_slot is PokemonSlot and _slot_name(source_slot as PokemonSlot) == CHARIZARD_EX:
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


func _count_name(player: PlayerState, target_name: String) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is(slot, [target_name]):
			count += 1
	return count


func _hand_name(player: PlayerState, hand_index: int) -> String:
	if hand_index < 0 or hand_index >= player.hand.size():
		return ""
	var card: CardInstance = player.hand[hand_index]
	return _card_name(card)


func _hand_has_name(player: PlayerState, target_name: String) -> bool:
	for card: CardInstance in player.hand:
		if _card_name(card) == target_name:
			return true
	return false


func _has_hand_card(player: PlayerState, target_name: String) -> bool:
	return _hand_has_name(player, target_name)


func _deck_has(player: PlayerState, target_name: String) -> bool:
	for card: CardInstance in player.deck:
		if _card_name(card) == target_name:
			return true
	return false


func _can_slot_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		if slot.attached_energy.size() >= str(attack.get("cost", "")).length():
			return true
	return false


func _can_slot_use_attack(slot: PokemonSlot, attack_name: String) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		if str(attack.get("name", "")) != attack_name:
			continue
		if slot.attached_energy.size() >= str(attack.get("cost", "")).length():
			return true
	return false


func _attack_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	var best := 99
	for attack: Dictionary in slot.get_card_data().attacks:
		best = mini(best, maxi(0, str(attack.get("cost", "")).length() - slot.attached_energy.size()))
	return best


func _retreat_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	return maxi(0, int(slot.get_card_data().retreat_cost) - slot.attached_energy.size())


func _is_rule_box(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_card_data() != null and str(slot.get_card_data().mechanic) != ""


func _estimate_heuristic_base(kind: String) -> float:
	match kind:
		"attack", "granted_attack":
			return 500.0
		"attach_energy":
			return 220.0
		"play_trainer":
			return 110.0
		"play_basic_to_bench":
			return 180.0
		"use_ability":
			return 160.0
		"retreat":
			return 90.0
		"attach_tool":
			return 90.0
	return 10.0


func _parse_damage_text(text: String) -> int:
	var cleaned := text.replace("+", "").replace("x", "").replace("×", "").replace("脳", "").strip_edges()
	return int(cleaned) if cleaned.is_valid_int() else 0


func _card_name(card: Variant) -> String:
	if card is CardInstance:
		var instance := card as CardInstance
		if instance.card_data != null:
			return str(instance.card_data.name_en) if str(instance.card_data.name_en) != "" else str(instance.card_data.name)
	return ""
