class_name TestVSTAREngineStrategies
extends TestBase


const REGIDRAGO_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRegidrago.gd"
const LUGIA_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLugiaArcheops.gd"
const DIALGA_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDialgaMetang.gd"
const ARCEUS_SCRIPT_PATH := "res://scripts/ai/DeckStrategyArceusGiratina.gd"


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_strategy(script_path: String) -> RefCounted:
	CardInstance.reset_id_counter()
	var script := _load_script(script_path)
	return script.new() if script != null else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "C",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = [],
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	cd.abilities.clear()
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _make_energy_cd(pname: String, energy_provides: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	cd.energy_provides = energy_provides
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_player(pi: int = 0) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = pi
	return player


func _make_game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := _make_player(pi)
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active %d" % pi), pi)
		gs.players.append(player)
	return gs


func _best_card_name(strategy: RefCounted, items: Array, step_id: String, context: Dictionary) -> String:
	var best_name := ""
	var best_score := -INF
	for item: Variant in items:
		var score: float = strategy.score_interaction_target(item, {"id": step_id}, context)
		if score > best_score:
			best_score = score
			if item is CardInstance:
				best_name = str((item as CardInstance).card_data.name)
	return best_name


func _best_slot_name(strategy: RefCounted, items: Array, step_id: String, context: Dictionary) -> String:
	var best_name := ""
	var best_score := -INF
	for item: Variant in items:
		var score: float = strategy.score_interaction_target(item, {"id": step_id}, context)
		if score > best_score:
			best_score = score
			if item is PokemonSlot:
				best_name = (item as PokemonSlot).get_pokemon_name()
	return best_name


func _best_copied_attack_label(strategy: RefCounted, items: Array, context: Dictionary) -> String:
	var best_label := ""
	var best_score := -INF
	for item: Variant in items:
		var score: float = strategy.score_interaction_target(item, {"id": "copied_attack"}, context)
		if score > best_score:
			best_score = score
			if item is Dictionary:
				var option: Dictionary = item
				var source_card: Variant = option.get("source_card", null)
				var attack: Dictionary = option.get("attack", {})
				if source_card is CardInstance:
					best_label = "%s:%s" % [(source_card as CardInstance).card_data.name, str(attack.get("name", ""))]
	return best_label


func test_vstar_engine_strategy_scripts_load() -> String:
	return run_checks([
		assert_not_null(_load_script(REGIDRAGO_SCRIPT_PATH), "DeckStrategyRegidrago.gd should load"),
		assert_not_null(_load_script(LUGIA_SCRIPT_PATH), "DeckStrategyLugiaArcheops.gd should load"),
		assert_not_null(_load_script(DIALGA_SCRIPT_PATH), "DeckStrategyDialgaMetang.gd should load"),
		assert_not_null(_load_script(ARCEUS_SCRIPT_PATH), "DeckStrategyArceusGiratina.gd should load"),
	])


func test_regidrago_setup_prefers_regidrago_v_active() -> String:
	var strategy := _new_strategy(REGIDRAGO_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRegidrago.gd should exist before opening setup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Regidrago V", "Basic", "G", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	return assert_eq(active_name, "Regidrago V", "Regidrago shells should open on Regidrago V when available")


func test_regidrago_search_prefers_dragon_attack_fuel_over_generic_basic() -> String:
	var strategy := _new_strategy(REGIDRAGO_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRegidrago.gd should exist before search priorities can be verified"
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Regidrago VSTAR", "VSTAR", "G", 280, "Regidrago V", "V"), 0)
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0),
	]
	var picked := _best_card_name(strategy, items, "search_pokemon", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Giratina VSTAR", "Regidrago should prefer dragon attack fuel over generic setup targets")


func test_lugia_setup_prefers_lugia_v_active() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before opening setup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Wellspring Mask Ogerpon ex", "Basic", "W", 210, "", "ex"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	return assert_eq(active_name, "Lugia V", "Lugia shells should lead with Lugia V")


func test_lugia_scores_discard_setup_higher_than_generic_draw() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before discard-setup scoring can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0)
	player.deck.append(CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0
	)
	var research_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(ultra_ball_score >= 350.0, "Lugia should heavily value discard setup pieces when Archeops is still in deck (got %f)" % ultra_ball_score),
		assert_true(ultra_ball_score > research_score, "Lugia should prefer direct discard setup over generic draw early"),
	])


func test_lugia_vstar_power_scores_high_once_archeops_are_in_discard() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before VSTAR-power priorities can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var lugia_slot := _make_slot(_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V"), 0)
	player.active_pokemon = lugia_slot
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	var ability_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": lugia_slot},
		gs,
		0
	)
	return assert_true(ability_score >= 700.0, "Lugia should strongly prefer Summoning Star once two Archeops are ready (got %f)" % ability_score)


func test_lugia_summon_targets_prefer_archeops() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before summon target priorities can be verified"
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0),
		CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0),
	]
	var picked := _best_card_name(strategy, items, "summon_targets", {})
	return assert_eq(picked, "Archeops", "Lugia should summon Archeops before generic colorless targets")


func test_dialga_setup_prefers_beldum_active_to_start_engine() -> String:
	var strategy := _new_strategy(DIALGA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDialgaMetang.gd should exist before opening setup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Origin Forme Dialga V", "Basic", "M", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Beldum", "Basic", "M", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Mew ex", "Basic", "P", 180, "", "ex"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	return assert_eq(active_name, "Beldum", "Dialga/Metang should open on Beldum to start the metal engine")


func test_dialga_scores_metang_evolution_above_generic_line() -> String:
	var strategy := _new_strategy(DIALGA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDialgaMetang.gd should exist before evolution priorities can be verified"
	var gs := _make_game_state(3)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Beldum", "Basic", "M", 70), 0))
	var metang_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Metang", "Stage 1", "M", 100, "Beldum"), 0)},
		gs,
		0
	)
	var generic_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Pidgeotto", "Stage 1", "C", 80, "Pidgey"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(metang_score >= 420.0, "Dialga should strongly value Metang engine progress (got %f)" % metang_score),
		assert_true(metang_score > generic_score, "Metang evolution should outrank a generic Stage 1 line"),
	])


func test_dialga_metang_ability_prioritizes_powering_dialga() -> String:
	var strategy := _new_strategy(DIALGA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDialgaMetang.gd should exist before Metang ability priorities can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var metang_slot := _make_slot(_make_pokemon_cd("Metang", "Stage 1", "M", 100, "Beldum"), 0)
	var dialga_slot := _make_slot(_make_pokemon_cd(
		"Origin Forme Dialga VSTAR",
		"VSTAR",
		"M",
		280,
		"Origin Forme Dialga V",
		"V",
		[],
		[{"name": "Metal Blast", "cost": "MMC", "damage": "220"}]
	), 0)
	dialga_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Metal Energy", "M"), 0))
	player.active_pokemon = dialga_slot
	player.bench.append(metang_slot)
	var ability_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": metang_slot},
		gs,
		0
	)
	return assert_true(ability_score >= 500.0, "Dialga should strongly value Metal Maker when Dialga is still short on energy (got %f)" % ability_score)


