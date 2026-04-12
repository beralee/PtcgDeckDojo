class_name DeckStrategyDragapultBanette
extends "res://scripts/ai/DeckStrategyBase.gd"


const STRATEGY_ID := "dragapult_banette"

const DREEPY := "Dreepy"
const DRAKLOAK := "Drakloak"
const DRAGAPULT_EX := "Dragapult ex"
const SHUPPET := "Shuppet"
const BANETTE_EX := "Banette ex"
const MUNKIDORI := "Munkidori"
const ROTOM_V := "Rotom V"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const RADIANT_ALAKAZAM := "Radiant Alakazam"
const MANAPHY := "Manaphy"

const ARVEN := "Arven"
const SALVATORE := "Salvatore"
const IONO := "Iono"
const BOSSS_ORDERS := "Boss's Orders"
const RARE_CANDY := "Rare Candy"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"
const EARTHEN_VESSEL := "Earthen Vessel"
const COUNTER_CATCHER := "Counter Catcher"
const NIGHT_STRETCHER := "Night Stretcher"
const HYPER_AROMA := "Hyper Aroma"
const RESCUE_BOARD := "Rescue Board"
const EXP_SHARE := "Exp. Share"
const TM_DEVOLUTION := "Technical Machine: Devolution"
const FOREST_SEAL_STONE := "Forest Seal Stone"
const LEAGUE_HQ := "Pokemon League Headquarters"
const LUMINOUS_ENERGY := "Luminous Energy"

const SEARCH_PRIORITY := {
	DRAGAPULT_EX: 100,
	DRAKLOAK: 92,
	DREEPY: 86,
	BANETTE_EX: 82,
	SHUPPET: 72,
	MUNKIDORI: 54,
	ROTOM_V: 40,
	LUMINEON_V: 30,
	FEZANDIPITI_EX: 26,
	RADIANT_ALAKAZAM: 20,
	MANAPHY: 18,
}


func get_strategy_id() -> String:
	return STRATEGY_ID


func get_signature_names() -> Array[String]:
	return [DRAGAPULT_EX, DRAKLOAK, DREEPY, BANETTE_EX, SHUPPET]


func get_state_encoder_class() -> GDScript:
	return null


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


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
			return _score_evolve(action, player)
		"play_trainer":
			return _score_trainer(action, game_state, player_index)
		"attach_energy":
			return _score_attach_energy(action, game_state, player_index)
		"attach_tool":
			return _score_attach_tool(action, game_state, player_index)
		"use_ability":
			return _score_use_ability(action, game_state, player_index)
		"retreat":
			return _score_retreat(player)
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(action, context.get("game_state", null), int(context.get("player_index", -1))) - _estimate_heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		if slot == null or slot.get_top_card() == null:
			continue
		match _slot_name(slot):
			DRAGAPULT_EX:
				score += 960.0
			DRAKLOAK:
				score += 300.0
			DREEPY:
				score += 145.0
			BANETTE_EX:
				score += 540.0
				if slot == player.active_pokemon:
					score += 70.0
			SHUPPET:
				score += 140.0
			MUNKIDORI:
				score += 130.0
			ROTOM_V:
				score += 90.0 if _count_name(player, DRAGAPULT_EX) == 0 else 35.0
			LUMINEON_V:
				score += 75.0
			FEZANDIPITI_EX:
				score += 120.0
			RADIANT_ALAKAZAM:
				score += 90.0
			MANAPHY:
				score += 45.0
		score += float(slot.attached_energy.size()) * 22.0
	if _count_name(player, BANETTE_EX) > 0 and _count_name(player, DRAGAPULT_EX) > 0:
		score += 170.0
	if _count_name(player, MUNKIDORI) > 0:
		score += 80.0
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.damage_counters > 0:
			score += float(slot.damage_counters) * 1.5
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
	if name in [BANETTE_EX, DRAGAPULT_EX, DRAKLOAK]:
		return 5
	if name in [SHUPPET, DREEPY]:
		return 14
	if name in [HYPER_AROMA, SALVATORE]:
		return 20
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
	if name == LEAGUE_HQ:
		return 150
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
		if step_id == "search_item":
			return _score_search_item(card, context)
		if step_id == "search_tool":
			return _score_search_tool(card, context)
		if step_id in ["search_pokemon", "search_cards", "bench_pokemon", "basic_pokemon", "buddy_poffin_pokemon"]:
			return _score_search_pokemon(card, context)
		if step_id in ["discard_card", "discard_cards", "discard_energy"]:
			var game_state: GameState = context.get("game_state", null)
			var player_index := int(context.get("player_index", -1))
			return float(get_discard_priority_contextual(card, game_state, player_index))
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id in ["attach_energy_target", "energy_target"]:
			return _score_attach_target(slot, context)
		if step_id in ["send_out", "pivot_target"]:
			return _score_send_out(slot)
		if step_id == "bench_damage_counters":
			return _score_bench_counter_target(slot)
	return 0.0


