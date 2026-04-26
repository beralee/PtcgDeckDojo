class_name TestAIStrongFixedOpenings
extends TestBase

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AIFixedDeckOrderRegistryScript = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const MIRAIDON_DECK_ID := 575720
const CHARIZARD_DECK_ID := 575716
const LUGIA_DECK_ID := 575657
const ARCEUS_DECK_ID := 569061

const CHARIZARD_FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/575716.json"
const LUGIA_FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/575657.json"
const ARCEUS_FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/569061.json"


func _make_ai_for_deck(player_index: int, deck_id: int) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var deck: DeckData = CardDatabase.get_deck(deck_id)
	if deck != null:
		var registry := DeckStrategyRegistryScript.new()
		registry.apply_strategy_for_deck(ai, deck)
	return ai


func _run_until_turn_end(
	gsm: GameStateMachine,
	bridge: HeadlessMatchBridge,
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent,
	target_turn_for_player: int,
	target_player: int,
	max_steps: int = 400
) -> Dictionary:
	var steps := 0
	var target_reached := false
	var target_turn_started := false
	var traces: Array[Dictionary] = []
	while steps < max_steps:
		if gsm.game_state.is_game_over():
			break
		if gsm.game_state.phase == GameState.GamePhase.MAIN \
				and gsm.game_state.current_player_index == target_player \
				and gsm.game_state.turn_number == target_turn_for_player:
			target_turn_started = true
		if target_turn_started \
				and gsm.game_state.phase == GameState.GamePhase.MAIN \
				and gsm.game_state.current_player_index != target_player:
			target_reached = true
			break

		var progressed := false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				var owner: int = bridge.get_pending_prompt_owner()
				if owner == 0:
					progressed = player_0_ai.run_single_step(bridge, gsm)
				elif owner == 1:
					progressed = player_1_ai.run_single_step(bridge, gsm)
		else:
			var current: int = gsm.game_state.current_player_index
			if current == 0:
				progressed = player_0_ai.run_single_step(bridge, gsm)
				_maybe_collect_trace(traces, player_0_ai)
			elif current == 1:
				progressed = player_1_ai.run_single_step(bridge, gsm)
				_maybe_collect_trace(traces, player_1_ai)
		if not progressed:
			break
		steps += 1
	return {"target_reached": target_reached, "steps": steps, "traces": traces}


func _maybe_collect_trace(traces: Array[Dictionary], ai: AIOpponent) -> void:
	if ai == null:
		return
	var trace = ai.get_last_decision_trace()
	if trace == null:
		return
	var payload: Dictionary = trace.to_dictionary() if trace.has_method("to_dictionary") else {}
	if payload.is_empty():
		return
	traces.append(payload)


func _trace_tail_summary(traces: Array[Dictionary], tracked_player_index: int, limit: int = 16) -> String:
	var filtered: Array[String] = []
	for trace: Dictionary in traces:
		if int(trace.get("player_index", -1)) != tracked_player_index:
			continue
		var chosen_action: Dictionary = trace.get("chosen_action", {}) as Dictionary
		var kind := str(chosen_action.get("kind", ""))
		var card_name := ""
		var card_payload: Variant = chosen_action.get("card", null)
		if card_payload is CardInstance and (card_payload as CardInstance).card_data != null:
			card_name = str((card_payload as CardInstance).card_data.name)
		elif card_payload is Dictionary:
			card_name = str((card_payload as Dictionary).get("name", ""))
		var target_name := str(chosen_action.get("target_name", ""))
		if target_name == "":
			var target_payload: Variant = chosen_action.get("target_slot", null)
			if target_payload is PokemonSlot:
				target_name = (target_payload as PokemonSlot).get_pokemon_name()
		var line := "T%d %s" % [int(trace.get("turn_number", -1)), kind]
		if card_name != "":
			line += ":%s" % card_name
		if target_name != "":
			line += "->%s" % target_name
		filtered.append(line)
	var start := maxi(0, filtered.size() - limit)
	return " | ".join(filtered.slice(start, filtered.size()))


func _filter_traces_for_turn(traces: Array[Dictionary], tracked_player_index: int, turn_number: int) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for trace: Dictionary in traces:
		if int(trace.get("player_index", -1)) != tracked_player_index:
			continue
		if int(trace.get("turn_number", -1)) != turn_number:
			continue
		filtered.append(trace)
	return filtered