func test_arceus_setup_prefers_arceus_v_active() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before opening setup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	return assert_eq(active_name, "Arceus V", "Arceus/Giratina should open on Arceus V")


func test_arceus_setup_falls_back_to_one_retreat_basic_after_arceus_v() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before setup fallback priorities can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [], 2), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70, "", "", [], [], 1), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70, "", "", [], [], 1), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	return assert_true(active_name == "Bidoof" or active_name == "Skwovet", "Without Arceus V, Arceus/Giratina should prefer a 1-retreat basic as the active over heavier retreat options")


func test_arceus_search_prefers_giratina_closer_once_arceus_is_online() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before search priorities can be verified"
	var gs := _make_game_state(4)
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	gs.players[0].active_pokemon = arceus_slot
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
	]
	var picked := _best_card_name(strategy, items, "search_pokemon", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Giratina VSTAR", "Arceus/Giratina should search its finisher once Arceus is online")


func test_arceus_search_prefers_second_arceus_before_side_engine() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before second Arceus search priorities can be verified"
	var gs := _make_game_state(2)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
	]
	var picked := _best_card_name(strategy, items, "search_pokemon", {"game_state": gs, "player_index": 0, "all_items": items})
	var nest_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_eq(picked, "Arceus V", "When only one Arceus is in play, search should complete the second Arceus before side-engine pieces"),
		assert_true(nest_ball_score >= 400.0, "Nest Ball should stay high-priority while the second Arceus is still missing (got %f)" % nest_ball_score),
	])


func test_arceus_double_turbo_prefers_arceus_over_giratina() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before energy routing can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = arceus_slot
	player.bench.append(giratina_slot)
	var energy := CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0)
	var arceus_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": energy, "target_slot": arceus_slot},
		gs,
		0
	)
	var giratina_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": energy, "target_slot": giratina_slot},
		gs,
		0
	)
	return run_checks([
		assert_true(arceus_score >= 450.0, "Arceus shell should aggressively open on Double Turbo to Arceus (got %f)" % arceus_score),
		assert_true(arceus_score > giratina_score, "Double Turbo should go to Arceus before Giratina in the opening setup"),
		assert_eq(giratina_score, 0.0, "Double Turbo should not be routed into Giratina in the opening setup"),
	])


func test_arceus_search_for_first_arceus_outranks_off_plan_opening_attach() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before first-Arceus launch ordering can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	player.bench.append(giratina_slot)
	var nest_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball"), 0)},
		gs,
		0
	)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0
	)
	var attach_to_giratina: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0), "target_slot": giratina_slot},
		gs,
		0
	)
	return run_checks([
		assert_true(nest_ball_score > attach_to_giratina, "When no Arceus is in play, searching the first Arceus should outrank attaching energy to Giratina first"),
		assert_true(ultra_ball_score > attach_to_giratina, "Ultra Ball should also outrank off-plan opening attachments until Arceus is online"),
		assert_eq(attach_to_giratina, 0.0, "Without any Arceus in play, opening energy should not be routed into Giratina before finding Arceus"),
	])


func test_arceus_benching_hand_arceus_outranks_redundant_opening_search() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before redundant opening search can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var hand_arceus := CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	player.hand.append(hand_arceus)
	player.hand.append(ultra_ball)
	player.hand.append(nest_ball)
	var bench_arceus_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": hand_arceus},
		gs,
		0
	)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": ultra_ball},
		gs,
		0
	)
	var nest_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": nest_ball},
		gs,
		0
	)
	return run_checks([
		assert_true(bench_arceus_score > ultra_ball_score, "If Arceus V is already in hand, directly benching it should outrank spending Ultra Ball to search another copy"),
		assert_true(bench_arceus_score > nest_ball_score, "If Arceus V is already in hand, directly benching it should also outrank redundant Nest Ball opening search"),
	])


func test_arceus_opening_attach_to_active_pivot_stays_live_until_first_arceus_appears() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before pivot fallback attachment can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var active_pivot := _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	player.active_pokemon = active_pivot
	var dte_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": active_pivot},
		gs,
		0
	)
	var basic_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0), "target_slot": active_pivot},
		gs,
		0
	)
	return run_checks([
		assert_true(dte_score > 0.0, "If Arceus is still missing, Double Turbo on an active 1-retreat pivot should stay live as a retreat-enabling fallback"),
		assert_true(basic_score > 0.0, "If Arceus is still missing, a basic Energy on the active 1-retreat pivot should also stay live rather than auto-passing"),
	])


func test_arceus_search_for_first_arceus_still_outranks_pivot_fallback_attach() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before pivot fallback ordering can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var active_pivot := _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	player.active_pokemon = active_pivot
	var nest_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball"), 0)},
		gs,
		0
	)
	var pivot_attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": active_pivot},
		gs,
		0
	)
	return assert_true(nest_ball_score > pivot_attach_score, "Finding the first Arceus should still outrank the pivot fallback attach in the opening")


func test_arceus_opening_typed_attach_to_active_giratina_stays_live_but_double_turbo_is_dead() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before active Giratina fallback attachment can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var active_giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	player.active_pokemon = active_giratina
	var dte_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": active_giratina},
		gs,
		0
	)
	var grass_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0), "target_slot": active_giratina},
		gs,
		0
	)
	return run_checks([
		assert_eq(dte_score, 0.0, "Double Turbo should stay off Giratina even in the opening fallback state"),
		assert_true(grass_score > 0.0, "With active Giratina and no Arceus online yet, a typed Energy should also stay live as fallback progress"),
	])


func test_arceus_benches_hand_arceus_before_non_arceus_manual_attach() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before hand-Arceus attachment ordering can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var active_giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	player.active_pokemon = active_giratina
	var hand_arceus := CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	player.hand.append(hand_arceus)
	var bench_arceus_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": hand_arceus},
		gs,
		0
	)
	var giratina_dte_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": active_giratina},
		gs,
		0
	)
	var giratina_grass_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0), "target_slot": active_giratina},
		gs,
		0
	)
	return run_checks([
		assert_true(bench_arceus_score > giratina_grass_score, "If Arceus is already in hand, benching it should outrank fallback energy onto Giratina"),
		assert_eq(giratina_dte_score, 0.0, "If Arceus is already in hand, Double Turbo should not be spent on Giratina first"),
	])


