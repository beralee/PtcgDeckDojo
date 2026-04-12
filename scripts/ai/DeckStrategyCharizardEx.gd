class_name DeckStrategyCharizardEx
extends "res://scripts/ai/DeckStrategyBase.gd"


const STRATEGY_ID := "charizard_ex"

const CHARMANDER := "Charmander"
const CHARMELEON := "Charmeleon"
const CHARIZARD_EX := "Charizard ex"
const PIDGEY := "Pidgey"
const PIDGEOT_EX := "Pidgeot ex"
const DUSKULL := "Duskull"
const DUSCLOPS := "Dusclops"
const DUSKNOIR := "Dusknoir"
const RADIANT_CHARIZARD := "Radiant Charizard"
const ROTOM_V := "Rotom V"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const MANAPHY := "Manaphy"

const ARVEN := "Arven"
const IONO := "Iono"
const BOSSS_ORDERS := "Boss's Orders"
const TURO := "Professor Turo's Scenario"
const THORTON := "Thorton"
const RARE_CANDY := "Rare Candy"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"
const NIGHT_STRETCHER := "Night Stretcher"
const SUPER_ROD := "Super Rod"
const COUNTER_CATCHER := "Counter Catcher"
const LOST_VACUUM := "Lost Vacuum"
const UNFAIR_STAMP := "Unfair Stamp"
const COLLAPSED_STADIUM := "Collapsed Stadium"
const FOREST_SEAL_STONE := "Forest Seal Stone"
const DEFIANCE_BAND := "Defiance Band"
const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"

const SEARCH_PRIORITY := {
	CHARIZARD_EX: 100,
	PIDGEOT_EX: 95,
	CHARMANDER: 88,
	PIDGEY: 82,
	DUSKNOIR: 70,
	DUSCLOPS: 62,
	DUSKULL: 56,
	RADIANT_CHARIZARD: 44,
	ROTOM_V: 36,
	LUMINEON_V: 30,
	FEZANDIPITI_EX: 24,
	MANAPHY: 18,
}


func get_strategy_id() -> String:
	return STRATEGY_ID


func get_signature_names() -> Array[String]:
	return [CHARIZARD_EX, CHARMANDER, PIDGEOT_EX, PIDGEY]


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
	var kind: String = str(action.get("kind", ""))
	match kind:
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
			return _score_retreat(player, game_state, player_index)
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
			CHARIZARD_EX:
				score += 980.0
				if _can_slot_attack(slot):
					score += 180.0
			PIDGEOT_EX:
				score += 680.0
			CHARMELEON:
				score += 280.0
			CHARMANDER:
				score += 150.0
			PIDGEY:
				score += 135.0
			DUSKNOIR:
				score += 420.0
			DUSCLOPS:
				score += 220.0
			DUSKULL:
				score += 110.0
			RADIANT_CHARIZARD:
				score += 150.0 + 40.0 * float(_opponent_prizes_taken(game_state, player_index))
			ROTOM_V:
				score += 110.0 if _count_name(player, PIDGEOT_EX) == 0 else 40.0
			LUMINEON_V:
				score += 95.0 if _count_name(player, PIDGEOT_EX) == 0 else 35.0
			FEZANDIPITI_EX:
				score += 130.0
			MANAPHY:
				score += 45.0
		score += float(slot.attached_energy.size()) * 24.0

	if _count_name(player, CHARIZARD_EX) > 0 and _count_name(player, PIDGEOT_EX) > 0:
		score += 220.0
	if _count_name(player, CHARIZARD_EX) > 0 and _count_name(player, DUSKNOIR) > 0:
		score += 110.0
	if _count_name(player, RADIANT_CHARIZARD) > 0 and _opponent_prizes_taken(game_state, player_index) >= 4:
		score += 150.0
	if opponent.active_pokemon != null and _is_two_prize_target(opponent.active_pokemon):
		score += 25.0
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.damage_counters > 0:
			score += 18.0

	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var card_data := slot.get_card_data()
	if card_data == null or card_data.attacks.is_empty():
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached := slot.attached_energy.size() + extra_context
	var name := _slot_name(slot)
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in card_data.attacks:
		var cost := str(attack.get("cost", ""))
		var damage := _parse_damage_text(str(attack.get("damage", "0")))
		if name == CHARIZARD_EX and str(attack.get("name", "")) == "Burning Darkness":
			damage = maxi(damage, 180)
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if name in [CHARIZARD_EX, PIDGEOT_EX, CHARMELEON, DUSKNOIR]:
		return 5
	if name in [CHARMANDER, PIDGEY, DUSKULL]:
		return 12
	if name in [FOREST_SEAL_STONE, RARE_CANDY]:
		return 20
	if card.card_data.is_energy():
		return 100
	if name in [ROTOM_V, LUMINEON_V]:
		return 140
	return 60


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if player.bench.size() >= 5 and name in [NEST_BALL, BUDDY_BUDDY_POFFIN]:
		return 210
	if name == PIDGEY and _count_name(player, PIDGEY) >= 1:
		return 150
	if name == DUSKULL and _count_name(player, DUSKULL) >= 1:
		return 145
	if name == RADIANT_CHARIZARD and _opponent_prizes_taken(game_state, player_index) < 3:
		return 170
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
		if step_id in ["attach_energy_target", "energy_target"]:
			return _score_manual_energy_target(slot, context)
		if step_id in ["send_out", "pivot_target"]:
			return _score_send_out_target(slot, context)
		if step_id == "bench_damage_counters":
			return _score_damage_counter_target(slot)
	return 0.0