func _trace_matches_action(trace: Dictionary, kind: String, card_name: String = "") -> bool:
	var chosen_action: Dictionary = trace.get("chosen_action", {}) as Dictionary
	if str(chosen_action.get("kind", "")) != kind:
		return false
	if card_name == "":
		return true
	var action_card_name := _resolved_action_card_name(chosen_action)
	if action_card_name == "":
		var source_slot_payload: Variant = chosen_action.get("source_slot", null)
		if source_slot_payload is PokemonSlot:
			action_card_name = _slot_name(source_slot_payload as PokemonSlot)
		elif source_slot_payload is Dictionary:
			action_card_name = str((source_slot_payload as Dictionary).get("pokemon_name", ""))
			if action_card_name == "":
				action_card_name = str((source_slot_payload as Dictionary).get("name", ""))
	return action_card_name == card_name


func _resolved_action_card_name(chosen_action: Dictionary) -> String:
	var card_payload: Variant = chosen_action.get("card", null)
	if card_payload is CardInstance and (card_payload as CardInstance).card_data != null:
		var cd: CardData = (card_payload as CardInstance).card_data
		return str(cd.name_en) if str(cd.name_en) != "" else str(cd.name)
	elif card_payload is Dictionary:
		var payload: Dictionary = card_payload as Dictionary
		var name_en := str(payload.get("name_en", ""))
		if name_en != "":
			return name_en
		return str(payload.get("name", ""))
	return ""


func _resolved_action_target_name(chosen_action: Dictionary) -> String:
	var resolved_target_name := str(chosen_action.get("target_name", ""))
	if resolved_target_name != "":
		return resolved_target_name
	var target_payload: Variant = chosen_action.get("target_slot", null)
	if target_payload is PokemonSlot:
		return _slot_name(target_payload as PokemonSlot)
	elif target_payload is Dictionary:
		var payload: Dictionary = target_payload as Dictionary
		resolved_target_name = str(payload.get("pokemon_name", ""))
		if resolved_target_name == "":
			resolved_target_name = str(payload.get("name", ""))
	return resolved_target_name


func _turn_contains_attack(traces: Array[Dictionary], tracked_player_index: int, turn_number: int, source_name: String = "", attack_name: String = "") -> bool:
	for trace: Dictionary in _filter_traces_for_turn(traces, tracked_player_index, turn_number):
		var chosen_action: Dictionary = trace.get("chosen_action", {}) as Dictionary
		if str(chosen_action.get("kind", "")) != "attack":
			continue
		if source_name != "":
			var source_slot_payload: Variant = chosen_action.get("source_slot", null)
			var resolved_source_name := ""
			if source_slot_payload is PokemonSlot:
				resolved_source_name = _slot_name(source_slot_payload as PokemonSlot)
			elif source_slot_payload is Dictionary:
				resolved_source_name = str((source_slot_payload as Dictionary).get("pokemon_name", ""))
				if resolved_source_name == "":
					resolved_source_name = str((source_slot_payload as Dictionary).get("name", ""))
			if resolved_source_name != source_name:
				continue
		if attack_name != "" and str(chosen_action.get("attack_name", "")) != attack_name:
			continue
		return true
	return false


func _turn_contains_attach_to_target(traces: Array[Dictionary], tracked_player_index: int, turn_number: int, card_name: String, target_name: String) -> bool:
	for trace: Dictionary in _filter_traces_for_turn(traces, tracked_player_index, turn_number):
		var chosen_action: Dictionary = trace.get("chosen_action", {}) as Dictionary
		if str(chosen_action.get("kind", "")) != "attach_energy":
			continue
		var action_card_name := _resolved_action_card_name(chosen_action)
		if action_card_name != card_name:
			continue
		var resolved_target_name := _resolved_action_target_name(chosen_action)
		if resolved_target_name == target_name:
			return true
	return false


func _turn_contains_attach_to_any_target(
	traces: Array[Dictionary],
	tracked_player_index: int,
	turn_number: int,
	card_names: Array[String],
	target_names: Array[String]
) -> bool:
	for trace: Dictionary in _filter_traces_for_turn(traces, tracked_player_index, turn_number):
		var chosen_action: Dictionary = trace.get("chosen_action", {}) as Dictionary
		if str(chosen_action.get("kind", "")) != "attach_energy":
			continue
		var action_card_name := _resolved_action_card_name(chosen_action)
		if not card_names.has(action_card_name):
			continue
		var resolved_target_name := _resolved_action_target_name(chosen_action)
		if target_names.has(resolved_target_name):
			return true
	return false