func test_arceus_keeps_giratina_fallback_attach_live_when_hand_arceus_cannot_be_benched() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before bench-full fallback attachment can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var active_giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	player.active_pokemon = active_giratina
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Radiant Gardevoir", "Basic", "P", 130, "", "Radiant"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	var giratina_grass_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0), "target_slot": active_giratina},
		gs,
		0
	)
	return assert_true(giratina_grass_score > 0.0, "If Arceus is stuck in hand because the bench is full, typed fallback energy on active Giratina should remain live")


func test_arceus_search_for_first_arceus_still_outranks_active_giratina_fallback_attach() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before active Giratina fallback ordering can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var active_giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	player.active_pokemon = active_giratina
	var nest_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball"), 0)},
		gs,
		0
	)
	var dte_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": active_giratina},
		gs,
		0
	)
	return assert_true(nest_ball_score > dte_score, "Finding the first Arceus should still outrank fallback energy on active Giratina")


func test_arceus_assignment_prefers_giratina_for_grass_energy_after_arceus_online() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Trinity Nova routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = arceus_slot
	player.bench.append(giratina_slot)
	var picked := _best_slot_name(
		strategy,
		[arceus_slot, giratina_slot],
		"assignment_target",
		{"game_state": gs, "player_index": 0, "source_card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)}
	)
	return assert_eq(picked, "Giratina V", "After Arceus is online, extra typed energy should route into Giratina")


func test_arceus_trinity_nova_source_selection_includes_psychic_and_avoids_all_grass() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Trinity Nova source selection can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	var grass_a := CardInstance.create(_make_energy_cd("Grass A", "G"), 0)
	var grass_b := CardInstance.create(_make_energy_cd("Grass B", "G"), 0)
	var grass_c := CardInstance.create(_make_energy_cd("Grass C", "G"), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic A", "P"), 0)
	var picked: Array = strategy.pick_interaction_items(
		[grass_a, grass_b, grass_c, psychic],
		{"id": "energy_assignments", "max_select": 3},
		{"game_state": gs, "player_index": 0}
	)
	var picked_names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance and (item as CardInstance).card_data != null:
			picked_names.append(str((item as CardInstance).card_data.name))
	return run_checks([
		assert_eq(picked.size(), 3, "Trinity Nova should still choose three basic Energy cards when they are available"),
		assert_true("Psychic A" in picked_names, "Trinity Nova should include a Psychic Energy when Giratina still lacks its Psychic requirement"),
		assert_true(not (picked_names == ["Grass A", "Grass B", "Grass C"]), "Trinity Nova should not blindly take three Grass Energy when Giratina still needs Psychic"),
	])


func test_arceus_trinity_nova_psychic_assignment_prefers_giratina_over_backup_arceus() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Trinity Nova Psychic routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var giratina_score: float = strategy.score_interaction_target(
		giratina,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": psychic}
	)
	var backup_arceus_score: float = strategy.score_interaction_target(
		backup_arceus,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": psychic}
	)
	return run_checks([
		assert_true(giratina_score > backup_arceus_score, "Trinity Nova's Psychic Energy should go to Giratina before backup Arceus while Giratina still lacks Psychic"),
		assert_true(giratina_score > 0.0, "Trinity Nova Psychic routing should stay live toward Giratina"),
	])


func test_arceus_trinity_nova_third_grass_prefers_backup_arceus_after_giratina_core_is_pending() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Trinity Nova late assignment routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "GPC", "damage": "280"}]), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var pending_assignments: Array = [
		{"source": CardInstance.create(_make_energy_cd("Grass Pending", "G"), 0), "target": giratina},
		{"source": CardInstance.create(_make_energy_cd("Psychic Pending", "P"), 0), "target": giratina},
	]
	var giratina_score: float = strategy.score_interaction_target(
		giratina,
		{"id": "energy_assignments"},
		{
			"game_state": gs,
			"player_index": 0,
			"source_card": grass,
			"pending_assignment_counts": {int(giratina.get_instance_id()): 2},
			"pending_assignments": pending_assignments,
		}
	)
	var backup_arceus_score: float = strategy.score_interaction_target(
		backup_arceus,
		{"id": "energy_assignments"},
		{
			"game_state": gs,
			"player_index": 0,
			"source_card": grass,
			"pending_assignment_counts": {int(giratina.get_instance_id()): 2},
			"pending_assignments": pending_assignments,
		}
	)
	return run_checks([
		assert_true(backup_arceus_score > giratina_score, "Once Giratina already has pending Grass and Psychic from Trinity Nova, the third Grass should pivot into the backup Arceus lane"),
		assert_true(backup_arceus_score > 0.0, "The backup Arceus lane should remain live for the leftover Trinity Nova attachment"),
	])


func test_arceus_assignment_stops_overfilling_active_arceus_when_shell_still_needs_targets() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before overfill routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina_slot)
	var energy := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var active_score: float = strategy.score_interaction_target(
		active_arceus,
		{"id": "assignment_target"},
		{"game_state": gs, "player_index": 0, "source_card": energy}
	)
	var backup_score: float = strategy.score_interaction_target(
		backup_arceus,
		{"id": "assignment_target"},
		{"game_state": gs, "player_index": 0, "source_card": energy}
	)
	var giratina_score: float = strategy.score_interaction_target(
		giratina_slot,
		{"id": "assignment_target"},
		{"game_state": gs, "player_index": 0, "source_card": energy}
	)
	return run_checks([
		assert_true(active_score < backup_score, "Once active Arceus is already online, Trinity Nova energy should stop overfilling it while the backup shell still needs energy"),
		assert_true(active_score < giratina_score, "Online active Arceus should also trail Giratina while the transition line is still missing energy"),
	])


func test_arceus_search_cards_prefers_typed_energy_for_giratina_transition() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before transition search priorities can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = arceus_slot
	player.bench.append(giratina_slot)
	var items: Array = [
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
	]
	var picked := _best_card_name(strategy, items, "search_cards", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Grass Energy", "Once Arceus is online, transition search should start prioritizing typed Giratina fuel")


func test_arceus_starbirth_outranks_bibarel_when_transition_piece_missing() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Starbirth transition scoring can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	var bibarel_slot := _make_slot(_make_pokemon_cd("Bibarel", "Stage 1", "C", 120, "Bidoof"), 0)
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = arceus_slot
	player.bench.append(giratina_slot)
	player.bench.append(bibarel_slot)
	player.hand.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	var arceus_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": arceus_slot},
		gs,
		0
	)
	var bibarel_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": bibarel_slot},
		gs,
		0
	)
	return assert_true(arceus_score > bibarel_score, "Starbirth should outrank Bibarel draw when Giratina transition fuel is still missing")


