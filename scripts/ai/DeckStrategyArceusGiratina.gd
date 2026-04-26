class_name DeckStrategyArceusGiratina
extends "res://scripts/ai/DeckStrategyBase.gd"


const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const ArceusGiratinaStateEncoderScript = preload("res://scripts/ai/ArceusGiratinaStateEncoder.gd")

var _value_net: RefCounted = null
var _encoder_class: GDScript = ArceusGiratinaStateEncoderScript

const ARCEUS_V := "Arceus V"
const ARCEUS_VSTAR := "Arceus VSTAR"
const GIRATINA_V := "Giratina V"
const GIRATINA_VSTAR := "Giratina VSTAR"
const BIDOOF := "Bidoof"
const BIBAREL := "Bibarel"
const SKWOVET := "Skwovet"
const IRON_LEAVES_EX := "Iron Leaves ex"
const RADIANT_GARDEVOIR := "Radiant Gardevoir"
const CHARMANDER := "Charmander"
const CHARMELEON := "Charmeleon"
const CHARIZARD_EX := "Charizard ex"
const PIDGEY := "Pidgey"
const PIDGEOT_EX := "Pidgeot ex"

const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"
const CAPTURING_AROMA := "Capturing Aroma"
const BOSSS_ORDERS := "Boss's Orders"
const IONO := "Iono"
const JUDGE := "Judge"
const LOST_VACUUM := "Lost Vacuum"
const LOST_CITY := "Lost City"
const SWITCH := "Switch"
const MAXIMUM_BELT := "Maximum Belt"
const CHOICE_BELT := "Choice Belt"

const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"
const GRASS_ENERGY := "Grass Energy"
const PSYCHIC_ENERGY := "Psychic Energy"
const JET_ENERGY := "Jet Energy"


func get_strategy_id() -> String:
	return "arceus_giratina"


func get_signature_names() -> Array[String]:
	return [ARCEUS_V, ARCEUS_VSTAR, GIRATINA_V, GIRATINA_VSTAR]


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
		basics.append({"index": i, "score": _setup_priority(card, player)})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var active_index: int = int(basics[0].get("index", -1))
	var bench_indices: Array[int] = []
	var chosen_names: Array[String] = []
	if active_index >= 0 and active_index < player.hand.size():
		chosen_names.append(_card_name(player.hand[active_index]))
	var desired_shell: Array[String] = [ARCEUS_V, ARCEUS_V, GIRATINA_V, BIDOOF, SKWOVET]
	for desired: String in desired_shell:
		for entry: Dictionary in basics:
			var idx: int = int(entry.get("index", -1))
			if idx == active_index or bench_indices.has(idx):
				continue
			var card_name := _card_name(player.hand[idx])
			if card_name != desired:
				continue
			if desired == ARCEUS_V and chosen_names.count(ARCEUS_V) >= 2:
				continue
			if desired == GIRATINA_V and chosen_names.count(GIRATINA_V) >= 1:
				continue
			if desired == BIDOOF and chosen_names.count(BIDOOF) >= 1:
				continue
			if desired == SKWOVET and chosen_names.count(SKWOVET) >= 1:
				continue
			bench_indices.append(idx)
			chosen_names.append(card_name)
			break
	if chosen_names.count(ARCEUS_V) >= 2 and chosen_names.count(GIRATINA_V) >= 1 and chosen_names.count(BIDOOF) >= 1 and chosen_names.count(SKWOVET) >= 1:
		return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}
	for entry: Dictionary in basics:
		var idx: int = int(entry.get("index", -1))
		if idx == active_index or bench_indices.has(idx):
			continue
		bench_indices.append(idx)
		if bench_indices.size() >= 5:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	var giratina := _best_giratina_slot(player)
	var backup_arceus := _backup_arceus_slot(player)
	var ready_bench := _best_ready_bench(player)
	var flags := {
		"vs_charizard": _is_charizard_pressure_matchup(game_state, player_index),
		"launch_online": _is_launch_online(player),
		"active_can_attack": _active_can_attack(player, game_state, player_index),
		"ready_bench_attacker": ready_bench != null,
		"backup_arceus_missing": _count_arceus_total(player) < 2,
		"backup_arceus_needs_energy": backup_arceus != null and _attack_energy_gap(backup_arceus) > 0,
		"giratina_missing": _count_giratina_total(player) == 0,
		"giratina_one_step_short": giratina != null and _attack_energy_gap(giratina) == 1,
		"needs_transition_piece": _needs_transition_piece(player),
		"thin_shell": _shell_is_thin(player),
		"severe_shell_gap": _needs_shell_rebuild(player),
		"deck_out_pressure": _has_deck_out_pressure(player),
		"hand_active_dte_live": _active_arceus_has_hand_dte_progress(player),
		"hand_backup_arceus_live": _can_bench_hand_arceus(player) and _count_arceus_total(player) < 2,
		"has_board_vstar": _count_named_on_field(player, ARCEUS_VSTAR) + _count_named_on_field(player, GIRATINA_VSTAR) > 0,
		"iron_leaves_ko_window": false,
		"cool_off_engine_churn": false,
	}
	flags["iron_leaves_ko_window"] = bool(flags.get("vs_charizard", false)) and _can_iron_leaves_take_charizard_ko_this_turn(game_state, player, player_index) and _can_make_iron_leaves_active_this_turn(player)
	var late_charizard_rebuild := bool(flags.get("vs_charizard", false)) and game_state.turn_number >= 6 and (
		bool(flags.get("backup_arceus_missing", false))
		or bool(flags.get("backup_arceus_needs_energy", false))
		or bool(flags.get("giratina_missing", false))
		or bool(flags.get("giratina_one_step_short", false))
	)
	var intent := "launch_shell"
	if bool(flags.get("iron_leaves_ko_window", false)):
		intent = "close_out_prizes"
	elif bool(flags.get("active_can_attack", false)):
		if phase == "launch":
			intent = "launch_shell"
		elif bool(flags.get("needs_transition_piece", false)) or bool(flags.get("backup_arceus_missing", false)) or bool(flags.get("backup_arceus_needs_energy", false)):
			intent = "bridge_to_finisher"
		else:
			intent = "convert_attack"
	elif bool(flags.get("has_board_vstar", false)) or bool(flags.get("launch_online", false)) or late_charizard_rebuild:
		intent = "rebuild_attacker"
	elif bool(flags.get("deck_out_pressure", false)):
		intent = "dead_turn_preserve_outs"
	var targets := {
		"primary_attacker_name": _slot_name(ready_bench) if ready_bench != null and not bool(flags.get("active_can_attack", false)) else _slot_name(player.active_pokemon),
		"bridge_target_name": "",
	}
	if intent == "bridge_to_finisher":
		if giratina != null and (bool(flags.get("needs_transition_piece", false)) or bool(flags.get("giratina_one_step_short", false))):
			targets["bridge_target_name"] = _slot_name(giratina)
		elif backup_arceus != null and bool(flags.get("backup_arceus_needs_energy", false)):
			targets["bridge_target_name"] = _slot_name(backup_arceus)
	flags["cool_off_engine_churn"] = bool(flags.get("vs_charizard", false)) and intent == "rebuild_attacker" and (
		bool(flags.get("backup_arceus_missing", false))
		or bool(flags.get("backup_arceus_needs_energy", false))
		or bool(flags.get("giratina_missing", false))
		or bool(flags.get("giratina_one_step_short", false))
	)
	var constraints := {
		"must_attack_if_available": intent == "bridge_to_finisher" and bool(flags.get("active_can_attack", false)) and str(targets.get("bridge_target_name", "")) != "",
		"forbid_engine_churn": false,
		"forbid_extra_bench_padding": false,
		"prefer_exact_hand_shell_progress": false,
	}
	constraints["must_attack_if_available"] = bool(constraints.get("must_attack_if_available", false)) \
		and (
			bool(flags.get("giratina_one_step_short", false))
			or (backup_arceus != null and _attack_energy_gap(backup_arceus) == 1 and not bool(flags.get("thin_shell", false)) and not bool(flags.get("severe_shell_gap", false)))
		)
	constraints["forbid_engine_churn"] = bool(constraints.get("must_attack_if_available", false)) or bool(flags.get("cool_off_engine_churn", false))
	constraints["forbid_extra_bench_padding"] = bool(constraints.get("must_attack_if_available", false)) or bool(flags.get("ready_bench_attacker", false))
	constraints["prefer_exact_hand_shell_progress"] = (
		not bool(flags.get("active_can_attack", false))
		and not bool(flags.get("ready_bench_attacker", false))
		and bool(flags.get("hand_active_dte_live", false))
		and bool(flags.get("hand_backup_arceus_live", false))
	)
	var modifiers: Array[String] = []
	for key: String in flags.keys():
		if bool(flags.get(key, false)):
			modifiers.append(key)
	modifiers.sort()
	return {
		"intent": intent,
		"phase": phase,
		"flags": flags,
		"targets": targets,
		"constraints": constraints,
		"modifiers": modifiers,
		"context": context.duplicate(true),
	}


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var contract := _normalize_turn_contract(build_turn_plan(game_state, player_index, context))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return contract
	var player: PlayerState = game_state.players[player_index]
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var owner: Dictionary = contract.get("owner", {}) if contract.get("owner", {}) is Dictionary else {}
	var priorities: Dictionary = contract.get("priorities", {}) if contract.get("priorities", {}) is Dictionary else {}
	var active_name := _slot_name(player.active_pokemon)
	var ready_bench := _best_ready_bench(player)
	var ready_bench_handoff := bool(flags.get("ready_bench_attacker", false)) and not bool(flags.get("active_can_attack", false))
	if ready_bench_handoff and ready_bench != null:
		owner["turn_owner_name"] = _slot_name(ready_bench)
		owner["pivot_target_name"] = _slot_name(ready_bench)
		if str(owner.get("bridge_target_name", "")) == "":
			owner["bridge_target_name"] = _slot_name(ready_bench)
	else:
		if str(owner.get("turn_owner_name", "")) == "":
			owner["turn_owner_name"] = active_name
		if str(owner.get("pivot_target_name", "")) == "":
			owner["pivot_target_name"] = str(owner.get("turn_owner_name", active_name))
	if bool(flags.get("iron_leaves_ko_window", false)):
		owner["bridge_target_name"] = IRON_LEAVES_EX
		owner["pivot_target_name"] = IRON_LEAVES_EX
	var attach_priority: Array[String] = []
	var bridge_target_name := str(owner.get("bridge_target_name", ""))
	var turn_owner_name := str(owner.get("turn_owner_name", ""))
	var pivot_target_name := str(owner.get("pivot_target_name", ""))
	if bridge_target_name != "":
		attach_priority.append(bridge_target_name)
	if turn_owner_name != "" and not attach_priority.has(turn_owner_name):
		attach_priority.append(turn_owner_name)
	if pivot_target_name != "" and not attach_priority.has(pivot_target_name):
		attach_priority.append(pivot_target_name)
	priorities["attach"] = attach_priority
	var handoff_priority: Array[String] = []
	if pivot_target_name != "":
		handoff_priority.append(pivot_target_name)
	if turn_owner_name != "" and not handoff_priority.has(turn_owner_name):
		handoff_priority.append(turn_owner_name)
	priorities["handoff"] = handoff_priority
	var search_priority: Array[String] = []
	if bridge_target_name != "":
		search_priority.append(bridge_target_name)
	if turn_owner_name != "" and not search_priority.has(turn_owner_name):
		search_priority.append(turn_owner_name)
	priorities["search"] = search_priority
	var search_cards: Array[String] = []
	if ready_bench_handoff:
		search_cards.append(SWITCH)
	match bridge_target_name:
		GIRATINA_V, GIRATINA_VSTAR:
			pass
		ARCEUS_V, ARCEUS_VSTAR:
			pass
		IRON_LEAVES_EX:
			search_cards.append_array([IRON_LEAVES_EX, SWITCH, GRASS_ENERGY])
	priorities["search_cards"] = search_cards
	contract["owner"] = owner
	contract["priorities"] = priorities
	return contract


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_play_basic(action.get("card", null), game_state, player, player_index, phase)
		"evolve":
			return _score_evolve(action.get("card", null), game_state, player, player_index, phase)
		"play_stadium":
			return _score_stadium(action.get("card", null), game_state, player, player_index, phase)
		"play_trainer":
			return _score_trainer(action, game_state, player, player_index, phase)
		"attach_energy":
			return _score_attach(action.get("card", null), action.get("target_slot", null), game_state, player, phase)
		"attach_tool":
			return _score_attach_tool(action, game_state, player, player_index, phase)
		"use_ability":
			return _score_use_ability(action.get("source_slot", null), game_state, player, phase)
		"retreat":
			return _score_retreat(action, game_state, player, player_index, phase)
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index, phase)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(action, context.get("game_state", null), int(context.get("player_index", -1)))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	var score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		var name := _slot_name(slot)
		if name == ARCEUS_VSTAR:
			score += 860.0
			score += float(slot.attached_energy.size()) * 90.0
		elif name == ARCEUS_V:
			score += 360.0
			score += float(slot.attached_energy.size()) * 70.0
		elif name == GIRATINA_VSTAR:
			score += 780.0
			score += float(slot.attached_energy.size()) * 88.0
		elif name == GIRATINA_V:
			score += 290.0
			score += float(slot.attached_energy.size()) * 60.0
		elif name == BIBAREL:
			score += 240.0
		elif name == BIDOOF:
			score += 120.0
		elif name == RADIANT_GARDEVOIR:
			score += 110.0
		score += float(slot.get_remaining_hp()) * 0.09
	var best_arceus := _best_arceus_slot(player)
	if best_arceus != null and _attack_energy_gap(best_arceus) <= 0:
		score += 260.0
	if _best_giratina_slot(player) != null and _attack_energy_gap(_best_giratina_slot(player)) <= 1:
		score += 220.0
	if phase == "transition":
		score += 120.0
	if phase == "convert":
		score += 220.0
	if _count_named_on_field(player, BIBAREL) > 0:
		score += 90.0
	if _count_named_on_field(player, SKWOVET) > 0 and _count_named_on_field(player, BIBAREL) > 0:
		score += 70.0
	if _core_shell_complete(player):
		score += 140.0
	if _target_formation_complete(player):
		score += 220.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached := _effective_energy_count(slot) + extra_context
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
	if name == RADIANT_GARDEVOIR:
		return 240
	if name == IRON_LEAVES_EX:
		return 235
	if name == SKWOVET:
		return 180
	if name == LOST_CITY:
		return 170
	if name == LOST_VACUUM:
		return 160
	if name == MAXIMUM_BELT or name == CHOICE_BELT:
		return 150
	if name == BIBAREL:
		return 80
	if name == BIDOOF:
		return 60
	if name == DOUBLE_TURBO_ENERGY:
		return 30
	if card.card_data.is_energy():
		return 90
	return 120


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var priority := get_discard_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return priority
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if name == RADIANT_GARDEVOIR:
		return 25 if _should_deploy_radiant_gardevoir(game_state, player, player_index) else 240
	if name == IRON_LEAVES_EX:
		return 30 if _should_deploy_iron_leaves(game_state, player, player_index) else 235
	if name == DOUBLE_TURBO_ENERGY and _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0:
		return 0
	if name == GIRATINA_VSTAR and _count_named_on_field(player, GIRATINA_V) > 0 and _count_named_on_field(player, GIRATINA_VSTAR) == 0:
		return 20
	if name == BIDOOF and _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
		return 15
	return priority


func get_search_priority(card: CardInstance) -> int:
	return _search_score(card, null, -1)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", ""))
	var card_items: Array[CardInstance] = []
	for item: Variant in items:
		if item is CardInstance:
			card_items.append(item as CardInstance)
	if step_id in ["search_pokemon", "basic_pokemon", "bench_pokemon"]:
		var player := _context_player(context)
		var game_state: GameState = context.get("game_state", null)
		var phase := _detect_phase(game_state, player) if game_state != null and player != null else "launch"
		if not _should_force_exact_active_arceus_shell_build(player, phase):
			return []
		return _pick_search_pokemon_by_score(card_items, int(step.get("max_select", 1)), context)
	if step_id == "search_cards":
		var exact_launch_payload: Array = _pick_exact_launch_starbirth_search_cards(items, int(step.get("max_select", items.size())), context)
		if not exact_launch_payload.is_empty():
			return exact_launch_payload
		var exact_post_redraw_shell_finish_payload: Array = call("_pick_exact_post_redraw_shell_finish_search_cards", items, int(step.get("max_select", items.size())), context)
		if not exact_post_redraw_shell_finish_payload.is_empty():
			return exact_post_redraw_shell_finish_payload
		var closeout_payload: Array = _pick_closeout_search_cards(items, int(step.get("max_select", items.size())), context)
		if not closeout_payload.is_empty():
			return closeout_payload
	if step_id != "energy_assignments":
		return []
	if card_items.is_empty():
		return []
	return _pick_energy_assignment_sources(card_items, int(step.get("max_select", card_items.size())), context)