func _slot_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_top_card() == null or slot.get_top_card().card_data == null:
		return ""
	var cd: CardData = slot.get_top_card().card_data
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)


func _find_slot_by_name(player: PlayerState, target_name: String) -> PokemonSlot:
	if player.active_pokemon != null and _slot_name(player.active_pokemon) == target_name:
		return player.active_pokemon
	for slot: PokemonSlot in player.bench:
		if slot != null and _slot_name(slot) == target_name:
			return slot
	return null


func _count_attached_named_energy(slot: PokemonSlot, target_name: String) -> int:
	if slot == null:
		return 0
	var count := 0
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var cd: CardData = card.card_data
		var cname := str(cd.name_en) if str(cd.name_en) != "" else str(cd.name)
		if cname == target_name:
			count += 1
	return count


func _count_attached_energy_provides(slot: PokemonSlot, energy_symbol: String) -> int:
	if slot == null:
		return 0
	var count := 0
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.energy_provides) == energy_symbol:
			count += 1
	return count


func _card_instance_name(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	var cd: CardData = card.card_data
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)


func _ensure_cards_not_prized(player: PlayerState, protected_names: Array[String]) -> void:
	if player == null or protected_names.is_empty():
		return
	for prize_index in range(player.prizes.size()):
		var prize_card: CardInstance = player.prizes[prize_index]
		if not protected_names.has(_card_instance_name(prize_card)):
			continue
		var swap_index := -1
		for deck_index in range(player.deck.size() - 1, -1, -1):
			var deck_card: CardInstance = player.deck[deck_index]
			if protected_names.has(_card_instance_name(deck_card)):
				continue
			swap_index = deck_index
			break
		if swap_index == -1:
			continue
		var replacement: CardInstance = player.deck[swap_index]
		player.deck[swap_index] = prize_card
		player.prizes[prize_index] = replacement
	player.reset_prize_layout()


func _describe_player_board(player: PlayerState) -> String:
	var parts: Array[String] = []
	if player.active_pokemon != null:
		parts.append("active=%s[%d]" % [_slot_name(player.active_pokemon), player.active_pokemon.attached_energy.size()])
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		parts.append("bench=%s[%d]" % [_slot_name(slot), slot.attached_energy.size()])
	return ", ".join(parts)


func _describe_hand(player: PlayerState) -> String:
	var names: Array[String] = []
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		names.append(str(card.card_data.name_en) if str(card.card_data.name_en) != "" else str(card.card_data.name))
	return "[" + ", ".join(names) + "]"


func _load_fixed_order(path: String) -> Array[Dictionary]:
	var registry := AIFixedDeckOrderRegistryScript.new()
	return registry.load_fixed_order_from_path(path)


func _miraidon_low_pressure_fixed_order() -> Array[Dictionary]:
	return [
		{"set_code": "CS6.5C", "card_index": "020"}, # Radiant Greninja
		{"set_code": "CS6aC", "card_index": "057"}, # Zapdos
		{"set_code": "CSV7C", "card_index": "185"}, # Rescue Board
		{"set_code": "CSV1C", "card_index": "118"}, # Bravery Charm
		{"set_code": "CSV1C", "card_index": "109"}, # Super Rod
		{"set_code": "CS6.5C", "card_index": "066"}, # Forest Seal Stone
		{"set_code": "CSV7C", "card_index": "201"}, # Gravity Mountain
		{"set_code": "CSV7C", "card_index": "188"}, # Heavy Baton
		{"set_code": "CSV7C", "card_index": "180"}, # Prime Catcher
		{"set_code": "CS6bC", "card_index": "123"}, # Lost Vacuum
		{"set_code": "CSV7C", "card_index": "191"}, # Ciphermaniac's Codebreaking
		{"set_code": "CS5DC", "card_index": "140"}, # Cyllene
		{"set_code": "CSV3C", "card_index": "123"}, # Iono
		{"set_code": "CSV7C", "card_index": "191"}, # Ciphermaniac's Codebreaking (turn-1 draw)
	]


