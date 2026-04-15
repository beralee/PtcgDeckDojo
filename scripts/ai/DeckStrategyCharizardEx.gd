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
		"play_stadium":
			return _score_stadium_play(action, game_state, player_index)
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
			return _score_retreat(action, player, game_state, player_index)
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(action, context.get("game_state", null), int(context.get("player_index", -1))) - _estimate_heuristic_base(str(action.get("kind", "")))


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id == "send_out":
			return _score_send_out_handoff_target(slot, context)
		if step_id == "self_switch_target":
			return _score_attack_owner_handoff_target(slot, context)
	return score_interaction_target(item, step, context)


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
	if name == ULTRA_BALL and _is_ultra_ball_opening_combo_window(player, game_state, card):
		return 25
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


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", ""))
	if step_id != "buddy_poffin_pokemon":
		return []
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null or items.is_empty():
		return []
	var card_items: Array[CardInstance] = []
	for item: Variant in items:
		if item is CardInstance:
			card_items.append(item as CardInstance)
	if card_items.is_empty():
		return []
	return _pick_buddy_poffin_targets(card_items, player, int(step.get("max_select", 2)), game_state)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if card.card_data == null:
			return 0.0
		if step_id == "supporter_card":
			return _score_search_supporter(card, context)
		if step_id == "stage2_card":
			return _score_search_pokemon(card, context)
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
			return _score_rare_candy_target(slot, context)
		if step_id in ["attach_energy_target", "energy_target", "assignment_target", "energy_assignments"]:
			return _score_manual_energy_target(slot, context)
		if step_id in ["send_out", "pivot_target"]:
			return _score_send_out_target(slot, context)
		if step_id == "bench_damage_counters":
			return _score_damage_counter_target(slot)
		if step_id == "self_ko_target":
			return _score_dusknoir_target(slot, context)
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
			if _should_defer_duskull_lane(player, game_state):
				return 90.0 if _count_name(player, DUSKULL) == 0 else 30.0
			return 220.0 if _count_name(player, DUSKULL) == 0 else 120.0
		ROTOM_V:
			if _is_combo_core_online(player):
				return 10.0
			return 240.0 if _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, ROTOM_V) == 0 else 80.0
		LUMINEON_V:
			if _should_shutdown_late_setup_trainers(player, game_state):
				return -20.0
			if _is_combo_core_online(player):
				return 10.0
			return 160.0 if _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, LUMINEON_V) == 0 else 60.0
		FEZANDIPITI_EX:
			if _is_combo_core_online(player):
				return 10.0
			return 150.0 if _count_name(player, FEZANDIPITI_EX) == 0 else 70.0
		RADIANT_CHARIZARD:
			if game_state != null and _opponent_prizes_taken(game_state, player_index) >= 4:
				return 240.0
			return 10.0
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
			if _should_suppress_dusk_lane_actions(player, game_state, player_index):
				return 40.0
			return 560.0
		DUSCLOPS:
			if _should_suppress_dusk_lane_actions(player, game_state, player_index):
				return 30.0
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
			return _rare_candy_value(player, game_state, player_index)
		ARVEN:
			return _score_arven(player, game_state, player_index)
		BUDDY_BUDDY_POFFIN:
			var live_poffin_shell_targets := _count_live_poffin_shell_targets(player, game_state)
			if live_poffin_shell_targets == 0 and (_should_defer_duskull_lane(player, game_state) or _is_combo_core_online(player)):
				return -40.0
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
			if _is_ultra_ball_opening_combo_window(player, game_state, action.get("card")):
				return 620.0
			return 320.0 if _needs_stage2_piece(player) else 190.0
		SUPER_ROD, NIGHT_STRETCHER:
			if _is_combo_core_online(player) and _has_only_deferred_dusk_recovery_targets(player):
				return 20.0
			return 280.0 if _has_core_piece_in_discard(player) else 20.0
		COUNTER_CATCHER:
			if _player_is_behind_in_prizes(game_state, player_index):
				if _can_take_bench_prize(game_state, player_index):
					return 420.0
				return 40.0 if _can_attack_soon(player) else 20.0
			return 20.0
		BOSSS_ORDERS:
			if _can_take_bench_prize(game_state, player_index):
				return 460.0
			return 20.0
		IONO:
			if opponent.prizes.size() <= 3:
				return 330.0
			return 180.0 if player.hand.size() <= 3 else 110.0
		UNFAIR_STAMP:
			return 300.0 if _player_is_behind_in_prizes(game_state, player_index) else 100.0
		TURO:
			if player.active_pokemon == null or player.active_pokemon.get_top_card() == null:
				return 0.0
			var active_name := _slot_name(player.active_pokemon)
			if _is_rule_box(player.active_pokemon) and player.active_pokemon.damage_counters >= 180 and _has_better_pivot(player):
				return 300.0
			if active_name in [ROTOM_V, LUMINEON_V, FEZANDIPITI_EX] and _is_combo_core_online(player) and _has_better_pivot(player):
				return 220.0
			return 0.0
		THORTON:
			return 160.0 if _has_stage2_target_in_discard(player) else 0.0
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
	var player: PlayerState = game_state.players[player_index]
	var tool_name := _card_name(card)
	var target_name := _slot_name(target_slot)
	match tool_name:
		FOREST_SEAL_STONE:
			if target_name not in [ROTOM_V, LUMINEON_V]:
				return -40.0
			if target_name == ROTOM_V:
				if _should_route_forest_seal_stone_to_rotom(player, game_state):
					return 520.0
				return 420.0 if _count_name(player, PIDGEOT_EX) == 0 else 160.0
			if target_name == LUMINEON_V:
				return 180.0 if _count_name(player, PIDGEOT_EX) == 0 else 120.0
			return -40.0
		DEFIANCE_BAND:
			if target_name in [CHARIZARD_EX, RADIANT_CHARIZARD, DUSKNOIR]:
				if _can_slot_attack(target_slot) or _can_attack_soon(player):
					return 320.0 if _player_is_behind_in_prizes(game_state, player_index) else 160.0
				return 20.0
			return -20.0
	return 50.0