func _score_basic_to_bench(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match _card_name(card):
		SHUPPET:
			return 380.0 if _count_name(player, SHUPPET) == 0 else 220.0
		DREEPY:
			return 360.0 if _count_name(player, DREEPY) == 0 else 210.0
		MUNKIDORI:
			return 220.0 if _count_name(player, MUNKIDORI) == 0 else 100.0
		ROTOM_V:
			return 200.0 if _count_name(player, DRAGAPULT_EX) == 0 and _count_name(player, ROTOM_V) == 0 else 70.0
	return 60.0


func _score_evolve(action: Dictionary, player: PlayerState) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	match _card_name(card):
		DRAGAPULT_EX:
			return 880.0 if _count_name(player, DRAGAPULT_EX) == 0 else 740.0
		BANETTE_EX:
			return 760.0 if _count_name(player, BANETTE_EX) == 0 else 560.0
		DRAKLOAK:
			return 520.0
	return 120.0


func _score_trainer(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var name := _card_name(action.get("card"))
	match name:
		SALVATORE:
			return 520.0 if _count_name(player, SHUPPET) > 0 and _count_name(player, BANETTE_EX) == 0 else 120.0
		ARVEN:
			return _score_arven(player, game_state, player_index)
		HYPER_AROMA:
			return 420.0 if (_count_name(player, SHUPPET) > 0 and _count_name(player, BANETTE_EX) == 0) or (_count_name(player, DREEPY) > 0 and _count_name(player, DRAGAPULT_EX) == 0) else 140.0
		RARE_CANDY:
			return 360.0 if (_has_hand_card(player, DRAGAPULT_EX) or _deck_has(player, DRAGAPULT_EX)) and _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) > 0 else 120.0
		BUDDY_BUDDY_POFFIN:
			return 360.0 if player.bench.size() < 5 and (_count_name(player, SHUPPET) == 0 or _count_name(player, DREEPY) == 0) else 180.0
		NEST_BALL, ULTRA_BALL:
			return 260.0 if player.bench.size() < 5 else 150.0
		EARTHEN_VESSEL:
			return 260.0 if _needs_energy(player) else 140.0
		COUNTER_CATCHER:
			return 420.0 if _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player) else 130.0
		BOSSS_ORDERS:
			return 380.0 if _can_take_bench_prize(game_state, player_index) else 150.0
		IONO:
			return 300.0 if opponent.prizes.size() <= 3 else 120.0
		NIGHT_STRETCHER:
			return 280.0 if _has_core_piece_in_discard(player) else 90.0
		LEAGUE_HQ:
			return 280.0 if _opponent_is_basic_heavy(game_state, player_index) else 100.0
	return 70.0


