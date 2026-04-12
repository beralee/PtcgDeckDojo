class_name DeckStrategyBlisseyTank
extends "res://scripts/ai/DeckStrategyBase.gd"

const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const BLISSEY_EX := "Blissey ex"
const CHANSEY := "Chansey"
const MUNKIDORI := "Munkidori"
const CORNERSTONE_OGERPON_EX := "Cornerstone Mask Ogerpon ex"
const GIRAFARIG := "Girafarig"
const FARIGIRAF_EX := "Farigiraf ex"

const CHERENS_CARE := "Cheren's Care"
const BOSSS_ORDERS := "Boss's Orders"
const PROFESSORS_RESEARCH := "Professor's Research"
const IONO := "Iono"
const ARVEN := "Arven"
const ARTAZON := "Artazon"

const HERO_CAPE := "Hero's Cape"
const TM_TURBO_ENERGIZE := "Technical Machine: Turbo Energize"
const TM_DEVOLUTION := "Technical Machine: Devolution"

const NEST_BALL := "Nest Ball"
const ULTRA_BALL := "Ultra Ball"
const HISUIAN_HEAVY_BALL := "Hisuian Heavy Ball"
const NIGHT_STRETCHER := "Night Stretcher"
const SUPER_ROD := "Super Rod"
const EARTHEN_VESSEL := "Earthen Vessel"
const LOST_VACUUM := "Lost Vacuum"
const POKEGEAR := "Pok\u00e9gear 3.0"

const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"

const TANK_NAMES: Array[String] = [BLISSEY_EX, CHANSEY, CORNERSTONE_OGERPON_EX]
const SUPPORT_NAMES: Array[String] = [MUNKIDORI, GIRAFARIG, FARIGIRAF_EX]


func get_strategy_id() -> String:
	return "blissey_tank"


func get_signature_names() -> Array[String]:
	return [BLISSEY_EX, CHANSEY, MUNKIDORI]


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
		"time_budget_ms": 3000,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type != "Pokemon" or str(card.card_data.stage) != "Basic":
			continue
		var name: String = _card_name(card)
		basics.append({"index": i, "name": name, "priority": _get_setup_priority(name)})

	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}

	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)

	var active_index: int = int(basics[0].get("index", -1))
	var bench_indices: Array[int] = []
	for entry: Dictionary in basics:
		var entry_index: int = int(entry.get("index", -1))
		if entry_index == active_index:
			continue
		bench_indices.append(entry_index)
		if bench_indices.size() >= 5:
			break

	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var kind: String = str(action.get("kind", ""))
	match kind:
		"play_basic_to_bench":
			return _abs_play_basic(action, player)
		"evolve":
			return _abs_evolve(action, game_state, player, player_index)
		"attach_energy":
			return _abs_attach_energy(action, game_state, player, player_index)
		"attach_tool":
			return _abs_attach_tool(action, player)
		"use_ability":
			return _abs_use_ability(action, game_state, player, player_index)
		"play_trainer":
			return _abs_play_trainer(action, game_state, player, player_index)
		"retreat":
			return _abs_retreat(game_state, player, player_index)
		"attack":
			return _abs_attack(game_state, player, player_index)
		"granted_attack":
			return _abs_attack(game_state, player, player_index)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var abs_score: float = score_action_absolute(action, game_state, player_index)
	return abs_score - _estimate_heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var score: float = 0.0

	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_is(slot, [BLISSEY_EX]):
			score += 380.0
			score += float(slot.get_remaining_hp()) * 0.9
			score += float(slot.attached_energy.size()) * 55.0
			if slot.attached_tool != null and _card_is(slot.attached_tool, [HERO_CAPE]):
				score += 120.0
		elif _slot_is(slot, [CHANSEY]):
			score += 120.0
		elif _slot_is(slot, [CORNERSTONE_OGERPON_EX]):
			score += 180.0
		elif _slot_is(slot, [MUNKIDORI]):
			score += 150.0
			if _slot_has_energy_type(slot, "D"):
				score += 110.0
		elif _slot_is(slot, [FARIGIRAF_EX]):
			score += 100.0

	if player.active_pokemon != null and _is_tank(player.active_pokemon):
		score += 120.0

	if opponent.active_pokemon != null:
		score -= float(opponent.active_pokemon.get_remaining_hp()) * 0.35
	if _count_matching_on_field(opponent, [BLISSEY_EX]) > 0:
		score -= 150.0

	return score