func test_arceus_transition_values_trinity_nova_over_generic_pressure() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Trinity Nova tempo scoring can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = arceus_slot
	player.bench.append(giratina_slot)
	var trinity_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": arceus_slot, "attack_name": "Trinity Nova", "projected_damage": 200},
		gs,
		0
	)
	var generic_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": arceus_slot, "attack_name": "Power Edge", "projected_damage": 200},
		gs,
		0
	)
	return assert_true(trinity_score > generic_score, "Transition phase should value Trinity Nova above generic same-damage pressure")


func test_arceus_capturing_aroma_outranks_trinity_nova_when_shell_is_thin() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Aroma launch timing can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = arceus_slot
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var aroma_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Capturing Aroma"), 0)},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": arceus_slot, "attack_name": "Trinity Nova", "projected_damage": 200},
		gs,
		0
	)
	return assert_true(aroma_score > attack_score, "When only one Arceus is in play and the shell is still thin, Capturing Aroma should outrank another immediate Trinity Nova")


func test_arceus_iono_outranks_trinity_nova_when_shell_is_thin_and_hand_is_stuck() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Iono launch timing can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = arceus_slot
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var iono_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": arceus_slot, "attack_name": "Trinity Nova", "projected_damage": 200},
		gs,
		0
	)
	return assert_true(iono_score > attack_score, "When the shell is still thin and the hand is stuck, Iono should outrank another immediate Trinity Nova to refresh resources")


func test_arceus_starbirth_outranks_trinity_nova_when_shell_rebuild_is_needed() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Starbirth shell-rebuild timing can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = arceus_slot
	player.hand.append(CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var starbirth_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": arceus_slot},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": arceus_slot, "attack_name": "Trinity Nova", "projected_damage": 200},
		gs,
		0
	)
	return assert_true(starbirth_score > attack_score, "When only one Arceus is online and the shell still lacks Giratina and the draw engine, Starbirth should outrank another Trinity Nova")


func test_arceus_search_cards_prefers_bidoof_over_typed_energy_when_shell_is_thin() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before thin-shell search priorities can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = arceus_slot
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	var items: Array = [
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
		CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0),
	]
	var picked := _best_card_name(strategy, items, "search_cards", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Bidoof", "When Arceus is online but the draw engine is still missing, search should complete Bidoof before grabbing more typed energy")


func test_arceus_conversion_prefers_giratina_finisher_over_arceus_followup() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before finisher conversion can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	var arceus_slot := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	giratina_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	giratina_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	arceus_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = giratina_slot
	player.bench.append(arceus_slot)
	var giratina_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": giratina_slot, "attack_name": "Lost Impact", "projected_damage": 220},
		gs,
		0
	)
	var arceus_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": arceus_slot, "attack_name": "Trinity Nova", "projected_damage": 220},
		gs,
		0
	)
	return assert_true(giratina_score > arceus_score, "Conversion phase should prefer the Giratina finisher over another Arceus follow-up")


func test_arceus_boss_orders_rises_when_it_creates_conversion_window() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before gust timing can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	giratina_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C"), 0))
	player.active_pokemon = giratina_slot
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var bench_target := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	opponent.bench.append(bench_target)
	var boss_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0), "target_slot": bench_target},
		gs,
		0
	)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(boss_score > judge_score, "Boss's Orders should rise when it creates a live conversion KO window")


func test_arceus_setup_benches_core_shell_before_off_plan_basics() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before opening shell can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Radiant Gardevoir", "Basic", "P", 130), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var bench_indices: Array = choice.get("bench_hand_indices", [])
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	var bench_names: Array[String] = []
	for idx_variant: Variant in bench_indices:
		var idx: int = int(idx_variant)
		bench_names.append(str(player.hand[idx].card_data.name))
	return run_checks([
		assert_eq(active_name, "Arceus V", "Arceus/Giratina should still open on Arceus V"),
		assert_eq(bench_names, ["Arceus V", "Giratina V", "Bidoof", "Skwovet"], "Opening shell should bench the second Arceus, Giratina, Bidoof, and Skwovet before off-plan basics"),
	])


func test_arceus_double_turbo_prefers_bench_arceus_over_giratina_after_launch() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before backup Arceus routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var bench_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Shred", "cost": "PCC", "damage": "160"}]), 0)
	player.active_pokemon = active_arceus
	player.bench.append(bench_arceus)
	player.bench.append(giratina_slot)
	var dte := CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0)
	var bench_arceus_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": dte, "target_slot": bench_arceus},
		gs,
		0
	)
	var giratina_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": dte, "target_slot": giratina_slot},
		gs,
		0
	)
	return run_checks([
		assert_true(bench_arceus_score > giratina_score, "Once the lead Arceus is online, Double Turbo should build the backup Arceus before Giratina"),
		assert_eq(giratina_score, 0.0, "Once the lead Arceus is online, Double Turbo should remain dead on Giratina"),
	])


func test_arceus_bibarel_engine_outranks_off_plan_support_once_core_board_missing() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Bibarel engine priorities can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	var bidoof_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var skwovet_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var radiant_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Radiant Gardevoir", "Basic", "P", 130), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(bidoof_score > radiant_score, "The Bibarel line should outrank off-plan support while the core board is still incomplete"),
		assert_true(skwovet_score > radiant_score, "Skwovet should also outrank off-plan support while the draw engine is still missing"),
	])


func test_arceus_skwovet_ability_is_dead_without_bibarel() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Skwovet ability gating can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	var skwovet_slot := _make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)
	player.bench.append(skwovet_slot)
	player.hand.append(CardInstance.create(_make_trainer_cd("Card A", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Card B", "Item"), 0))
	var skwovet_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": skwovet_slot},
		gs,
		0
	)
	return assert_eq(skwovet_score, 0.0, "Without Bibarel on the field, Skwovet should never spend its ability first")


func test_arceus_skwovet_ability_outranks_bibarel_when_both_are_online() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Skwovet/Bibarel sequencing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	var bibarel_slot := _make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0)
	var skwovet_slot := _make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)
	player.bench.append(bibarel_slot)
	player.bench.append(skwovet_slot)
	player.hand.append(CardInstance.create(_make_trainer_cd("Card A", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Card B", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Card C", "Item"), 0))
	var bibarel_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": bibarel_slot},
		gs,
		0
	)
	var skwovet_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": skwovet_slot},
		gs,
		0
	)
	return run_checks([
		assert_true(skwovet_score > bibarel_score, "When Bibarel is online, Skwovet should be taken first so Bibarel can draw after the hand reset"),
		assert_true(skwovet_score > 0.0, "When Bibarel is online, Skwovet should become a live sequencing action"),
	])