func _score_stadium_play(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var name := _card_name(action.get("card"))
	match name:
		COLLAPSED_STADIUM:
			var score := 10.0
			if _has_bench_liability(player):
				score += 160.0
			if opponent != null and opponent.bench.size() >= 5:
				score += 40.0
			elif opponent != null and opponent.bench.size() >= 4 and _has_bench_liability(player):
				score += 20.0
			if game_state.stadium_card != null:
				score += 40.0
			return score
	return _score_trainer(action, game_state, player_index)


func _score_use_ability(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var source_slot: PokemonSlot = action.get("source_slot")
	var ability_index := int(action.get("ability_index", 0))
	if source_slot == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = _opponent(game_state, player_index)
	if _is_forest_seal_stone_ability(source_slot, ability_index):
		return _score_forest_seal_stone_ability(player, game_state, player_index)
	match _slot_name(source_slot):
		CHARIZARD_EX:
			return _score_infernal_reign_ability(player, game_state, player_index)
		PIDGEOT_EX:
			if _should_shut_off_quick_search(player, game_state, player_index):
				return 20.0
			return 560.0
		ROTOM_V:
			if _should_shut_off_rotom_draw(player, game_state):
				if player.hand.size() >= 2:
					return -120.0
				return -60.0
			if _count_name(player, PIDGEOT_EX) > 0:
				if _count_name(player, CHARIZARD_EX) > 0:
					return -60.0 if player.hand.size() >= 2 else -20.0
				if player.hand.size() >= 4:
					return -20.0
				return 10.0
			if _count_name(player, PIDGEOT_EX) == 0:
				if game_state != null and int(game_state.turn_number) <= 2:
					return 340.0
				if player.hand.size() <= 5:
					return 380.0
			return 90.0
		LUMINEON_V:
			return 320.0 if not _has_supporter_in_hand(player) and _count_name(player, PIDGEOT_EX) == 0 else 120.0
		FEZANDIPITI_EX:
			if _is_combo_core_online(player):
				return -60.0 if player.hand.size() >= 2 else -20.0
			return 260.0 if player.hand.size() <= 3 else 120.0
		DUSKNOIR:
			if _should_suppress_dusk_lane_actions(player, game_state, player_index):
				return -40.0 if not _has_dusknoir_conversion_target(game_state, player_index) else 240.0
			if _has_dusknoir_conversion_target(game_state, player_index):
				return 420.0
			return -20.0
		DUSCLOPS:
			if _should_suppress_dusk_lane_actions(player, game_state, player_index):
				return -20.0 if not _has_dusknoir_conversion_target(game_state, player_index) else 180.0
			if _has_dusknoir_conversion_target(game_state, player_index):
				return 280.0
			return -10.0
	return 0.0


func _score_retreat(action: Dictionary, player: PlayerState, game_state: GameState, player_index: int) -> float:
	var active := player.active_pokemon
	if active == null:
		return 0.0
	var target_slot: PokemonSlot = action.get("bench_target")
	if _should_block_opening_shell_retreat(active, target_slot, player, game_state):
		return -40.0
	if target_slot != null and target_slot.get_top_card() != null:
		var target_name := _slot_name(target_slot)
		if target_name == CHARIZARD_EX and _can_slot_attack(target_slot):
			if _is_transition_pivot_active(active) and _retreat_gap(active) <= 0:
				var convert_score := 620.0
				var opponent_active := game_state.players[1 - player_index].active_pokemon
				if opponent_active != null and int(predict_attacker_damage(target_slot).get("damage", 0)) >= opponent_active.get_remaining_hp():
					convert_score += 120.0
				return convert_score
			return 440.0
		if _can_slot_attack(target_slot):
			return 320.0
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
	var combo_missing := _missing_opening_combo_piece_count(player)
	match name:
		RARE_CANDY:
			if opening_shell_thin and not _has_hand_card(player, CHARIZARD_EX):
				return 220.0
			return _rare_candy_value(player, game_state, player_index) + 320.0
		BUDDY_BUDDY_POFFIN:
			if _needs_early_rotom_setup(player, game_state):
				return 420.0
			if combo_missing >= 2:
				return 700.0
			if opening_shell_thin:
				return 680.0
			return 520.0 if _missing_core_basic_count(player) >= 2 else 260.0
		ULTRA_BALL:
			return 460.0 if _needs_stage2_piece(player) else 210.0
		NEST_BALL:
			if _needs_early_rotom_setup(player, game_state):
				return 760.0
			if combo_missing >= 1 and _count_name(player, PIDGEOT_EX) == 0:
				return 640.0 if _count_name(player, ROTOM_V) == 0 else 610.0
			if opening_shell_thin:
				return 620.0 if _count_name(player, PIDGEY) == 0 else 560.0
			return 360.0 if _missing_core_basic_count(player) >= 1 else 180.0
		COUNTER_CATCHER:
			return 420.0 if game_state != null and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player) else 120.0
		NIGHT_STRETCHER, SUPER_ROD:
			if _is_combo_core_online(player) and _has_only_deferred_dusk_recovery_targets(player):
				return 90.0
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
			if not _has_live_forest_seal_target(player):
				return 20.0
			if _needs_early_rotom_setup(player, game_state):
				return 560.0
			return 520.0 if _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, ROTOM_V) + _count_name(player, LUMINEON_V) > 0 else 120.0
		DEFIANCE_BAND:
			return 360.0 if game_state != null and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player) else 20.0
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