func predict_attacker_damage(slot: PokemonSlot, _extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var damage: int = _best_attack_damage(slot)
	var can_attack: bool = _get_attack_energy_gap(slot) <= 0
	return {"damage": damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if _card_is(card, [BLISSEY_EX, CHANSEY, MUNKIDORI, CORNERSTONE_OGERPON_EX]):
		return 5
	if _card_is(card, [HERO_CAPE, CHERENS_CARE]):
		return 15
	if card.card_data.card_type == "Basic Energy":
		return 110
	if card.card_data.card_type == "Special Energy":
		return 90
	if card.card_data.card_type == "Item" or card.card_data.card_type == "Tool":
		return 80
	return 50


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	if player.is_bench_full() and _card_is(card, [NEST_BALL, HISUIAN_HEAVY_BALL]):
		return 180
	if _card_is(card, [CHANSEY]) and _count_matching_on_field(player, [CHANSEY, BLISSEY_EX]) >= 2:
		return 160
	if _card_is(card, [MUNKIDORI]) and _count_matching_on_field(player, [MUNKIDORI]) >= 1:
		return 150
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if _card_is(card, [CHANSEY]):
		return 100
	if _card_is(card, [BLISSEY_EX]):
		return 95
	if _card_is(card, [MUNKIDORI]):
		return 90
	if _card_is(card, [CORNERSTONE_OGERPON_EX]):
		return 80
	if _card_is(card, [FARIGIRAF_EX, GIRAFARIG]):
		return 86
	if _card_is(card, [HERO_CAPE]):
		return 75
	if _card_is(card, [TM_TURBO_ENERGIZE]):
		return 72
	if _card_is(card, [ULTRA_BALL]):
		return 68
	if _card_is(card, [NEST_BALL]):
		return 66
	if _card_is(card, [CHERENS_CARE]):
		return 64
	return 20


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))

	if item is CardInstance:
		var card: CardInstance = item as CardInstance
		if step_id in ["search_pokemon", "search_cards", "basic_pokemon", "bench_pokemon"]:
			return float(get_search_priority(card))
		if step_id in ["search_item", "search_tool"]:
			return float(get_search_priority(card))
		if step_id in ["discard_card", "discard_cards", "discard_energy"]:
			return float(get_discard_priority_contextual(card, game_state, player_index))
		return float(get_search_priority(card))

	if not (item is PokemonSlot):
		return 0.0

	var slot: PokemonSlot = item as PokemonSlot
	match step_id:
		"source_pokemon":
			return _score_damage_source_target(slot)
		"target_pokemon":
			return _score_damage_move_target(slot)
		"assignment_target", "energy_assignment":
			return _score_assignment_target(slot, context)
	return _score_assignment_target(slot, context)


func _abs_play_basic(action: Dictionary, player: PlayerState) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null or player.is_bench_full():
		return 0.0
	if _card_is(card, [CHANSEY]):
		if _count_matching_on_field(player, [CHANSEY, BLISSEY_EX]) >= 2:
			return 120.0
		return 340.0
	if _card_is(card, [MUNKIDORI]):
		if _count_matching_on_field(player, [MUNKIDORI]) >= 1:
			return 90.0
		return 300.0
	if _card_is(card, [CORNERSTONE_OGERPON_EX]):
		return 240.0 if _count_matching_on_field(player, [CORNERSTONE_OGERPON_EX]) == 0 else 130.0
	if _card_is(card, [GIRAFARIG]):
		return 220.0 if _count_matching_on_field(player, [FARIGIRAF_EX, GIRAFARIG]) == 0 else 90.0
	return 40.0