func test_arceus_radiant_gardevoir_stays_negative_until_v_window_and_shell_ready() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Radiant Gardevoir deployment gating can be verified"

	var setup_gs := _make_game_state(4)
	var setup_player := setup_gs.players[0]
	setup_player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	setup_player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	setup_player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	setup_gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var setup_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Radiant Gardevoir", "Basic", "P", 130, "", "Radiant"), 0)},
		setup_gs,
		0
	)

	var v_window_gs := _make_game_state(5)
	var v_window_player := v_window_gs.players[0]
	v_window_player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	v_window_player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	v_window_player.bench.append(_make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V"), 0))
	v_window_player.bench.append(_make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0))
	v_window_player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	v_window_gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var v_window_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Radiant Gardevoir", "Basic", "P", 130, "", "Radiant"), 0)},
		v_window_gs,
		0
	)

	return run_checks([
		assert_true(setup_score < 0.0, "Radiant Gardevoir should be a negative-value bench action before the shell is online and no opposing V is active"),
		assert_true(v_window_score > setup_score, "Radiant Gardevoir should only rise once the board is built and the opposing active is a V Pokemon"),
	])


func test_arceus_trainer_timing_prefers_judge_when_ahead_and_iono_when_behind() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before supporter timing can be verified"
	var ahead_gs := _make_game_state(5)
	var ahead_player := ahead_gs.players[0]
	var ahead_opponent := ahead_gs.players[1]
	ahead_player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	ahead_player.prizes = []
	for i: int in 2:
		ahead_player.prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i), 0))
	for i: int in 5:
		ahead_opponent.prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i), 1))
	var ahead_judge: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		ahead_gs,
		0
	)
	var ahead_iono: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)},
		ahead_gs,
		0
	)

	var behind_gs := _make_game_state(5)
	var behind_player := behind_gs.players[0]
	var behind_opponent := behind_gs.players[1]
	behind_player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	for i: int in 5:
		behind_player.prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i), 0))
	for i: int in 2:
		behind_opponent.prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i), 1))
	behind_player.hand.append(CardInstance.create(_make_trainer_cd("Card A", "Item"), 0))
	behind_player.hand.append(CardInstance.create(_make_trainer_cd("Card B", "Item"), 0))
	behind_player.hand.append(CardInstance.create(_make_trainer_cd("Card C", "Item"), 0))
	behind_player.hand.append(CardInstance.create(_make_trainer_cd("Card D", "Item"), 0))
	var behind_judge: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		behind_gs,
		0
	)
	var behind_iono: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)},
		behind_gs,
		0
	)
	return run_checks([
		assert_true(ahead_judge > ahead_iono, "When Arceus is ahead, Judge should outrank Iono as the default disruption"),
		assert_true(behind_iono > behind_judge, "When Arceus is behind, Iono should outrank Judge as the comeback disruption"),
	])


func test_arceus_boss_orders_stays_low_without_immediate_attack_window() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Boss's Orders timing can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	var bench_target := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(bench_target)
	var boss_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0), "target_slot": bench_target},
		gs,
		0
	)
	var aroma_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Capturing Aroma"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_eq(boss_score, 0.0, "Boss's Orders should not be spent in launch when the active cannot attack and no immediate swing exists"),
		assert_true(aroma_score > boss_score, "Setup search should outrank Boss's Orders when Arceus is still trying to launch"),
	])


func test_arceus_lost_vacuum_stays_low_without_any_valid_target() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Lost Vacuum timing can be verified"
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var vacuum_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0)},
		gs,
		0
	)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_eq(vacuum_score, 0.0, "Lost Vacuum should stay dead when there is no stadium or tool target to remove"),
		assert_true(ultra_ball_score > vacuum_score, "Real setup cards should outrank Lost Vacuum when there is nothing meaningful to vacuum"),
	])


func test_arceus_lost_city_stays_live_once_shell_is_online() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Lost City timing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var lost_city_score: float = strategy.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd("Lost City", "Stadium"), 0)},
		gs,
		0
	)
	return assert_true(lost_city_score > 0.0, "Once Arceus is online, Lost City should stay a live stadium action instead of being invisible to absolute scoring")


func test_arceus_deck_out_pressure_cools_off_draw_and_search_churn() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before deck-out cooloff rules can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	active_giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	active_giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var bibarel := _make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0)
	var skwovet := _make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)
	player.active_pokemon = active_giratina
	player.bench.append(backup_arceus)
	player.bench.append(bibarel)
	player.bench.append(skwovet)
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck Filler %d" % i, "Item"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var skwovet_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": skwovet},
		gs,
		0
	)
	var bibarel_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": bibarel},
		gs,
		0
	)
	var nest_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball"), 0)},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_giratina, "attack_name": "Lost Impact", "projected_damage": 280},
		gs,
		0
	)
	return run_checks([
		assert_eq(skwovet_score, 0.0, "Under deck-out pressure with a ready attacker, Skwovet should cool off instead of churning extra draws"),
		assert_eq(bibarel_score, 0.0, "Under deck-out pressure with a ready attacker, Bibarel should also stop low-value redraw churn"),
		assert_eq(nest_ball_score, 0.0, "Under deck-out pressure with a ready attacker, extra Nest Ball shell padding should shut off"),
		assert_true(attack_score > 0.0, "The live finisher should remain available while the churn actions cool off"),
	])


func test_arceus_conversion_cools_off_midgame_search_and_redraw_churn() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before conversion cooloff rules can be verified"
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	var bibarel := _make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0)
	var skwovet := _make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	player.bench.append(bibarel)
	player.bench.append(skwovet)
	for i: int in 10:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck Filler %d" % i, "Item"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var aroma_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Capturing Aroma"), 0)},
		gs,
		0
	)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge"), 0)},
		gs,
		0
	)
	var skwovet_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": skwovet},
		gs,
		0
	)
	var bibarel_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": bibarel},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 200},
		gs,
		0
	)
	return run_checks([
		assert_eq(aroma_score, 0.0, "Once the active attacker is live and the core shell is already formed, Capturing Aroma should cool off instead of padding the turn"),
		assert_eq(judge_score, 0.0, "Once the active attacker is live and the core shell is already formed, Judge should cool off instead of burning a redraw window"),
		assert_eq(skwovet_score, 0.0, "Once the active attacker is live and the core shell is already formed, Skwovet should stop midgame redraw churn"),
		assert_eq(bibarel_score, 0.0, "Once the active attacker is live and the core shell is already formed, Bibarel should also cool off"),
		assert_true(attack_score > 0.0, "The live attack should remain available while the midgame churn actions cool off"),
	])