func test_charizard_strong_fixed_order_hits_t2_charizard_and_pidgeot_board() -> String:
	var charizard_deck: DeckData = CardDatabase.get_deck(CHARIZARD_DECK_ID)
	if charizard_deck == null:
		return assert_true(false, "Charizard deck should load")
	var opponent_deck: DeckData = CardDatabase.get_deck(MIRAIDON_DECK_ID)
	if opponent_deck == null:
		return assert_true(false, "Opponent deck should load")
	var fixed_order := _load_fixed_order(CHARIZARD_FIXED_ORDER_PATH)
	if fixed_order.is_empty():
		return assert_true(false, "Fixed order should load: %s" % CHARIZARD_FIXED_ORDER_PATH)

	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.set_deck_order_override(0, fixed_order)
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = 101
	gsm.start_game(charizard_deck, opponent_deck, 0)
	_ensure_cards_not_prized(gsm.game_state.players[0], [
		"Charmander",
		"Pidgey",
		"Pidgeot ex",
		"Charizard ex",
		"Rare Candy",
		"Rotom V",
	])

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	var player_0_ai := _make_ai_for_deck(0, CHARIZARD_DECK_ID)
	var player_1_ai := _make_ai_for_deck(1, MIRAIDON_DECK_ID)
	var outcome := _run_until_turn_end(gsm, bridge, player_0_ai, player_1_ai, 3, 0)

	var player: PlayerState = gsm.game_state.players[0]
	var pidgeot_slot := _find_slot_by_name(player, "Pidgeot ex")
	var charizard_slot := _find_slot_by_name(player, "Charizard ex")
	var rotom_slot := _find_slot_by_name(player, "Rotom V")
	var pidgey_energy_total := 0
	for slot: PokemonSlot in player.bench:
		if slot != null and _slot_name(slot) == "Pidgey":
			pidgey_energy_total += slot.attached_energy.size()
	if player.active_pokemon != null and _slot_name(player.active_pokemon) == "Pidgey":
		pidgey_energy_total += player.active_pokemon.attached_energy.size()
	var board_desc := _describe_player_board(player)
	var trace_tail := _trace_tail_summary(outcome.get("traces", []), 0)
	var turn_one_traces := _filter_traces_for_turn(outcome.get("traces", []), 0, 1)
	var rotom_ability_used_last := false
	if not turn_one_traces.is_empty():
		rotom_ability_used_last = _trace_matches_action(turn_one_traces[turn_one_traces.size() - 1], "use_ability", "Rotom V")
	var run_desc := "turn=%d current=%d steps=%d game_over=%s board=%s trace=%s" % [
		int(gsm.game_state.turn_number),
		int(gsm.game_state.current_player_index),
		int(outcome.get("steps", 0)),
		str(gsm.game_state.is_game_over()),
		board_desc,
		trace_tail,
	]
	run_desc += " hand=%s" % _describe_hand(player)

	if is_instance_valid(bridge):
		bridge.free()

	return run_checks([
		assert_true(bool(outcome.get("target_reached", false)), "Target turn should complete for Charizard strong fixed opening (%s)" % run_desc),
		assert_not_null(rotom_slot, "By first-player T1/T2 the board should include Rotom V as the draw engine pivot (%s) | %s | hand=%s" % [board_desc, trace_tail, _describe_hand(player)]),
		assert_true(rotom_ability_used_last, "Turn 1 should end by using Rotom V's ability after the shell is set (%s) | %s | hand=%s" % [board_desc, trace_tail, _describe_hand(player)]),
		assert_not_null(pidgeot_slot, "By first-player T2 the board should contain Pidgeot ex (%s) | %s | hand=%s" % [board_desc, trace_tail, _describe_hand(player)]),
		assert_not_null(charizard_slot, "By first-player T2 the board should contain Charizard ex (%s) | %s | hand=%s" % [board_desc, trace_tail, _describe_hand(player)]),
		assert_eq(0 if pidgeot_slot == null else pidgeot_slot.attached_energy.size(), 0, "Pidgeot ex should be online without attached energy"),
		assert_eq(pidgey_energy_total, 0, "Pidgey should stay energy-free in the strong opening line"),
		assert_eq(0 if rotom_slot == null else rotom_slot.attached_energy.size(), 0, "Rotom V should stay energy-free in the strong opening line"),
		assert_eq(0 if charizard_slot == null else charizard_slot.attached_energy.size(), 2, "Charizard ex should have exactly 2 attached energies by T2"),
	])