func _score_rare_candy_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var selected_stage2: CardInstance = _selected_stage2_from_context(context)
	var slot_name := _slot_name(slot)
	if selected_stage2 == null:
		if slot_name == CHARMANDER:
			return 220.0
		if slot_name == PIDGEY:
			return 200.0
		if slot_name == DUSKULL:
			return 80.0
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	match _card_name(selected_stage2):
		CHARIZARD_EX:
			return 980.0 if slot_name == CHARMANDER else 0.0
		PIDGEOT_EX:
			return 920.0 if slot_name == PIDGEY else 0.0
		DUSKNOIR:
			return 260.0 if slot_name == DUSKULL and not _should_suppress_dusk_lane_actions(player, game_state, player_index) else 0.0
	return 0.0


func _selected_stage2_from_context(context: Dictionary) -> CardInstance:
	var selected_raw: Variant = context.get("stage2_card", [])
	if selected_raw is Array and not (selected_raw as Array).is_empty():
		var first_item: Variant = (selected_raw as Array)[0]
		if first_item is CardInstance:
			return first_item as CardInstance
	return null


func _score_search_pokemon(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return float(get_search_priority(card))
	var defer_charizard_stage2 := _should_defer_charizard_stage2_search(player, game_state, player_index)
	if name == CHARIZARD_EX and _player_has_ready_stage2_target(player, CHARMANDER, CHARMELEON):
		if defer_charizard_stage2:
			return 380.0
		return 940.0 if _should_prioritize_direct_charizard_line(player, game_state, player_index) else 860.0
	if name == PIDGEOT_EX and _count_name(player, PIDGEY) > 0 and _count_name(player, PIDGEOT_EX) == 0:
		return 720.0 if _should_prioritize_direct_charizard_line(player, game_state, player_index) else 800.0
	if name == CHARMANDER and _count_name(player, CHARMANDER) == 0:
		return 740.0
	if name == CHARMANDER and _should_shutdown_extra_charmander_lane(player, game_state):
		return 40.0
	if name == CHARMANDER and _needs_second_charmander_for_combo(player, game_state):
		return 700.0
	if name == CHARMANDER and _count_name(player, CHARIZARD_EX) == 0 and _count_name(player, CHARMANDER) == 1:
		return 540.0
	if name == PIDGEY and _count_name(player, PIDGEY) == 0:
		if game_state != null and int(game_state.turn_number) <= 4:
			if _count_name(player, CHARMANDER) == 0:
				return 820.0
			return 780.0
		return 700.0
	if name == DUSKNOIR and _count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) > 0:
		return 520.0
	if name == DUSKULL and _count_name(player, DUSKULL) == 0 and _has_primary_setup_established(player):
		if _should_defer_duskull_lane(player, game_state):
			return 120.0
		return 500.0
	if name == LUMINEON_V and _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, LUMINEON_V) == 0:
		if not _has_supporter_in_hand(player) and _deck_has(player, ARVEN):
			if _has_primary_setup_established(player) and game_state != null and int(game_state.turn_number) <= 5:
				return 340.0
			return 260.0
	if name == ROTOM_V and _count_name(player, PIDGEOT_EX) == 0 and _count_name(player, ROTOM_V) == 0:
		return 620.0 if _needs_early_rotom_setup(player, game_state) else 260.0
	return float(get_search_priority(card))