func test_arceus_switch_outranks_redraw_when_ready_bench_finisher_unlocks_attack() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Switch attack-window timing can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_skwovet := _make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)
	active_skwovet.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	var bibarel := _make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0)
	player.active_pokemon = active_skwovet
	player.bench.append(giratina)
	player.bench.append(bibarel)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var switch_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Switch"), 0)},
		gs,
		0
	)
	var iono_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Iono"), 0)},
		gs,
		0
	)
	var bibarel_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": bibarel},
		gs,
		0
	)
	return run_checks([
		assert_true(switch_score > iono_score, "When Switch immediately unlocks the ready bench finisher, it should outrank Iono redraw churn"),
		assert_true(switch_score > bibarel_score, "When Switch immediately unlocks the ready bench finisher, it should also outrank Bibarel redraw churn"),
		assert_true(switch_score >= 300.0, "Switch should become a real positive action when it opens the live attack window"),
	])


func test_arceus_post_launch_reentry_keeps_giratina_transition_live() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-launch re-entry timing can be verified"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var bibarel := _make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0)
	var skwovet := _make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)
	player.active_pokemon = active_arceus
	player.bench.append(giratina)
	player.bench.append(bibarel)
	player.bench.append(skwovet)
	for i: int in 5:
		player.prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i), 0))
	for i: int in 2:
		opponent.prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i), 1))
	player.hand.append(CardInstance.create(_make_trainer_cd("Card A", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Card B", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Card C", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Card D", "Item"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0), "target_slot": giratina},
		gs,
		0
	)
	var iono_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)},
		gs,
		0
	)
	var skwovet_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": skwovet},
		gs,
		0
	)
	var bibarel_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": bibarel},
		gs,
		0
	)
	return run_checks([
		assert_true(attach_score > iono_score, "After the first Arceus shell breaks, near-ready Giratina should keep the deck in transition rather than falling back to Iono-first launch logic"),
		assert_true(attach_score > skwovet_score, "After the first Arceus shell breaks, near-ready Giratina should outrank Skwovet redraw churn"),
		assert_true(attach_score > bibarel_score, "After the first Arceus shell breaks, near-ready Giratina should also outrank Bibarel redraw churn"),
	])


func test_arceus_iron_leaves_only_rises_when_it_can_take_immediate_charizard_ko() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Iron Leaves deployment rules can be verified"

	var charizard_gs := _make_game_state(4)
	var charizard_player := charizard_gs.players[0]
	var charizard_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	charizard_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	charizard_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	charizard_player.active_pokemon = charizard_arceus
	charizard_gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage2", "D", 330, "Charmeleon", "ex"), 1)
	var charizard_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0)},
		charizard_gs,
		0
	)

	var moon_gs := _make_game_state(4)
	var moon_player := moon_gs.players[0]
	var moon_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	moon_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	moon_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	moon_player.active_pokemon = moon_arceus
	moon_gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Roaring Moon ex", "Basic", "D", 230, "", "ex"), 1)
	var moon_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0)},
		moon_gs,
		0
	)

	var low_energy_gs := _make_game_state(4)
	var low_energy_player := low_energy_gs.players[0]
	var low_energy_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	low_energy_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	low_energy_player.active_pokemon = low_energy_arceus
	low_energy_gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage2", "D", 330, "Charmeleon", "ex"), 1)
	var low_energy_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0)},
		low_energy_gs,
		0
	)

	return run_checks([
		assert_true(charizard_score > moon_score, "Iron Leaves should rise specifically into Charizard ex rather than generic Dark attackers"),
		assert_true(charizard_score > low_energy_score, "Iron Leaves should only spike when the current board can actually convert into an immediate Charizard knockout"),
		assert_true(charizard_score >= 600.0, "When Iron Leaves can immediately take a Charizard knockout, it should become a top-priority bench action"),
		assert_true(moon_score <= 40.0, "Against non-Charizard Dark decks, Iron Leaves should stay a low-probability bench target"),
		assert_true(low_energy_score <= 40.0, "Without enough movable energy to threaten Prism Edge immediately, Iron Leaves should stay a low-probability bench target"),
	])


func test_arceus_does_not_route_energy_into_iron_leaves_without_dark_window() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Iron Leaves energy routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	var iron_leaves_slot := _make_slot(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(giratina_slot)
	player.bench.append(iron_leaves_slot)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var attach_to_giratina: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0), "target_slot": giratina_slot},
		gs,
		0
	)
	var attach_to_iron_leaves: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0), "target_slot": iron_leaves_slot},
		gs,
		0
	)
	var assignment_to_giratina: float = strategy.score_interaction_target(
		giratina_slot,
		{"id": "assignment_target"},
		{"game_state": gs, "player_index": 0, "source_card": CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)}
	)
	var assignment_to_iron_leaves: float = strategy.score_interaction_target(
		iron_leaves_slot,
		{"id": "assignment_target"},
		{"game_state": gs, "player_index": 0, "source_card": CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)}
	)
	return run_checks([
		assert_true(attach_to_giratina > attach_to_iron_leaves, "Without a Dark active window, manual energy should route into Giratina before Iron Leaves"),
		assert_true(assignment_to_giratina > assignment_to_iron_leaves, "Without a Dark active window, assignment routing should also avoid Iron Leaves"),
	])


func test_arceus_does_not_route_energy_into_off_plan_support_after_launch() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before off-plan energy routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var bench_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	var radiant_slot := _make_slot(_make_pokemon_cd("Radiant Gardevoir", "Basic", "P", 130), 0)
	player.active_pokemon = active_arceus
	player.bench.append(bench_arceus)
	player.bench.append(giratina_slot)
	player.bench.append(radiant_slot)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var energy := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var attach_to_backup_arceus: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": energy, "target_slot": bench_arceus},
		gs,
		0
	)
	var attach_to_radiant: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": energy, "target_slot": radiant_slot},
		gs,
		0
	)
	var assignment_to_backup_arceus: float = strategy.score_interaction_target(
		bench_arceus,
		{"id": "assignment_target"},
		{"game_state": gs, "player_index": 0, "source_card": energy}
	)
	var assignment_to_radiant: float = strategy.score_interaction_target(
		radiant_slot,
		{"id": "assignment_target"},
		{"game_state": gs, "player_index": 0, "source_card": energy}
	)
	return run_checks([
		assert_true(attach_to_backup_arceus > attach_to_radiant, "Once launch is online, manual energy should keep building the Arceus shell instead of drifting into Radiant Gardevoir"),
		assert_true(assignment_to_backup_arceus > assignment_to_radiant, "Assignment routing should also avoid off-plan support targets after launch"),
		assert_eq(attach_to_radiant, 0.0, "Radiant Gardevoir should not receive manual energy routing in the normal Arceus shell plan"),
		assert_eq(assignment_to_radiant, 0.0, "Radiant Gardevoir should not receive assignment routing in the normal Arceus shell plan"),
	])