func _score_basic_to_bench(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if name == CHARMANDER and _should_shutdown_extra_charmander_lane(player, game_state):
		return 20.0
	match name:
		CHARMANDER:
			return 360.0 if _count_name(player, CHARMANDER) == 0 else 220.0
		PIDGEY:
			return 340.0 if _count_name(player, PIDGEY) == 0 else 180.0
		DUSKULL:
			return 280.0 if _count_name(player, DUSKULL) == 0 else 150.0
		ROTOM_V:
			return 240.0 if _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, ROTOM_V) == 0 else 80.0
		LUMINEON_V:
			return 160.0 if _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, LUMINEON_V) == 0 else 60.0
		FEZANDIPITI_EX:
			return 150.0 if _count_name(player, FEZANDIPITI_EX) == 0 else 70.0
		RADIANT_CHARIZARD:
			return 120.0
	return 40.0


func _score_evolve(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match _card_name(card):
		CHARIZARD_EX:
			var score := 860.0 if _count_name(player, CHARIZARD_EX) == 0 else 720.0
			if _should_prioritize_direct_charizard_line(player, game_state, player_index):
				score += 120.0
			if _player_has_ready_stage2_target(player, CHARMANDER, CHARMELEON):
				score += 80.0
			return score
		PIDGEOT_EX:
			var pidgeot_score := 780.0 if _count_name(player, PIDGEOT_EX) == 0 else 620.0
			if _should_prioritize_direct_charizard_line(player, game_state, player_index):
				pidgeot_score -= 120.0
			return pidgeot_score
		DUSKNOIR:
			return 560.0
		DUSCLOPS:
			return 430.0
		CHARMELEON:
			return 420.0
	return 120.0


func _score_trainer(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var name := _card_name(action.get("card"))
	match name:
		RARE_CANDY:
			return _rare_candy_value(player)
		ARVEN:
			return _score_arven(player, game_state, player_index)
		BUDDY_BUDDY_POFFIN:
			if player.bench.size() >= 5:
				return 0.0
			var missing_small_basics := 0
			if _count_name(player, CHARMANDER) == 0:
				missing_small_basics += 1
			if _count_name(player, PIDGEY) == 0:
				missing_small_basics += 1
			if _count_name(player, DUSKULL) == 0:
				missing_small_basics += 1
			return 360.0 if missing_small_basics >= 2 else 240.0
		NEST_BALL:
			if _should_shutdown_extra_charmander_lane(player, game_state):
				return 60.0
			if _needs_early_rotom_setup(player, game_state):
				return 320.0
			return 300.0 if player.bench.size() < 5 and _missing_core_basic_count(player) >= 1 else 150.0
		ULTRA_BALL:
			return 320.0 if _needs_stage2_piece(player) else 190.0
		SUPER_ROD, NIGHT_STRETCHER:
			return 280.0 if _has_core_piece_in_discard(player) else 20.0
		COUNTER_CATCHER:
			if _player_is_behind_in_prizes(game_state, player_index):
				if _can_take_bench_prize(game_state, player_index):
					return 420.0
				return 100.0 if _can_attack_soon(player) else 40.0
			return 20.0
		BOSSS_ORDERS:
			if _can_take_bench_prize(game_state, player_index):
				return 460.0
			return 80.0 if _can_attack_soon(player) else 20.0
		IONO:
			if opponent.prizes.size() <= 3:
				return 330.0
			return 180.0 if player.hand.size() <= 3 else 110.0
		UNFAIR_STAMP:
			return 300.0 if _player_is_behind_in_prizes(game_state, player_index) else 100.0
		TURO:
			if player.active_pokemon != null and _is_rule_box(player.active_pokemon) and player.active_pokemon.damage_counters >= 180 and _has_better_pivot(player):
				return 300.0
			return 90.0
		THORTON:
			return 160.0 if _has_stage2_target_in_discard(player) else 60.0
		LOST_VACUUM:
			return 120.0 if game_state.stadium_card != null else 10.0
		COLLAPSED_STADIUM:
			return 220.0 if _has_bench_liability(player) else 90.0
	return 80.0


func _score_attach_energy(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var target_slot: PokemonSlot = action.get("target_slot")
	var energy_card: CardInstance = action.get("card")
	if target_slot == null or energy_card == null or energy_card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var energy_name := _card_name(energy_card)
	if energy_name == DOUBLE_TURBO_ENERGY:
		if _slot_name(target_slot) == PIDGEOT_EX:
			return 120.0
		return 40.0
	if str(energy_card.card_data.energy_provides) == "R":
		return _score_fire_attach_target(target_slot, player, game_state, player_index)
	return 40.0


func _score_attach_tool(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	var target_slot: PokemonSlot = action.get("target_slot")
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var tool_name := _card_name(card)
	var target_name := _slot_name(target_slot)
	match tool_name:
		FOREST_SEAL_STONE:
			if target_name == ROTOM_V:
				if _should_route_forest_seal_stone_to_rotom(game_state.players[player_index], game_state):
					return 520.0
				return 420.0 if _count_name(game_state.players[player_index], PIDGEOT_EX) == 0 else 160.0
			if target_name == LUMINEON_V:
				return 180.0 if _count_name(game_state.players[player_index], PIDGEOT_EX) == 0 else 120.0
			if target_name == FEZANDIPITI_EX:
				return 40.0
			return 40.0
		DEFIANCE_BAND:
			if target_name in [CHARIZARD_EX, RADIANT_CHARIZARD, DUSKNOIR]:
				return 320.0 if _player_is_behind_in_prizes(game_state, player_index) else 160.0
			return 80.0
	return 50.0


func _score_use_ability(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var source_slot: PokemonSlot = action.get("source_slot")
	if source_slot == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = _opponent(game_state, player_index)
	match _slot_name(source_slot):
		PIDGEOT_EX:
			return 560.0
		ROTOM_V:
			if _count_name(player, PIDGEOT_EX) > 0:
				if _count_name(player, CHARIZARD_EX) > 0 or player.hand.size() >= 4:
					return -20.0
				return 20.0
			if _count_name(player, PIDGEOT_EX) == 0:
				if game_state != null and int(game_state.turn_number) <= 2:
					return 340.0
				if player.hand.size() <= 5:
					return 380.0
			return 90.0
		LUMINEON_V:
			return 320.0 if not _has_supporter_in_hand(player) and _count_name(player, PIDGEOT_EX) == 0 else 120.0
		FEZANDIPITI_EX:
			return 260.0 if player.hand.size() <= 3 else 120.0
		DUSKNOIR:
			if _can_attack_soon(player) and _has_valuable_damage_counter_target(opponent):
				return 420.0
			return 150.0
		DUSCLOPS:
			if _can_attack_soon(player) and _has_valuable_damage_counter_target(opponent):
				return 280.0
			return 110.0
	return 0.0


func _score_retreat(player: PlayerState, game_state: GameState, player_index: int) -> float:
	var active := player.active_pokemon
	if active == null:
		return 0.0
	if _slot_name(active) in [ROTOM_V, LUMINEON_V, MANAPHY, PIDGEY, DUSKULL]:
		return 260.0 if _has_better_pivot(player) else 90.0
	if active.damage_counters >= 180 and _is_rule_box(active):
		return 220.0 if _has_better_pivot(player) else 90.0
	if _slot_name(active) == CHARIZARD_EX and not _can_slot_attack(active) and _has_better_pivot(player):
		return 180.0
	return 40.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var active := player.active_pokemon
	if active == null:
		return 0.0
	var opponent_active := game_state.players[1 - player_index].active_pokemon
	var projected_damage := int(action.get("projected_damage", 0))
	if projected_damage <= 0:
		projected_damage = int(predict_attacker_damage(active).get("damage", 0))
	var attack_name := str(action.get("attack_name", ""))
	var score := 180.0 + float(projected_damage)

	if opponent_active != null and projected_damage >= opponent_active.get_remaining_hp():
		score += 420.0
		if _is_two_prize_target(opponent_active):
			score += 120.0
	elif projected_damage > 0:
		score += 80.0

	match _slot_name(active):
		CHARIZARD_EX:
			if attack_name == "Burning Darkness" or attack_name == "":
				score += 220.0
			score += 30.0 * float(_opponent_prizes_taken(game_state, player_index))
			if _player_is_behind_in_prizes(game_state, player_index):
				score += 60.0
		RADIANT_CHARIZARD:
			if _opponent_prizes_taken(game_state, player_index) >= 4:
				score += 220.0
		DUSKNOIR:
			score += 100.0 if projected_damage >= 150 else 30.0
	return score


func _score_search_item(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return float(get_search_priority(card))
	var opening_shell_thin := _should_prioritize_opening_shell_over_candy(player, game_state)
	match name:
		RARE_CANDY:
			if opening_shell_thin and not _has_hand_card(player, CHARIZARD_EX):
				return 220.0
			return _rare_candy_value(player) + 320.0
		BUDDY_BUDDY_POFFIN:
			if opening_shell_thin:
				return 680.0
			return 520.0 if _missing_core_basic_count(player) >= 2 else 260.0
		ULTRA_BALL:
			return 460.0 if _needs_stage2_piece(player) else 210.0
		NEST_BALL:
			if opening_shell_thin:
				return 620.0 if _count_name(player, PIDGEY) == 0 else 560.0
			return 360.0 if _missing_core_basic_count(player) >= 1 else 180.0
		COUNTER_CATCHER:
			return 420.0 if game_state != null and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player) else 120.0
		NIGHT_STRETCHER, SUPER_ROD:
			return 360.0 if _has_core_piece_in_discard(player) else 90.0
		UNFAIR_STAMP:
			return 320.0 if game_state != null and _player_is_behind_in_prizes(game_state, player_index) else 110.0
	return 80.0


func _score_search_tool(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return 0.0
	match name:
		FOREST_SEAL_STONE:
			if _count_name(player, ROTOM_V) == 0 and _count_name(player, LUMINEON_V) == 0:
				return 90.0
			if _needs_early_rotom_setup(player, game_state):
				return 560.0
			return 520.0 if _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, ROTOM_V) + _count_name(player, LUMINEON_V) > 0 else 120.0
		DEFIANCE_BAND:
			return 360.0 if game_state != null and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player) else 160.0
	return 90.0


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
			return 40.0
	return float(get_search_priority(card))


func _score_search_supporter(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null:
		return 80.0
	var name := _card_name(card)
	var score := _score_trainer({"card": card}, game_state, player_index)
	if name == ARVEN and _count_name(player, PIDGEOT_EX) > 0:
		score -= 380.0
		score = maxf(score, 120.0)
	return score


func _score_search_pokemon(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return float(get_search_priority(card))
	if name == CHARIZARD_EX and _player_has_ready_stage2_target(player, CHARMANDER, CHARMELEON):
		return 940.0 if _should_prioritize_direct_charizard_line(player, game_state, player_index) else 860.0
	if name == PIDGEOT_EX and _count_name(player, PIDGEY) > 0 and _count_name(player, PIDGEOT_EX) == 0:
		return 720.0 if _should_prioritize_direct_charizard_line(player, game_state, player_index) else 800.0
	if name == CHARMANDER and _count_name(player, CHARMANDER) == 0:
		return 740.0
	if name == CHARMANDER and _should_shutdown_extra_charmander_lane(player, game_state):
		return 40.0
	if name == CHARMANDER and _count_name(player, CHARIZARD_EX) == 0 and _count_name(player, CHARMANDER) == 1:
		return 540.0
	if name == PIDGEY and _count_name(player, PIDGEY) == 0:
		return 700.0
	if name == DUSKNOIR and _count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) > 0:
		return 520.0
	if name == DUSKULL and _count_name(player, DUSKULL) == 0 and _has_primary_setup_established(player):
		return 500.0
	if name == ROTOM_V and _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, ROTOM_V) == 0:
		return 620.0 if _needs_early_rotom_setup(player, game_state) else 260.0
	return float(get_search_priority(card))


func _score_manual_energy_target(slot: PokemonSlot, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null:
		return 0.0
	return _score_fire_attach_target(slot, player, game_state, player_index)


func _score_send_out_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var score := float(slot.get_remaining_hp()) * 0.6 - float(_retreat_gap(slot)) * 25.0
	if _can_slot_attack(slot):
		score += 280.0
	match _slot_name(slot):
		CHARIZARD_EX:
			score += 220.0
		RADIANT_CHARIZARD:
			score += 140.0
		PIDGEOT_EX:
			score += 100.0
		ROTOM_V, LUMINEON_V, MANAPHY:
			score -= 80.0
	return score


func _score_damage_counter_target(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var score := float(slot.get_prize_count()) * 120.0
	score += float(slot.damage_counters) * 2.0
	score -= float(slot.get_remaining_hp())
	if slot.get_remaining_hp() <= 130:
		score += 180.0
	return score


func _opening_priority(name: String, player: PlayerState) -> float:
	match name:
		PIDGEY:
			return 340.0 if _hand_has_name(player, CHARMANDER) else 310.0
		ROTOM_V:
			if _hand_has_name(player, CHARMANDER) and _hand_has_name(player, PIDGEY):
				return 360.0
			return 320.0 if not _hand_has_name(player, PIDGEY) else 250.0
		CHARMANDER:
			return 280.0
		DUSKULL:
			return 210.0
		MANAPHY:
			return 120.0
		RADIANT_CHARIZARD:
			return 90.0
	return 70.0


func _bench_priority(name: String, player: PlayerState) -> float:
	match name:
		CHARMANDER:
			return 560.0 if not _hand_has_name(player, CHARMANDER) else 540.0
		PIDGEY:
			return 520.0 if not _hand_has_name(player, PIDGEY) else 500.0
		DUSKULL:
			return 430.0
		ROTOM_V:
			return 260.0
		LUMINEON_V:
			return 180.0
		FEZANDIPITI_EX:
			return 160.0
		MANAPHY:
			return 120.0
		RADIANT_CHARIZARD:
			return 100.0
	return 0.0


func _rare_candy_value(player: PlayerState) -> float:
	if (_has_hand_card(player, CHARIZARD_EX) or _deck_has(player, CHARIZARD_EX)) and _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) > 0:
		return 560.0
	if (_has_hand_card(player, PIDGEOT_EX) or _deck_has(player, PIDGEOT_EX)) and _count_name(player, PIDGEY) > 0:
		return 480.0
	if (_has_hand_card(player, DUSKNOIR) or _deck_has(player, DUSKNOIR)) and _count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) > 0:
		return 360.0
	return 160.0


func _score_arven(player: PlayerState, game_state: GameState, player_index: int) -> float:
	var item_value := 120.0
	if _deck_has(player, RARE_CANDY):
		item_value = maxf(item_value, _rare_candy_value(player) - 80.0)
	if _deck_has(player, BUDDY_BUDDY_POFFIN) and _missing_core_basic_count(player) >= 2:
		item_value = maxf(item_value, 320.0)
	if _deck_has(player, ULTRA_BALL) and _needs_stage2_piece(player):
		item_value = maxf(item_value, 280.0)
	if _deck_has(player, COUNTER_CATCHER) and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player):
		item_value = maxf(item_value, 300.0)

	var tool_value := 60.0
	if _deck_has(player, FOREST_SEAL_STONE) and _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, ROTOM_V) + _count_name(player, LUMINEON_V) + _count_name(player, FEZANDIPITI_EX) > 0:
		tool_value = maxf(tool_value, 280.0)
	if _deck_has(player, DEFIANCE_BAND) and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player):
		tool_value = maxf(tool_value, 220.0)
	return maxf(item_value + tool_value, 180.0)


func _score_fire_attach_target(target_slot: PokemonSlot, player: PlayerState, game_state: GameState, player_index: int) -> float:
	if target_slot == null or target_slot.get_top_card() == null:
		return 0.0
	var name := _slot_name(target_slot)
	var opponent_taken := _opponent_prizes_taken(game_state, player_index)
	match name:
		CHARIZARD_EX:
			if target_slot == player.active_pokemon and _attack_gap(target_slot) == 1:
				return 520.0
			return 340.0 if _count_name(player, CHARIZARD_EX) > 0 else 240.0
		CHARMELEON:
			return 360.0
		CHARMANDER:
			return 420.0 if _count_name(player, CHARIZARD_EX) == 0 else 250.0
		RADIANT_CHARIZARD:
			return 420.0 if opponent_taken >= 4 else 70.0
	return 50.0


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


func _opponent(game_state: GameState, player_index: int) -> PlayerState:
	return game_state.players[1 - player_index]


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


func _missing_core_basic_count(player: PlayerState) -> int:
	var missing := 0
	if _count_name(player, CHARMANDER) == 0:
		missing += 1
	if _count_name(player, PIDGEY) == 0:
		missing += 1
	return missing


func _has_primary_setup_established(player: PlayerState) -> bool:
	return _count_name(player, CHARMANDER) > 0 and _count_name(player, PIDGEY) > 0


func _needs_stage2_piece(player: PlayerState) -> bool:
	return _count_name(player, CHARIZARD_EX) == 0 or _count_name(player, PIDGEOT_EX) == 0


func _should_prioritize_opening_shell_over_candy(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _count_name(player, PIDGEOT_EX) > 0:
		return false
	if _count_name(player, PIDGEY) == 0:
		return true
	if _count_name(player, CHARMANDER) == 0:
		return true
	if _has_primary_setup_established(player):
		return false
	if game_state != null and int(game_state.turn_number) <= 4 and player.bench.size() <= 1:
		return true
	return false


func _should_shutdown_extra_charmander_lane(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _count_name(player, CHARIZARD_EX) == 0 or _count_name(player, PIDGEOT_EX) == 0:
		return false
	if _count_name(player, CHARMANDER) == 0:
		return false
	if game_state != null and int(game_state.turn_number) < 6:
		return false
	return true


func _needs_early_rotom_setup(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _count_name(player, PIDGEOT_EX) > 0 or _count_name(player, ROTOM_V) > 0:
		return false
	if not _has_primary_setup_established(player):
		return false
	if game_state != null and int(game_state.turn_number) > 4:
		return false
	return true


func _should_route_forest_seal_stone_to_rotom(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _count_name(player, PIDGEOT_EX) > 0 or _count_name(player, ROTOM_V) == 0:
		return false
	if not _has_primary_setup_established(player):
		return false
	if game_state != null and int(game_state.turn_number) > 4:
		return false
	return true


func _player_has_ready_stage2_target(player: PlayerState, basic_name: String, stage1_name: String) -> bool:
	return _count_name(player, basic_name) + _count_name(player, stage1_name) > 0


func _has_supporter_in_hand(player: PlayerState) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Supporter":
			return true
	return false


func _should_prioritize_direct_charizard_line(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null or game_state == null:
		return false
	if _count_name(player, CHARIZARD_EX) > 0:
		return false
	if not _player_has_ready_stage2_target(player, CHARMANDER, CHARMELEON):
		return false
	var opponent := _opponent(game_state, player_index)
	if opponent == null or not _has_lightning_pressure(opponent):
		return false
	if _player_is_behind_in_prizes(game_state, player_index):
		return true
	return _has_convertible_two_prize_bench_target(opponent)




func _has_core_piece_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		var name := _card_name(card)
		if name in [CHARIZARD_EX, CHARMANDER, PIDGEOT_EX, PIDGEY, DUSKNOIR, DUSKULL]:
			return true
	return false


func _has_stage2_target_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		var name := _card_name(card)
		if name in [CHARIZARD_EX, PIDGEOT_EX]:
			return true
	return false


func _player_is_behind_in_prizes(game_state: GameState, player_index: int) -> bool:
	return game_state.players[player_index].prizes.size() > game_state.players[1 - player_index].prizes.size()


func _opponent_prizes_taken(game_state: GameState, player_index: int) -> int:
	return 6 - game_state.players[1 - player_index].prizes.size()


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


func _can_attack_soon(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _can_slot_attack(slot) or _attack_gap(slot) <= 1:
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
		var cost_len := str(attack.get("cost", "")).length()
		best = mini(best, maxi(0, cost_len - slot.attached_energy.size()))
	return best


func _retreat_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	return maxi(0, int(slot.get_card_data().retreat_cost) - slot.attached_energy.size())


func _has_better_pivot(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if _can_slot_attack(slot) or _slot_name(slot) in [CHARIZARD_EX, PIDGEOT_EX, RADIANT_CHARIZARD]:
			return true
	return false


func _has_bench_liability(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if _slot_name(slot) in [ROTOM_V, LUMINEON_V] and slot.damage_counters == 0:
			return true
	return false


func _has_valuable_damage_counter_target(opponent: PlayerState) -> bool:
	if opponent == null:
		return false
	if opponent.active_pokemon != null and (
		opponent.active_pokemon.get_remaining_hp() <= 130 or _is_two_prize_target(opponent.active_pokemon)
	):
		return true
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.get_top_card() != null and (slot.get_remaining_hp() <= 130 or _is_two_prize_target(slot)):
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
		if slot == null or slot.get_top_card() == null:
			continue
		if _is_two_prize_target(slot) and slot.get_remaining_hp() <= 210:
			return true
	return false


func _is_rule_box(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	return str(slot.get_card_data().mechanic) != ""


func _is_two_prize_target(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_prize_count() >= 2


func _parse_damage_text(text: String) -> int:
	var cleaned := text.replace("+", "").replace("x", "").replace("×", "").replace("脳", "").strip_edges()
	return int(cleaned) if cleaned.is_valid_int() else 0


func _card_name(card: Variant) -> String:
	if card is CardInstance:
		var instance := card as CardInstance
		if instance.card_data != null:
			return str(instance.card_data.name_en) if str(instance.card_data.name_en) != "" else str(instance.card_data.name)
	return ""