func _score_manual_energy_target(slot: PokemonSlot, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null:
		return 0.0
	var source_card: Variant = context.get("source_card", null)
	if source_card is CardInstance:
		var source_instance := source_card as CardInstance
		if source_instance.card_data != null and str(source_instance.card_data.energy_provides) == "R":
			return _score_fire_attach_target(slot, player, game_state, player_index, context)
	return _score_fire_attach_target(slot, player, game_state, player_index, context)


func _score_infernal_reign_ability(player: PlayerState, game_state: GameState, player_index: int) -> float:
	if player == null:
		return 0.0
	if _count_fire_energy_in_deck(player) == 0:
		return -20.0
	var best_target_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		best_target_score = maxf(best_target_score, _score_fire_attach_target(slot, player, game_state, player_index))
	if best_target_score >= 500.0:
		return 560.0
	if best_target_score >= 300.0:
		return 500.0
	if _count_name(player, PIDGEOT_EX) == 0:
		return 380.0
	return 240.0


func _score_send_out_handoff_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null or not _is_opening_rotom_send_out_window(player, game_state):
		return 0.0
	var score := 0.0
	match _slot_name(slot):
		ROTOM_V:
			score = 900.0
		CHARMANDER:
			score = 180.0
		PIDGEY:
			score = 150.0
		DUSKULL:
			score = 60.0
	return score


func _score_attack_owner_handoff_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null:
		return 0.0
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return 0.0
	if _slot_name(active) not in [ROTOM_V, LUMINEON_V, FEZANDIPITI_EX]:
		return 0.0
	if _slot_name(slot) == CHARIZARD_EX and _can_slot_attack(slot):
		var score := _score_send_out_target(slot, context)
		score += 220.0
		return score
	return 0.0


func _score_handoff_target(slot: PokemonSlot, step_id: String, context: Dictionary) -> float:
	if step_id == "send_out":
		return _score_send_out_handoff_target(slot, context)
	if step_id == "self_switch_target":
		return _score_attack_owner_handoff_target(slot, context)
	return 0.0


func _score_send_out_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var name := _slot_name(slot)
	var score := float(slot.get_remaining_hp()) * 0.6 - float(_retreat_gap(slot)) * 25.0
	if _can_slot_attack(slot):
		score += 280.0
	match name:
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
			return 120.0
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
			return 150.0
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


func _rare_candy_value(player: PlayerState, game_state: GameState = null, player_index: int = -1) -> float:
	if (_has_hand_card(player, CHARIZARD_EX) or _deck_has(player, CHARIZARD_EX)) and _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) > 0:
		return 560.0
	if (_has_hand_card(player, PIDGEOT_EX) or _deck_has(player, PIDGEOT_EX)) and _count_name(player, PIDGEY) > 0:
		return 480.0
	if (_has_hand_card(player, DUSKNOIR) or _deck_has(player, DUSKNOIR)) and _count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) > 0:
		if _should_suppress_dusk_lane_actions(player, game_state, player_index):
			return 60.0
		return 360.0
	return 160.0


func _score_arven(player: PlayerState, game_state: GameState, player_index: int) -> float:
	var item_value := 120.0
	var combo_missing := _missing_opening_combo_piece_count(player)
	var late_setup_shutdown := _should_shutdown_late_setup_trainers(player, game_state)
	if _deck_has(player, RARE_CANDY):
		item_value = maxf(item_value, _rare_candy_value(player, game_state, player_index) - 80.0)
	if not late_setup_shutdown and _deck_has(player, BUDDY_BUDDY_POFFIN) and combo_missing >= 2:
		item_value = maxf(item_value, 360.0)
	if not late_setup_shutdown and _deck_has(player, NEST_BALL) and combo_missing >= 1 and _count_name(player, PIDGEOT_EX) == 0:
		item_value = maxf(item_value, 340.0)
	if not late_setup_shutdown and _deck_has(player, BUDDY_BUDDY_POFFIN) and _missing_core_basic_count(player) >= 2:
		item_value = maxf(item_value, 320.0)
	if _deck_has(player, ULTRA_BALL) and _needs_stage2_piece(player):
		item_value = maxf(item_value, 280.0)
	if _deck_has(player, COUNTER_CATCHER) and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player):
		item_value = maxf(item_value, 300.0)

	var tool_value := 60.0
	if _deck_has(player, FOREST_SEAL_STONE) and _count_name(player, PIDGEOT_EX) == 0 and _has_live_forest_seal_target(player):
		tool_value = maxf(tool_value, 280.0)
	if _deck_has(player, DEFIANCE_BAND) and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player):
		tool_value = maxf(tool_value, 220.0)
	if late_setup_shutdown and item_value <= 120.0 and tool_value <= 60.0:
		return 60.0
	return maxf(item_value + tool_value, 180.0)