func test_arceus_discard_prefers_off_plan_techs_before_core_shell_cards() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before contextual discard priorities can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Radiant Gardevoir", "Basic", "P", 130, "", "Radiant"), 0),
		CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0),
		CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0),
		CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0),
	]
	var picked := _best_card_name(strategy, items, "discard_cards", {"game_state": gs, "player_index": 0, "all_items": items})
	return run_checks([
		assert_true(picked == "Radiant Gardevoir" or picked == "Iron Leaves ex", "When they are off-plan, Radiant Gardevoir and Iron Leaves ex should be the preferred discard targets before Arceus VSTAR or Double Turbo Energy"),
	])


func test_arceus_search_cards_prefers_double_turbo_when_it_enables_immediate_attack() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before immediate Double Turbo search priorities can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	var items: Array = [
		CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0),
		CardInstance.create(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0),
		CardInstance.create(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V"), 0),
	]
	var picked := _best_card_name(strategy, items, "search_cards", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Double Turbo Energy", "When Double Turbo gives the active Arceus immediate Trinity Nova, it should be the top search hit")


func test_arceus_double_turbo_prefers_active_arceus_when_it_turns_on_trinity_nova() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before immediate Double Turbo routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina_slot)
	var dte := CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0)
	var active_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": dte, "target_slot": active_arceus},
		gs,
		0
	)
	var backup_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": dte, "target_slot": backup_arceus},
		gs,
		0
	)
	var giratina_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": dte, "target_slot": giratina_slot},
		gs,
		0
	)
	return run_checks([
		assert_true(active_score > backup_score, "If Double Turbo turns on the active Arceus immediately, that should outrank building the backup Arceus"),
		assert_true(active_score > giratina_score, "If Double Turbo turns on the active Arceus immediately, that should also outrank Giratina setup"),
	])


func test_arceus_launch_online_discourages_retreating_active_arceus_vstar() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before retreat discipline can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var retreat_score: float = strategy.score_action_absolute({"kind": "retreat"}, gs, 0)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 200},
		gs,
		0
	)
	return run_checks([
		assert_true(retreat_score < 0.0, "Once Arceus VSTAR is online and the shell is nearly built, retreating should be actively discouraged"),
		assert_true(attack_score > retreat_score, "Online Arceus VSTAR should prefer attacking over fleeing"),
	])


func test_arceus_convert_retreat_is_allowed_when_ready_giratina_finishes_the_game() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before finisher retreat windows can be verified"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 280, "", "ex"), 1)
	var retreat_score: float = strategy.score_action_absolute({"kind": "retreat"}, gs, 0)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 200},
		gs,
		0
	)
	return run_checks([
		assert_true(retreat_score > 0.0, "Once the full shell is online and Giratina VSTAR has the clean finisher, retreat should become legal and favorable"),
		assert_true(retreat_score > attack_score, "A clean Giratina finisher window should outrank another Trinity Nova when Arceus cannot finish the target"),
	])


func test_arceus_retreat_prefers_ready_giratina_target_over_engine_pivot() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before retreat target ordering can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	var skwovet := _make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)
	player.active_pokemon = active_arceus
	player.bench.append(giratina)
	player.bench.append(skwovet)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 280, "", "ex"), 1)
	var giratina_retreat_score: float = strategy.score_action_absolute(
		{"kind": "retreat", "bench_target": giratina},
		gs,
		0
	)
	var skwovet_retreat_score: float = strategy.score_action_absolute(
		{"kind": "retreat", "bench_target": skwovet},
		gs,
		0
	)
	return run_checks([
		assert_true(giratina_retreat_score > skwovet_retreat_score, "When retreat is correct, Arceus/Giratina should prefer the ready Giratina finisher over an engine pivot target"),
		assert_true(giratina_retreat_score >= 300.0, "Retreating into the ready Giratina finisher should stay a real positive action"),
	])


func test_arceus_send_out_prefers_backup_arceus_over_one_prize_engine() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before send-out priorities can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	var bidoof := _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	player.bench.append(bidoof)
	var picked := _best_slot_name(strategy, [backup_arceus, giratina, bidoof], "send_out", {"game_state": gs, "player_index": 0})
	return assert_eq(picked, "Arceus VSTAR", "When the lead Arceus falls, Arceus/Giratina should send out the backup Arceus before one-prize engine pieces")


func test_arceus_handoff_prefers_ready_giratina_over_backup_arceus_after_launch() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before handoff priorities can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var ready_giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	ready_giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	ready_giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	ready_giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	var bidoof := _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	player.active_pokemon = active_arceus
	player.bench.append(ready_giratina)
	player.bench.append(backup_arceus)
	player.bench.append(bidoof)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var send_out_pick := _best_slot_name(strategy, [ready_giratina, backup_arceus, bidoof], "send_out", {"game_state": gs, "player_index": 0})
	var switch_pick := _best_slot_name(strategy, [ready_giratina, backup_arceus, bidoof], "self_switch_target", {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_eq(send_out_pick, "Giratina VSTAR", "Once launch is online and Giratina VSTAR is ready, knockout replacement should hand off to the finisher instead of recycling backup Arceus"),
		assert_eq(switch_pick, "Giratina VSTAR", "Switch-like handoff prompts should agree with send_out and keep attack ownership on the ready Giratina finisher"),
	])


func test_arceus_attach_tool_prefers_maximum_belt_on_online_active_arceus() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before tool routing can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var maximum_belt := CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0)
	var arceus_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": maximum_belt, "target_slot": active_arceus},
		gs,
		0
	)
	var giratina_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0), "target_slot": giratina},
		gs,
		0
	)
	return run_checks([
		assert_true(arceus_score >= 500.0, "Online active Arceus VSTAR should strongly value Maximum Belt in the midgame shell plan"),
		assert_true(arceus_score > giratina_score, "Maximum Belt should land on the active Arceus VSTAR before Giratina in the normal tempo plan"),
	])


func test_arceus_attach_tool_prefers_choice_belt_into_v_targets() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Choice Belt routing can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var bibarel := _make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(bibarel)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var choice_belt := CardInstance.create(_make_trainer_cd("Choice Belt", "Tool"), 0)
	var arceus_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": choice_belt, "target_slot": active_arceus},
		gs,
		0
	)
	var bibarel_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd("Choice Belt", "Tool"), 0), "target_slot": bibarel},
		gs,
		0
	)
	return run_checks([
		assert_true(arceus_score > bibarel_score, "Choice Belt should prefer a ready Arceus VSTAR when the opposing active is a V target"),
		assert_true(arceus_score >= 420.0, "Choice Belt should become a real tempo tool against V targets rather than generic filler"),
	])