func should_preserve_empty_interaction_selection(step: Dictionary, context: Dictionary = {}) -> bool:
	if str(step.get("id", "")) != "energy_assignments":
		return false
	var player := _context_player(context)
	return player != null and _is_launch_online(player) and not _energy_assignment_needs_more_exact_progress(player, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_pokemon", "search_cards", "search_item"]:
			return float(_search_score(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id in ["discard_energy", "lost_zone_energy"]:
			return _score_discard_energy_target(card, context)
		if step_id in ["discard_card", "discard_cards"]:
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id == "energy_assignments":
			return _score_energy_assignment_source(card, context)
	if item is PokemonSlot and step_id in ["assignment_target", "energy_assignment", "energy_assignments"]:
		return _assignment_target_score(item as PokemonSlot, context)
	if item is PokemonSlot and step_id in ["opponent_switch_target", "opponent_bench_target"]:
		return _score_opponent_switch_target(item as PokemonSlot, context)
	if item is PokemonSlot and step_id in ["send_out", "switch_target", "self_switch_target", "pivot_target", "heavy_baton_target"]:
		return _score_handoff_target(item as PokemonSlot, step_id, context)
	return 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is PokemonSlot and step_id in ["opponent_switch_target", "opponent_bench_target"]:
		return _score_opponent_switch_target(item as PokemonSlot, context)
	if item is PokemonSlot and step_id in ["send_out", "switch_target", "self_switch_target", "pivot_target", "heavy_baton_target"]:
		return _score_handoff_target(item as PokemonSlot, step_id, context)
	return score_interaction_target(item, step, context)


func _pick_search_pokemon_by_score(card_items: Array[CardInstance], max_select: int, context: Dictionary) -> Array:
	if card_items.is_empty() or max_select <= 0:
		return []
	var scored: Array[Dictionary] = []
	for i: int in card_items.size():
		scored.append({
			"index": i,
			"card": card_items[i],
			"score": _score_search_pokemon_target(card_items[i], context),
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("score", 0.0))
		var score_b: float = float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return int(a.get("index", -1)) < int(b.get("index", -1))
		return score_a > score_b
	)
	var picked: Array = []
	for i: int in mini(max_select, scored.size()):
		picked.append(scored[i].get("card"))
	return picked


func _score_search_pokemon_target(card: CardInstance, context: Dictionary) -> float:
	return float(_search_score(card, context.get("game_state", null), int(context.get("player_index", -1))))


func _setup_priority(card_or_name: Variant, player: PlayerState) -> float:
	var name := ""
	var retreat_cost := 99
	if card_or_name is CardInstance:
		var card := card_or_name as CardInstance
		name = _card_name(card)
		if card != null and card.card_data != null:
			retreat_cost = int(card.card_data.retreat_cost)
	else:
		name = str(card_or_name)
	if name == ARCEUS_V:
		return 380.0
	if retreat_cost <= 1:
		if name == BIDOOF:
			return 300.0
		if name == SKWOVET:
			return 290.0
		return 260.0
	if name == GIRATINA_V:
		return 280.0 if _count_named_in_hand(player, ARCEUS_V) > 0 else 250.0
	if name == BIDOOF:
		return 220.0
	if name == SKWOVET:
		return 170.0
	if name == RADIANT_GARDEVOIR:
		return -120.0
	if name == IRON_LEAVES_EX:
		return -110.0
	return 100.0


func _score_play_basic(card: CardInstance, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if card == null or card.card_data == null or player.is_bench_full():
		return 0.0
	var name := _card_name(card)
	var turn_plan := _current_turn_plan(game_state, player_index, {"kind": "play_basic_to_bench", "card_name": name})
	if _should_force_exact_post_redraw_rebuild_finish_progress(game_state, player, player_index, name):
		if name == ARCEUS_V:
			return 980.0
	if _should_force_exact_post_giratina_rebuild_finish_progress(game_state, player, player_index, name):
		if name == ARCEUS_V:
			return 1000.0
	if _should_force_exact_post_redraw_shell_finish_progress(game_state, player, player_index, name):
		if name == SKWOVET:
			return 960.0
		if name == GIRATINA_V:
			return 920.0
	if _should_force_exact_rebuild_in_hand_shell_basic_before_redraw(game_state, player, player_index, name):
		if name == GIRATINA_V:
			return 900.0
		if name == BIDOOF:
			return 840.0
		if name == SKWOVET:
			return 800.0
	if _should_force_exact_in_hand_shell_basic_before_search(game_state, player, player_index, name):
		if name == GIRATINA_V:
			return 920.0
		if name == BIDOOF:
			return 860.0
		if name == SKWOVET:
			return 820.0
	if name == ARCEUS_V and _should_force_exact_second_arceus_before_launch_attack(game_state, player, player_index):
		return 760.0
	if name == ARCEUS_V and _should_force_exact_second_arceus_before_redraw_or_attack(game_state, player, player_index):
		return 980.0
	if _should_force_exact_post_giratina_shell_finish_progress(game_state, player, player_index, name):
		if name == BIDOOF:
			return 780.0
		if name == SKWOVET:
			return 680.0
	if _should_force_exact_post_redraw_shell_convert_progress(game_state, player, player_index, name):
		if name == GIRATINA_V:
			return 760.0
		if name == BIDOOF:
			return 700.0
		if name == SKWOVET:
			return 620.0
	if _has_exact_iron_leaves_closeout_progress(game_state, player, player_index) and name in [ARCEUS_V, GIRATINA_V, BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
		return 0.0
	var ready_bench_handoff := _turn_plan_flag(turn_plan, "ready_bench_attacker") and not _turn_plan_flag(turn_plan, "active_can_attack")
	var keep_backup_arceus_live := _should_force_backup_arceus_shell(game_state, player, player_index, phase)
	if _target_formation_complete(player):
		return 0.0
	if ready_bench_handoff or _active_should_hand_off_to_ready_bench(player, game_state, player_index):
		return 0.0
	if _should_cool_off_draw_churn(player):
		return 0.0
	if _should_cool_off_post_launch_shell_padding(player, phase) and name in [ARCEUS_V, BIDOOF, SKWOVET]:
		if not (name == ARCEUS_V and keep_backup_arceus_live):
			return 0.0
	if _core_shell_complete(player) and name not in [ARCEUS_V, GIRATINA_V, BIDOOF, SKWOVET]:
		return 0.0
	if name == ARCEUS_V:
		if _count_arceus_total(player) >= 2:
			return 0.0
		if keep_backup_arceus_live:
			return 420.0
		return 360.0
	if name == GIRATINA_V:
		if _count_giratina_total(player) >= 1:
			return 0.0
		return 300.0 if phase != "convert" else 190.0
	if name == BIDOOF:
		return 260.0 if _count_bibarel_line_total(player) == 0 else 0.0
	if name == SKWOVET:
		return 210.0 if _count_named_on_field(player, SKWOVET) == 0 else 0.0
	if name == RADIANT_GARDEVOIR:
		if _count_named_on_field(player, RADIANT_GARDEVOIR) > 0:
			return 0.0
		return 145.0 if _should_deploy_radiant_gardevoir(game_state, player, player_index) else -140.0
	if name == IRON_LEAVES_EX:
		if _can_iron_leaves_take_charizard_ko_this_turn(game_state, player, player_index):
			return 760.0 if phase != "launch" else 620.0
		if _should_deploy_iron_leaves(game_state, player, player_index):
			return 210.0 if phase == "convert" else 150.0
		return -120.0
	return 80.0


func _score_evolve(card: CardInstance, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if _is_exact_post_redraw_rebuild_finish_window(game_state, player, player_index):
		if name == GIRATINA_VSTAR:
			return 1040.0
		if name == BIBAREL:
			return 1020.0
	if _is_exact_post_giratina_rebuild_finish_window(game_state, player, player_index):
		if name == BIBAREL:
			return 1030.0
	if name == ARCEUS_VSTAR:
		if _should_prioritize_backup_arceus_vstar_convert_before_attack(game_state, player, player_index):
			return 1240.0
		var arceus := _best_arceus_slot(player)
		if arceus != null and _attack_energy_gap(arceus) <= 1:
			return 940.0
		return 820.0
	if name == GIRATINA_VSTAR:
		if _should_cool_off_giratina_vstar_before_arceus_owner_is_online(player):
			return 120.0
		if _best_arceus_slot(player) != null and phase != "launch":
			return 760.0
		return 620.0
	if name == BIBAREL:
		return 540.0 if _count_named_on_field(player, BIBAREL) == 0 else 260.0
	return 100.0


func _score_stadium(card: CardInstance, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name != LOST_CITY:
		return 0.0
	if game_state != null and game_state.stadium_card != null and _card_name(game_state.stadium_card) == LOST_CITY:
		return 0.0
	if phase == "convert":
		return 180.0
	if _is_launch_online(player):
		return 140.0
	return 80.0


func _score_trainer(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	var strong_launch_arceus_lock := _should_force_active_arceus_launch_line(player, phase)
	var exact_launch_conversion_search_cooloff := _should_cool_off_exact_launch_search_after_backup_arceus(player, phase)
	var exact_active_arceus_shell_build := _should_force_exact_active_arceus_shell_build(player, phase)
	var exact_trinity_nova_line := _should_force_exact_active_trinity_nova_line(player, phase)
	var turn_plan := _current_turn_plan(game_state, player_index, {"kind": "play_trainer", "card_name": name})
	var cool_off_draw_churn := _should_cool_off_draw_churn(player)
	var cool_off_conversion_churn := _should_cool_off_conversion_churn(player)
	var launch_online := _is_launch_online(player)
	var needs_transition := _needs_transition_piece(player)
	var thin_shell := _shell_is_thin(player)
	var severe_shell_gap := _needs_shell_rebuild(player)
	var hand_arceus_live := _can_bench_hand_arceus(player)
	var charizard_reentry_engine_cooloff := _should_cool_off_charizard_reentry_engine(game_state, player, player_index, phase)
	var charizard_hand_arceus_rebuild_window := _should_bench_hand_arceus_before_redraw(game_state, player, player_index)
	var ready_bench_handoff := _turn_plan_flag(turn_plan, "ready_bench_attacker") and not _turn_plan_flag(turn_plan, "active_can_attack")
	var ready_bench := _best_ready_bench(player)
	var immediate_handoff_window := ready_bench_handoff or _active_should_hand_off_to_ready_bench(player, game_state, player_index)
	var exact_iron_leaves_closeout := _has_exact_iron_leaves_closeout_progress(game_state, player, player_index)
	var exact_rebuild_redraw_before_attack := _should_force_exact_rebuild_redraw_before_attack(game_state, player, player_index, name)
	var exact_rebuild_in_hand_shell_basic_before_redraw := _should_cool_off_exact_rebuild_redraw_until_basic_benched(game_state, player, player_index, name)
	var exact_pre_starbirth_backup_progress := _should_force_exact_pre_starbirth_backup_progress(game_state, player, player_index, name)
	var exact_post_backup_vstar_redraw_finish := _should_force_exact_post_backup_vstar_redraw_finish(game_state, player, player_index, name)
	var exact_post_redraw_rebuild_finish := _should_force_exact_post_redraw_rebuild_finish_search(game_state, player, player_index, name)
	var exact_post_giratina_rebuild_finish := _should_force_exact_post_giratina_rebuild_finish_search(game_state, player, player_index, name)
	var exact_post_redraw_shell_finish := _should_cool_off_exact_post_redraw_shell_finish_search(game_state, player, player_index, name)
	var exact_post_redraw_shell_convert := _should_force_exact_post_redraw_shell_convert_progress(game_state, player, player_index, name)
	var exact_post_giratina_shell_finish := _should_force_exact_post_giratina_shell_finish_progress(game_state, player, player_index, name)
	var exact_in_hand_shell_basic_before_search := _should_cool_off_search_until_in_hand_shell_basics_are_benched(game_state, player, player_index, name)
	if exact_pre_starbirth_backup_progress:
		if name == ULTRA_BALL:
			return 920.0
		if name == CAPTURING_AROMA:
			return 860.0
		if name in [IONO, JUDGE, LOST_CITY, LOST_VACUUM]:
			return 0.0
	if exact_post_backup_vstar_redraw_finish:
		if name == JUDGE:
			return 960.0
		if name == IONO:
			return 0.0
	if exact_post_redraw_rebuild_finish:
		if name == ULTRA_BALL:
			return 860.0
		if name == CAPTURING_AROMA:
			return 820.0
		if name == NEST_BALL:
			return 780.0
		if name in [IONO, JUDGE]:
			return 0.0
	if exact_post_giratina_rebuild_finish:
		if name == ULTRA_BALL:
			return 900.0
		if name == CAPTURING_AROMA:
			return 840.0
		if name == NEST_BALL:
			return 760.0
		if name in [IONO, JUDGE]:
			return 0.0
	if exact_post_redraw_shell_finish:
		return 0.0
	if name == IONO and _should_force_exact_bridge_redraw_before_attack(turn_plan, player):
		return 1180.0
	if exact_rebuild_in_hand_shell_basic_before_redraw:
		return 0.0
	if exact_rebuild_redraw_before_attack and name in [IONO, JUDGE]:
		return 940.0 if name == JUDGE else 900.0
	if exact_post_redraw_shell_convert:
		if name == ULTRA_BALL:
			return 860.0
		if name == CAPTURING_AROMA:
			return 800.0
		if name == NEST_BALL:
			return 760.0
		if name in [IONO, JUDGE]:
			return 0.0
	if exact_post_giratina_shell_finish:
		if name == ULTRA_BALL:
			return 720.0
		if name == CAPTURING_AROMA:
			return 680.0
		if name == NEST_BALL:
			return 760.0
		if name in [IONO, JUDGE]:
			return 0.0
	if exact_in_hand_shell_basic_before_search:
		return 0.0
	if cool_off_draw_churn and name in [NEST_BALL, ULTRA_BALL, CAPTURING_AROMA, IONO, JUDGE]:
		if not severe_shell_gap:
			return 0.0
	if cool_off_conversion_churn and name in [NEST_BALL, ULTRA_BALL, CAPTURING_AROMA, IONO, JUDGE]:
		if not severe_shell_gap:
			return 0.0
	if charizard_reentry_engine_cooloff:
		if name in [IONO, JUDGE]:
			return 0.0
	if charizard_hand_arceus_rebuild_window and name in [IONO, JUDGE]:
		return 0.0
	if exact_iron_leaves_closeout and name in [IONO, JUDGE]:
		return 0.0
	if exact_active_arceus_shell_build:
		if name in [ULTRA_BALL, CAPTURING_AROMA, IONO, JUDGE, LOST_CITY, LOST_VACUUM]:
			return 0.0
	if exact_launch_conversion_search_cooloff and name in [ULTRA_BALL, NEST_BALL, CAPTURING_AROMA]:
		return 0.0
	if exact_trinity_nova_line and name in [ULTRA_BALL, NEST_BALL, CAPTURING_AROMA, IONO, JUDGE, SWITCH, LOST_CITY, LOST_VACUUM]:
		return 0.0
	if immediate_handoff_window and name in [ULTRA_BALL, NEST_BALL, CAPTURING_AROMA, IONO, JUDGE]:
		return 0.0
	if name == ULTRA_BALL:
		if _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0:
			if hand_arceus_live:
				return 280.0
			return 560.0
		if _count_arceus_total(player) == 1:
			if hand_arceus_live:
				return 300.0 if thin_shell else 250.0
			return 680.0 if thin_shell else 520.0
		if _count_named_on_field(player, ARCEUS_V) > 0 and _count_named_on_field(player, ARCEUS_VSTAR) == 0:
			return 500.0
		if _count_named_on_field(player, GIRATINA_V) == 0:
			return 470.0
		if launch_online and needs_transition:
			return 430.0
		if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
			return 360.0
		return 240.0
	if name == NEST_BALL:
		if exact_active_arceus_shell_build:
			return 760.0
		if _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0:
			if hand_arceus_live:
				return 240.0
			return 480.0
		if _count_arceus_total(player) == 1:
			if hand_arceus_live:
				return 260.0
			return 620.0 if thin_shell else 430.0
		if _count_named_on_field(player, GIRATINA_V) == 0:
			return 360.0
		if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
			return 320.0
		return 180.0
	if name == CAPTURING_AROMA:
		if _count_arceus_total(player) == 1:
			if hand_arceus_live:
				return 320.0 if thin_shell else 240.0
			return 900.0 if severe_shell_gap else (760.0 if thin_shell else 560.0)
		if _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0 and hand_arceus_live:
			return 260.0
		if _count_named_on_field(player, ARCEUS_V) > 0 and _count_named_on_field(player, ARCEUS_VSTAR) == 0:
			return 420.0
		if _count_named_on_field(player, GIRATINA_V) == 0:
			return 320.0
		if launch_online and needs_transition:
			return 300.0
		return 160.0
	if name == BOSSS_ORDERS:
		var active := player.active_pokemon
		var target_slot: PokemonSlot = action.get("target_slot", null)
		var active_ready := active != null and _attack_energy_gap(active) <= 0
		if active_ready and target_slot != null and _best_attack_damage(active) >= target_slot.get_remaining_hp():
			return 620.0
		if phase == "convert" and active_ready:
			return 180.0
		return 0.0
	if name == IONO:
		if strong_launch_arceus_lock:
			return 0.0
		if severe_shell_gap and player.hand.size() <= 4 and phase != "convert" and not _player_is_ahead_in_prizes(game_state, player_index):
			return 920.0
		if _player_is_behind_in_prizes(game_state, player_index):
			return 320.0 if player.hand.size() >= 4 else 250.0
		return 130.0 if player.hand.size() <= 3 else 80.0
	if name == JUDGE:
		if strong_launch_arceus_lock:
			return 0.0
		if _player_is_ahead_in_prizes(game_state, player_index):
			return 310.0 if phase != "launch" else 240.0
		return 150.0 if phase != "launch" else 100.0
	if name == SWITCH:
		if ready_bench_handoff or _active_should_hand_off_to_ready_bench(player, game_state, player_index):
			if ready_bench != null and _slot_name(ready_bench) == ARCEUS_VSTAR:
				return 580.0
			if ready_bench != null and _slot_name(ready_bench) == GIRATINA_VSTAR:
				return 540.0
			return 420.0
		return 80.0
	if name == LOST_CITY:
		return 170.0 if phase != "launch" else 90.0
	if name == LOST_VACUUM:
		if game_state != null and game_state.stadium_card != null:
			return 180.0
		for slot: PokemonSlot in _all_slots(game_state.players[1 - player_index] if game_state != null else null):
			if slot != null and slot.attached_tool != null:
				return 170.0
		for slot: PokemonSlot in _all_slots(player):
			if slot != null and slot.attached_tool != null:
				return 120.0
		return 0.0
	return 90.0


func _score_attach(card: CardInstance, target_slot: PokemonSlot, game_state: GameState, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var target_name := _slot_name(target_slot)
	var card_name := _card_name(card)
	var arceus_total := _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR)
	var player_index := game_state.players.find(player) if game_state != null else -1
	var turn_plan := _current_turn_plan(game_state, player_index, {"kind": "attach_energy", "target_name": target_name, "card_name": card_name})
	if _should_hold_non_arceus_attach_for_hand_arceus(player, target_slot, phase):
		return 0.0
	var exact_trinity_nova_line := _should_force_exact_active_trinity_nova_line(player, phase)
	var pivot_fallback_live := _should_enable_pivot_fallback_attach(player, target_slot, phase)
	var active_giratina_fallback_live := _should_enable_active_giratina_fallback_attach(player, target_slot, phase)
	if phase == "launch" and arceus_total == 0 and target_name not in [ARCEUS_V, ARCEUS_VSTAR] and not pivot_fallback_live and not active_giratina_fallback_live:
		return 0.0
	var arceus_ready := false
	var arceus := _best_arceus_slot(player)
	var backup_arceus := _backup_arceus_slot(player)
	var active_slot := player.active_pokemon
	var active_has_dte := active_slot != null and _count_attached_named_energy(active_slot, DOUBLE_TURBO_ENERGY) > 0
	var exact_bridge_attach_before_attack := _should_prioritize_exact_bridge_attach_before_attack(
		game_state,
		player,
		player_index,
		target_slot,
		card,
		turn_plan
	)
	if _should_force_exact_post_redraw_rebuild_finish_attach(game_state, player, player_index, target_slot, card):
		return 990.0
	if _should_force_exact_post_giratina_rebuild_finish_attach(game_state, player, player_index, target_slot, card):
		return 985.0
	if _should_force_exact_post_redraw_shell_finish_attach(game_state, player, player_index, target_slot, card):
		return 980.0
	if arceus != null:
		arceus_ready = _attack_energy_gap(arceus) <= 1
	if card_name == DOUBLE_TURBO_ENERGY:
		if target_name == ARCEUS_V or target_name == ARCEUS_VSTAR:
			if exact_trinity_nova_line and target_slot != active_slot:
				return 40.0
			if target_slot == active_slot and active_has_dte and _attack_energy_gap(target_slot) == 1:
				return 40.0
			if target_slot == active_slot and _slot_is(target_slot, [ARCEUS_VSTAR]) and _attack_energy_gap(target_slot) > 0 and _attack_energy_gap(target_slot) <= 2:
				return 760.0
			if _should_prioritize_backup_arceus_dte_convert_before_attack(game_state, player, player_index, target_slot):
				return 1210.0
			if exact_bridge_attach_before_attack:
				return 1120.0
			if target_slot == backup_arceus and arceus_ready:
				return 500.0 if _attack_energy_gap(target_slot) > 0 else 120.0
			return 520.0 if _attack_energy_gap(target_slot) > 0 else 90.0
		if target_name == GIRATINA_V or target_name == GIRATINA_VSTAR:
			return 0.0
		if pivot_fallback_live:
			return 220.0 if arceus_total == 0 else 160.0
	if card_name == JET_ENERGY:
		if target_name == ARCEUS_V or target_name == ARCEUS_VSTAR:
			return 360.0 if phase == "launch" else 180.0
		if target_name == GIRATINA_V or target_name == GIRATINA_VSTAR:
			return 320.0 if phase != "launch" or arceus_ready else 150.0
	if card.card_data.is_energy():
		if target_name == ARCEUS_V or target_name == ARCEUS_VSTAR:
			if exact_trinity_nova_line and target_slot == active_slot and card_name != DOUBLE_TURBO_ENERGY:
				return 860.0
			if exact_bridge_attach_before_attack:
				return 1100.0
			if phase == "launch":
				return 420.0 if _attack_energy_gap(target_slot) > 0 else 120.0
			if target_slot == backup_arceus and _needs_backup_arceus_energy(player):
				return 250.0
			return 160.0 if _attack_energy_gap(target_slot) > 0 else 90.0
		if target_name == GIRATINA_V or target_name == GIRATINA_VSTAR:
			if active_giratina_fallback_live:
				return 170.0
			if exact_bridge_attach_before_attack:
				return 1110.0
			return 400.0 if arceus_ready or phase != "launch" else 180.0
		if target_name == IRON_LEAVES_EX:
			if _can_iron_leaves_attack_after_manual_attach(game_state, player, game_state.players.find(player), target_slot, card):
				return 560.0
			return 180.0 if _should_deploy_iron_leaves(game_state, player, game_state.players.find(player)) else 0.0
		if pivot_fallback_live:
			return 180.0 if arceus_total == 0 else 120.0
		return 0.0
	return 0.0


func _score_use_ability(source_slot: PokemonSlot, game_state: GameState, player: PlayerState, phase: String) -> float:
	if source_slot == null:
		return 0.0
	var name := _slot_name(source_slot)
	var player_index := game_state.players.find(player) if game_state != null else -1
	var turn_plan := _current_turn_plan(game_state, player_index, {"kind": "use_ability", "source_name": name})
	var exact_trinity_nova_line := _should_force_exact_active_trinity_nova_line(player, phase)
	if _should_cool_off_charizard_reentry_engine(game_state, player, game_state.players.find(player) if game_state != null else -1, phase):
		if name in [BIBAREL, SKWOVET]:
			return 0.0
	if name == ARCEUS_VSTAR:
		if exact_trinity_nova_line:
			return 0.0
		if _should_cool_off_exact_pre_starbirth_until_backup_progress(game_state, player, player_index):
			return 0.0
		if _should_cool_off_exact_post_backup_vstar_until_redraw(game_state, player, player_index):
			return 0.0
		if _should_cool_off_exact_post_redraw_starbirth_until_shell_finish(game_state, player, player_index):
			return 0.0
		if _should_cool_off_exact_rebuild_starbirth_before_redraw(game_state, player, player_index):
			return 0.0
		if _should_require_exact_closeout_starbirth(game_state, player, player_index):
			return 0.0
		if _turn_plan_constraint(turn_plan, "prefer_exact_hand_shell_progress"):
			var exact_hand_progress_score := 180.0
			if _turn_plan_flag(turn_plan, "hand_active_dte_live"):
				exact_hand_progress_score = 120.0
			if _turn_plan_flag(turn_plan, "hand_active_dte_live") and _turn_plan_flag(turn_plan, "hand_backup_arceus_live"):
				exact_hand_progress_score = 80.0
			return exact_hand_progress_score
		var active_arceus := player.active_pokemon if player.active_pokemon != null and _slot_is(player.active_pokemon, [ARCEUS_VSTAR]) else null
		var active_needs_dte_now := active_arceus != null and _attack_energy_gap(active_arceus) > 0 and _attack_energy_gap(active_arceus) <= 2 and _count_named_in_hand(player, DOUBLE_TURBO_ENERGY) == 0
		var need_giratina := _count_named_on_field(player, GIRATINA_V) + _count_named_on_field(player, GIRATINA_VSTAR) == 0
		var need_dte := _count_named_in_hand(player, DOUBLE_TURBO_ENERGY) == 0
		var needs_transition := _needs_transition_piece(player)
		var thin_shell := _shell_is_thin(player)
		var severe_shell_gap := _needs_shell_rebuild(player)
		if active_needs_dte_now:
			return 760.0
		if severe_shell_gap:
			return 980.0
		if need_giratina or need_dte:
			return 680.0
		if thin_shell and needs_transition:
			return 620.0
		if needs_transition:
			return 540.0
		return 420.0 if phase == "launch" else 220.0
	if name == BIBAREL:
		if _should_cool_off_draw_churn(player) or _should_cool_off_conversion_churn(player):
			return 0.0
		var bonus := 0.0
		if _count_named_on_field(player, SKWOVET) > 0:
			bonus += 40.0
		return 250.0 + bonus if player.hand.size() <= 3 else 150.0 + bonus
	if name == SKWOVET:
		if _count_named_on_field(player, BIBAREL) <= 0:
			return 0.0
		if _should_cool_off_draw_churn(player) or _should_cool_off_conversion_churn(player):
			return 0.0
		return 340.0 if player.hand.size() >= 2 else 300.0
	return 0.0


func _score_attach_tool(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var card: CardInstance = action.get("card", null)
	var target_slot: PokemonSlot = action.get("target_slot", null)
	if card == null or card.card_data == null or target_slot == null or target_slot.attached_tool != null:
		return 0.0
	var tool_name := _card_name(card)
	var target_name := _slot_name(target_slot)
	if _should_force_exact_post_giratina_shell_finish_progress(game_state, player, player_index, tool_name):
		if tool_name in [MAXIMUM_BELT, CHOICE_BELT] and target_name == ARCEUS_VSTAR and target_slot == player.active_pokemon:
			return 760.0
	var opponent: PlayerState = game_state.players[1 - player_index] if game_state != null and player_index >= 0 and (1 - player_index) >= 0 and (1 - player_index) < game_state.players.size() else null
	var opponent_active: PokemonSlot = opponent.active_pokemon if opponent != null else null
	var opponent_mechanic := ""
	if opponent_active != null and opponent_active.get_card_data() != null:
		opponent_mechanic = str(opponent_active.get_card_data().mechanic)
	if tool_name == MAXIMUM_BELT:
		if bool(call("_is_exact_post_redraw_shell_finish_payload_window", game_state, player, player_index)):
			var payload_backup_arceus := _backup_arceus_slot(player)
			if payload_backup_arceus != null and target_slot == payload_backup_arceus and _slot_is(payload_backup_arceus, [ARCEUS_VSTAR]) and payload_backup_arceus.attached_tool == null:
				return 980.0
			if target_slot == player.active_pokemon:
				return 0.0
		if target_name == ARCEUS_VSTAR:
			if target_slot == player.active_pokemon and _attack_energy_gap(target_slot) <= 0:
				return 540.0 if phase != "launch" else 420.0
			if _attack_energy_gap(target_slot) <= 1:
				return 320.0
			return 120.0
		if target_name == GIRATINA_VSTAR:
			if phase == "convert" and _attack_energy_gap(target_slot) <= 0:
				return 430.0 if opponent_active != null and _is_two_prize_target(opponent_active) else 320.0
			return 140.0
		return 20.0
	if tool_name == CHOICE_BELT:
		if opponent_mechanic in ["V", "VSTAR", "VMAX"]:
			if target_name == ARCEUS_VSTAR:
				if target_slot == player.active_pokemon and _attack_energy_gap(target_slot) <= 0:
					return 460.0 if phase != "launch" else 360.0
				if _attack_energy_gap(target_slot) <= 1:
					return 280.0
			if target_name == GIRATINA_VSTAR and _attack_energy_gap(target_slot) <= 0:
				return 360.0 if phase == "convert" else 260.0
		return 20.0
	return 30.0


func _score_retreat(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if game_state == null or player.active_pokemon == null:
		return 0.0
	var active_name := _slot_name(player.active_pokemon)
	if active_name == ARCEUS_V and _should_force_active_arceus_launch_line(player, phase):
		return -320.0
	var target_slot: PokemonSlot = action.get("bench_target", null)
	if target_slot == null:
		if active_name == ARCEUS_VSTAR and _should_convert_to_giratina_finisher(game_state, player, player_index):
			for slot: PokemonSlot in player.bench:
				if slot != null and _slot_name(slot) == GIRATINA_VSTAR and _attack_energy_gap(slot) <= 0:
					target_slot = slot
					break
	if target_slot == null:
		target_slot = _best_ready_bench(player)
	var target_quality := _retreat_target_quality(target_slot)
	if active_name == ARCEUS_VSTAR:
		if _should_convert_to_giratina_finisher(game_state, player, player_index):
			if target_slot != null and _slot_name(target_slot) == GIRATINA_VSTAR and _attack_energy_gap(target_slot) <= 0:
				return 420.0
			return -120.0
		if _attack_energy_gap(player.active_pokemon) <= 0:
			return -260.0 if _core_shell_complete(player) else -220.0
		if _attack_energy_gap(player.active_pokemon) <= 1:
			return -160.0
	if target_slot == null:
		return 0.0
	if active_name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
		return 120.0 + target_quality
	if active_name == GIRATINA_V and phase == "launch" and _best_arceus_slot(player) != null:
		return 80.0 + target_quality
	return 40.0 + target_quality


func _score_attack(action: Dictionary, game_state: GameState, player_index: int, phase: String) -> float:
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	var player: PlayerState = game_state.players[player_index]
	var source_slot: PokemonSlot = action.get("source_slot", null)
	var source_name := _slot_name(source_slot)
	var attack_name := str(action.get("attack_name", ""))
	var projected_damage := int(action.get("projected_damage", 0))
	var score := 500.0 + float(projected_damage)
	if defender != null and projected_damage >= defender.get_remaining_hp():
		score += 280.0
	if phase == "transition" and source_name == ARCEUS_VSTAR and attack_name == "Trinity Nova":
		if _needs_transition_piece(player):
			score += 140.0
		else:
			score += 60.0
	if source_name == ARCEUS_VSTAR and attack_name == "Trinity Nova" and _should_cool_off_exact_post_giratina_attack_for_shell_finish(game_state, player, player_index, projected_damage):
		score -= 620.0
	if source_name == ARCEUS_VSTAR and attack_name == "Trinity Nova" and _should_cool_off_exact_post_giratina_attack_for_rebuild_finish(game_state, player, player_index, projected_damage):
		score -= 660.0
	if source_name == ARCEUS_VSTAR and attack_name == "Trinity Nova" and _should_cool_off_exact_post_redraw_attack_for_rebuild_finish(game_state, player, player_index, projected_damage):
		score -= 680.0
	if source_name == ARCEUS_VSTAR and attack_name == "Trinity Nova" and _should_cool_off_exact_post_redraw_attack_for_shell_convert(game_state, player, player_index, projected_damage):
		score -= 620.0
	if source_name == ARCEUS_VSTAR and attack_name == "Trinity Nova" and _should_cool_off_exact_rebuild_attack_for_shell_repair(game_state, player, player_index, projected_damage):
		score -= 720.0
	if phase == "convert" and source_name == GIRATINA_VSTAR:
		score += 130.0
	if phase == "convert" and source_name == ARCEUS_VSTAR and _is_giratina_ready(player):
		score -= 80.0
		if defender != null and projected_damage < defender.get_remaining_hp():
			score -= 220.0
	if source_name == ARCEUS_VSTAR and attack_name == "Trinity Nova" and _target_formation_complete(player):
		score -= 220.0
	if phase == "convert":
		score += 40.0
	return score


func _search_score(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		if name == ARCEUS_VSTAR:
			return 110
		if name == GIRATINA_VSTAR:
			return 100
		if name == ARCEUS_V:
			return 95
		if name == GIRATINA_V:
			return 88
		if name == BIBAREL:
			return 70
		return 20
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	var turn_plan := _current_turn_plan(game_state, player_index, {"step_id": "search_cards", "search_card_name": name})
	var active_arceus := player.active_pokemon if player.active_pokemon != null and _slot_is(player.active_pokemon, [ARCEUS_VSTAR]) else null
	var thin_shell := _shell_is_thin(player)
	var severe_shell_gap := _needs_shell_rebuild(player)
	var keep_backup_arceus_live := _should_force_backup_arceus_shell(game_state, player, player_index, phase)
	var ready_bench_handoff := _turn_plan_flag(turn_plan, "ready_bench_attacker") and not _turn_plan_flag(turn_plan, "active_can_attack")
	var ready_bench := _best_ready_bench(player)
	if _is_exact_pre_starbirth_backup_progress_window(game_state, player, player_index):
		if name == ARCEUS_VSTAR and _count_named_on_field(player, ARCEUS_V) > 0 and _count_named_on_field(player, ARCEUS_VSTAR) == 1:
			return 320
		if name == GIRATINA_V and _count_giratina_total(player) == 0:
			return 220
		if name == BIDOOF and _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
			return 140
		if name == SKWOVET and _count_named_on_field(player, SKWOVET) == 0:
			return 120
	if _is_exact_post_redraw_shell_convert_window(game_state, player, player_index):
		if name == GIRATINA_V and _count_giratina_total(player) == 0:
			return 280
		if name == BIDOOF and _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
			return 220
		if name == SKWOVET and _count_named_on_field(player, SKWOVET) == 0:
			return 180
	if _is_exact_post_giratina_shell_finish_window(game_state, player, player_index):
		if name == BIDOOF and _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
			return 260
		if name == MAXIMUM_BELT and active_arceus != null and active_arceus.attached_tool == null:
			return 220
		if name == SKWOVET and _count_named_on_field(player, SKWOVET) == 0:
			return 170
	if bool(call("_is_exact_post_redraw_shell_finish_payload_window", game_state, player, player_index)):
		if name == BIDOOF and _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
			return 320
		if name == MAXIMUM_BELT:
			var payload_backup_arceus := _backup_arceus_slot(player)
			if payload_backup_arceus != null and _slot_is(payload_backup_arceus, [ARCEUS_VSTAR]) and payload_backup_arceus.attached_tool == null:
				return 300
	if name == ARCEUS_V and _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0:
		return 145
	if name == ARCEUS_V and _count_arceus_total(player) == 1:
		if keep_backup_arceus_live:
			return 196
		if severe_shell_gap:
			return 172
		return 156 if _count_named_on_field(player, GIRATINA_V) + _count_named_on_field(player, GIRATINA_VSTAR) == 0 else 144
	if name == ARCEUS_VSTAR and _count_named_on_field(player, ARCEUS_V) > 0 and _count_named_on_field(player, ARCEUS_VSTAR) == 0:
		return 160
	if name == GIRATINA_V and _count_named_on_field(player, GIRATINA_V) + _count_named_on_field(player, GIRATINA_VSTAR) == 0:
		return 150 if severe_shell_gap and _count_arceus_total(player) >= 2 else (138 if _best_arceus_slot(player) != null else 124)
	if name == GIRATINA_VSTAR and _count_named_on_field(player, GIRATINA_V) > 0 and _count_named_on_field(player, GIRATINA_VSTAR) == 0:
		return 170 if _best_arceus_slot(player) != null else 118
	if name == GRASS_ENERGY or name == PSYCHIC_ENERGY:
		if phase != "launch" and _needs_transition_piece(player):
			return 150
		return 24
	if name == JET_ENERGY:
		if phase == "launch" and _best_arceus_slot(player) != null and _attack_energy_gap(_best_arceus_slot(player)) > 0:
			return 138
		if phase != "launch" and _needs_transition_piece(player):
			return 146
		return 30
	if name == DOUBLE_TURBO_ENERGY:
		if active_arceus != null and _attack_energy_gap(active_arceus) > 0 and _attack_energy_gap(active_arceus) <= 2:
			return 220
		if _count_named_on_field(player, ARCEUS_V) > 0:
			return 132
		return 36
	if name == SWITCH:
		if ready_bench_handoff or _active_should_hand_off_to_ready_bench(player, game_state, player_index):
			if ready_bench != null and _slot_name(ready_bench) == ARCEUS_VSTAR:
				return 232
			if ready_bench != null and _slot_name(ready_bench) == GIRATINA_VSTAR:
				return 224
			return 208
		return 24
	if name == BIDOOF and _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
		if keep_backup_arceus_live:
			return 84
		if severe_shell_gap and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1:
			return 166
		if thin_shell and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1:
			return 154
		if phase != "launch" and _needs_transition_piece(player):
			return 96
		return 120
	if name == BIBAREL and _count_named_on_field(player, BIDOOF) > 0 and _count_named_on_field(player, BIBAREL) == 0:
		if keep_backup_arceus_live:
			return 96
		return 156 if thin_shell and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1 else 128
	if name == SKWOVET and _count_named_on_field(player, SKWOVET) == 0:
		if keep_backup_arceus_live:
			return 76
		if severe_shell_gap and _count_bibarel_line_total(player) > 0 and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1:
			return 158
		if thin_shell and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1:
			return 148 if _count_bibarel_line_total(player) > 0 else 132
		return 116 if _count_named_on_field(player, BIBAREL) > 0 or _count_named_on_field(player, BIDOOF) > 0 else 90
	if name == RADIANT_GARDEVOIR:
		return 112 if _should_deploy_radiant_gardevoir(game_state, player, player_index) else -40
	if name == IRON_LEAVES_EX:
		return 118 if _should_deploy_iron_leaves(game_state, player, player_index) else -50
	return 20


func _assignment_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var source_card: CardInstance = context.get("source_card", null)
	var source_name := _card_name(source_card)
	var source_provides := str(source_card.card_data.energy_provides) if source_card != null and source_card.card_data != null else ""
	var slot_name := _slot_name(slot)
	var player := _context_player(context)
	var launch_online := player != null and _is_launch_online(player)
	var backup_arceus := _backup_arceus_slot(player)
	var giratina := _best_giratina_slot(player)
	if _is_exact_double_vstar_shell_distribution_window(player, context):
		if slot == backup_arceus:
			var score := 920.0
			if source_provides == "G":
				score += 40.0
			return score
		if slot == giratina:
			return 0.0
	if source_name == DOUBLE_TURBO_ENERGY:
		if slot_name == ARCEUS_VSTAR or slot_name == ARCEUS_V:
			if slot == backup_arceus and launch_online:
				return 470.0
			return 440.0
		if slot_name == GIRATINA_V or slot_name == GIRATINA_VSTAR:
			return 0.0
	if source_name == GRASS_ENERGY or source_name == PSYCHIC_ENERGY or source_name == JET_ENERGY:
		if launch_online and slot == backup_arceus:
			var backup_score := 260.0
			if _backup_arceus_needs_first_basic_progress_after_pending(slot, context):
				backup_score += 160.0
			elif _needs_backup_arceus_energy(player):
				backup_score += 70.0
			if source_name == GRASS_ENERGY:
				backup_score += 10.0
			return backup_score
		if slot == player.active_pokemon and slot_name in [ARCEUS_V, ARCEUS_VSTAR] and launch_online and _attack_energy_gap(slot) <= 0:
			if _needs_backup_arceus_energy(player) or _needs_transition_piece(player):
				return 40.0
		if launch_online and (slot_name == GIRATINA_VSTAR or slot_name == GIRATINA_V):
			var giratina_score := 300.0
			if source_name == PSYCHIC_ENERGY and _giratina_needs_type_after_pending(slot, "P", context):
				giratina_score += 180.0
			elif source_name == GRASS_ENERGY and _giratina_needs_type_after_pending(slot, "G", context):
				giratina_score += 120.0
				if _giratina_needs_type_after_pending(slot, "P", context):
					giratina_score += 120.0
			elif giratina != null and slot == giratina and _attack_gap_after_pending(slot, context) <= 1:
				giratina_score += 60.0
			return giratina_score
		if slot_name == ARCEUS_VSTAR or slot_name == ARCEUS_V:
			return 260.0
		if slot_name == GIRATINA_VSTAR or slot_name == GIRATINA_V:
			return 210.0
		if slot_name == IRON_LEAVES_EX:
			var game_state: GameState = context.get("game_state", null)
			var player_index: int = int(context.get("player_index", -1))
			return 180.0 if _should_deploy_iron_leaves(game_state, player, player_index) else 0.0
		return 0.0
	if slot_name == GIRATINA_VSTAR or slot_name == GIRATINA_V:
		return 360.0
	if slot_name == ARCEUS_VSTAR or slot_name == ARCEUS_V:
		return 300.0
	return 0.0


func _pick_energy_assignment_sources(items: Array[CardInstance], max_select: int, context: Dictionary) -> Array:
	if items.is_empty() or max_select <= 0:
		return []
	var selected: Array = []
	var remaining: Array[CardInstance] = items.duplicate()
	var player := _context_player(context)
	var giratina := _best_giratina_slot(player)
	var backup_arceus := _backup_arceus_slot(player)
	if player != null and _is_launch_online(player):
		if _is_exact_double_vstar_shell_distribution_window(player, context):
			while selected.size() < max_select:
				var previous_size := selected.size()
				_append_first_matching_energy_source(selected, remaining, max_select, ["G"])
				if selected.size() == previous_size:
					_append_first_matching_energy_source(selected, remaining, max_select, ["P"])
				if selected.size() == previous_size:
					break
			if not selected.is_empty():
				return selected
		if giratina == null and _count_giratina_total(player) == 0 and backup_arceus != null:
			while selected.size() < max_select:
				var previous_size := selected.size()
				_append_first_matching_energy_source(selected, remaining, max_select, ["G"])
				if selected.size() == previous_size:
					break
		if giratina != null and _giratina_needs_type_after_pending(giratina, "P", context):
			_append_first_matching_energy_source(selected, remaining, max_select, ["P"])
		if giratina != null and _giratina_needs_type_after_pending(giratina, "G", context):
			_append_first_matching_energy_source(selected, remaining, max_select, ["G"])
		if backup_arceus != null and _backup_arceus_needs_first_basic_progress_after_pending(backup_arceus, context):
			_append_first_matching_energy_source(selected, remaining, max_select, ["G", "P"])
		if selected.is_empty() and not _energy_assignment_needs_more_exact_progress(player, context):
			return []
		if not selected.is_empty():
			return selected
	while selected.size() < max_select and not remaining.is_empty():
		var best_card: CardInstance = null
		var best_score := -INF
		for card: CardInstance in remaining:
			var score := _score_energy_assignment_source(card, context)
			if score > best_score:
				best_score = score
				best_card = card
		if best_card == null:
			break
		selected.append(best_card)
		remaining.erase(best_card)
	return selected


func _append_first_matching_energy_source(selected: Array, remaining: Array[CardInstance], max_select: int, energy_types: Array[String]) -> void:
	if selected.size() >= max_select:
		return
	for card: CardInstance in remaining:
		if card == null or card.card_data == null:
			continue
		if energy_types.has(str(card.card_data.energy_provides)):
			selected.append(card)
			remaining.erase(card)
			return


func _energy_assignment_needs_more_exact_progress(player: PlayerState, context: Dictionary) -> bool:
	if player == null:
		return false
	var giratina := _best_giratina_slot(player)
	if giratina != null and (_giratina_needs_type_after_pending(giratina, "P", context) or _giratina_needs_type_after_pending(giratina, "G", context)):
		return true
	var backup_arceus := _backup_arceus_slot(player)
	if backup_arceus != null and _backup_arceus_needs_first_basic_progress_after_pending(backup_arceus, context):
		return true
	return false


func _score_energy_assignment_source(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var player := _context_player(context)
	var giratina := _best_giratina_slot(player)
	var provided := str(card.card_data.energy_provides)
	var score := 40.0
	if player != null and _is_launch_online(player) and giratina != null:
		if provided == "P" and _giratina_needs_type_after_pending(giratina, "P", context):
			score += 220.0
		elif provided == "G" and _giratina_needs_type_after_pending(giratina, "G", context):
			score += 180.0
		else:
			score += 80.0
	return score


func _score_discard_energy_target(card: CardInstance, context: Dictionary = {}) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var player := _context_player(context)
	if player == null or player.active_pokemon == null:
		return float(get_discard_priority(card))
	var active := player.active_pokemon
	var owner_slot := _find_attached_energy_owner_slot(player, card)
	if owner_slot == null:
		return float(get_discard_priority(card))
	var provided := str(card.card_data.energy_provides)
	if owner_slot == active and _slot_is(active, [GIRATINA_V, GIRATINA_VSTAR]):
		if provided == "G":
			return 280.0
		if provided == "P":
			return 20.0 if _attached_energy_type_count(active, "P") <= 1 else 120.0
	return 120.0 if owner_slot == active else 180.0


func _current_turn_plan(game_state: GameState, player_index: int, extra_context: Dictionary = {}) -> Dictionary:
	var turn_contract := get_turn_contract_context()
	if not turn_contract.is_empty():
		return turn_contract
	var turn_plan := get_turn_plan_context()
	if not turn_plan.is_empty():
		return turn_plan
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	return build_turn_contract(game_state, player_index, extra_context)


func _context_turn_plan(context: Dictionary, step_id: String = "") -> Dictionary:
	var turn_plan: Variant = context.get("turn_plan", {})
	if turn_plan is Dictionary and not (turn_plan as Dictionary).is_empty():
		return (turn_plan as Dictionary).duplicate(true)
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	return _current_turn_plan(game_state, player_index, {"step_id": step_id, "prompt_kind": "interaction"})


func _turn_plan_flag(turn_plan: Dictionary, flag_name: String) -> bool:
	var flags: Variant = turn_plan.get("flags", {})
	if not (flags is Dictionary):
		return false
	return bool((flags as Dictionary).get(flag_name, false))


func _turn_plan_constraint(turn_plan: Dictionary, constraint_name: String) -> bool:
	var constraints: Variant = turn_plan.get("constraints", {})
	if not (constraints is Dictionary):
		return false
	return bool((constraints as Dictionary).get(constraint_name, false))


func _turn_contract_flag(turn_contract: Dictionary, flag_name: String) -> bool:
	return _turn_plan_flag(turn_contract, flag_name)


func _turn_contract_priority_rank(turn_contract: Dictionary, priority_name: String, value: String) -> int:
	if value == "":
		return -1
	var priorities: Variant = turn_contract.get("priorities", {})
	if not (priorities is Dictionary):
		return -1
	var priority_list: Variant = (priorities as Dictionary).get(priority_name, [])
	if not (priority_list is Array):
		return -1
	for i: int in (priority_list as Array).size():
		if str((priority_list as Array)[i]) == value:
			return i
	return -1


func _turn_contract_priority_bonus(turn_contract: Dictionary, priority_name: String, value: String, first_bonus: float, later_bonus: float = 0.0) -> float:
	var rank := _turn_contract_priority_rank(turn_contract, priority_name, value)
	if rank == 0:
		return first_bonus
	if rank > 0:
		return later_bonus
	return 0.0


func _turn_contract_owner_name(turn_contract: Dictionary, field_name: String) -> String:
	var owner: Variant = turn_contract.get("owner", {})
	if not (owner is Dictionary):
		return ""
	return str((owner as Dictionary).get(field_name, ""))


func _turn_contract_search_bonus(card_name: String, turn_contract: Dictionary, player: PlayerState) -> int:
	var priorities: Variant = turn_contract.get("priorities", {})
	if not (priorities is Dictionary):
		return 0
	var shell_is_thin := _turn_contract_flag(turn_contract, "thin_shell") or _turn_contract_flag(turn_contract, "severe_shell_gap")
	var bridge_target_name: String = _turn_contract_owner_name(turn_contract, "bridge_target_name")
	var giratina := _best_giratina_slot(player)
	if not shell_is_thin and bridge_target_name in [GIRATINA_V, GIRATINA_VSTAR] and giratina != null:
		if card_name == PSYCHIC_ENERGY and _giratina_needs_type_after_pending(giratina, "P", {}):
			return 88
		if card_name == GRASS_ENERGY and _giratina_needs_type_after_pending(giratina, "G", {}):
			return 72
	var search_cards_variant: Variant = (priorities as Dictionary).get("search_cards", [])
	if search_cards_variant is Array:
		var search_cards := search_cards_variant as Array
		for i: int in search_cards.size():
			if str(search_cards[i]) != card_name:
				continue
			if i == 0:
				return 42
			if i == 1:
				return 28
			return 16
	if bridge_target_name in [GIRATINA_V, GIRATINA_VSTAR]:
		if not shell_is_thin and card_name == GIRATINA_V and _count_giratina_total(player) == 0:
			return 24
		if not shell_is_thin and card_name == GIRATINA_VSTAR and _count_named_on_field(player, GIRATINA_V) > 0 and _count_named_on_field(player, GIRATINA_VSTAR) == 0:
			return 22
	return 0


func _pick_closeout_search_cards(items: Array, max_select: int, context: Dictionary = {}) -> Array:
	if max_select <= 0:
		return []
	var game_state: GameState = context.get("game_state", null)
	var player: PlayerState = _context_player(context)
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player == null or player_index < 0:
		return []
	var turn_contract := _context_turn_plan(context, "search_cards")
	if str(turn_contract.get("intent", "")) != "close_out_prizes":
		return []
	if _turn_contract_owner_name(turn_contract, "bridge_target_name") != IRON_LEAVES_EX:
		return []
	var desired_names := _exact_closeout_search_card_names(game_state, player, player_index)
	if desired_names.is_empty():
		return []
	var picked: Array = []
	var remaining_names: Array[String] = desired_names.duplicate()
	for desired_name: String in remaining_names:
		if picked.size() >= max_select:
			break
		for item: Variant in items:
			if not (item is CardInstance) or (item as CardInstance).card_data == null:
				continue
			if picked.has(item):
				continue
			if _card_name(item as CardInstance) == desired_name:
				picked.append(item)
				break
	for item: Variant in picked:
		remaining_names.erase(_card_name(item as CardInstance))
	if not remaining_names.is_empty():
		return []
	return picked


func _pick_exact_launch_starbirth_search_cards(items: Array, max_select: int, context: Dictionary = {}) -> Array:
	if max_select <= 0:
		return []
	var game_state: GameState = context.get("game_state", null)
	var player: PlayerState = _context_player(context)
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player == null or player_index < 0:
		return []
	var phase := _detect_phase(game_state, player)
	if phase != "launch":
		return []
	var active := player.active_pokemon
	var backup_arceus := _backup_arceus_slot(player)
	if active == null or not _slot_is(active, [ARCEUS_VSTAR]):
		return []
	if backup_arceus == null or not _slot_is(backup_arceus, [ARCEUS_V]):
		return []
	if _count_attached_named_energy(active, DOUBLE_TURBO_ENERGY) != 1:
		return []
	if _attack_energy_gap(active) != 1:
		return []
	if _count_named_on_field(player, ARCEUS_VSTAR) != 1:
		return []
	if _count_named_in_hand(player, GRASS_ENERGY) > 0 or _count_named_in_hand(player, JET_ENERGY) > 0:
		return []
	var desired_names: Array[String] = [ARCEUS_VSTAR]
	if _deck_has_named(player, GRASS_ENERGY):
		desired_names.append(GRASS_ENERGY)
	else:
		return []
	var picked: Array = []
	for desired_name: String in desired_names:
		if picked.size() >= max_select:
			break
		for item: Variant in items:
			if not (item is CardInstance) or (item as CardInstance).card_data == null:
				continue
			if picked.has(item):
				continue
			if _card_name(item as CardInstance) == desired_name:
				picked.append(item)
				break
	if picked.size() != mini(max_select, desired_names.size()):
		return []
	return picked


func _pick_exact_post_redraw_shell_finish_search_cards(items: Array, max_select: int, context: Dictionary = {}) -> Array:
	if max_select <= 0:
		return []
	var game_state: GameState = context.get("game_state", null)
	var player: PlayerState = _context_player(context)
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player == null or player_index < 0:
		return []
	if not bool(call("_is_exact_post_redraw_shell_finish_payload_window", game_state, player, player_index)):
		return []
	var desired_names: Array[String] = []
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0 and _count_named_in_hand(player, BIDOOF) == 0:
		if not _deck_has_named(player, BIDOOF):
			return []
		desired_names.append(BIDOOF)
	var backup_arceus := _backup_arceus_slot(player)
	if backup_arceus != null and _slot_is(backup_arceus, [ARCEUS_VSTAR]) and backup_arceus.attached_tool == null and _count_named_in_hand(player, MAXIMUM_BELT) == 0:
		if not _deck_has_named(player, MAXIMUM_BELT):
			return []
		desired_names.append(MAXIMUM_BELT)
	if desired_names.is_empty():
		return []
	var picked: Array = []
	for desired_name: String in desired_names:
		if picked.size() >= max_select:
			break
		for item: Variant in items:
			if not (item is CardInstance) or (item as CardInstance).card_data == null:
				continue
			if picked.has(item):
				continue
			if _card_name(item as CardInstance) == desired_name:
				picked.append(item)
				break
	if picked.size() != mini(max_select, desired_names.size()):
		return []
	return picked


func _exact_closeout_search_card_names(game_state: GameState, player: PlayerState, player_index: int) -> Array[String]:
	var needs_search: Array[String] = []
	var on_board_iron_leaves := _best_on_board_iron_leaves_slot(player)
	var active_iron_leaves := player.active_pokemon != null and _slot_name(player.active_pokemon) == IRON_LEAVES_EX
	var hand_iron_leaves_count := _count_named_in_hand(player, IRON_LEAVES_EX)
	var deck_has_iron_leaves := _deck_has_named(player, IRON_LEAVES_EX)
	var retreat_ready := player.active_pokemon != null and player.active_pokemon.get_card_data() != null and _effective_energy_count(player.active_pokemon) >= int(player.active_pokemon.get_card_data().retreat_cost)
	var has_switch_in_hand := _count_named_in_hand(player, SWITCH) > 0
	var needs_switch := false
	if on_board_iron_leaves != null and not active_iron_leaves and not retreat_ready and not has_switch_in_hand:
		needs_switch = true
		needs_search.append(SWITCH)
	if on_board_iron_leaves == null and hand_iron_leaves_count <= 0:
		if not deck_has_iron_leaves:
			return []
		needs_search.append(IRON_LEAVES_EX)
	var closeout_slot: PokemonSlot = on_board_iron_leaves
	if closeout_slot == null and hand_iron_leaves_count > 0:
		closeout_slot = _virtual_iron_leaves_slot()
	if closeout_slot == null and deck_has_iron_leaves:
		closeout_slot = _virtual_iron_leaves_slot()
	if closeout_slot == null:
		return []
	var energy_need := _iron_leaves_missing_closeout_energy(game_state, player, closeout_slot, closeout_slot == on_board_iron_leaves, needs_switch)
	if energy_need == "":
		return needs_search
	if energy_need != GRASS_ENERGY:
		return []
	if game_state.energy_attached_this_turn:
		return []
	if _count_named_in_hand(player, GRASS_ENERGY) > 0:
		return needs_search
	if not _deck_has_named(player, GRASS_ENERGY):
		return []
	needs_search.append(GRASS_ENERGY)
	return needs_search


func _iron_leaves_missing_closeout_energy(
	game_state: GameState,
	player: PlayerState,
	iron_leaves: PokemonSlot,
	is_on_board_copy: bool,
	needs_switch: bool
) -> String:
	if game_state == null or player == null or iron_leaves == null:
		return ""
	if is_on_board_copy:
		if _iron_leaves_prism_edge_locked_this_turn(iron_leaves, game_state):
			return "blocked"
		if needs_switch:
			# Search payload can still carry Switch, so only energy is evaluated here.
			pass
		var current_energy := _effective_energy_count(iron_leaves)
		var current_grass := _attached_energy_type_count(iron_leaves, "G")
		if current_energy >= 3 and current_grass >= 2:
			return ""
		if current_energy == 2 and current_grass == 1:
			return GRASS_ENERGY
		return "blocked"
	var movable_energy := _count_movable_iron_leaves_energy(player)
	var movable_grass := _count_movable_iron_leaves_grass(player)
	if movable_energy >= 3 and movable_grass >= 2:
		return ""
	if movable_energy == 2 and movable_grass == 1:
		return GRASS_ENERGY
	return "blocked"


func _virtual_iron_leaves_slot() -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_make_virtual_iron_leaves_card_data(), -1))
	return slot


func _make_virtual_iron_leaves_card_data() -> CardData:
	var cd := CardData.new()
	cd.name = IRON_LEAVES_EX
	cd.name_en = IRON_LEAVES_EX
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = "G"
	cd.hp = 220
	cd.mechanic = "ex"
	cd.attacks.append({"name": "Prism Edge", "cost": "GGC", "damage": "180"})
	return cd


func _deck_has_named(player: PlayerState, card_name: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and _card_name(card) == card_name:
			return true
	return false


func _should_require_exact_closeout_starbirth(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player_index < 0:
		return false
	var turn_contract := _current_turn_plan(game_state, player_index, {"kind": "use_ability", "source_name": ARCEUS_VSTAR})
	if str(turn_contract.get("intent", "")) != "close_out_prizes":
		return false
	if _turn_contract_owner_name(turn_contract, "bridge_target_name") != IRON_LEAVES_EX:
		return false
	return _exact_closeout_search_card_names(game_state, player, player_index).is_empty()


func _has_exact_iron_leaves_closeout_progress(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var turn_contract := _current_turn_plan(game_state, player_index, {"kind": "closeout_progress_check"})
	if str(turn_contract.get("intent", "")) != "close_out_prizes":
		return false
	if _turn_contract_owner_name(turn_contract, "bridge_target_name") != IRON_LEAVES_EX:
		return false
	var iron_leaves := _best_on_board_iron_leaves_slot(player)
	if iron_leaves == null or _iron_leaves_prism_edge_locked_this_turn(iron_leaves, game_state):
		return false
	if not _can_make_slot_active_this_turn(player, iron_leaves):
		return false
	var current_energy := _effective_energy_count(iron_leaves)
	var current_grass := _attached_energy_type_count(iron_leaves, "G")
	if current_energy >= 3 and current_grass >= 2:
		return true
	if game_state.energy_attached_this_turn:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		if _can_iron_leaves_attack_after_manual_attach(game_state, player, player_index, iron_leaves, card):
			return true
	return false


func _can_make_slot_active_this_turn(player: PlayerState, slot: PokemonSlot) -> bool:
	if player == null or slot == null:
		return false
	if player.active_pokemon == slot:
		return true
	if _count_named_in_hand(player, SWITCH) > 0:
		return true
	if player.active_pokemon == null or player.active_pokemon.get_card_data() == null:
		return false
	return _effective_energy_count(player.active_pokemon) >= int(player.active_pokemon.get_card_data().retreat_cost)


func _can_make_iron_leaves_active_this_turn(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if slot != null and _slot_name(slot) == IRON_LEAVES_EX and _can_make_slot_active_this_turn(player, slot):
			return true
	return player.active_pokemon != null and _slot_name(player.active_pokemon) == IRON_LEAVES_EX


func _detect_phase(game_state: GameState, player: PlayerState) -> String:
	if player == null:
		return "launch"
	if _target_formation_complete(player):
		return "convert"
	if _is_launch_online(player):
		var giratina := _best_giratina_slot(player)
		if giratina != null and _attack_energy_gap(giratina) <= 1:
			return "convert"
		return "transition"
	if _has_post_launch_reentry_lane(player):
		var reentry_giratina := _best_giratina_slot(player)
		if reentry_giratina != null and _attack_energy_gap(reentry_giratina) <= 0:
			return "convert"
		return "transition"
	return "launch"


func _is_launch_online(player: PlayerState) -> bool:
	var arceus := _best_arceus_slot(player)
	if arceus == null:
		return false
	return _slot_name(arceus) == ARCEUS_VSTAR and _attack_energy_gap(arceus) <= 0


func _needs_transition_piece(player: PlayerState) -> bool:
	var giratina := _best_giratina_slot(player)
	if giratina == null:
		return true
	if _slot_name(giratina) == GIRATINA_V and _count_named_in_hand(player, GIRATINA_VSTAR) == 0:
		return true
	return _attack_energy_gap(giratina) > 1


func _is_giratina_ready(player: PlayerState) -> bool:
	var giratina := _best_giratina_slot(player)
	if giratina == null:
		return false
	return _slot_name(giratina) == GIRATINA_VSTAR and _attack_energy_gap(giratina) <= 0


func _has_post_launch_reentry_lane(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_arceus_total(player) <= 0:
		return false
	var giratina := _best_giratina_slot(player)
	if giratina == null or _slot_name(giratina) != GIRATINA_VSTAR:
		return false
	return _attack_energy_gap(giratina) <= 1


func _context_player(context: Dictionary) -> PlayerState:
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _pending_assignment_count(slot: PokemonSlot, context: Dictionary) -> int:
	if slot == null or context.is_empty():
		return 0
	var pending_assignment_counts: Variant = context.get("pending_assignment_counts", {})
	if not (pending_assignment_counts is Dictionary):
		return 0
	return int((pending_assignment_counts as Dictionary).get(int(slot.get_instance_id()), 0))


func _pending_energy_type_count(slot: PokemonSlot, energy_type: String, context: Dictionary) -> int:
	if slot == null or context.is_empty():
		return 0
	var pending_assignments: Variant = context.get("pending_assignments", [])
	if not (pending_assignments is Array):
		return 0
	var total := 0
	for entry: Variant in pending_assignments:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		if assignment.get("target", null) != slot:
			continue
		var source_card: Variant = assignment.get("source", null)
		if not (source_card is CardInstance) or (source_card as CardInstance).card_data == null:
			continue
		if str((source_card as CardInstance).card_data.energy_provides) == energy_type:
			total += 1
	return total


func _attached_energy_type_count(slot: PokemonSlot, energy_type: String) -> int:
	if slot == null:
		return 0
	var total := 0
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if str(energy.card_data.energy_provides) == energy_type:
			total += 1
	return total


func _find_attached_energy_owner_slot(player: PlayerState, energy_card: CardInstance) -> PokemonSlot:
	if player == null or energy_card == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if slot == null:
			continue
		if energy_card in slot.attached_energy:
			return slot
	return null


func _count_attached_named_energy(slot: PokemonSlot, target_name: String) -> int:
	if slot == null or target_name == "":
		return 0
	var total := 0
	for energy: CardInstance in slot.attached_energy:
		if _card_name(energy) == target_name:
			total += 1
	return total


func _giratina_needs_type_after_pending(slot: PokemonSlot, energy_type: String, context: Dictionary) -> bool:
	if slot == null or not _slot_is(slot, [GIRATINA_V, GIRATINA_VSTAR]):
		return false
	return _attached_energy_type_count(slot, energy_type) + _pending_energy_type_count(slot, energy_type, context) <= 0


func _backup_arceus_needs_first_basic_progress_after_pending(slot: PokemonSlot, context: Dictionary) -> bool:
	if slot == null or not _slot_is(slot, [ARCEUS_V, ARCEUS_VSTAR]):
		return false
	return _effective_energy_count(slot) + _pending_assignment_count(slot, context) <= 0


func _attack_gap_after_pending(slot: PokemonSlot, context: Dictionary, additional_energy: int = 0) -> int:
	return maxi(0, _attack_energy_gap(slot) - _pending_assignment_count(slot, context) - additional_energy)


func _best_arceus_slot(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var slot_name := _slot_name(slot)
		if slot_name != ARCEUS_V and slot_name != ARCEUS_VSTAR:
			continue
		var score := float(slot.attached_energy.size()) * 55.0
		if slot_name == ARCEUS_VSTAR:
			score += 220.0
		if slot == player.active_pokemon:
			score += 40.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _backup_arceus_slot(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in player.bench:
		var slot_name := _slot_name(slot)
		if slot_name != ARCEUS_V and slot_name != ARCEUS_VSTAR:
			continue
		var score := float(_effective_energy_count(slot)) * 50.0
		if slot_name == ARCEUS_VSTAR:
			score += 180.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_giratina_slot(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var slot_name := _slot_name(slot)
		if slot_name != GIRATINA_V and slot_name != GIRATINA_VSTAR:
			continue
		var score := float(slot.attached_energy.size()) * 50.0
		if slot_name == GIRATINA_VSTAR:
			score += 180.0
		if slot == player.active_pokemon:
			score += 30.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_ready_bench(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in player.bench:
		if slot != null and _attack_energy_gap(slot) <= 0 and _best_attack_damage(slot) > 0:
			return slot
	return null


func _retreat_target_quality(slot: PokemonSlot) -> float:
	if slot == null:
		return -220.0
	var name := _slot_name(slot)
	if name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
		return -220.0
	var score := float(_best_attack_damage(slot)) * 0.6
	var gap := _attack_energy_gap(slot)
	if gap <= 0:
		score += 200.0
	elif gap == 1:
		score += 60.0
	if name == GIRATINA_VSTAR:
		score += 120.0
	elif name == ARCEUS_VSTAR:
		score += 100.0
	elif name == GIRATINA_V:
		score += 40.0
	elif name == ARCEUS_V:
		score += 20.0
	return score


func _send_out_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var player := _context_player(context)
	var score := 100.0 + float(_best_attack_damage(slot))
	var name := _slot_name(slot)
	if name == ARCEUS_VSTAR:
		score += 220.0
		if player != null and slot == _backup_arceus_slot(player):
			score += 120.0
	elif name == ARCEUS_V:
		score += 120.0
	elif name == GIRATINA_VSTAR:
		score += 180.0
	elif name == GIRATINA_V:
		score += 80.0
	elif name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
		score -= 260.0
	if player != null:
		if _slot_name(slot) == ARCEUS_VSTAR and _attack_energy_gap(slot) <= 0:
			score += 160.0
		if _slot_name(slot) == GIRATINA_VSTAR and _attack_energy_gap(slot) <= 0:
			score += 90.0
		if _is_launch_online(player):
			if name == ARCEUS_VSTAR:
				score += 160.0
			elif name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
				score -= 120.0
	return score


func _score_handoff_target(slot: PokemonSlot, step_id: String, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var player := _context_player(context)
	if player == null:
		return _send_out_target_score(slot, context)
	var game_state: GameState = context.get("game_state", null)
	var phase := _detect_phase(game_state, player)
	var turn_plan := _context_turn_plan(context, step_id)
	var name := _slot_name(slot)
	var is_ready := _attack_energy_gap(slot) <= 0 and _best_attack_damage(slot) > 0
	var is_near_ready := _attack_energy_gap(slot) == 1 and _best_attack_damage(slot) > 0
	var score := float(_best_attack_damage(slot)) * 0.8
	var pivot_target_name := _turn_contract_owner_name(turn_plan, "pivot_target_name")
	if name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
		score -= 360.0
	if step_id in ["self_switch_target", "switch_target", "pivot_target", "heavy_baton_target"]:
		score += 25.0
	if phase == "launch":
		if name == ARCEUS_VSTAR:
			score += 620.0 if is_ready else (500.0 if is_near_ready else 300.0)
		elif name == ARCEUS_V:
			score += 420.0 if is_near_ready else 240.0
		elif name == GIRATINA_VSTAR:
			score += 240.0 if is_ready else (170.0 if is_near_ready else 80.0)
		elif name == GIRATINA_V:
			score += 190.0 if is_near_ready else 100.0
		return score
	if name == GIRATINA_VSTAR:
		score += 760.0 if is_ready else (560.0 if is_near_ready else 260.0)
	elif name == GIRATINA_V:
		score += 420.0 if is_near_ready else (240.0 if is_ready else 130.0)
	elif name == ARCEUS_VSTAR:
		score += 620.0 if is_ready else (340.0 if is_near_ready else 180.0)
	elif name == ARCEUS_V:
		score += 220.0 if is_near_ready else 90.0
	if _is_giratina_ready(player):
		if name == GIRATINA_VSTAR:
			score += 180.0
		elif name == ARCEUS_VSTAR:
			score -= 140.0
		elif name == ARCEUS_V:
			score -= 80.0
	if _has_post_launch_reentry_lane(player):
		if name == GIRATINA_VSTAR and _attack_energy_gap(slot) <= 1:
			score += 120.0
		elif name == ARCEUS_VSTAR and _attack_energy_gap(slot) <= 0:
			score -= 60.0
	return score


func _score_opponent_switch_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player: PlayerState = _context_player(context)
	if game_state == null or player == null or player.active_pokemon == null:
		return 0.0
	var turn_plan := _context_turn_plan(context, "opponent_switch_target")
	var projected_damage := _estimate_active_damage_against_target(player, game_state, slot)
	var remaining_hp := slot.get_remaining_hp()
	var can_knock_out := projected_damage >= remaining_hp and projected_damage > 0
	var score := 0.0
	if _is_two_prize_target(slot):
		score += 180.0
	if can_knock_out:
		score += 460.0
	else:
		score -= 120.0
	if str(turn_plan.get("intent", "")) == "bridge_to_finisher":
		if can_knock_out:
			score += 140.0
		score += _turn_contract_priority_bonus(turn_plan, "search", _slot_name(slot), 40.0, 20.0)
	if _slot_name(player.active_pokemon) == ARCEUS_VSTAR:
		if _slot_name(slot) == "Miraidon ex" and can_knock_out:
			score += 120.0
		if _slot_name(slot) == "Iron Hands ex" and not can_knock_out:
			score -= 180.0
	return score


func _should_prioritize_backup_arceus_vstar_convert_before_attack(
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> bool:
	if game_state == null or player == null or player_index < 0:
		return false
	var active_slot := player.active_pokemon
	if active_slot == null or not _slot_is(active_slot, [ARCEUS_VSTAR]):
		return false
	if _attack_energy_gap(active_slot) > 0:
		return false
	var backup_arceus := _backup_arceus_slot(player)
	if backup_arceus == null or not _slot_is(backup_arceus, [ARCEUS_V]):
		return false
	if _count_attached_named_energy(backup_arceus, DOUBLE_TURBO_ENERGY) <= 0:
		return false
	if _count_named_in_hand(player, ARCEUS_VSTAR) <= 0:
		return false
	return _count_attached_basic_energy_local(backup_arceus) > 0


func _should_prioritize_backup_arceus_dte_convert_before_attack(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	target_slot: PokemonSlot
) -> bool:
	if game_state == null or player == null or player_index < 0 or target_slot == null:
		return false
	var active_slot := player.active_pokemon
	if active_slot == null or not _slot_is(active_slot, [ARCEUS_VSTAR]):
		return false
	if _attack_energy_gap(active_slot) > 0:
		return false
	var backup_arceus := _backup_arceus_slot(player)
	if backup_arceus == null or target_slot != backup_arceus or not _slot_is(backup_arceus, [ARCEUS_V]):
		return false
	if _count_attached_named_energy(backup_arceus, DOUBLE_TURBO_ENERGY) > 0:
		return false
	return _count_attached_basic_energy_local(backup_arceus) > 0


func _should_force_exact_bridge_redraw_before_attack(turn_plan: Dictionary, player: PlayerState) -> bool:
	if player == null:
		return false
	if str(turn_plan.get("intent", "")) != "bridge_to_finisher":
		return false
	if not _turn_plan_flag(turn_plan, "active_can_attack"):
		return false
	if not _turn_plan_flag(turn_plan, "backup_arceus_missing"):
		return false
	if not _turn_plan_flag(turn_plan, "needs_transition_piece"):
		return false
	if not _turn_plan_flag(turn_plan, "thin_shell"):
		return false
	if player.hand.size() != 1:
		return false
	return _count_named_on_field(player, BIBAREL) <= 0 and _count_named_on_field(player, GIRATINA_VSTAR) <= 0


func _is_exact_rebuild_shell_redraw_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) < 2:
		return false
	if _count_giratina_total(player) > 0:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_named_on_field(player, SKWOVET) > 0:
		return false
	if player.hand.size() <= 0 or player.hand.size() > 2:
		return false
	if game_state.supporter_used_this_turn:
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	return _attack_energy_gap(player.active_pokemon) <= 0 and _best_attack_damage(player.active_pokemon) > 0


func _is_exact_pre_redraw_shell_rebuild_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if game_state.supporter_used_this_turn:
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) != 1:
		return false
	if _count_named_on_field(player, ARCEUS_V) <= 0:
		return false
	if _count_giratina_total(player) > 0:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_named_on_field(player, SKWOVET) > 0:
		return false
	if player.hand.size() <= 0 or player.hand.size() > 5:
		return false
	var has_redraw := false
	var has_backup_progress := false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var card_name := _card_name(card)
		if card_name in [IONO, JUDGE]:
			has_redraw = true
		if card_name in [ULTRA_BALL, CAPTURING_AROMA, ARCEUS_VSTAR]:
			has_backup_progress = true
	if not has_redraw or not has_backup_progress:
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	if _attack_energy_gap(player.active_pokemon) > 0:
		return false
	return _estimate_active_damage_against_target(player, game_state, defender) < defender.get_remaining_hp()


func _should_cool_off_exact_rebuild_starbirth_before_redraw(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	return _is_exact_pre_redraw_shell_rebuild_window(game_state, player, player_index)


func _is_exact_post_backup_vstar_redraw_finish_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if game_state.supporter_used_this_turn:
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) < 2:
		return false
	if _count_giratina_total(player) > 0:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_named_on_field(player, SKWOVET) > 0:
		return false
	if _count_attached_named_energy(player.active_pokemon, DOUBLE_TURBO_ENERGY) != 1:
		return false
	if _attack_energy_gap(player.active_pokemon) != 1:
		return false
	if player.hand.size() != 1:
		return false
	return _count_named_in_hand(player, JUDGE) == 1


func _should_cool_off_exact_post_backup_vstar_until_redraw(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	return _is_exact_post_backup_vstar_redraw_finish_window(game_state, player, player_index)


func _is_exact_pre_starbirth_backup_progress_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if game_state.supporter_used_this_turn:
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) != 1:
		return false
	if _count_named_on_field(player, ARCEUS_V) <= 0:
		return false
	if _count_giratina_total(player) > 0:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_named_on_field(player, SKWOVET) > 0:
		return false
	if player.hand.size() <= 0 or player.hand.size() > 5:
		return false
	if _count_named_in_hand(player, DOUBLE_TURBO_ENERGY) > 0:
		return false
	var has_redraw := false
	var has_backup_progress := false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var card_name := _card_name(card)
		if card_name in [IONO, JUDGE]:
			has_redraw = true
		if card_name in [ULTRA_BALL, CAPTURING_AROMA]:
			has_backup_progress = true
	if not has_redraw or not has_backup_progress:
		return false
	return _attack_energy_gap(player.active_pokemon) > 0 and _attack_energy_gap(player.active_pokemon) <= 2


func _should_cool_off_exact_pre_starbirth_until_backup_progress(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	return _is_exact_pre_starbirth_backup_progress_window(game_state, player, player_index)


func _should_force_exact_pre_starbirth_backup_progress(game_state: GameState, player: PlayerState, player_index: int, card_name: String) -> bool:
	if card_name not in [ULTRA_BALL, CAPTURING_AROMA, IONO, JUDGE, LOST_CITY, LOST_VACUUM]:
		return false
	return _is_exact_pre_starbirth_backup_progress_window(game_state, player, player_index)


func _should_force_exact_post_backup_vstar_redraw_finish(game_state: GameState, player: PlayerState, player_index: int, card_name: String) -> bool:
	if card_name not in [JUDGE, IONO]:
		return false
	return _is_exact_post_backup_vstar_redraw_finish_window(game_state, player, player_index)


func _should_force_exact_rebuild_redraw_before_attack(game_state: GameState, player: PlayerState, player_index: int, trainer_name: String) -> bool:
	if trainer_name not in [IONO, JUDGE]:
		return false
	if not _is_exact_rebuild_shell_redraw_window(game_state, player, player_index):
		return false
	if _has_exact_rebuild_shell_basic_waiting(player):
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	if _estimate_active_damage_against_target(player, game_state, defender) >= defender.get_remaining_hp():
		return false
	var seen_trainer := false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			return false
		var card_name := _card_name(card)
		if card_name == trainer_name:
			seen_trainer = true
			continue
		if card_name not in [GIRATINA_V, BIDOOF, SKWOVET, GRASS_ENERGY, PSYCHIC_ENERGY, MAXIMUM_BELT]:
			return false
	return seen_trainer


func _should_cool_off_exact_rebuild_attack_for_shell_repair(game_state: GameState, player: PlayerState, player_index: int, projected_damage: int) -> bool:
	if not _is_exact_rebuild_shell_redraw_window(game_state, player, player_index):
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	return projected_damage < defender.get_remaining_hp()


func _has_exact_rebuild_shell_basic_waiting(player: PlayerState) -> bool:
	if player == null:
		return false
	var priority_basic := _exact_post_redraw_shell_priority_basic(player)
	if priority_basic == "":
		return false
	return _count_named_in_hand(player, priority_basic) > 0


func _should_force_exact_rebuild_in_hand_shell_basic_before_redraw(game_state: GameState, player: PlayerState, player_index: int, card_name: String) -> bool:
	if card_name not in [GIRATINA_V, BIDOOF, SKWOVET]:
		return false
	if not _is_exact_rebuild_shell_redraw_window(game_state, player, player_index):
		return false
	if _count_named_in_hand(player, card_name) <= 0:
		return false
	return _exact_post_redraw_shell_priority_basic(player) == card_name


func _should_cool_off_exact_rebuild_redraw_until_basic_benched(game_state: GameState, player: PlayerState, player_index: int, trainer_name: String) -> bool:
	if trainer_name not in [IONO, JUDGE]:
		return false
	if not _is_exact_rebuild_shell_redraw_window(game_state, player, player_index):
		return false
	return _has_exact_rebuild_shell_basic_waiting(player)


func _is_exact_post_redraw_rebuild_finish_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not game_state.supporter_used_this_turn:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) != 1:
		return false
	if _count_named_on_field(player, GIRATINA_V) != 1 or _count_named_on_field(player, GIRATINA_VSTAR) > 0:
		return false
	if _count_named_on_field(player, BIDOOF) <= 0 or _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_named_on_field(player, SKWOVET) <= 0:
		return false
	if _count_arceus_total(player) > 2:
		return false
	if _count_arceus_total(player) == 2:
		var backup_arceus := _backup_arceus_slot(player)
		if backup_arceus == null or not _slot_is(backup_arceus, [ARCEUS_V]):
			return false
	if player.hand.size() <= 0 or player.hand.size() > 6:
		return false
	var giratina := _best_giratina_slot(player)
	if not _is_exact_rebuild_finish_giratina_one_step_short(giratina):
		return false
	if _attack_energy_gap(player.active_pokemon) > 0:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var card_name := _card_name(card)
		if card_name in [GIRATINA_VSTAR, BIBAREL, ARCEUS_V, ULTRA_BALL, NEST_BALL, CAPTURING_AROMA, PSYCHIC_ENERGY]:
			return true
	return false


func _should_force_exact_post_redraw_rebuild_finish_progress(game_state: GameState, player: PlayerState, player_index: int, card_name: String) -> bool:
	if card_name != ARCEUS_V:
		return false
	if not _is_exact_post_redraw_rebuild_finish_window(game_state, player, player_index):
		return false
	return _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) < 2


func _should_force_exact_post_redraw_rebuild_finish_search(game_state: GameState, player: PlayerState, player_index: int, trainer_name: String) -> bool:
	if trainer_name not in [ULTRA_BALL, NEST_BALL, CAPTURING_AROMA, IONO, JUDGE]:
		return false
	if not _is_exact_post_redraw_rebuild_finish_window(game_state, player, player_index):
		return false
	if trainer_name in [IONO, JUDGE]:
		return true
	return _count_named_in_hand(player, GIRATINA_VSTAR) <= 0 or _count_named_in_hand(player, BIBAREL) <= 0 or _count_arceus_total(player) < 2


func _should_force_exact_post_redraw_rebuild_finish_attach(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	target_slot: PokemonSlot,
	card: CardInstance
) -> bool:
	if card == null or target_slot == null:
		return false
	if not _is_exact_post_redraw_rebuild_finish_window(game_state, player, player_index):
		return false
	if _card_name(card) != PSYCHIC_ENERGY:
		return false
	return _slot_is(target_slot, [ARCEUS_V]) and _count_attached_basic_energy_local(target_slot) <= 0


func _is_exact_rebuild_finish_giratina_one_step_short(slot: PokemonSlot) -> bool:
	if slot == null or not _slot_is(slot, [GIRATINA_V, GIRATINA_VSTAR]):
		return false
	var slot_data := slot.get_card_data()
	if slot_data != null and not slot_data.attacks.is_empty():
		return _attack_energy_gap(slot) <= 1
	var total_energy := _effective_energy_count(slot)
	var grass_count := _attached_energy_type_count(slot, "G")
	var psychic_count := _attached_energy_type_count(slot, "P")
	return total_energy == 2 and grass_count >= 1 and psychic_count >= 1


func _is_exact_post_giratina_rebuild_finish_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not game_state.supporter_used_this_turn:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) != 1:
		return false
	if _count_named_on_field(player, GIRATINA_VSTAR) != 1 or _count_named_on_field(player, GIRATINA_V) > 0:
		return false
	if _count_named_on_field(player, BIDOOF) <= 0 or _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_named_on_field(player, SKWOVET) <= 0:
		return false
	if _count_arceus_total(player) > 2:
		return false
	if _count_arceus_total(player) == 2:
		var backup_arceus := _backup_arceus_slot(player)
		if backup_arceus == null or not _slot_is(backup_arceus, [ARCEUS_V]):
			return false
	if player.hand.size() <= 0 or player.hand.size() > 8:
		return false
	if _attack_energy_gap(player.active_pokemon) > 0:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var card_name := _card_name(card)
		if card_name in [BIBAREL, ARCEUS_V, ULTRA_BALL, NEST_BALL, CAPTURING_AROMA, PSYCHIC_ENERGY]:
			return true
	return false


func _should_force_exact_post_giratina_rebuild_finish_progress(game_state: GameState, player: PlayerState, player_index: int, card_name: String) -> bool:
	if card_name != ARCEUS_V:
		return false
	if not _is_exact_post_giratina_rebuild_finish_window(game_state, player, player_index):
		return false
	return _count_arceus_total(player) < 2


func _should_force_exact_post_giratina_rebuild_finish_search(game_state: GameState, player: PlayerState, player_index: int, trainer_name: String) -> bool:
	if trainer_name not in [ULTRA_BALL, NEST_BALL, CAPTURING_AROMA, IONO, JUDGE]:
		return false
	if not _is_exact_post_giratina_rebuild_finish_window(game_state, player, player_index):
		return false
	if trainer_name in [IONO, JUDGE]:
		return true
	return _count_named_in_hand(player, BIBAREL) <= 0 or _count_arceus_total(player) < 2


func _should_force_exact_post_giratina_rebuild_finish_attach(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	target_slot: PokemonSlot,
	card: CardInstance
) -> bool:
	if card == null or target_slot == null:
		return false
	if not _is_exact_post_giratina_rebuild_finish_window(game_state, player, player_index):
		return false
	if _card_name(card) != PSYCHIC_ENERGY:
		return false
	return _slot_is(target_slot, [ARCEUS_V]) and _count_attached_basic_energy_local(target_slot) <= 0


func _is_exact_post_redraw_shell_convert_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) < 2:
		return false
	if not game_state.supporter_used_this_turn:
		return false
	if _count_giratina_total(player) > 0:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_named_on_field(player, SKWOVET) > 0:
		return false
	if player.hand.size() <= 0 or player.hand.size() > 5:
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	if _attack_energy_gap(player.active_pokemon) > 0:
		return false
	if _estimate_active_damage_against_target(player, game_state, defender) >= defender.get_remaining_hp():
		return false
	var has_progress_piece := false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			return false
		var card_name := _card_name(card)
		if card_name in [GIRATINA_V, BIDOOF, SKWOVET, ULTRA_BALL, NEST_BALL, CAPTURING_AROMA]:
			has_progress_piece = true
	return has_progress_piece


func _should_force_exact_post_redraw_shell_convert_progress(game_state: GameState, player: PlayerState, player_index: int, card_name: String) -> bool:
	if not _is_exact_post_redraw_shell_convert_window(game_state, player, player_index):
		return false
	return card_name in [GIRATINA_V, BIDOOF, SKWOVET, ULTRA_BALL, NEST_BALL, CAPTURING_AROMA]


func _has_exact_in_hand_shell_basic_waiting(player: PlayerState) -> bool:
	if player == null:
		return false
	var priority_basic := _exact_post_redraw_shell_priority_basic(player)
	if priority_basic == "":
		return false
	return _count_named_in_hand(player, priority_basic) > 0


func _exact_post_redraw_shell_priority_basic(player: PlayerState) -> String:
	if player == null:
		return ""
	if _count_giratina_total(player) <= 0:
		return GIRATINA_V
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) <= 0:
		return BIDOOF
	if _count_named_on_field(player, SKWOVET) <= 0:
		return SKWOVET
	return ""


func _should_force_exact_in_hand_shell_basic_before_search(game_state: GameState, player: PlayerState, player_index: int, card_name: String) -> bool:
	if card_name not in [GIRATINA_V, BIDOOF, SKWOVET]:
		return false
	if not _is_exact_post_redraw_shell_convert_window(game_state, player, player_index):
		return false
	if _count_named_in_hand(player, card_name) <= 0:
		return false
	return _exact_post_redraw_shell_priority_basic(player) == card_name


func _should_cool_off_search_until_in_hand_shell_basics_are_benched(game_state: GameState, player: PlayerState, player_index: int, trainer_name: String) -> bool:
	if trainer_name not in [ULTRA_BALL, NEST_BALL, CAPTURING_AROMA]:
		return false
	if not _is_exact_post_redraw_shell_convert_window(game_state, player, player_index):
		return false
	return _has_exact_in_hand_shell_basic_waiting(player)


func _is_exact_post_redraw_shell_finish_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not game_state.supporter_used_this_turn:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) < 2:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_giratina_total(player) <= 0 and _count_named_in_hand(player, GIRATINA_V) <= 0:
		return false
	if player.hand.size() <= 0 or player.hand.size() > 5:
		return false
	return _has_exact_post_redraw_shell_finish_pending(player)


func _has_exact_post_redraw_shell_finish_pending(player: PlayerState) -> bool:
	return _exact_post_redraw_shell_finish_pending_basic(player) != "" or _exact_post_redraw_shell_finish_needs_active_grass(player)


func _exact_post_redraw_shell_finish_pending_basic(player: PlayerState) -> String:
	if player == null:
		return ""
	if _count_giratina_total(player) <= 0 and _count_named_in_hand(player, GIRATINA_V) > 0:
		return GIRATINA_V
	if _count_named_on_field(player, SKWOVET) <= 0 and _count_named_in_hand(player, SKWOVET) > 0:
		return SKWOVET
	return ""


func _exact_post_redraw_shell_finish_needs_active_grass(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if _count_named_in_hand(player, GRASS_ENERGY) <= 0:
		return false
	return _count_attached_named_energy(player.active_pokemon, DOUBLE_TURBO_ENERGY) > 0 and _attack_energy_gap(player.active_pokemon) == 1


func _should_force_exact_post_redraw_shell_finish_progress(game_state: GameState, player: PlayerState, player_index: int, card_name: String) -> bool:
	if not _is_exact_post_redraw_shell_finish_window(game_state, player, player_index):
		return false
	return _exact_post_redraw_shell_finish_pending_basic(player) == card_name


func _should_force_exact_post_redraw_shell_finish_attach(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	target_slot: PokemonSlot,
	card: CardInstance
) -> bool:
	if card == null or target_slot == null:
		return false
	if not _is_exact_post_redraw_shell_finish_window(game_state, player, player_index):
		return false
	if _card_name(card) != GRASS_ENERGY:
		return false
	return target_slot == player.active_pokemon and _exact_post_redraw_shell_finish_needs_active_grass(player)


func _should_cool_off_exact_post_redraw_shell_finish_search(game_state: GameState, player: PlayerState, player_index: int, trainer_name: String) -> bool:
	if trainer_name not in [ULTRA_BALL, NEST_BALL, CAPTURING_AROMA, IONO, JUDGE]:
		return false
	if not _is_exact_post_redraw_shell_finish_window(game_state, player, player_index):
		return false
	return _has_exact_post_redraw_shell_finish_pending(player)


func _should_cool_off_exact_post_redraw_starbirth_until_shell_finish(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if not _is_exact_post_redraw_shell_finish_window(game_state, player, player_index):
		return false
	return _has_exact_post_redraw_shell_finish_pending(player)


func _is_exact_post_redraw_shell_finish_payload_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not game_state.supporter_used_this_turn:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if _count_attached_named_energy(player.active_pokemon, DOUBLE_TURBO_ENERGY) != 1:
		return false
	if _attack_energy_gap(player.active_pokemon) > 0:
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) < 2:
		return false
	if _count_named_on_field(player, SKWOVET) <= 0:
		return false
	if _count_giratina_total(player) <= 0:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	var backup_arceus := _backup_arceus_slot(player)
	if backup_arceus == null or not _slot_is(backup_arceus, [ARCEUS_VSTAR]):
		return false
	return _effective_energy_count(backup_arceus) < 3 or backup_arceus.attached_tool == null


func _should_cool_off_exact_post_redraw_attack_for_shell_convert(game_state: GameState, player: PlayerState, player_index: int, projected_damage: int) -> bool:
	if not _is_exact_post_redraw_shell_convert_window(game_state, player, player_index):
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	return projected_damage < defender.get_remaining_hp()


func _should_cool_off_exact_post_redraw_attack_for_rebuild_finish(game_state: GameState, player: PlayerState, player_index: int, projected_damage: int) -> bool:
	if not _is_exact_post_redraw_rebuild_finish_window(game_state, player, player_index):
		return false
	return projected_damage > 0


func _should_cool_off_exact_post_giratina_attack_for_rebuild_finish(game_state: GameState, player: PlayerState, player_index: int, projected_damage: int) -> bool:
	if not _is_exact_post_giratina_rebuild_finish_window(game_state, player, player_index):
		return false
	return projected_damage > 0


func _is_exact_post_giratina_shell_finish_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if not game_state.supporter_used_this_turn:
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) < 2:
		return false
	if _count_giratina_total(player) <= 0:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	if player.hand.size() <= 0 or player.hand.size() > 4:
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	if _attack_energy_gap(player.active_pokemon) > 0:
		return false
	if _estimate_active_damage_against_target(player, game_state, defender) >= defender.get_remaining_hp():
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var card_name := _card_name(card)
		if card_name in [BIDOOF, SKWOVET, MAXIMUM_BELT, CHOICE_BELT]:
			return true
	return false


func _should_force_exact_post_giratina_shell_finish_progress(game_state: GameState, player: PlayerState, player_index: int, card_name: String) -> bool:
	if not _is_exact_post_giratina_shell_finish_window(game_state, player, player_index):
		return false
	return card_name in [BIDOOF, SKWOVET, MAXIMUM_BELT, CHOICE_BELT]


func _should_cool_off_exact_post_giratina_attack_for_shell_finish(game_state: GameState, player: PlayerState, player_index: int, projected_damage: int) -> bool:
	if not _is_exact_post_giratina_shell_finish_window(game_state, player, player_index):
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	return projected_damage < defender.get_remaining_hp()


func _is_exact_double_vstar_shell_distribution_window(player: PlayerState, context: Dictionary) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	var game_state: GameState = context.get("game_state", null)
	if game_state == null or not game_state.supporter_used_this_turn:
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) < 2:
		return false
	var giratina := _best_giratina_slot(player)
	if giratina == null or not _slot_is(giratina, [GIRATINA_V]):
		return false
	if _effective_energy_count(giratina) + _pending_assignment_count(giratina, context) > 0:
		return false
	var backup_arceus := _backup_arceus_slot(player)
	if backup_arceus == null or not _slot_is(backup_arceus, [ARCEUS_VSTAR]):
		return false
	return _effective_energy_count(backup_arceus) + _pending_assignment_count(backup_arceus, context) < 3


func _estimate_active_damage_against_target(player: PlayerState, game_state: GameState, target: PokemonSlot) -> int:
	if player == null or player.active_pokemon == null or target == null or target.get_card_data() == null:
		return 0
	var player_index := game_state.players.find(player)
	if player_index < 0:
		return 0
	var validator := RuleValidator.new()
	var active := player.active_pokemon
	var card_data := active.get_card_data()
	if card_data == null:
		return 0
	var best := 0
	for attack_index: int in card_data.attacks.size():
		if not validator.can_use_attack(game_state, player_index, attack_index, null):
			continue
		var attack: Dictionary = card_data.attacks[attack_index]
		best = maxi(best, _estimate_attack_damage_against_target(active, attack, target))
	return best


func _estimate_attack_damage_against_target(source_slot: PokemonSlot, attack: Dictionary, target_slot: PokemonSlot) -> int:
	if source_slot == null or target_slot == null:
		return 0
	var damage := _parse_damage(str(attack.get("damage", "0")))
	if damage <= 0:
		return 0
	if _count_attached_named_energy(source_slot, DOUBLE_TURBO_ENERGY) > 0:
		damage -= 20
	var tool_name := _card_name(source_slot.attached_tool)
	var target_mechanic := str(target_slot.get_card_data().mechanic) if target_slot.get_card_data() != null else ""
	if tool_name == MAXIMUM_BELT and target_mechanic == "ex":
		damage += 50
	elif tool_name == CHOICE_BELT and target_mechanic in ["V", "VSTAR", "VMAX"]:
		damage += 30
	return maxi(damage, 0)


func _should_prioritize_exact_bridge_attach_before_attack(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	target_slot: PokemonSlot,
	card: CardInstance,
	turn_plan: Dictionary
) -> bool:
	if game_state == null or player == null or target_slot == null or card == null or player.active_pokemon == null:
		return false
	if str(turn_plan.get("intent", "")) != "bridge_to_finisher":
		return false
	if not _turn_plan_flag(turn_plan, "active_can_attack"):
		return false
	if _turn_contract_owner_name(turn_plan, "turn_owner_name") != _slot_name(player.active_pokemon):
		return false
	if _turn_contract_owner_name(turn_plan, "bridge_target_name") != _slot_name(target_slot):
		return false
	if target_slot == player.active_pokemon:
		return false
	var card_name := _card_name(card)
	if _slot_is(target_slot, [GIRATINA_V, GIRATINA_VSTAR]):
		return (
			(card_name == PSYCHIC_ENERGY and _giratina_needs_type_after_pending(target_slot, "P", {}))
			or (card_name == GRASS_ENERGY and _giratina_needs_type_after_pending(target_slot, "G", {}))
		)
	if _slot_is(target_slot, [ARCEUS_V, ARCEUS_VSTAR]):
		if card_name == DOUBLE_TURBO_ENERGY:
			return _attack_energy_gap(target_slot) > 0 and _attack_energy_gap(target_slot) <= 2
		if card.card_data.is_energy():
			return _backup_arceus_needs_first_basic_progress_after_pending(target_slot, {})
	return false


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	var min_gap := 99
	var attached_count := _effective_energy_count(slot)
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		min_gap = mini(min_gap, maxi(0, cost.length() - attached_count))
	return min_gap


func _effective_energy_count(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	var total := 0
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if _card_name(energy) == DOUBLE_TURBO_ENERGY:
			total += 2
		else:
			total += 1
	return total


func _count_attached_basic_energy_local(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	var count := 0
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if str(energy.card_data.card_type) == "Basic Energy":
			count += 1
	return count


func _best_attack_damage(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	var best := 0
	for attack: Dictionary in slot.get_card_data().attacks:
		best = maxi(best, _parse_damage(str(attack.get("damage", "0"))))
	return best


func _all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
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


func _count_arceus_total(player: PlayerState) -> int:
	return _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR)


func _count_giratina_total(player: PlayerState) -> int:
	return _count_named_on_field(player, GIRATINA_V) + _count_named_on_field(player, GIRATINA_VSTAR)


func _count_bibarel_line_total(player: PlayerState) -> int:
	return _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL)


func _can_bench_hand_arceus(player: PlayerState) -> bool:
	return player != null and not player.is_bench_full() and _count_named_in_hand(player, ARCEUS_V) > 0


func _core_shell_complete(player: PlayerState) -> bool:
	if player == null:
		return false
	return (
		_count_arceus_total(player) >= 2
		and _count_giratina_total(player) >= 1
		and _count_bibarel_line_total(player) >= 1
		and _count_named_on_field(player, SKWOVET) >= 1
	)


func _target_formation_complete(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _slot_name(player.active_pokemon) != ARCEUS_VSTAR or _attack_energy_gap(player.active_pokemon) > 0:
		return false
	var backup_arceus := _backup_arceus_slot(player)
	var giratina := _best_giratina_slot(player)
	return (
		backup_arceus != null
		and _slot_name(backup_arceus) == ARCEUS_VSTAR
		and _attack_energy_gap(backup_arceus) <= 0
		and giratina != null
		and _slot_name(giratina) == GIRATINA_VSTAR
		and _attack_energy_gap(giratina) <= 0
		and _count_named_on_field(player, BIBAREL) >= 1
		and _count_named_on_field(player, SKWOVET) >= 1
	)


func _shell_is_thin(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_arceus_total(player) <= 1:
		return true
	if _count_giratina_total(player) == 0:
		return true
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
		return true
	if _count_named_on_field(player, SKWOVET) == 0:
		return true
	return false


func _needs_shell_rebuild(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_arceus_total(player) != 1:
		return false
	if _count_giratina_total(player) == 0:
		return true
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
		return true
	if _count_named_on_field(player, SKWOVET) == 0:
		return true
	return false


func _needs_backup_arceus_energy(player: PlayerState) -> bool:
	var backup_arceus := _backup_arceus_slot(player)
	return backup_arceus != null and _attack_energy_gap(backup_arceus) > 0


func _should_cool_off_giratina_vstar_before_arceus_owner_is_online(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [GIRATINA_V]):
		return false
	if _count_named_on_field(player, GIRATINA_VSTAR) > 0:
		return false
	var best_arceus := _best_arceus_slot(player)
	if best_arceus == null:
		return false
	if _slot_name(best_arceus) != ARCEUS_V:
		return false
	if _attack_energy_gap(best_arceus) > 1:
		return false
	return _attack_energy_gap(player.active_pokemon) > 0


func _has_ready_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot == null:
			continue
		if _best_attack_damage(slot) <= 0:
			continue
		if _attack_energy_gap(slot) <= 0:
			return true
	return false


func _has_deck_out_pressure(player: PlayerState) -> bool:
	return player != null and player.deck.size() <= 8


func _active_can_attack(player: PlayerState, game_state: GameState = null, player_index: int = -1) -> bool:
	if player == null or player.active_pokemon == null or _best_attack_damage(player.active_pokemon) <= 0 or _attack_energy_gap(player.active_pokemon) > 0:
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return true
	var validator := RuleValidator.new()
	var card_data := player.active_pokemon.get_card_data()
	if card_data == null:
		return false
	for attack_index: int in card_data.attacks.size():
		if validator.can_use_attack(game_state, player_index, attack_index, null):
			return true
	return false


func _should_cool_off_draw_churn(player: PlayerState) -> bool:
	return _has_deck_out_pressure(player) and _has_ready_attacker(player)


func _should_cool_off_conversion_churn(player: PlayerState) -> bool:
	return (
		player != null
		and _active_can_attack(player)
		and _core_shell_complete(player)
		and not _needs_transition_piece(player)
	)


func _should_cool_off_post_launch_shell_padding(player: PlayerState, phase: String) -> bool:
	if player == null or phase == "launch":
		return false
	if _count_arceus_total(player) <= 0 or _count_giratina_total(player) <= 0:
		return false
	if _needs_shell_rebuild(player):
		return false
	return _is_launch_online(player) or _has_post_launch_reentry_lane(player)


func _should_force_backup_arceus_shell(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> bool:
	if game_state == null or player == null or phase == "launch":
		return false
	if not _is_charizard_pressure_matchup(game_state, player_index):
		return false
	if not _is_launch_online(player):
		return false
	if _count_arceus_total(player) >= 2:
		return false
	return _count_giratina_total(player) >= 1


func _should_force_exact_second_arceus_before_redraw_or_attack(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null:
		return false
	if player.is_bench_full():
		return false
	if player.active_pokemon == null or not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if _attack_energy_gap(player.active_pokemon) > 0:
		return false
	if _count_arceus_total(player) != 1:
		return false
	if _count_named_in_hand(player, ARCEUS_V) <= 0:
		return false
	if _count_giratina_total(player) > 0:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_named_on_field(player, SKWOVET) > 0:
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	return _estimate_active_damage_against_target(player, game_state, defender) < defender.get_remaining_hp()


func _should_force_exact_second_arceus_before_launch_attack(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null:
		return false
	if player.is_bench_full():
		return false
	if player.active_pokemon == null or not _slot_is(player.active_pokemon, [ARCEUS_V]):
		return false
	if _attack_energy_gap(player.active_pokemon) > 0:
		return false
	if _count_arceus_total(player) != 1:
		return false
	if _count_named_in_hand(player, ARCEUS_V) <= 0:
		return false
	if _count_giratina_total(player) > 0:
		return false
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) > 0:
		return false
	if _count_named_on_field(player, SKWOVET) > 0:
		return false
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon if player_index >= 0 and player_index < game_state.players.size() else null
	if defender == null:
		return false
	return _estimate_active_damage_against_target(player, game_state, defender) < defender.get_remaining_hp()


func _active_arceus_has_hand_dte_progress(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_V, ARCEUS_VSTAR]):
		return false
	var gap := _attack_energy_gap(player.active_pokemon)
	return gap > 0 and gap <= 2 and _count_named_in_hand(player, DOUBLE_TURBO_ENERGY) > 0


func _should_force_active_arceus_launch_line(player: PlayerState, phase: String) -> bool:
	if player == null or phase != "launch" or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_V]):
		return false
	if _count_named_in_hand(player, ARCEUS_VSTAR) <= 0:
		return false
	return _attack_energy_gap(player.active_pokemon) <= 1


func _should_force_exact_active_arceus_shell_build(player: PlayerState, phase: String) -> bool:
	if player == null or phase != "launch" or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_V]):
		return false
	if _count_named_in_hand(player, ARCEUS_VSTAR) <= 0:
		return false
	if _count_named_in_hand(player, DOUBLE_TURBO_ENERGY) <= 0:
		return false
	if _count_arceus_total(player) != 1 or player.is_bench_full():
		return false
	return _can_bench_hand_arceus(player) or _count_named_in_hand(player, NEST_BALL) > 0


func _should_force_exact_active_trinity_nova_line(player: PlayerState, phase: String) -> bool:
	if player == null or phase != "launch" or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_VSTAR]):
		return false
	if _count_attached_named_energy(player.active_pokemon, DOUBLE_TURBO_ENERGY) != 1:
		return false
	if _attack_energy_gap(player.active_pokemon) != 1:
		return false
	if _count_arceus_total(player) < 2 or _count_giratina_total(player) == 0:
		return false
	return _count_named_in_hand(player, GRASS_ENERGY) + _count_named_in_hand(player, PSYCHIC_ENERGY) + _count_named_in_hand(player, JET_ENERGY) > 0


func _should_cool_off_exact_launch_search_after_backup_arceus(player: PlayerState, phase: String) -> bool:
	if player == null or phase != "launch" or player.active_pokemon == null:
		return false
	if not _slot_is(player.active_pokemon, [ARCEUS_V]):
		return false
	if _count_named_in_hand(player, ARCEUS_VSTAR) <= 0:
		return false
	if _count_arceus_total(player) < 2:
		return false
	if _count_named_in_hand(player, DOUBLE_TURBO_ENERGY) <= 0 and _count_attached_named_energy(player.active_pokemon, DOUBLE_TURBO_ENERGY) <= 0:
		return false
	return true


func _should_bench_hand_arceus_before_redraw(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null:
		return false
	if player.is_bench_full():
		return false
	if not _is_charizard_pressure_matchup(game_state, player_index):
		return false
	if _count_named_in_hand(player, ARCEUS_V) <= 0:
		return false
	if _count_arceus_total(player) >= 2:
		return false
	if _active_can_attack(player):
		return false
	if game_state.turn_number < 5:
		return false
	if _count_named_on_field(player, ARCEUS_VSTAR) > 0 or _count_named_on_field(player, GIRATINA_VSTAR) > 0:
		return true
	return _count_giratina_total(player) > 0


func _should_cool_off_charizard_reentry_engine(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> bool:
	if game_state == null or player == null or phase == "launch":
		return false
	if not _is_charizard_pressure_matchup(game_state, player_index):
		return false
	if not _is_launch_online(player):
		return false
	if _active_can_attack(player):
		return false
	if _count_arceus_total(player) < 2:
		return true
	var backup_arceus := _backup_arceus_slot(player)
	if backup_arceus == null:
		return false
	if _slot_is(backup_arceus, [ARCEUS_V]):
		return true
	return _slot_is(backup_arceus, [ARCEUS_VSTAR]) and _attack_energy_gap(backup_arceus) > 0


func _is_charizard_pressure_matchup(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_slots(opponent):
		var name := _slot_name(slot)
		if name in [CHARMANDER, CHARMELEON, CHARIZARD_EX, PIDGEY, PIDGEOT_EX]:
			return true
	return false


func _active_should_hand_off_to_ready_bench(player: PlayerState, game_state: GameState = null, player_index: int = -1) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _active_can_attack(player):
		return false
	var ready_bench := _best_ready_bench(player)
	if ready_bench == null:
		return false
	return _retreat_target_quality(ready_bench) >= 250.0


func _should_enable_pivot_fallback_attach(player: PlayerState, target_slot: PokemonSlot, phase: String) -> bool:
	if player == null or target_slot == null or phase != "launch":
		return false
	if target_slot != player.active_pokemon:
		return false
	if not _slot_is(target_slot, [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]):
		return false
	if target_slot.get_card_data() == null:
		return false
	var retreat_cost := int(target_slot.get_card_data().retreat_cost)
	if retreat_cost <= 0:
		return false
	if target_slot.attached_energy.size() >= retreat_cost:
		return false
	return _count_arceus_total(player) <= 1 and not _target_formation_complete(player)


func _should_enable_active_giratina_fallback_attach(player: PlayerState, target_slot: PokemonSlot, phase: String) -> bool:
	if player == null or target_slot == null or phase != "launch":
		return false
	if target_slot != player.active_pokemon:
		return false
	if not _slot_is(target_slot, [GIRATINA_V, GIRATINA_VSTAR]):
		return false
	return _count_arceus_total(player) == 0 and _attack_energy_gap(target_slot) > 0


func _should_hold_non_arceus_attach_for_hand_arceus(player: PlayerState, target_slot: PokemonSlot, phase: String) -> bool:
	if player == null or target_slot == null or phase != "launch":
		return false
	if _count_arceus_total(player) > 0:
		return false
	if player.is_bench_full():
		return false
	if _count_named_in_hand(player, ARCEUS_V) <= 0:
		return false
	return not _slot_is(target_slot, [ARCEUS_V, ARCEUS_VSTAR])


func _should_deploy_iron_leaves(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null or opponent.active_pokemon.get_card_data() == null:
		return false
	if _slot_name(opponent.active_pokemon) != "Charizard ex":
		return false
	return _can_iron_leaves_take_charizard_ko_this_turn(game_state, player, player_index)


func _can_iron_leaves_take_charizard_ko_this_turn(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null or _slot_name(opponent.active_pokemon) != CHARIZARD_EX:
		return false
	var on_board_iron_leaves := _best_on_board_iron_leaves_slot(player)
	if on_board_iron_leaves != null and _can_on_board_iron_leaves_take_charizard_ko_this_turn(game_state, player, on_board_iron_leaves):
		return true
	return _can_hand_iron_leaves_take_charizard_ko_this_turn(game_state, player)


func _can_iron_leaves_attack_after_manual_attach(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	target_slot: PokemonSlot,
	card: CardInstance
) -> bool:
	if game_state == null or player == null or target_slot == null or card == null or card.card_data == null:
		return false
	if player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null or _slot_name(opponent.active_pokemon) != CHARIZARD_EX:
		return false
	if _slot_name(target_slot) == IRON_LEAVES_EX and _iron_leaves_prism_edge_locked_this_turn(target_slot, game_state):
		return false
	var attach_energy := 2 if _card_name(card) == DOUBLE_TURBO_ENERGY else 1
	var grass_count := _attached_energy_type_count(target_slot, "G") + (1 if _card_name(card) == GRASS_ENERGY else 0)
	return _effective_energy_count(target_slot) + attach_energy >= 3 and grass_count >= 2


func _count_movable_iron_leaves_energy(player: PlayerState) -> int:
	if player == null:
		return 0
	var total := 0
	for slot: PokemonSlot in _all_slots(player):
		if slot != null:
			total += _effective_energy_count(slot)
	return total


func _count_movable_iron_leaves_grass(player: PlayerState) -> int:
	if player == null:
		return 0
	var total := 0
	for slot: PokemonSlot in _all_slots(player):
		total += _attached_energy_type_count(slot, "G")
	return total


func _best_on_board_iron_leaves_slot(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) == IRON_LEAVES_EX:
			return slot
	return null


func _can_hand_iron_leaves_take_charizard_ko_this_turn(game_state: GameState, player: PlayerState) -> bool:
	if game_state == null or player == null:
		return false
	if _count_named_in_hand(player, IRON_LEAVES_EX) <= 0 or player.is_bench_full():
		return false
	var movable_energy := _count_movable_iron_leaves_energy(player)
	var movable_grass := _count_movable_iron_leaves_grass(player)
	if movable_energy >= 3 and movable_grass >= 2:
		return true
	if game_state.energy_attached_this_turn:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		var attach_energy := 2 if _card_name(card) == DOUBLE_TURBO_ENERGY else 1
		var attach_grass := 1 if _card_name(card) == GRASS_ENERGY else 0
		if movable_energy + attach_energy >= 3 and movable_grass + attach_grass >= 2:
			return true
	return false


func _can_on_board_iron_leaves_take_charizard_ko_this_turn(game_state: GameState, player: PlayerState, iron_leaves: PokemonSlot) -> bool:
	if game_state == null or player == null or iron_leaves == null or _slot_name(iron_leaves) != IRON_LEAVES_EX:
		return false
	if _iron_leaves_prism_edge_locked_this_turn(iron_leaves, game_state):
		return false
	if not _can_make_slot_active_this_turn(player, iron_leaves):
		return false
	var current_energy := _effective_energy_count(iron_leaves)
	var current_grass := _attached_energy_type_count(iron_leaves, "G")
	if current_energy >= 3 and current_grass >= 2:
		return true
	if game_state.energy_attached_this_turn:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		var attach_energy := 2 if _card_name(card) == DOUBLE_TURBO_ENERGY else 1
		var attach_grass := 1 if _card_name(card) == GRASS_ENERGY else 0
		if current_energy + attach_energy >= 3 and current_grass + attach_grass >= 2:
			return true
	return false


func _iron_leaves_prism_edge_locked_this_turn(slot: PokemonSlot, game_state: GameState) -> bool:
	if slot == null or game_state == null:
		return false
	for effect_data: Dictionary in slot.effects:
		if str(effect_data.get("type", "")) != "attack_lock":
			continue
		if str(effect_data.get("attack_name", "")) != "Prism Edge":
			continue
		if int(effect_data.get("turn", -999)) == game_state.turn_number - 2:
			return true
	return false


func _should_deploy_radiant_gardevoir(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if _count_named_on_field(player, RADIANT_GARDEVOIR) > 0:
		return false
	if not _core_shell_complete(player):
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null or opponent.active_pokemon.get_card_data() == null:
		return false
	var mechanic := str(opponent.active_pokemon.get_card_data().mechanic)
	return mechanic in ["V", "VSTAR", "VMAX"]


func _count_field_energy_of_types(player: PlayerState, types: Array[String]) -> int:
	if player == null:
		return 0
	var total := 0
	for slot: PokemonSlot in _all_slots(player):
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			var provided := str(energy.card_data.energy_provides)
			if types.has(provided):
				total += 1
	return total


func _player_is_behind_in_prizes(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	return game_state.players[player_index].prizes.size() > game_state.players[1 - player_index].prizes.size()


func _player_is_ahead_in_prizes(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	return game_state.players[player_index].prizes.size() < game_state.players[1 - player_index].prizes.size()


func _is_two_prize_target(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var mechanic := str(slot.get_card_data().mechanic)
	return mechanic in ["V", "VMAX", "VSTAR", "ex", "EX", "GX"]


func _should_convert_to_giratina_finisher(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if player_index < 0 or player_index >= game_state.players.size():
		return false
	if _slot_name(player.active_pokemon) != ARCEUS_VSTAR:
		return false
	var giratina := _best_giratina_slot(player)
	if giratina == null or giratina == player.active_pokemon:
		return false
	if _slot_name(giratina) != GIRATINA_VSTAR or _attack_energy_gap(giratina) > 0:
		return false
	var opponent_active := game_state.players[1 - player_index].active_pokemon
	if opponent_active == null:
		return false
	var giratina_damage := _best_attack_damage(giratina)
	if giratina_damage < opponent_active.get_remaining_hp():
		return false
	var arceus_damage := _best_attack_damage(player.active_pokemon)
	if arceus_damage < opponent_active.get_remaining_hp():
		return true
	return phase_is_convert(player, game_state) and _is_two_prize_target(opponent_active)


func phase_is_convert(player: PlayerState, game_state: GameState) -> bool:
	return _detect_phase(game_state, player) == "convert"


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