func _score_fire_attach_target(
	target_slot: PokemonSlot,
	player: PlayerState,
	game_state: GameState,
	player_index: int,
	context: Dictionary = {}
) -> float:
	if target_slot == null or target_slot.get_top_card() == null:
		return 0.0
	var name := _slot_name(target_slot)
	var opponent_taken := _opponent_prizes_taken(game_state, player_index)
	if name in [DUSKULL, DUSCLOPS, DUSKNOIR] and _should_suppress_dusk_lane_actions(player, game_state, player_index):
		return -30.0
	var target_attack_gap_current := _attack_gap_after_pending(target_slot, context, 0)
	var target_attack_gap_after := _attack_gap_after_pending(target_slot, context, 1)
	var target_retreat_gap_after := _retreat_gap_after_pending(target_slot, context, 1)
	var benched_charizard := _best_benched_charizard_slot(player)
	var benched_charizard_current_gap := _attack_gap_after_pending(benched_charizard, context, 0)
	if target_slot == player.active_pokemon and _is_transition_pivot_active(target_slot):
		if benched_charizard != null and benched_charizard_current_gap == 0 and target_retreat_gap_after == 0:
			return 560.0
		if benched_charizard != null and benched_charizard_current_gap <= 1 and target_retreat_gap_after == 0:
			return 180.0
	match name:
		CHARIZARD_EX:
			if target_attack_gap_current == 0:
				return 160.0
			if target_slot == player.active_pokemon and target_attack_gap_after == 0:
				return 620.0
			if target_slot == player.active_pokemon and target_attack_gap_after == 1:
				return 520.0
			if target_slot != player.active_pokemon and _is_transition_pivot_active(player.active_pokemon):
				if target_attack_gap_after == 0:
					return 640.0
				if target_attack_gap_after == 1:
					return 600.0
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


func _count_hand_name(player: PlayerState, target_name: String) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.hand:
		if _card_name(card) == target_name:
			count += 1
	return count


func _pick_buddy_poffin_targets(items: Array[CardInstance], player: PlayerState, max_select: int, game_state: GameState = null) -> Array:
	var remaining: Array[CardInstance] = items.duplicate()
	var selected: Array[CardInstance] = []
	var local_counts := {
		CHARMANDER: _count_name(player, CHARMANDER),
		PIDGEY: _count_name(player, PIDGEY),
		DUSKULL: _count_name(player, DUSKULL),
	}
	if max_select <= 0:
		return selected

	_try_take_named_card(remaining, selected, PIDGEY, max_select, local_counts)
	_try_take_named_card(remaining, selected, CHARMANDER, max_select, local_counts)
	if _local_count(local_counts, CHARMANDER) == 1 and _count_name(player, CHARIZARD_EX) == 0 and _count_name(player, PIDGEOT_EX) == 0:
		if game_state == null or int(game_state.turn_number) <= 4:
			_try_take_named_card(remaining, selected, CHARMANDER, max_select, local_counts)
	if _local_count(local_counts, PIDGEY) == 0:
		_try_take_named_card(remaining, selected, PIDGEY, max_select, local_counts)
	if not _should_defer_duskull_lane(player, game_state):
		if not _is_combo_core_online(player):
			_try_take_named_card(remaining, selected, DUSKULL, max_select, local_counts)

	if selected.size() >= max_select or remaining.is_empty():
		return selected
	if _is_combo_core_online(player):
		return selected
	if _should_defer_duskull_lane(player, game_state):
		if _local_count(local_counts, PIDGEY) < 1:
			return selected
		if _local_count(local_counts, CHARMANDER) < 2:
			return selected
		if _count_name(player, ROTOM_V) == 0:
			return selected
	remaining.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var score_a := _score_search_pokemon(a, {"game_state": game_state, "player_index": player.player_index})
		var score_b := _score_search_pokemon(b, {"game_state": game_state, "player_index": player.player_index})
		if is_equal_approx(score_a, score_b):
			return _card_name(a) < _card_name(b)
		return score_a > score_b
	)
	for card: CardInstance in remaining:
		if selected.size() >= max_select:
			break
		selected.append(card)
	return selected


func _try_take_named_card(
	remaining: Array[CardInstance],
	selected: Array[CardInstance],
	target_name: String,
	max_select: int,
	local_counts: Dictionary
) -> void:
	if selected.size() >= max_select:
		return
	for i: int in range(remaining.size()):
		var card := remaining[i]
		if _card_name(card) != target_name:
			continue
		selected.append(card)
		remaining.remove_at(i)
		local_counts[target_name] = _local_count(local_counts, target_name) + 1
		return