func _abs_evolve(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return 0.0
	if _card_is(card, [BLISSEY_EX]):
		if _count_matching_on_field(player, [BLISSEY_EX]) == 0:
			return 700.0
		return 480.0
	if _card_is(card, [FARIGIRAF_EX]):
		if _opponent_has_basic_ex_pressure(game_state, player_index):
			return 380.0 if _count_matching_on_field(player, [FARIGIRAF_EX]) == 0 else 340.0
		return 220.0
	return 70.0


func _abs_attach_energy(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var energy_card: CardInstance = action.get("card", null)
	if target_slot == null or energy_card == null or energy_card.card_data == null:
		return 0.0

	var is_special: bool = str(energy_card.card_data.card_type) == "Special Energy"
	var energy_type: String = str(energy_card.card_data.energy_provides)
	var energy_name: String = _card_name(energy_card)
	var gap: int = _get_attack_energy_gap(target_slot)

	if energy_name == DOUBLE_TURBO_ENERGY:
		if _slot_is(target_slot, [BLISSEY_EX, CHANSEY]):
			if gap <= 1:
				return 430.0
			return 330.0
		if _slot_is(target_slot, [CORNERSTONE_OGERPON_EX, FARIGIRAF_EX]):
			return 180.0
		return 60.0

	if is_special:
		return 90.0

	if energy_type == "D":
		if _slot_is(target_slot, [MUNKIDORI]):
			return 360.0 if not _slot_has_energy_type(target_slot, "D") else 250.0
		if _slot_is(target_slot, [BLISSEY_EX]):
			return 210.0
		return 90.0

	if energy_type == "P":
		if _slot_is(target_slot, [FARIGIRAF_EX]) and _opponent_has_basic_ex_pressure(game_state, player_index):
			return 390.0 if gap > 0 else 280.0
		if _slot_is(target_slot, [BLISSEY_EX]) and _opponent_has_basic_ex_pressure(game_state, player_index):
			return 240.0

	if _slot_is(target_slot, [BLISSEY_EX]):
		if gap <= 1:
			return 380.0
		return 300.0
	if _slot_is(target_slot, [CHANSEY]):
		return 260.0
	if _slot_is(target_slot, [CORNERSTONE_OGERPON_EX]):
		return 220.0
	if _slot_is(target_slot, [FARIGIRAF_EX]):
		return 170.0
	if _slot_is(target_slot, [MUNKIDORI]):
		return 120.0
	return 60.0


func _abs_attach_tool(action: Dictionary, player: PlayerState) -> float:
	var card: CardInstance = action.get("card", null)
	var target_slot: PokemonSlot = action.get("target_slot", null)
	if card == null or card.card_data == null or target_slot == null:
		return 0.0

	if _card_is(card, [HERO_CAPE]):
		if _slot_is(target_slot, [BLISSEY_EX]):
			return 360.0
		if _slot_is(target_slot, [CHANSEY]):
			return 260.0
		if _slot_is(target_slot, [CORNERSTONE_OGERPON_EX]):
			return 220.0
		return 140.0

	if _card_is(card, [TM_TURBO_ENERGIZE]):
		if _slot_is(target_slot, [CHANSEY]) and _has_turbo_energize_followup(player):
			return 340.0
		if _slot_is(target_slot, [CHANSEY, BLISSEY_EX]):
			return 260.0
		if _slot_is(target_slot, [CORNERSTONE_OGERPON_EX]):
			return 200.0
		return 80.0

	if _card_is(card, [TM_DEVOLUTION]):
		return 180.0

	return 70.0


func _abs_use_ability(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var source_slot: PokemonSlot = action.get("source_slot", null)
	if source_slot == null:
		return 0.0

	if _slot_is(source_slot, [BLISSEY_EX]):
		if not _slot_has_basic_energy(source_slot):
			return 40.0
		var best_target: float = 0.0
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot == source_slot:
				continue
			best_target = maxf(best_target, _score_assignment_target(slot, {
				"game_state": game_state,
				"player_index": player_index,
			}))
		return 220.0 + best_target * 0.5

	if _slot_is(source_slot, [MUNKIDORI]):
		return _abs_munkidori_ability(game_state, player, player_index)

	return 0.0


func _abs_play_trainer(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return 0.0

	if _card_is(card, [CHERENS_CARE]):
		var active: PokemonSlot = player.active_pokemon
		if active != null and _slot_is(active, [BLISSEY_EX, CHANSEY]) and active.damage_counters >= 150:
			var recovery_value: float = float(active.damage_counters) * 1.8
			recovery_value += float(active.attached_energy.size()) * 35.0
			if active.attached_tool != null:
				recovery_value += 80.0
			return 420.0 + recovery_value
		return 170.0

	if _card_is(card, [ARVEN]):
		var need_cape: bool = _first_untooled_tank(player) != null
		var need_tm: bool = _has_basic_tank_without_energy(player)
		if need_cape and need_tm:
			return 420.0
		if need_cape or need_tm:
			return 310.0
		return 180.0

	if _card_is(card, [BOSSS_ORDERS]):
		var ko_damage: int = _best_attack_damage(player.active_pokemon)
		if _can_ko_any_opponent_bench(game_state, player_index, ko_damage):
			return 760.0
		return 240.0

	if _card_is(card, [IONO]):
		return 230.0 if player.hand.size() <= 3 else 170.0

	if _card_is(card, [PROFESSORS_RESEARCH]):
		return 210.0 if player.hand.size() <= 4 else 150.0

	if _card_is(card, [ARTAZON]):
		return 240.0 if _count_matching_on_field(player, [CHANSEY]) == 0 else 120.0

	if _card_is(card, [NIGHT_STRETCHER, SUPER_ROD]):
		return 220.0 if _has_key_pokemon_in_discard(player) else 110.0

	if _card_is(card, [NEST_BALL]):
		return 260.0 if not player.is_bench_full() and _count_matching_on_field(player, [CHANSEY]) == 0 else 120.0

	if _card_is(card, [ULTRA_BALL]):
		return 250.0

	if _card_is(card, [HISUIAN_HEAVY_BALL, EARTHEN_VESSEL, POKEGEAR]):
		return 160.0

	if _card_is(card, [LOST_VACUUM]):
		return 140.0 if game_state.stadium_card != null else 90.0

	return 80.0


func _abs_retreat(game_state: GameState, player: PlayerState, player_index: int) -> float:
	if player.active_pokemon == null:
		return 0.0
	if _is_tank(player.active_pokemon) and player.active_pokemon.damage_counters >= 180:
		for slot: PokemonSlot in player.bench:
			if _can_attack_now(slot):
				return 260.0
	if not _is_tank(player.active_pokemon) and _best_attack_damage(player.active_pokemon) == 0:
		for slot: PokemonSlot in player.bench:
			if _can_attack_now(slot):
				return 220.0
	return 70.0


func _abs_attack(game_state: GameState, player: PlayerState, player_index: int) -> float:
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return 0.0
	var damage: int = _best_attack_damage(active)
	if damage <= 0 or _get_attack_energy_gap(active) > 0:
		return 0.0
	var opponent: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	if opponent != null and damage >= opponent.get_remaining_hp():
		return 850.0
	if _slot_is(active, [BLISSEY_EX]):
		return 540.0
	if _slot_is(active, [CORNERSTONE_OGERPON_EX, FARIGIRAF_EX]):
		return 480.0
	return 320.0


func _abs_munkidori_ability(game_state: GameState, player: PlayerState, player_index: int) -> float:
	var munkidori: PokemonSlot = player.get_all_pokemon().filter(func(slot: PokemonSlot) -> bool:
		return _slot_is(slot, [MUNKIDORI])
	).front() if _count_matching_on_field(player, [MUNKIDORI]) > 0 else null
	if munkidori == null or not _slot_has_energy_type(munkidori, "D"):
		return 0.0

	var max_move: int = mini(30, _best_damage_source_counters(player))
	if max_move <= 0:
		return 0.0

	var best_score: float = 120.0
	for slot: PokemonSlot in game_state.players[1 - player_index].get_all_pokemon():
		var remaining_after: int = slot.get_remaining_hp() - max_move
		if remaining_after <= 0:
			best_score = maxf(best_score, 720.0)
		elif remaining_after <= 30:
			best_score = maxf(best_score, 420.0)
		else:
			best_score = maxf(best_score, 180.0 + float(max_move))
	return best_score


func _score_damage_source_target(slot: PokemonSlot) -> float:
	if slot == null:
		return 0.0
	var score: float = float(slot.damage_counters)
	if _slot_is(slot, [BLISSEY_EX]):
		score += 250.0
	elif _slot_is(slot, [CHANSEY]):
		score += 120.0
	elif _slot_is(slot, [CORNERSTONE_OGERPON_EX]):
		score += 170.0
	return score


func _score_damage_move_target(slot: PokemonSlot) -> float:
	if slot == null:
		return 0.0
	var score: float = 300.0 - float(slot.get_remaining_hp())
	if slot.get_remaining_hp() <= 30:
		score += 300.0
	elif slot.get_remaining_hp() <= 60:
		score += 180.0
	if slot == null:
		return 0.0
	if _is_tank(slot):
		score -= 80.0
	score += float(slot.damage_counters) * 0.3
	return score


func _score_assignment_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var source_card: CardInstance = context.get("source_card", null)
	if source_card != null and source_card.card_data != null and str(source_card.card_data.energy_provides) == "D":
		if _slot_is(slot, [MUNKIDORI]):
			return 420.0
		if _slot_is(slot, [BLISSEY_EX]):
			return 210.0
		if _slot_is(slot, [CORNERSTONE_OGERPON_EX]):
			return 180.0
		return 120.0
	if source_card != null and source_card.card_data != null and str(source_card.card_data.energy_provides) == "P":
		var game_state: GameState = context.get("game_state", null)
		var player_index: int = int(context.get("player_index", -1))
		if _slot_is(slot, [FARIGIRAF_EX]) and _opponent_has_basic_ex_pressure(game_state, player_index):
			return 360.0
		if _slot_is(slot, [BLISSEY_EX]):
			return 250.0
		if _slot_is(slot, [MUNKIDORI]):
			return 170.0

	if _slot_is(slot, [BLISSEY_EX]):
		if _get_attack_energy_gap(slot) <= 1:
			return 360.0
		return 300.0
	if _slot_is(slot, [CORNERSTONE_OGERPON_EX]):
		return 240.0 if _get_attack_energy_gap(slot) > 0 else 180.0
	if _slot_is(slot, [FARIGIRAF_EX]):
		return 210.0
	if _slot_is(slot, [MUNKIDORI]):
		return 190.0 if not _slot_has_energy_type(slot, "D") else 130.0
	if _slot_is(slot, [CHANSEY]):
		return 180.0
	return 90.0


func _get_setup_priority(name: String) -> int:
	if name == CHANSEY:
		return 100
	if name == CORNERSTONE_OGERPON_EX:
		return 88
	if name == GIRAFARIG:
		return 78
	if name == MUNKIDORI:
		return 72
	return 20


func _estimate_heuristic_base(kind: String) -> float:
	match kind:
		"attack": return 500.0
		"granted_attack": return 500.0
		"attach_energy": return 220.0
		"attach_tool": return 160.0
		"play_basic_to_bench": return 180.0
		"evolve": return 180.0
		"use_ability": return 160.0
		"play_trainer": return 110.0
		"retreat": return 90.0
	return 10.0


func _card_name(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	if str(card.card_data.name_en) != "":
		return str(card.card_data.name_en)
	return str(card.card_data.name)


func _slot_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_card_data() == null:
		return ""
	if str(slot.get_card_data().name_en) != "":
		return str(slot.get_card_data().name_en)
	return str(slot.get_pokemon_name())


func _card_is(card: CardInstance, aliases: Array[String]) -> bool:
	return _matches_aliases(_card_name(card), aliases)


func _slot_is(slot: PokemonSlot, aliases: Array) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	return cd.name in aliases or cd.name_en in aliases


func _matches_aliases(name: String, aliases: Array[String]) -> bool:
	for alias: String in aliases:
		if name == alias:
			return true
	return false


func _count_matching_on_field(player: PlayerState, aliases: Array[String]) -> int:
	var count: int = 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_is(slot, aliases):
			count += 1
	return count


func _slot_has_energy_type(slot: PokemonSlot, energy_type: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.energy_provides) == energy_type:
			return true
	return false


func _slot_has_basic_energy(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.card_type) == "Basic Energy":
			return true
	return false


func _get_attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 999
	var attached: int = slot.attached_energy.size()
	var min_gap: int = 999
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		min_gap = mini(min_gap, maxi(0, cost.length() - attached))
	return min_gap


func _best_attack_damage(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	var best: int = 0
	for attack: Dictionary in slot.get_card_data().attacks:
		var damage: int = int(str(attack.get("damage", "0")).strip_edges())
		best = maxi(best, damage)
	return best


func _is_tank(slot: PokemonSlot) -> bool:
	return _slot_is(slot, TANK_NAMES)


func _first_untooled_tank(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_tank(slot) and slot.attached_tool == null:
			return slot
	return null


func _has_basic_tank_without_energy(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_is(slot, [CHANSEY]) and slot.attached_energy.is_empty():
			return true
	return false


func _has_turbo_energize_followup(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		if _slot_is(slot, [BLISSEY_EX, CHANSEY, CORNERSTONE_OGERPON_EX, FARIGIRAF_EX]):
			return true
	return false


func _can_attack_now(slot: PokemonSlot) -> bool:
	return slot != null and _best_attack_damage(slot) > 0 and _get_attack_energy_gap(slot) <= 0


func _best_damage_source_counters(player: PlayerState) -> int:
	var best: int = 0
	for slot: PokemonSlot in player.get_all_pokemon():
		best = maxi(best, slot.damage_counters)
	return best


func _can_ko_any_opponent_bench(game_state: GameState, player_index: int, damage: int) -> bool:
	if damage <= 0:
		return false
	for slot: PokemonSlot in game_state.players[1 - player_index].bench:
		if slot != null and slot.get_remaining_hp() <= damage:
			return true
	return false


func _has_key_pokemon_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		if _card_is(card, [CHANSEY, BLISSEY_EX, MUNKIDORI, CORNERSTONE_OGERPON_EX]):
			return true
	return false


func _opponent_has_basic_ex_pressure(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for slot: PokemonSlot in game_state.players[1 - player_index].get_all_pokemon():
		if _slot_is_basic_ex(slot):
			return true
	return false


func _slot_is_basic_ex(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	return str(slot.get_card_data().stage) == "Basic" and str(slot.get_card_data().mechanic) == "ex"