func test_lugia_strong_fixed_order_hits_t2_lugia_vstar_and_double_archeops() -> String:
	var lugia_deck: DeckData = CardDatabase.get_deck(LUGIA_DECK_ID)
	if lugia_deck == null:
		return assert_true(false, "Lugia deck should load")
	var opponent_deck: DeckData = CardDatabase.get_deck(MIRAIDON_DECK_ID)
	if opponent_deck == null:
		return assert_true(false, "Opponent deck should load")
	var fixed_order := _load_fixed_order(LUGIA_FIXED_ORDER_PATH)
	if fixed_order.is_empty():
		return assert_true(false, "Fixed order should load: %s" % LUGIA_FIXED_ORDER_PATH)

	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.set_deck_order_override(0, fixed_order)
	gsm.set_deck_order_override(1, _miraidon_low_pressure_fixed_order())
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = 303
	gsm.start_game(lugia_deck, opponent_deck, 0)
	_ensure_cards_not_prized(gsm.game_state.players[0], [
		"Lugia V",
		"Lugia VSTAR",
		"Archeops",
		"Ultra Ball",
		"Double Turbo Energy",
		"Minccino",
	])

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	var player_0_ai := _make_ai_for_deck(0, LUGIA_DECK_ID)
	var player_1_ai := _make_ai_for_deck(1, MIRAIDON_DECK_ID)
	var outcome := _run_until_turn_end(gsm, bridge, player_0_ai, player_1_ai, 3, 0)

	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := player.active_pokemon
	var lugia_vstar_slot := _find_slot_by_name(player, "Lugia VSTAR")
	var archeops_count := 0
	for slot: PokemonSlot in player.bench:
		if slot != null and _slot_name(slot) == "Archeops":
			archeops_count += 1
	if active_slot != null and _slot_name(active_slot) == "Archeops":
		archeops_count += 1
	var turn_three_traces := _filter_traces_for_turn(outcome.get("traces", []), 0, 3)
	var used_summoning_star := false
	for trace: Dictionary in turn_three_traces:
		if _trace_matches_action(trace, "use_ability", "Lugia VSTAR"):
			used_summoning_star = true
			break
	var board_desc := _describe_player_board(player)
	var trace_tail := _trace_tail_summary(outcome.get("traces", []), 0)
	var run_desc := "turn=%d current=%d steps=%d game_over=%s board=%s trace=%s hand=%s" % [
		int(gsm.game_state.turn_number),
		int(gsm.game_state.current_player_index),
		int(outcome.get("steps", 0)),
		str(gsm.game_state.is_game_over()),
		board_desc,
		trace_tail,
		_describe_hand(player),
	]

	if is_instance_valid(bridge):
		bridge.free()

	return run_checks([
		assert_true(bool(outcome.get("target_reached", false)), "Target turn should complete for Lugia strong fixed opening (%s)" % run_desc),
		assert_eq(_slot_name(active_slot), "Lugia VSTAR", "Active should be Lugia VSTAR by first-player T2 (%s)" % run_desc),
		assert_not_null(lugia_vstar_slot, "Board should contain Lugia VSTAR by first-player T2 (%s)" % run_desc),
		assert_true(used_summoning_star, "First-player T2 should use Lugia VSTAR's Summoning Star (%s)" % run_desc),
		assert_eq(archeops_count, 2, "Strong opening should bench exactly 2 Archeops by first-player T2 (%s)" % run_desc),
		assert_true(active_slot != null and active_slot.attached_energy.size() >= 1, "Lugia VSTAR should already have at least one attached energy card when the engine comes online (%s)" % run_desc),
	])