func test_arceus_stops_benching_basic_pokemon_once_target_formation_is_complete() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before full-shell bench locking can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var extra_arceus_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)},
		gs,
		0
	)
	var extra_bidoof_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)},
		gs,
		0
	)
	return run_checks([
		assert_eq(extra_arceus_score, 0.0, "Once the target formation is complete, Arceus should stop benching more basics"),
		assert_eq(extra_bidoof_score, 0.0, "Once the target formation is complete, Arceus should stop benching extra engine basics"),
	])


func test_arceus_stops_padding_shell_once_launch_and_giratina_lane_are_live() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-launch shell padding can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(giratina)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var extra_arceus_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)},
		gs,
		0
	)
	var bidoof_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var skwovet_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)},
		gs,
		0
	)
	return run_checks([
		assert_eq(extra_arceus_score, 0.0, "Once Arceus is online and a Giratina lane exists, extra Arceus padding should stop"),
		assert_eq(bidoof_score, 0.0, "Once Arceus is online and a Giratina lane exists, engine basics should stop padding the shell"),
		assert_eq(skwovet_score, 0.0, "Once Arceus is online and a Giratina lane exists, Skwovet should not be benched ahead of conversion"),
	])


func test_arceus_keeps_second_arceus_live_into_charizard_after_launch() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Charizard backup-Arceus windows can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(giratina)
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("Judge", "Supporter"), i))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 1)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 1))
	var extra_arceus_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)},
		gs,
		0
	)
	var bidoof_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var skwovet_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(extra_arceus_score > 0.0, "Into Charizard, the second Arceus lane should stay live after launch if backup Arceus is still missing"),
		assert_true(extra_arceus_score > bidoof_score, "Into Charizard, the second Arceus lane should outrank rebuilding the Bidoof engine once launch is already online"),
		assert_true(extra_arceus_score > skwovet_score, "Into Charizard, the second Arceus lane should also outrank Skwovet padding once launch is already online"),
	])


func test_arceus_search_keeps_second_arceus_ahead_of_engine_into_charizard() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Charizard search ordering can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 1)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 1))
	var options: Array = [
		CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
		CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0),
	]
	var picked := _best_card_name(strategy, options, "search_pokemon", {"game_state": gs, "player_index": 0})
	return assert_eq(picked, "Arceus V", "Into Charizard, second-Arceus search should stay ahead of extra engine hits after launch")


func test_arceus_charizard_reentry_cools_off_redraw_before_backup_arceus_ready() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Charizard re-entry cooloff can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var live_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	live_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	live_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var stranded_giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = stranded_giratina
	player.bench.append(live_arceus)
	player.bench.append(backup_arceus)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage2", "D", 330, "Charmeleon", "ex"), 1)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Pidgeot ex", "Stage2", "C", 280, "Pidgeotto", "ex"), 1))
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		gs,
		0
	)
	var iono_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)},
		gs,
		0
	)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": backup_arceus},
		gs,
		0
	)
	return run_checks([
		assert_eq(judge_score, 0.0, "Into Charizard re-entry, Judge should not interrupt the backup-Arceus rebuild window"),
		assert_eq(iono_score, 0.0, "Into Charizard re-entry, Iono should also stay dead while the backup Arceus still needs to be rebuilt"),
		assert_true(attach_score > 0.0, "Into Charizard re-entry, manual Double Turbo attachment to the backup Arceus should remain live"),
	])


func test_arceus_charizard_reentry_cools_off_bibarel_and_skwovet_abilities() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Charizard re-entry draw churn can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var live_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	live_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	live_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var stranded_giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	var bibarel := _make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0)
	var skwovet := _make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)
	player.active_pokemon = stranded_giratina
	player.bench.append(live_arceus)
	player.bench.append(backup_arceus)
	player.bench.append(bibarel)
	player.bench.append(skwovet)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage2", "D", 330, "Charmeleon", "ex"), 1)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Pidgeot ex", "Stage2", "C", 280, "Pidgeotto", "ex"), 1))
	var bibarel_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": bibarel, "ability_index": 0}, gs, 0)
	var skwovet_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": skwovet, "ability_index": 0}, gs, 0)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": backup_arceus},
		gs,
		0
	)
	return run_checks([
		assert_eq(bibarel_score, 0.0, "Into Charizard re-entry, Bibarel should cool off until the backup Arceus line is actually online"),
		assert_eq(skwovet_score, 0.0, "Into Charizard re-entry, Skwovet should also cool off instead of spending the rebuild turn on redraw churn"),
		assert_true(attach_score > bibarel_score, "Into Charizard re-entry, rebuilding the backup Arceus should outrank Bibarel draw"),
		assert_true(attach_score > skwovet_score, "Into Charizard re-entry, rebuilding the backup Arceus should also outrank Skwovet"),
	])


func test_regidrago_discard_prefers_real_dragon_fuel_over_radiant_charizard() -> String:
	var strategy := _new_strategy(REGIDRAGO_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRegidrago.gd should exist before discard priorities can be verified"
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Radiant Charizard", "Basic", "R", 160), 0),
	]
	var picked := _best_card_name(strategy, items, "discard_cards", {})
	return assert_eq(picked, "Giratina VSTAR", "Regidrago should discard dragon attack fuel before off-plan non-dragon tech")


func test_regidrago_copied_attack_prefers_haxorus_into_special_energy_target() -> String:
	var strategy := _new_strategy(REGIDRAGO_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRegidrago.gd should exist before copied attack priorities can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var opp_active := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opp_active.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 1))
	gs.players[1].active_pokemon = opp_active
	var options: Array = [
		{
			"source_card": CardInstance.create(_make_pokemon_cd("Haxorus", "Stage 2", "N", 170, "Fraxure"), 0),
			"attack_index": 0,
			"attack": {"name": "Crusher Stomp", "cost": "F", "damage": "", "text": "", "is_vstar_power": false},
		},
		{
			"source_card": CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
		},
	]
	var picked := _best_copied_attack_label(strategy, options, {"game_state": gs, "player_index": 0})
	return assert_eq(picked, "Haxorus:Crusher Stomp", "Regidrago should prioritize Haxorus into a special-energy target")


func test_regidrago_copied_attack_prefers_dragapult_when_bench_pressure_exists() -> String:
	var strategy := _new_strategy(REGIDRAGO_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRegidrago.gd should exist before copied attack bench-pressure priorities can be verified"
	var gs := _make_game_state(4)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 330, "", "ex"), 1)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1))
	var options: Array = [
		{
			"source_card": CardInstance.create(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Lost Impact", "cost": "GPC", "damage": "280", "text": "", "is_vstar_power": false},
		},
		{
			"source_card": CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
		},
	]
	var picked := _best_copied_attack_label(strategy, options, {"game_state": gs, "player_index": 0})
	return assert_eq(picked, "Dragapult ex:Phantom Dive", "Regidrago should value Dragapult's spread when the opponent has a developed bench")