func _score_attach_energy(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var target_slot: PokemonSlot = action.get("target_slot")
	var card: CardInstance = action.get("card")
	if target_slot == null or card == null or card.card_data == null:
		return 0.0
	var energy_name := _card_name(card)
	var energy_type := str(card.card_data.energy_provides)
	if energy_name == LUMINOUS_ENERGY:
		if _slot_name(target_slot) == MUNKIDORI:
			return 420.0
		if _slot_name(target_slot) == DRAGAPULT_EX:
			return 260.0
	if energy_type == "P":
		return _psychic_attach_score(target_slot, game_state.players[player_index], game_state.turn_number)
	if energy_type == "R":
		return _dragapult_attach_score(target_slot, game_state.players[player_index])
	return 40.0


func _score_attach_tool(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	var target_slot: PokemonSlot = action.get("target_slot")
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var tool_name := _card_name(card)
	var target_name := _slot_name(target_slot)
	match tool_name:
		RESCUE_BOARD:
			if target_name in [SHUPPET, DREEPY, MANAPHY] or target_slot == game_state.players[player_index].active_pokemon:
				return 300.0
			return 140.0
		EXP_SHARE:
			if target_name in [DRAGAPULT_EX, BANETTE_EX]:
				return 260.0
			return 90.0
		TM_DEVOLUTION:
			return 240.0 if _opponent_has_evolution(game_state, player_index) else 100.0
		FOREST_SEAL_STONE:
			if target_name in [ROTOM_V, LUMINEON_V, FEZANDIPITI_EX]:
				return 340.0 if _count_name(game_state.players[player_index], DRAGAPULT_EX) == 0 else 100.0
			return 40.0
	return 60.0


func _score_use_ability(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var source_slot: PokemonSlot = action.get("source_slot")
	if source_slot == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match _slot_name(source_slot):
		DRAKLOAK:
			return 420.0
		MUNKIDORI:
			return 260.0 if _slot_has_energy_name(source_slot, LUMINOUS_ENERGY) or _slot_has_energy_type(source_slot, "D") else 80.0
		ROTOM_V:
			return 320.0 if _count_name(player, DRAGAPULT_EX) == 0 and player.hand.size() <= 5 else 90.0
		LUMINEON_V:
			return 280.0 if not _has_supporter_in_hand(player) else 110.0
		FEZANDIPITI_EX:
			return 220.0 if player.hand.size() <= 3 else 100.0
		RADIANT_ALAKAZAM:
			return 160.0
	return 0.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var active := player.active_pokemon
	if active == null:
		return 0.0
	var attack_name := str(action.get("attack_name", ""))
	var projected_damage := int(action.get("projected_damage", 0))
	if projected_damage <= 0:
		projected_damage = int(predict_attacker_damage(active).get("damage", 0))
	var score := 180.0 + float(projected_damage)
	if opponent.active_pokemon != null and projected_damage >= opponent.active_pokemon.get_remaining_hp():
		score += 420.0
	if _slot_name(active) == BANETTE_EX:
		if attack_name == "Everlasting Darkness":
			score += 320.0 if game_state.turn_number <= 2 else 220.0
		if attack_name == "Poltergeist":
			score += 140.0 if projected_damage >= 180 else 60.0
	if _slot_name(active) == DRAGAPULT_EX and (attack_name == "Phantom Dive" or projected_damage >= 200):
		score += 240.0
		if _opponent_has_damage_counters(opponent):
			score += 80.0
	return score


func _score_search_item(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return float(get_search_priority(card))
	match name:
		HYPER_AROMA:
			return 520.0 if _count_name(player, SHUPPET) > 0 or _count_name(player, DREEPY) > 0 else 150.0
		BUDDY_BUDDY_POFFIN:
			return 460.0 if _count_name(player, SHUPPET) == 0 or _count_name(player, DREEPY) == 0 else 180.0
		NEST_BALL:
			return 320.0 if _count_name(player, SHUPPET) == 0 or _count_name(player, DREEPY) == 0 else 150.0
		ULTRA_BALL:
			return 360.0 if _count_name(player, DRAGAPULT_EX) == 0 or _count_name(player, BANETTE_EX) == 0 else 180.0
		EARTHEN_VESSEL:
			return 320.0 if _needs_energy(player) else 140.0
		COUNTER_CATCHER:
			return 400.0 if game_state != null and _player_is_behind_in_prizes(game_state, player_index) else 120.0
		NIGHT_STRETCHER:
			return 320.0 if _has_core_piece_in_discard(player) else 90.0
	return 80.0


func _score_search_tool(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	match name:
		RESCUE_BOARD:
			return 320.0 if player.active_pokemon != null and _slot_name(player.active_pokemon) in [SHUPPET, DREEPY, MANAPHY] else 170.0
		EXP_SHARE:
			return 260.0 if _count_name(player, BANETTE_EX) > 0 or _count_name(player, DRAGAPULT_EX) > 0 else 100.0
		TM_DEVOLUTION:
			return 250.0 if _opponent_has_evolution(game_state, player_index) else 100.0
		FOREST_SEAL_STONE:
			return 340.0 if _count_name(player, DRAGAPULT_EX) == 0 and _count_name(player, ROTOM_V) + _count_name(player, LUMINEON_V) + _count_name(player, FEZANDIPITI_EX) > 0 else 100.0
	return 90.0


func _score_search_pokemon(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return float(get_search_priority(card))
	if name == BANETTE_EX and _count_name(player, SHUPPET) > 0 and _count_name(player, BANETTE_EX) == 0:
		return 860.0
	if name == SHUPPET and _count_name(player, SHUPPET) == 0:
		return 700.0
	if name == DRAGAPULT_EX and _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) > 0:
		return 820.0
	if name == DRAKLOAK and _count_name(player, DREEPY) > 0:
		return 720.0
	if name == DREEPY and _count_name(player, DREEPY) == 0:
		return 660.0
	if name == MUNKIDORI and _count_name(player, MUNKIDORI) == 0:
		return 300.0
	return float(get_search_priority(card))


func _score_attach_target(slot: PokemonSlot, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null:
		return 0.0
	var luminous_ready := false
	if context.has("card") and context.get("card") is CardInstance:
		luminous_ready = _card_name(context.get("card")) == LUMINOUS_ENERGY
	if luminous_ready and _slot_name(slot) == MUNKIDORI:
		return 420.0
	if _slot_name(slot) in [BANETTE_EX, SHUPPET]:
		return 380.0 if game_state.turn_number <= 2 else 220.0
	if _slot_name(slot) in [DRAGAPULT_EX, DRAKLOAK, DREEPY]:
		return 340.0 if _count_name(player, BANETTE_EX) > 0 else 380.0
	return 60.0


func _score_send_out(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var score := float(slot.get_remaining_hp()) * 0.6 - float(_retreat_gap(slot)) * 25.0
	if _can_slot_attack(slot):
		score += 280.0
	match _slot_name(slot):
		BANETTE_EX:
			score += 200.0
		DRAGAPULT_EX:
			score += 220.0
		DRAKLOAK:
			score += 90.0
		ROTOM_V, LUMINEON_V:
			score -= 80.0
	return score


func _score_bench_counter_target(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var score := float(slot.get_prize_count()) * 120.0
	score += float(slot.damage_counters) * 2.0
	if slot.get_remaining_hp() <= 60:
		score += 180.0
	score -= float(slot.get_remaining_hp())
	return score


func _opening_priority(name: String, player: PlayerState) -> float:
	match name:
		SHUPPET:
			return 360.0 if _hand_has_name(player, SALVATORE) else 330.0
		DREEPY:
			return 310.0
		ROTOM_V:
			return 250.0
		MUNKIDORI:
			return 170.0
	return 90.0


func _bench_priority(name: String, _player: PlayerState) -> float:
	match name:
		DREEPY:
			return 520.0
		SHUPPET:
			return 500.0
		MUNKIDORI:
			return 240.0
		ROTOM_V:
			return 220.0
		MANAPHY:
			return 120.0
	return 0.0


func _score_arven(player: PlayerState, game_state: GameState, player_index: int) -> float:
	var item_value := 120.0
	if _deck_has(player, HYPER_AROMA):
		item_value = maxf(item_value, 320.0)
	if _deck_has(player, BUDDY_BUDDY_POFFIN) and (_count_name(player, SHUPPET) == 0 or _count_name(player, DREEPY) == 0):
		item_value = maxf(item_value, 260.0)
	if _deck_has(player, EARTHEN_VESSEL) and _needs_energy(player):
		item_value = maxf(item_value, 220.0)
	if _deck_has(player, COUNTER_CATCHER) and _player_is_behind_in_prizes(game_state, player_index):
		item_value = maxf(item_value, 250.0)

	var tool_value := 70.0
	if _deck_has(player, RESCUE_BOARD):
		tool_value = maxf(tool_value, 210.0)
	if _deck_has(player, EXP_SHARE):
		tool_value = maxf(tool_value, 160.0)
	if _deck_has(player, TM_DEVOLUTION) and _opponent_has_evolution(game_state, player_index):
		tool_value = maxf(tool_value, 220.0)
	return maxf(item_value + tool_value, 200.0)


func _needs_energy(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) in [SHUPPET, BANETTE_EX, DREEPY, DRAKLOAK, DRAGAPULT_EX] and _attack_gap(slot) > 0:
			return true
	return false


func _psychic_attach_score(slot: PokemonSlot, player: PlayerState, turn: int) -> float:
	match _slot_name(slot):
		BANETTE_EX:
			return 460.0 if turn <= 2 else 260.0
		SHUPPET:
			return 420.0 if turn <= 2 else 220.0
		DRAGAPULT_EX:
			return 340.0
		DRAKLOAK, DREEPY:
			return 300.0 if _count_name(player, BANETTE_EX) > 0 else 360.0
	return 60.0


func _dragapult_attach_score(slot: PokemonSlot, player: PlayerState) -> float:
	match _slot_name(slot):
		DRAGAPULT_EX:
			return 400.0
		DRAKLOAK, DREEPY:
			return 360.0 if _count_name(player, BANETTE_EX) > 0 else 400.0
	return 40.0


func _score_retreat(player: PlayerState) -> float:
	if player.active_pokemon == null:
		return 0.0
	if _slot_name(player.active_pokemon) in [ROTOM_V, LUMINEON_V, MANAPHY]:
		return 220.0 if not player.bench.is_empty() else 70.0
	return 70.0


func _has_supporter_in_hand(player: PlayerState) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Supporter":
			return true
	return false


func _has_core_piece_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		var name := _card_name(card)
		if name in [DRAGAPULT_EX, DRAKLOAK, DREEPY, BANETTE_EX, SHUPPET]:
			return true
	return false


func _player_is_behind_in_prizes(game_state: GameState, player_index: int) -> bool:
	return game_state.players[player_index].prizes.size() > game_state.players[1 - player_index].prizes.size()


func _can_attack_soon(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _can_slot_attack(slot) or _attack_gap(slot) <= 1:
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


func _opponent_is_basic_heavy(game_state: GameState, player_index: int) -> bool:
	var opponent: PlayerState = game_state.players[1 - player_index]
	var basics := 0
	var evolved := 0
	for slot: PokemonSlot in _all_slots(opponent):
		if slot == null or slot.get_card_data() == null:
			continue
		if str(slot.get_card_data().stage) == "Basic":
			basics += 1
		else:
			evolved += 1
	return basics > evolved


func _opponent_has_damage_counters(opponent: PlayerState) -> bool:
	if opponent.active_pokemon != null and opponent.active_pokemon.damage_counters > 0:
		return true
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.damage_counters > 0:
			return true
	return false


func _opponent_has_evolution(game_state: GameState, player_index: int) -> bool:
	var opponent: PlayerState = game_state.players[1 - player_index]
	for slot: PokemonSlot in _all_slots(opponent):
		if slot != null and slot.get_card_data() != null and str(slot.get_card_data().stage) != "Basic":
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


func _slot_has_energy_name(slot: PokemonSlot, energy_name: String) -> bool:
	for card: CardInstance in slot.attached_energy:
		if _card_name(card) == energy_name:
			return true
	return false


func _slot_has_energy_type(slot: PokemonSlot, energy_type: String) -> bool:
	for card: CardInstance in slot.attached_energy:
		if card != null and card.card_data != null and str(card.card_data.energy_provides) == energy_type:
			return true
	return false


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