func test_arceus_strong_fixed_order_hits_t2_trinity_nova_distribution() -> String:
	var arceus_deck: DeckData = CardDatabase.get_deck(ARCEUS_DECK_ID)
	if arceus_deck == null:
		return assert_true(false, "Arceus deck should load")
	var opponent_deck: DeckData = CardDatabase.get_deck(MIRAIDON_DECK_ID)
	if opponent_deck == null:
		return assert_true(false, "Opponent deck should load")
	var fixed_order := _load_fixed_order(ARCEUS_FIXED_ORDER_PATH)
	if fixed_order.is_empty():
		return assert_true(false, "Fixed order should load: %s" % ARCEUS_FIXED_ORDER_PATH)

	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.set_deck_order_override(0, fixed_order)
	gsm.set_deck_order_override(1, _miraidon_low_pressure_fixed_order())
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = 202
	gsm.start_game(arceus_deck, opponent_deck, 0)
	_ensure_cards_not_prized(gsm.game_state.players[0], [
		"Arceus V",
		"Arceus VSTAR",
		"Giratina V",
		"Giratina VSTAR",
		"Double Turbo Energy",
		"Bidoof",
	])

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	var player_0_ai := _make_ai_for_deck(0, ARCEUS_DECK_ID)
	var player_1_ai := _make_ai_for_deck(1, MIRAIDON_DECK_ID)
	var outcome := _run_until_turn_end(gsm, bridge, player_0_ai, player_1_ai, 3, 0)

	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := player.active_pokemon
	var backup_arceus: PokemonSlot = null
	var giratina: PokemonSlot = null
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		if backup_arceus == null and _slot_name(slot) == "Arceus VSTAR":
			backup_arceus = slot
		elif giratina == null and _slot_name(slot) == "Giratina V":
			giratina = slot
		elif giratina == null and _slot_name(slot) == "Giratina VSTAR":
			giratina = slot
	var board_desc := _describe_player_board(player)
	var trace_tail := _trace_tail_summary(outcome.get("traces", []), 0)
	var turn_three_attack_live := _turn_contains_attack(outcome.get("traces", []), 0, 3)
	var turn_one_dte_on_active_arceus := _turn_contains_attach_to_any_target(
		outcome.get("traces", []),
		0,
		1,
		["Double Turbo Energy", "双重涡轮能量"],
		["Arceus V", "阿尔宙斯V", "Arceus VSTAR", "阿尔宙斯VSTAR"]
	)
	var run_desc := "turn=%d current=%d steps=%d game_over=%s board=%s" % [
		int(gsm.game_state.turn_number),
		int(gsm.game_state.current_player_index),
		int(outcome.get("steps", 0)),
		str(gsm.game_state.is_game_over()),
		board_desc,
	]

	if is_instance_valid(bridge):
		bridge.free()

	return run_checks([
		assert_true(bool(outcome.get("target_reached", false)), "Target turn should complete for Arceus strong fixed opening (%s)" % run_desc),
		assert_true(turn_one_dte_on_active_arceus, "Turn 1 must end with Double Turbo Energy attached to the active Arceus line (%s) | %s" % [board_desc, trace_tail]),
		assert_true(turn_three_attack_live, "Arceus strong opening must actually attack on the first-player T2 turn before the Trinity Nova distribution checks (%s) | %s" % [board_desc, trace_tail]),
		assert_eq(_slot_name(active_slot), "Arceus VSTAR", "Active should be Arceus VSTAR by first-player T2 (%s) | %s" % [board_desc, trace_tail]),
		assert_eq(2 if active_slot == null else active_slot.attached_energy.size(), 2, "Active Arceus VSTAR should have exactly 2 attached energy cards (%s) | %s" % [board_desc, trace_tail]),
		assert_eq(1 if active_slot == null else _count_attached_named_energy(active_slot, "Double Turbo Energy"), 1, "Active Arceus VSTAR should have one Double Turbo Energy (%s) | %s" % [board_desc, trace_tail]),
		assert_true(active_slot != null and active_slot.attached_energy.size() == 2 and _count_attached_named_energy(active_slot, "Double Turbo Energy") == 1, "Active Arceus VSTAR should have one Double Turbo plus one other energy (%s) | %s" % [board_desc, trace_tail]),
		assert_not_null(backup_arceus, "Bench should contain a backup Arceus VSTAR after Trinity Nova (%s) | %s" % [board_desc, trace_tail]),
		assert_eq(0 if backup_arceus == null else backup_arceus.attached_energy.size(), 1, "Backup Arceus should receive 1 energy from Trinity Nova (%s) | %s" % [board_desc, trace_tail]),
		assert_not_null(giratina, "Bench should contain Giratina after Trinity Nova (%s) | %s" % [board_desc, trace_tail]),
		assert_eq(0 if giratina == null else giratina.attached_energy.size(), 2, "Giratina should receive exactly 2 attached energies from Trinity Nova (%s) | %s" % [board_desc, trace_tail]),
		assert_eq(0 if giratina == null else _count_attached_energy_provides(giratina, "G"), 1, "Giratina should receive exactly 1 Grass energy (%s) | %s" % [board_desc, trace_tail]),
		assert_eq(0 if giratina == null else _count_attached_energy_provides(giratina, "P"), 1, "Giratina should receive exactly 1 Psychic energy (%s) | %s" % [board_desc, trace_tail]),
	])