func _local_count(local_counts: Dictionary, name: String) -> int:
	return int(local_counts.get(name, 0))


func _deck_has(player: PlayerState, target_name: String) -> bool:
	for card: CardInstance in player.deck:
		if _card_name(card) == target_name:
			return true
	return false


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


func _missing_core_basic_count(player: PlayerState) -> int:
	var missing := 0
	if _count_name(player, CHARMANDER) == 0:
		missing += 1
	if _count_name(player, PIDGEY) == 0:
		missing += 1
	return missing


func _has_primary_setup_established(player: PlayerState) -> bool:
	return _count_name(player, CHARMANDER) > 0 and _count_name(player, PIDGEY) > 0


func _missing_opening_combo_piece_count(player: PlayerState) -> int:
	var missing := 0
	if _count_name(player, CHARMANDER) < 2:
		missing += 2 - _count_name(player, CHARMANDER)
	if _count_name(player, PIDGEY) == 0:
		missing += 1
	if _count_name(player, ROTOM_V) == 0:
		missing += 1
	return missing


func _has_opening_combo_shell(player: PlayerState) -> bool:
	return _count_name(player, CHARMANDER) >= 2 and _count_name(player, PIDGEY) >= 1 and _count_name(player, ROTOM_V) >= 1


func _is_handoff_launch_shell_phase(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _is_combo_core_online(player):
		return false
	if _count_name(player, CHARIZARD_EX) > 0 or _count_name(player, PIDGEOT_EX) > 0:
		return false
	if not _has_primary_setup_established(player):
		return false
	if _count_name(player, ROTOM_V) == 0:
		return false
	if game_state != null and int(game_state.turn_number) > 4:
		return false
	return true


func _is_opening_rotom_send_out_window(player: PlayerState, game_state: GameState = null) -> bool:
	if not _is_handoff_launch_shell_phase(player, game_state):
		return false
	if game_state != null and int(game_state.turn_number) > 2:
		return false
	if player.bench.size() > 3:
		return false
	if _count_name(player, ROTOM_V) != 1:
		return false
	if _count_name(player, CHARMANDER) < 1 or _count_name(player, PIDGEY) < 1:
		return false
	if _count_name(player, DUSKNOIR) > 0 or _count_name(player, DUSCLOPS) > 0:
		return false
	return true


func _needs_second_charmander_for_combo(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _count_name(player, CHARIZARD_EX) > 0:
		return false
	if _count_name(player, CHARMANDER) != 1:
		return false
	if _count_name(player, PIDGEOT_EX) > 0:
		return false
	if game_state != null and int(game_state.turn_number) > 4:
		return false
	return true


func _should_defer_charizard_stage2_search(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null:
		return false
	if _count_name(player, CHARIZARD_EX) > 0:
		return false
	if _has_hand_card(player, RARE_CANDY):
		return false
	if _should_prioritize_direct_charizard_line(player, game_state, player_index):
		return false
	if game_state != null and int(game_state.turn_number) > 4:
		return false
	return not _has_opening_combo_shell(player)


func _is_forest_seal_stone_ability(slot: PokemonSlot, ability_index: int) -> bool:
	if slot == null or slot.get_card_data() == null or slot.attached_tool == null or slot.attached_tool.card_data == null:
		return false
	var native_count := slot.get_card_data().abilities.size()
	if ability_index < native_count:
		return false
	return str(slot.attached_tool.card_data.effect_id) == "9fa9943ccda36f417ac3cb675177c216"


func _score_forest_seal_stone_ability(player: PlayerState, game_state: GameState, player_index: int) -> float:
	if player == null:
		return 0.0
	if _count_name(player, CHARIZARD_EX) > 0 and _count_name(player, PIDGEOT_EX) > 0:
		return 220.0
	if _should_prioritize_direct_charizard_line(player, game_state, player_index):
		return 620.0
	if not _has_primary_setup_established(player):
		return 180.0
	if not _has_opening_combo_shell(player):
		return 260.0
	if _count_name(player, CHARIZARD_EX) == 0 or _count_name(player, PIDGEOT_EX) == 0:
		return 560.0
	if not _has_hand_card(player, RARE_CANDY):
		return 520.0
	return 260.0


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


func _should_shutdown_late_setup_trainers(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null or game_state == null:
		return false
	if not _is_combo_core_online(player):
		return false
	if int(game_state.turn_number) < 6:
		return false
	if not _can_attack_soon(player):
		return false
	return _should_shutdown_extra_charmander_lane(player, game_state)


func _should_defer_duskull_lane(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _count_name(player, DUSKNOIR) > 0 or _count_name(player, DUSCLOPS) > 0:
		return false
	if _has_opening_combo_shell(player):
		return false
	if game_state != null and int(game_state.turn_number) > 4:
		return false
	return true


func _should_suppress_dusk_lane_actions(player: PlayerState, game_state: GameState = null, player_index: int = -1) -> bool:
	if player == null:
		return false
	if _has_dusknoir_conversion_board(player, game_state, player_index):
		return false
	if _count_name(player, CHARIZARD_EX) > 0 and (_can_attack_soon(player) or _count_name(player, PIDGEOT_EX) > 0):
		return false
	if game_state != null and int(game_state.turn_number) > 4 and (_count_name(player, CHARIZARD_EX) > 0 or _count_name(player, PIDGEOT_EX) > 0):
		return false
	return not _has_opening_combo_shell(player)


func _needs_early_rotom_setup(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _count_name(player, PIDGEOT_EX) > 0 or _count_name(player, ROTOM_V) > 0:
		return false
	if _has_hand_card(player, ROTOM_V):
		return false
	if not _deck_has(player, ROTOM_V):
		return false
	if not _has_primary_setup_established(player):
		return false
	if game_state != null and int(game_state.turn_number) > 4:
		return false
	return true


func _count_live_poffin_shell_targets(player: PlayerState, game_state: GameState = null) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null or not card.card_data.is_basic_pokemon() or int(card.card_data.hp) > 70:
			continue
		var name := _card_name(card)
		if name == PIDGEY and _count_name(player, PIDGEY) == 0:
			count += 1
		elif name == CHARMANDER:
			if _count_name(player, CHARMANDER) == 0:
				count += 1
			elif _needs_second_charmander_for_combo(player, game_state):
				count += 1
	return count


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


func _is_combo_core_online(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_name(player, CHARIZARD_EX) > 0 and _count_name(player, PIDGEOT_EX) > 0


func _should_shut_off_quick_search(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null or game_state == null:
		return false
	if not _is_combo_core_online(player):
		return false
	if _has_live_backup_charizard_lane(player):
		return false
	if player.deck.size() > 6:
		return false
	if _can_take_bench_prize(game_state, player_index):
		return false
	if _needs_stage2_piece(player):
		return false
	if _has_core_piece_in_discard(player):
		return false
	if player.hand.size() <= 2:
		return false
	return true


func _should_shut_off_rotom_draw(player: PlayerState, game_state: GameState) -> bool:
	if player == null or game_state == null:
		return false
	var turn_number := int(game_state.turn_number)
	if turn_number <= 3:
		return false
	if _is_combo_core_online(player):
		return true
	if _count_name(player, CHARIZARD_EX) == 0:
		return false
	if turn_number >= 5 and player.hand.size() >= 2:
		return true
	if player.deck.size() <= 12:
		return true
	if _count_name(player, PIDGEOT_EX) > 0:
		return true
	return not _has_live_backup_charizard_lane(player)


func _has_live_backup_charizard_lane(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_name(player, CHARIZARD_EX) >= 2:
		return false
	if _count_name(player, CHARMANDER) + _count_name(player, CHARMELEON) == 0:
		return false
	var has_stage2_access := _has_hand_card(player, CHARIZARD_EX) or _deck_has(player, CHARIZARD_EX)
	var has_candy_access := _has_hand_card(player, RARE_CANDY) or _deck_has(player, RARE_CANDY)
	return has_stage2_access and has_candy_access


func _has_live_forest_seal_target(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_name(player, ROTOM_V) > 0 or _count_name(player, LUMINEON_V) > 0


func _count_ultra_ball_safe_discard_fodder(player: PlayerState, game_state: GameState, source_card: Variant = null) -> int:
	if player == null:
		return 0
	var count := 0
	for hand_card: CardInstance in player.hand:
		if hand_card == null or hand_card.card_data == null:
			continue
		if source_card is CardInstance and hand_card == source_card:
			continue
		var name := _card_name(hand_card)
		if name in [RARE_CANDY, ULTRA_BALL]:
			continue
		if get_discard_priority_contextual(hand_card, game_state, player.player_index) >= 60:
			count += 1
	return count


func _is_ultra_ball_opening_combo_window(player: PlayerState, game_state: GameState, source_card: Variant = null) -> bool:
	if player == null or game_state == null:
		return false
	if int(game_state.turn_number) > 3:
		return false
	if not _has_hand_card(player, RARE_CANDY):
		return false
	if _count_hand_name(player, ULTRA_BALL) < 2:
		return false
	if _count_ultra_ball_safe_discard_fodder(player, game_state, source_card) < 2:
		return false
	if not _has_primary_setup_established(player):
		return false
	var charizard_live := _count_name(player, CHARIZARD_EX) == 0 and not _has_hand_card(player, CHARIZARD_EX) and _player_has_ready_stage2_target(player, CHARMANDER, CHARMELEON) and _deck_has(player, CHARIZARD_EX)
	var pidgeot_live := _count_name(player, PIDGEOT_EX) == 0 and not _has_hand_card(player, PIDGEOT_EX) and _player_has_ready_stage2_target(player, PIDGEY, "Pidgeotto") and _deck_has(player, PIDGEOT_EX)
	return charizard_live and pidgeot_live


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


func _has_rebuild_piece_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		var name := _card_name(card)
		if name in [CHARIZARD_EX, CHARMANDER, PIDGEOT_EX, PIDGEY]:
			return true
	return false


func _has_only_deferred_dusk_recovery_targets(player: PlayerState) -> bool:
	if player == null:
		return false
	var has_dusk_piece := false
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		var name := _card_name(card)
		if name in [DUSKULL, DUSCLOPS, DUSKNOIR]:
			has_dusk_piece = true
			continue
		if card.card_data.is_energy():
			return false
		if name in [CHARIZARD_EX, CHARMANDER, CHARMELEON, PIDGEOT_EX, PIDGEY, RADIANT_CHARIZARD]:
			return false
		return false
	return has_dusk_piece


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


func _pending_assignment_count(slot: PokemonSlot, context: Dictionary) -> int:
	if slot == null or context.is_empty():
		return 0
	var pending_assignment_counts: Variant = context.get("pending_assignment_counts", {})
	if not (pending_assignment_counts is Dictionary):
		return 0
	return int((pending_assignment_counts as Dictionary).get(int(slot.get_instance_id()), 0))


func _attack_gap_after_pending(slot: PokemonSlot, context: Dictionary, additional_energy: int = 0) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	return maxi(0, _attack_gap(slot) - _pending_assignment_count(slot, context) - additional_energy)


func _retreat_gap_after_pending(slot: PokemonSlot, context: Dictionary, additional_energy: int = 0) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	return maxi(0, _retreat_gap(slot) - _pending_assignment_count(slot, context) - additional_energy)


func _best_benched_charizard_slot(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best: PokemonSlot = null
	var best_gap := 99
	for slot: PokemonSlot in player.bench:
		if slot == null or _slot_name(slot) != CHARIZARD_EX:
			continue
		var gap := _attack_gap(slot)
		if best == null or gap < best_gap:
			best = slot
			best_gap = gap
	return best


func _is_transition_pivot_active(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	return _slot_name(slot) in [ROTOM_V, LUMINEON_V, PIDGEY, DUSKULL, MANAPHY, FEZANDIPITI_EX, PIDGEOT_EX]


func _should_block_opening_shell_retreat(active: PokemonSlot, target_slot: PokemonSlot, player: PlayerState, game_state: GameState) -> bool:
	if active == null or target_slot == null or player == null or game_state == null:
		return false
	if int(game_state.turn_number) > 3:
		return false
	if _is_combo_core_online(player):
		return false
	if _slot_name(active) != CHARMANDER:
		return false
	if active.damage_counters > 0:
		return false
	if _can_slot_attack(target_slot):
		return false
	var target_name := _slot_name(target_slot)
	if target_name in [ROTOM_V, LUMINEON_V]:
		return false
	return target_name in [CHARMANDER, PIDGEY, DUSKULL, MANAPHY, FEZANDIPITI_EX, PIDGEOT_EX]


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
			if not _is_combo_core_online(player) and _count_name(player, CHARIZARD_EX) == 0:
				continue
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


func _has_dusknoir_conversion_board(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null:
		return false
	if _count_name(player, CHARIZARD_EX) > 0 and _can_attack_soon(player):
		return true
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		if _has_dusknoir_conversion_target(game_state, player_index):
			return true
	return false


func _has_dusknoir_conversion_target(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null:
		return false
	var context := {"game_state": game_state, "player_index": player_index}
	for slot: PokemonSlot in _all_slots(opponent):
		if _score_dusknoir_target(slot, context) >= 350.0:
			return true
	return false


func _score_dusknoir_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var remaining_hp := slot.get_remaining_hp()
	var self_ko_damage := 50
	var score := float(slot.get_prize_count()) * 90.0
	if remaining_hp <= self_ko_damage:
		score += 640.0
		return score
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score - float(remaining_hp) * 0.2
	var player: PlayerState = game_state.players[player_index]
	var active := player.active_pokemon
	var opponent: PlayerState = game_state.players[1 - player_index]
	if active != null and slot == opponent.active_pokemon:
		var attack_info: Dictionary = predict_attacker_damage(active)
		if bool(attack_info.get("can_attack", false)):
			var follow_up_damage := int(attack_info.get("damage", 0))
			if remaining_hp <= self_ko_damage + follow_up_damage:
				score += 420.0
				return score
	score -= 120.0
	score -= float(remaining_hp) * 0.25
	return score


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
