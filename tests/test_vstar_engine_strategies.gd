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


func test_lugia_setup_prefers_minccino_over_side_attackers_when_owner_missing() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before missing-owner opening setup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Wellspring Mask Ogerpon ex", "Basic", "W", 210, "", "ex"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	return assert_eq(active_name, "Minccino", "Without Lugia V in hand, Lugia shells should still open on Minccino before side attackers")


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


func test_lugia_vstar_power_stays_dead_before_any_archeops_hit_discard() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before pre-discard VSTAR-power timing can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var lugia_slot := _make_slot(_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V"), 0)
	player.active_pokemon = lugia_slot
	var research := CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)
	player.hand.append(research)
	var ability_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": lugia_slot},
		gs,
		0
	)
	var research_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": research},
		gs,
		0
	)
	return run_checks([
		assert_true(ability_score <= 0.0, "Lugia should not fire Summoning Star before any Archeops are in discard (got %f)" % ability_score),
		assert_true(research_score > ability_score, "Pre-discard setup draw should outrank a dead Summoning Star activation"),
	])


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


func test_lugia_early_attach_prefers_lugia_owner_over_side_attackers() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before opening attachment discipline can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(
		_make_pokemon_cd(
			"Lugia V",
			"Basic",
			"C",
			220,
			"",
			"V",
			[],
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
		),
		0
	)
	var iron_hands := _make_slot(
		_make_pokemon_cd(
			"Iron Hands ex",
			"Basic",
			"L",
			230,
			"",
			"ex",
			[],
			[{"name": "Amp You Very Much", "cost": "LCCC", "damage": "120"}]
		),
		0
	)
	var wellspring := _make_slot(
		_make_pokemon_cd(
			"Wellspring Mask Ogerpon ex",
			"Basic",
			"W",
			210,
			"",
			"ex",
			[],
			[{"name": "Myriad Leaf Shower", "cost": "WCC", "damage": "140"}]
		),
		0
	)
	player.bench.append(iron_hands)
	player.bench.append(wellspring)
	var jet_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	var iron_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0), "target_slot": iron_hands},
		gs,
		0
	)
	var wellspring_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0), "target_slot": wellspring},
		gs,
		0
	)
	return run_checks([
		assert_true(jet_score > iron_score, "Lugia opening should attach Jet Energy to Lugia owner before Iron Hands ex (got %f vs %f)" % [jet_score, iron_score]),
		assert_true(jet_score > wellspring_score, "Lugia opening should attach Jet Energy to Lugia owner before Wellspring Mask Ogerpon ex (got %f vs %f)" % [jet_score, wellspring_score]),
	])


func test_lugia_search_prefers_first_lugia_owner_over_archeops_when_owner_missing() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before first-owner search priorities can be verified"
	var gs := _make_game_state(2)
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0),
		CardInstance.create(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0),
	]
	var picked := _best_card_name(strategy, items, "search_pokemon", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Lugia V", "Lugia should search the first Lugia owner before raw Archeops fuel when no Lugia is online")


func test_lugia_search_prefers_archeops_once_lugia_owner_is_already_in_hand() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before owner-in-hand search priorities can be verified"
	var gs := _make_game_state(2)
	gs.players[0].hand.append(CardInstance.create(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0),
		CardInstance.create(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0),
	]
	var picked := _best_card_name(strategy, items, "search_pokemon", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Archeops", "Once Lugia V is already in hand, Lugia should use search to load Archeops before taking a duplicate owner")


func test_lugia_search_does_not_take_vstar_before_first_owner_hits_field() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before VSTAR search timing can be verified"
	var gs := _make_game_state(2)
	gs.players[0].hand.append(CardInstance.create(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0),
		CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0),
	]
	var picked := _best_card_name(strategy, items, "search_pokemon", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Archeops", "Before the first Lugia owner is on the field, Lugia should finish shell progress instead of searching Lugia VSTAR")


func test_lugia_plays_first_owner_before_spending_more_search() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before owner-first launch sequencing can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	var lugia_v := CardInstance.create(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0)
	player.hand.append(lugia_v)
	var play_owner_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": lugia_v},
		gs,
		0
	)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(play_owner_score >= 500.0, "When Lugia V is already in hand, benching the first owner should become a launch-shell priority (got %f)" % play_owner_score),
		assert_true(play_owner_score > ultra_ball_score, "Lugia should bench the first Lugia V before spending another search card in launch shell"),
	])


func test_lugia_early_attach_prefers_benched_lugia_owner_over_active_side_attacker() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before benched-owner attach priorities can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(
		_make_pokemon_cd(
			"Iron Hands ex",
			"Basic",
			"L",
			230,
			"",
			"ex",
			[],
			[{"name": "Amp You Very Much", "cost": "LCCC", "damage": "120"}]
		),
		0
	)
	var lugia := _make_slot(
		_make_pokemon_cd(
			"Lugia V",
			"Basic",
			"C",
			220,
			"",
			"V",
			[],
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
		),
		0
	)
	player.bench.append(lugia)
	var lugia_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": lugia},
		gs,
		0
	)
	var iron_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	return run_checks([
		assert_true(lugia_score > iron_score, "Lugia opening should attach Double Turbo Energy to the benched Lugia owner before feeding an off-plan active side attacker"),
		assert_true(lugia_score >= 400.0, "Benched Lugia owner should stay a high-priority attach target in the launch shell"),
	])


func test_lugia_launch_shell_keeps_special_energy_off_side_attacker_when_owner_missing() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before side-attacker attachment suppression can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(
		_make_pokemon_cd(
			"Wellspring Mask Ogerpon ex",
			"Basic",
			"W",
			210,
			"",
			"ex",
			[],
			[{"name": "Myriad Leaf Shower", "cost": "WCC", "damage": "140"}]
		),
		0
	)
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var side_attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	return assert_true(side_attach_score <= 20.0, "Without any Lugia owner online, Lugia should keep Jet Energy off off-plan side attackers in launch shell (got %f)" % side_attach_score)


func test_lugia_turn_contract_names_bridge_when_shell_missing() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before turn-contract shell metadata can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	return run_checks([
		assert_eq(str(turn_contract.get("intent", "")), "launch_shell", "Lugia should expose a launch-shell contract before Archeops is online"),
		assert_eq(str((turn_contract.get("owner", {}) as Dictionary).get("bridge_target_name", "")), "Lugia V", "Missing-owner launch shells should advertise Lugia V as the bridge target"),
		assert_true("Lugia V" in ((turn_contract.get("priorities", {}) as Dictionary).get("search", []) as Array), "Missing-owner launch shells should rank Lugia V in search priorities"),
	])


func test_lugia_turn_contract_stops_prioritizing_archeops_once_engine_is_online() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before post-engine turn-contract metadata can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(
		_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V", [], [{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]),
		0
	)
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags := turn_contract.get("flags", {}) as Dictionary
	var search_priorities := ((turn_contract.get("priorities", {}) as Dictionary).get("search", []) as Array)
	return run_checks([
		assert_true(bool(flags.get("engine_online", false)), "This board should count as engine-online for Lugia"),
		assert_true(not bool(flags.get("archeops_short", false)), "Once Archeops is already online, the contract should stop advertising an Archeops-short shell"),
		assert_true("Archeops" not in search_priorities, "Post-engine search priorities should not keep Archeops as a rebuild target"),
		assert_true("Cinccino" in search_priorities or "Lugia V" in search_priorities or "Lugia VSTAR" in search_priorities, "Post-engine search should pivot toward real rebuild/conversion targets"),
	])


func test_lugia_evolve_prefers_cinccino_once_archeops_engine_is_online() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Cinccino evolve priorities can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var cinccino_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Cinccino", "Stage 1", "C", 110, "Minccino"), 0)},
		gs,
		0
	)
	var generic_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Pidgeotto", "Stage 1", "C", 80, "Pidgey"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(cinccino_score >= 600.0, "Once Archeops is online, evolving Minccino into Cinccino should become a top-priority line (got %f)" % cinccino_score),
		assert_true(cinccino_score > generic_score, "Cinccino evolve should outrank generic Stage 1 evolution once the Lugia engine is online"),
	])


func test_lugia_search_prefers_cinccino_over_side_attacker_once_minccino_is_online() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Cinccino search priorities can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Cinccino", "Stage 1", "C", 110, "Minccino"), 0),
		CardInstance.create(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 0),
	]
	var picked := _best_card_name(strategy, items, "search_pokemon", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Cinccino", "With Minccino already online, Lugia should search the Cinccino attacker before a side attacker")


func test_lugia_special_energy_attach_prefers_cinccino_over_iron_hands_once_engine_is_online() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Cinccino special-energy routing can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	var cinccino := _make_slot(_make_pokemon_cd("Cinccino", "Stage 1", "C", 110, "Minccino"), 0)
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 0)
	player.bench.append(cinccino)
	player.bench.append(iron_hands)
	var gift_to_cinccino: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Gift Energy", "C", "Special Energy"), 0), "target_slot": cinccino},
		gs,
		0
	)
	var gift_to_iron_hands: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Gift Energy", "C", "Special Energy"), 0), "target_slot": iron_hands},
		gs,
		0
	)
	return run_checks([
		assert_true(gift_to_cinccino > gift_to_iron_hands, "With Archeops online, special energy should route into Cinccino before Iron Hands ex when building the main attacker"),
		assert_true(gift_to_cinccino >= 260.0, "Cinccino should remain a live special-energy target once the engine is online"),
	])


func test_lugia_cinccino_damage_model_recognizes_special_energy_scaling() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Cinccino damage scaling can be verified"
	var cinccino_slot := _make_slot(
		_make_pokemon_cd(
			"Cinccino",
			"Stage 1",
			"C",
			110,
			"Minccino",
			"",
			[],
			[
				{"name": "Special Roll", "cost": "CC", "damage": "70x"},
				{"name": "Tail Smack", "cost": "C", "damage": "30"}
			]
		),
		0
	)
	cinccino_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "C", "Special Energy"), 0))
	cinccino_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	var forecast: Dictionary = strategy.predict_attacker_damage(cinccino_slot)
	return run_checks([
		assert_true(bool(forecast.get("can_attack", false)), "Cinccino with two special energy should be recognized as attack-ready"),
		assert_eq(int(forecast.get("damage", 0)), 140, "Cinccino damage model should read 2 attached special energy as 140 damage"),
	])


func test_lugia_convert_attack_cools_off_research_once_engine_and_attacker_are_online() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before late churn suppression can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var active_lugia := _make_slot(
		_make_pokemon_cd(
			"Lugia VSTAR",
			"VSTAR",
			"C",
			280,
			"Lugia V",
			"V",
			[],
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
		),
		0
	)
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "C", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Mist Energy", "C", "Special Energy"), 0))
	player.active_pokemon = active_lugia
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "projected_damage": 220},
		gs,
		0
	)
	var research_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(attack_score > research_score, "Once Lugia is already attack-ready and Archeops is online, attacking should outrank redraw churn"),
		assert_true(research_score <= 100.0, "Late redraw should cool off once the Lugia engine is already converting"),
	])


func test_lugia_deck_out_pressure_cools_off_great_ball_once_attacker_is_live() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before deck-out churn suppression can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active_lugia := _make_slot(
		_make_pokemon_cd(
			"Lugia VSTAR",
			"VSTAR",
			"C",
			280,
			"Lugia V",
			"V",
			[],
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
		),
		0
	)
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Mist Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_lugia
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	player.deck.clear()
	for i: int in 8:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck Filler %d" % i), 0))
	var great_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Great Ball"), 0)},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_lugia, "attack_name": "Tempest Dive", "projected_damage": 220},
		gs,
		0
	)
	return run_checks([
		assert_eq(great_ball_score, 0.0, "When the deck is low and Lugia already has a live attacker, Great Ball should cool off instead of burning more redraw churn"),
		assert_true(attack_score > great_ball_score, "A live attack should outrank deck-out padding search"),
	])


func test_lugia_deck_out_pressure_cools_off_fezandipiti_draw_once_attacker_is_live() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Fezandipiti draw cooloff can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active_lugia := _make_slot(
		_make_pokemon_cd(
			"Lugia VSTAR",
			"VSTAR",
			"C",
			280,
			"Lugia V",
			"V",
			[],
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
		),
		0
	)
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Mist Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_lugia
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	var fez := _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	player.bench.append(fez)
	player.deck.clear()
	for i: int in 8:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck Filler %d" % i), 0))
	var fez_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": fez},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_lugia, "attack_name": "Tempest Dive", "projected_damage": 220},
		gs,
		0
	)
	return run_checks([
		assert_eq(fez_score, 0.0, "When the deck is low and Lugia already has a live attacker, Fezandipiti draw should cool off instead of pushing toward deck out"),
		assert_true(attack_score > fez_score, "A live attack should outrank Fezandipiti redraw churn"),
	])


func test_lugia_convert_attack_cools_off_side_padding_once_engine_is_online() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before side-padding suppression can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var active_lugia := _make_slot(
		_make_pokemon_cd(
			"Lugia VSTAR",
			"VSTAR",
			"C",
			280,
			"Lugia V",
			"V",
			[],
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
		),
		0
	)
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "C", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Mist Energy", "C", "Special Energy"), 0))
	player.active_pokemon = active_lugia
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var cornerstone_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Cornerstone Mask Ogerpon ex", "Basic", "F", 210, "", "ex"), 0)},
		gs,
		0
	)
	var minccino_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(cornerstone_score <= 20.0, "Once the engine is online, off-plan side attackers should stop padding the bench"),
		assert_true(minccino_score <= 40.0, "Once Lugia is already converting and a Minccino rebuild line already exists, extra Minccino padding should cool off"),
	])


func test_lugia_play_stadium_keeps_jamming_tower_live_into_tool_heavy_charizard_board() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Jamming Tower timing can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 1)
	rotom.attached_tool = CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 1)
	var pidgeot := _make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 1)
	pidgeot.attached_tool = CardInstance.create(_make_trainer_cd("Defiance Band", "Tool"), 1)
	opponent.bench.append(rotom)
	opponent.bench.append(pidgeot)
	var jamming := CardInstance.create(_make_trainer_cd("Jamming Tower", "Stadium"), 0)
	var play_score: float = strategy.score_action_absolute({"kind": "play_stadium", "card": jamming}, gs, 0)
	return assert_true(play_score >= 180.0, "Jamming Tower should stay a live stadium action when it blanks high-value Charizard tools (got %f)" % play_score)


func test_lugia_play_stadium_keeps_collapsed_stadium_dead_in_opening_without_cleanup() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before empty Collapsed Stadium timing can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 1))
	var collapsed := CardInstance.create(_make_trainer_cd("Collapsed Stadium", "Stadium"), 0)
	var play_score: float = strategy.score_action_absolute({"kind": "play_stadium", "card": collapsed}, gs, 0)
	return assert_true(play_score <= 20.0, "Collapsed Stadium should stay dead in the opening when neither side has real trim value (got %f)" % play_score)


func test_lugia_play_stadium_keeps_collapsed_stadium_live_for_cleanup_and_wide_opponent_bench() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Collapsed Stadium cleanup timing can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Cinccino", "Stage 1", "C", 110, "Minccino"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 190, "", "V"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Wellspring Mask Ogerpon ex", "Basic", "W", 210, "", "ex"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(_make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 190, "", "V"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 1))
	var collapsed := CardInstance.create(_make_trainer_cd("Collapsed Stadium", "Stadium"), 0)
	var play_score: float = strategy.score_action_absolute({"kind": "play_stadium", "card": collapsed}, gs, 0)
	return assert_true(play_score >= 180.0, "Collapsed Stadium should stay live when it trims a spent Lugia bench and a wide Charizard bench at the same time (got %f)" % play_score)


func test_lugia_supporter_card_prefers_research_over_boss_while_owner_missing() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before supporter bridge timing can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var items: Array = [
		CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0),
		CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0),
		CardInstance.create(_make_trainer_cd("Thorton", "Supporter"), 0),
	]
	var picked := _best_card_name(strategy, items, "supporter_card", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Professor's Research", "When no Lugia owner is online, Lumineon should bridge into live draw support instead of Boss/Thorton")


func test_lugia_supporter_card_prefers_jacq_once_owner_is_online_and_vstar_missing() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Jacq bridge timing can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var items: Array = [
		CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0),
		CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0),
		CardInstance.create(_make_trainer_cd("Jacq", "Supporter"), 0),
	]
	var picked := _best_card_name(strategy, items, "supporter_card", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Jacq", "Once Lugia V is online and VSTAR is still missing, Lumineon should prefer Jacq to finish the launch shell")


func test_lugia_send_out_prefers_ready_cinccino_over_support_bench() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Lugia send-out handoff can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0)
	var ready_cinccino := _make_slot(
		_make_pokemon_cd(
			"Cinccino",
			"Stage 1",
			"C",
			110,
			"Minccino",
			"",
			[],
			[{"name": "Special Roll", "cost": "CC", "damage": "70x"}]
		),
		0
	)
	ready_cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	ready_cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0))
	var lumineon := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 190, "", "V"), 0)
	var minccino := _make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0)
	var picked := _best_slot_name(strategy, [ready_cinccino, lumineon, minccino], "send_out", {"game_state": gs, "player_index": 0})
	return assert_eq(picked, "Cinccino", "Once the engine is online, Lugia should send out the ready Cinccino instead of support bench pieces")


func test_lugia_switch_target_prefers_ready_cinccino_over_engine_support() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before Lugia switch handoff can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active_lugia := _make_slot(
		_make_pokemon_cd(
			"Lugia VSTAR",
			"VSTAR",
			"C",
			280,
			"Lugia V",
			"V",
			[],
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
		),
		0
	)
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Mist Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_lugia
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	var ready_cinccino := _make_slot(
		_make_pokemon_cd(
			"Cinccino",
			"Stage 1",
			"C",
			110,
			"Minccino",
			"",
			[],
			[{"name": "Special Roll", "cost": "CC", "damage": "70x"}]
		),
		0
	)
	ready_cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	ready_cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0))
	var lumineon := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 190, "", "V"), 0)
	player.bench.append(ready_cinccino)
	player.bench.append(lumineon)
	var picked := _best_slot_name(strategy, [ready_cinccino, lumineon], "self_switch_target", {"game_state": gs, "player_index": 0})
	return assert_eq(picked, "Cinccino", "When switching off a live Lugia board, Lugia should pivot into the ready Cinccino instead of engine support")


func test_lugia_convert_retreat_prefers_ready_cinccino_over_nonlethal_lugia_attack() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before conversion retreat timing can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active_lugia := _make_slot(
		_make_pokemon_cd(
			"Lugia VSTAR",
			"VSTAR",
			"C",
			280,
			"Lugia V",
			"V",
			[],
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
		),
		0
	)
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Mist Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_lugia
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	var cinccino := _make_slot(
		_make_pokemon_cd(
			"Cinccino",
			"Stage 1",
			"C",
			110,
			"Minccino",
			"",
			[],
			[{"name": "Special Roll", "cost": "CC", "damage": "70x"}]
		),
		0
	)
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0))
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "", "Special Energy"), 0))
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Mist Energy", "", "Special Energy"), 0))
	player.bench.append(cinccino)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Target ex", "Basic", "C", 280, "", "ex"), 1)
	var retreat_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": cinccino}, gs, 0)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_lugia, "attack_name": "Tempest Dive", "projected_damage": 220},
		gs,
		0
	)
	return run_checks([
		assert_true(retreat_score > attack_score, "When ready Cinccino converts a KO that active Lugia misses, retreat should outrank another nonlethal Lugia swing"),
		assert_true(retreat_score >= 300.0, "Retreating into the ready Cinccino finisher should stay a real positive action"),
	])


func test_lugia_retreat_prefers_ready_cinccino_target_over_support_bench() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before retreat target ordering can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active_lugia := _make_slot(
		_make_pokemon_cd(
			"Lugia VSTAR",
			"VSTAR",
			"C",
			280,
			"Lugia V",
			"V",
			[],
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
		),
		0
	)
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "", "Special Energy"), 0))
	active_lugia.attached_energy.append(CardInstance.create(_make_energy_cd("Mist Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_lugia
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	var cinccino := _make_slot(
		_make_pokemon_cd(
			"Cinccino",
			"Stage 1",
			"C",
			110,
			"Minccino",
			"",
			[],
			[{"name": "Special Roll", "cost": "CC", "damage": "70x"}]
		),
		0
	)
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0))
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "", "Special Energy"), 0))
	player.bench.append(cinccino)
	var lumineon := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 190, "", "V"), 0)
	player.bench.append(lumineon)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Target ex", "Basic", "C", 230, "", "ex"), 1)
	var cinccino_retreat_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": cinccino}, gs, 0)
	var lumineon_retreat_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": lumineon}, gs, 0)
	return run_checks([
		assert_true(cinccino_retreat_score > lumineon_retreat_score, "When retreat is correct, Lugia should prefer the ready Cinccino attacker over a support pivot"),
		assert_true(lumineon_retreat_score <= 40.0, "Retreating into a non-attacking support bench should stay low in conversion windows"),
	])


func test_lugia_launch_shell_prefers_owner_attach_over_side_chip_attack() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before launch-shell attack suppression can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var side_attacker := _make_slot(
		_make_pokemon_cd(
			"Wellspring Mask Ogerpon ex",
			"Basic",
			"W",
			210,
			"",
			"ex",
			[],
			[{"name": "Water Arrow", "cost": "C", "damage": "20"}]
		),
		0
	)
	side_attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "", "Special Energy"), 0))
	var lugia_v := _make_slot(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0)
	player.active_pokemon = side_attacker
	player.bench.append(lugia_v)
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var attack_score: float = strategy.score_action_absolute({"kind": "attack", "projected_damage": 20}, gs, 0)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Gift Energy", "", "Special Energy"), 0), "target_slot": lugia_v},
		gs,
		0
	)
	return assert_true(attach_score > attack_score, "Before the Lugia VSTAR shell is online, attaching to the benched Lugia owner should outrank a low-value side attack")


func test_lugia_launch_shell_prefers_vstar_search_over_side_chip_attack() -> String:
	var strategy := _new_strategy(LUGIA_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should exist before launch-shell VSTAR search timing can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var side_attacker := _make_slot(
		_make_pokemon_cd(
			"Wellspring Mask Ogerpon ex",
			"Basic",
			"W",
			210,
			"",
			"ex",
			[],
			[{"name": "Water Arrow", "cost": "C", "damage": "20"}]
		),
		0
	)
	side_attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy", "", "Special Energy"), 0))
	player.active_pokemon = side_attacker
	player.bench.append(_make_slot(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, "Lugia V", "V"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	var attack_score: float = strategy.score_action_absolute({"kind": "attack", "projected_damage": 20}, gs, 0)
	var jacq_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Jacq", "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(jacq_score > attack_score, "When Lugia V is online but VSTAR is still missing, exact VSTAR search should outrank a low-value side attack")




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


func test_arceus_basic_search_prefers_second_arceus_over_tech_basics_in_exact_launch_shell() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact-launch basic search priorities can be verified"
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V", [], [{"name": "Trinity Charge", "cost": "CC", "damage": "0"}]), 0)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0),
	]
	var picked := _best_card_name(strategy, items, "basic_pokemon", {"game_state": gs, "player_index": 0, "all_items": items})
	return assert_eq(picked, "Arceus V", "With active Arceus, hand VSTAR, and hand DTE, basic search should complete the second Arceus before Giratina or Iron Leaves")


func test_arceus_pick_interaction_items_basic_search_returns_second_arceus_in_exact_launch_shell() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact-launch basic search pick can be verified"
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V", [], [{"name": "Trinity Charge", "cost": "CC", "damage": "0"}]), 0)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	var arceus := CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina := CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	var iron_leaves := CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0)
	var items: Array = [iron_leaves, giratina, arceus]
	var planned: Variant = strategy.pick_interaction_items(
		items,
		{"id": "basic_pokemon", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	if not (planned is Array) or (planned as Array).is_empty():
		return "pick_interaction_items should return a non-empty exact-launch basic search plan, got %s" % str(planned)
	var chosen: CardInstance = (planned as Array)[0] as CardInstance
	var chosen_name := str(chosen.card_data.name) if chosen != null and chosen.card_data != null else ""
	return assert_eq(chosen_name, "Arceus V", "Exact-launch basic search should explicitly pick the second Arceus instead of Giratina or Iron Leaves")


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


func test_arceus_trinity_nova_source_selection_prefers_all_grass_when_only_backup_arceus_lane_exists() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before backup Arceus grass stocking can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
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
		assert_eq(picked.size(), 3, "Trinity Nova should still choose three basic Energy cards when only the backup Arceus lane is live"),
		assert_eq(picked_names, ["Grass A", "Grass B", "Grass C"], "Without any Giratina lane on board, Trinity Nova should stock the backup Arceus lane with Grass before Psychic"),
	])


func test_arceus_trinity_nova_source_selection_prefers_backup_vstar_grass_stock_when_double_vstar_shell_is_still_thin() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact double-VSTAR Trinity Nova source routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	gs.supporter_used_this_turn = true
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
		assert_eq(picked.size(), 3, "Exact double-VSTAR shell routing should still choose three Energy cards"),
		assert_eq(picked_names, ["Grass A", "Grass B", "Grass C"], "When double Arceus VSTAR is already online but the shell is still thin, Trinity Nova should stock the backup Arceus lane with Grass before taking Psychic for Giratina"),
	])


func test_arceus_trinity_nova_source_selection_keeps_backup_vstar_grass_stock_after_shell_finish_basics_are_online() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-redraw double-VSTAR Trinity Nova source routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(giratina)
	gs.supporter_used_this_turn = true
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
		assert_eq(picked.size(), 3, "Post-redraw double-VSTAR shell routing should still take three Energy cards"),
		assert_eq(picked_names, ["Grass A", "Grass B", "Grass C"], "Even after Bidoof and Skwovet are already online, Trinity Nova should keep stocking the backup Arceus lane before a still-cold Giratina basic in the exact shell-finish window"),
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


func test_arceus_trinity_nova_first_grass_prefers_giratina_while_both_core_types_are_missing() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Trinity Nova first-grass routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var giratina_score: float = strategy.score_interaction_target(
		giratina,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": grass}
	)
	var backup_arceus_score: float = strategy.score_interaction_target(
		backup_arceus,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": grass}
	)
	return run_checks([
		assert_true(giratina_score > backup_arceus_score, "When Giratina still lacks both Grass and Psychic, the first Grass should go to Giratina before starting backup Arceus"),
		assert_true(giratina_score > 0.0, "The first Grass lane into Giratina should stay live"),
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


func test_arceus_trinity_nova_exact_double_vstar_shell_assignment_prefers_backup_arceus_over_giratina() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact double-VSTAR assignment routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	gs.supporter_used_this_turn = true
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var giratina_score: float = strategy.score_interaction_target(
		giratina,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": grass}
	)
	var backup_arceus_score: float = strategy.score_interaction_target(
		backup_arceus,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": grass}
	)
	return run_checks([
		assert_true(backup_arceus_score > giratina_score, "In the exact double-VSTAR shell window, Trinity Nova should fill the backup Arceus before routing Grass into Giratina"),
		assert_true(backup_arceus_score >= 900.0, "The backup Arceus lane should become a first-class Trinity Nova assignment target in the exact shell window"),
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


func test_arceus_second_dte_stays_below_basic_energy_when_active_only_needs_one_more() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before overfill DTE routing can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina_slot)
	var second_dte := CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var second_dte_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": second_dte, "target_slot": active_arceus},
		gs,
		0
	)
	var grass_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": grass, "target_slot": active_arceus},
		gs,
		0
	)
	return run_checks([
		assert_true(grass_score > second_dte_score, "Once active Arceus already has one Double Turbo and only needs one more energy, a basic attachment should outrank a second Double Turbo"),
		assert_true(second_dte_score < 120.0, "A second Double Turbo should cool off sharply once one DTE is already attached and active Arceus only needs one more energy"),
	])


func test_arceus_exact_trinity_nova_line_cools_off_churn_and_pushes_basic_attach() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact Trinity Nova line discipline can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var giratina_slot := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina_slot)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var dte := CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var attach_basic_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": grass, "target_slot": active_arceus},
		gs,
		0
	)
	var bench_dte_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": dte, "target_slot": backup_arceus},
		gs,
		0
	)
	var iono_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)},
		gs,
		0
	)
	var nest_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)},
		gs,
		0
	)
	var starbirth_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": active_arceus},
		gs,
		0
	)
	return run_checks([
		assert_true(attach_basic_score > bench_dte_score, "When active Arceus VSTAR only needs one basic energy to cash in Trinity Nova, that basic attachment should outrank building the backup Arceus first"),
		assert_eq(iono_score, 0.0, "The exact Trinity Nova line should cool off Iono"),
		assert_eq(nest_score, 0.0, "The exact Trinity Nova line should cool off extra Nest Ball churn"),
		assert_eq(starbirth_score, 0.0, "If the hand already contains the exact missing basic energy, Starbirth should stay dead"),
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
	charizard_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	charizard_player.active_pokemon = charizard_arceus
	charizard_player.hand.append(CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0))
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
	moon_player.hand.append(CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0))
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
	low_energy_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	low_energy_player.active_pokemon = low_energy_arceus
	low_energy_player.hand.append(CardInstance.create(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 210, "", "ex"), 0))
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
		assert_true(low_energy_score <= 40.0, "Without the second Grass requirement online, Iron Leaves should stay a low-probability bench target"),
	])


func test_arceus_attach_jet_to_iron_leaves_does_not_false_positive_charizard_ko() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Iron Leaves attach routing can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var iron_leaves := _make_slot(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 220, "", "ex", [], [{"name": "Prism Edge", "cost": "GGC", "damage": "180"}]), 0)
	iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(iron_leaves)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage2", "D", 330, "Charmeleon", "ex"), 1)
	var jet_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0), "target_slot": iron_leaves},
		gs,
		0
	)
	return assert_true(jet_score < 560.0, "Jet Energy should not be treated as an immediate Iron Leaves Charizard knockout when the second Grass requirement is still missing")


func test_arceus_closeout_contract_requires_attackable_iron_leaves_not_just_old_board_copy() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Iron Leaves closeout convertibility can be verified"
	var gs := _make_game_state(13)
	var player := gs.players[0]
	var active_iron_leaves := _make_slot(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 220, "", "ex", [], [{"name": "Prism Edge", "cost": "GGC", "damage": "180"}]), 0)
	active_iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	active_iron_leaves.effects.append({
		"type": "attack_lock",
		"attack_name": "Prism Edge",
		"attack_index": 0,
		"turn": 11,
	})
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_iron_leaves
	player.bench.append(backup_arceus)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage2", "D", 330, "Charmeleon", "ex"), 1)
	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"kind": "action_selection"})
	return run_checks([
		assert_true(bool(turn_contract.get("flags", {}).get("vs_charizard", false)), "This board should still count as the Charizard matchup window"),
		assert_true(not bool(turn_contract.get("flags", {}).get("active_can_attack", false)), "Prism Edge self-lock should also clear the active_can_attack signal instead of leaving a fake ready-attacker flag behind"),
		assert_true(not bool(turn_contract.get("flags", {}).get("iron_leaves_ko_window", false)), "A board copy of Iron Leaves that is locked by Prism Edge should not be treated as a live same-turn Charizard knockout"),
		assert_true(str(turn_contract.get("intent", "")) != "close_out_prizes", "If the current Iron Leaves copy cannot attack this turn, the contract should not drift into close_out_prizes"),
	])


func test_arceus_closeout_starbirth_stays_dead_when_iron_leaves_line_is_already_live() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before close-out Starbirth timing can be verified"
	var gs := _make_game_state(13)
	var player := gs.players[0]
	var active_iron_leaves := _make_slot(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 220, "", "ex", [], [{"name": "Prism Edge", "cost": "GGC", "damage": "180"}]), 0)
	active_iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var bench_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	player.active_pokemon = active_iron_leaves
	player.bench.append(bench_arceus)
	player.deck.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage2", "D", 330, "Charmeleon", "ex"), 1)
	var starbirth_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": bench_arceus, "ability_index": 0},
		gs,
		0
	)
	return assert_eq(starbirth_score, 0.0, "When the Iron Leaves close-out line is already live and Starbirth cannot fetch any exact missing piece, Arceus VSTAR should not spend the turn on off-plan search payloads")


func test_arceus_exact_iron_leaves_closeout_cools_off_judge_and_bench_padding() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact Iron Leaves close-out timing can be verified"
	var gs := _make_game_state(13)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}], 2), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var bench_iron_leaves := _make_slot(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 220, "", "ex", [], [{"name": "Prism Edge", "cost": "GGC", "damage": "180"}]), 0)
	bench_iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	bench_iron_leaves.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(bench_iron_leaves)
	player.hand.append(CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage2", "D", 330, "Charmeleon", "ex"), 1)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		gs,
		0
	)
	var bench_arceus_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)},
		gs,
		0
	)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Jet Energy", "C", "Special Energy"), 0), "target_slot": bench_iron_leaves},
		gs,
		0
	)
	return run_checks([
		assert_eq(judge_score, 0.0, "When Iron Leaves already has an exact same-turn Charizard close-out line, Judge should stay dead"),
		assert_eq(bench_arceus_score, 0.0, "When Iron Leaves already has an exact same-turn Charizard close-out line, extra shell padding should stay dead"),
		assert_true(attach_score > judge_score, "In the exact close-out window, real convert progress should outrank redraw"),
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


func test_arceus_giratina_discard_energy_keeps_active_psychic_over_grass() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Giratina energy discard routing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "GPC", "damage": "280"}]), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var grass_a := CardInstance.create(_make_energy_cd("Grass A", "G"), 0)
	var grass_b := CardInstance.create(_make_energy_cd("Grass B", "G"), 0)
	active_giratina.attached_energy.append(psychic)
	active_giratina.attached_energy.append(grass_a)
	active_giratina.attached_energy.append(grass_b)
	player.active_pokemon = active_giratina
	var grass_score: float = strategy.score_interaction_target(
		grass_a,
		{"id": "discard_energy"},
		{"game_state": gs, "player_index": 0}
	)
	var psychic_score: float = strategy.score_interaction_target(
		psychic,
		{"id": "discard_energy"},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_true(grass_score > psychic_score, "When active Giratina VSTAR discards energy, Grass should be preferred over the last Psychic"),
		assert_true(psychic_score < 50.0, "The last Psychic on active Giratina should be strongly protected during discard-energy prompts"),
	])


func test_arceus_giratina_lost_zone_energy_keeps_active_psychic_over_grass() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Giratina lost-zone discard routing can be verified"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var active_giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "GPC", "damage": "280"}]), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var grass_a := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var grass_b := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	active_giratina.attached_energy.append(psychic)
	active_giratina.attached_energy.append(grass_a)
	active_giratina.attached_energy.append(grass_b)
	player.active_pokemon = active_giratina
	var grass_score: float = strategy.score_interaction_target(
		grass_a,
		{"id": "lost_zone_energy"},
		{"game_state": gs, "player_index": 0}
	)
	var psychic_score: float = strategy.score_interaction_target(
		psychic,
		{"id": "lost_zone_energy"},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_true(grass_score > psychic_score, "When Lost Impact prompts for lost-zone energy, Grass should still be preferred over the last Psychic"),
		assert_true(psychic_score < 50.0, "The last Psychic on active Giratina should stay strongly protected during lost-zone discard prompts"),
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


func test_arceus_exact_launch_starbirth_prefers_backup_vstar_and_grass_over_redundant_dte() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact Starbirth launch payloads can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.deck = [
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0),
	]
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0),
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0),
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
	]
	var picked: Array = strategy.pick_interaction_items(
		items,
		{"id": "search_cards", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var picked_names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance and (item as CardInstance).card_data != null:
			picked_names.append(str((item as CardInstance).card_data.name))
	return run_checks([
		assert_eq(picked.size(), 2, "The exact Arceus launch Starbirth window should commit to a 2-card payload"),
		assert_true("Arceus VSTAR" in picked_names, "The exact launch payload should fetch the second Arceus VSTAR for the backup shell"),
		assert_true("Grass Energy" in picked_names, "The exact launch payload should fetch the missing typed energy for active Trinity Nova"),
		assert_true(not ("Double Turbo Energy" in picked_names), "The exact launch payload should not burn Starbirth on a redundant second Double Turbo"),
	])


func test_arceus_benches_second_arceus_before_redraw_or_nonlethal_attack() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact second-Arceus launch timing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var bench_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": player.hand[0]}, gs, 0)
	var iono_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": player.hand[1]}, gs, 0)
	var attack_score: float = strategy.score_action_absolute({"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 180}, gs, 0)
	return run_checks([
		assert_true(bench_score > iono_score, "Once active Trinity Nova is live but the shell still lacks a backup Arceus, benching the second Arceus should outrank redraw (bench=%f iono=%f)" % [bench_score, iono_score]),
		assert_true(bench_score > attack_score, "The same exact second-Arceus window should bench the backup shell before a nonlethal Trinity Nova (bench=%f attack=%f)" % [bench_score, attack_score]),
	])


func test_arceus_benches_second_arceus_before_nonlethal_trinity_charge() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact second-Arceus launch timing can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V", [], [{"name": "Trinity Charge", "cost": "CC", "damage": "0"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var bench_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": player.hand[0]}, gs, 0)
	var attack_score: float = strategy.score_action_absolute({"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Charge", "projected_damage": 0}, gs, 0)
	return run_checks([
		assert_true(bench_score > attack_score, "When active Arceus V is already online but the shell still lacks a backup Arceus, benching the second Arceus should outrank a nonlethal Trinity Charge (bench=%f attack=%f)" % [bench_score, attack_score]),
		assert_true(bench_score >= 700.0, "This exact launch bench window should stay a high-priority opening action (got %f)" % bench_score),
	])


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


func test_arceus_launch_lock_discourages_retreating_dte_active_arceus_v() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before strong-launch retreat discipline can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V", [], [{"name": "Trinity Charge", "cost": "CC", "damage": "0"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0))
	var bidoof := _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	player.bench.append(bidoof)
	var retreat_score: float = strategy.score_action_absolute(
		{"kind": "retreat", "bench_target": bidoof},
		gs,
		0
	)
	return assert_true(retreat_score < 0.0, "When active Arceus V is already on the DTE->VSTAR launch line, retreating it should be actively discouraged")


func test_arceus_launch_lock_cools_off_iono_before_vstar_conversion() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before strong-launch redraw timing can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V", [], [{"name": "Trinity Charge", "cost": "CC", "damage": "0"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0))
	var iono_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)},
		gs,
		0
	)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		gs,
		0
	)
	var evolve_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_eq(iono_score, 0.0, "When Arceus V only needs the VSTAR conversion to cash in its DTE launch line, Iono should stay dead"),
		assert_eq(judge_score, 0.0, "The same launch-lock window should also cool off Judge"),
		assert_true(evolve_score > iono_score, "Arceus VSTAR evolution should outrank redraw in this scripted launch window"),
	])


func test_arceus_exact_active_launch_shell_build_prefers_backup_arceus_over_redundant_search() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact active Arceus shell-build ordering can be verified"
	var gs := _make_game_state(1)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V", [], [{"name": "Trinity Charge", "cost": "CC", "damage": "0"}]), 0)
	player.active_pokemon = active_arceus
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var judge := CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.hand.append(nest_ball)
	player.hand.append(ultra_ball)
	player.hand.append(judge)
	var nest_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": nest_ball},
		gs,
		0
	)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": ultra_ball},
		gs,
		0
	)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": judge},
		gs,
		0
	)
	var dte_attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": active_arceus},
		gs,
		0
	)
	return run_checks([
		assert_true(nest_ball_score > ultra_ball_score, "With active Arceus, hand Arceus VSTAR, and hand DTE, Nest Ball for the backup Arceus should outrank redundant Ultra Ball search"),
		assert_true(dte_attach_score > ultra_ball_score, "The same exact launch shell should keep the active DTE attach ahead of off-plan Ultra Ball churn"),
		assert_eq(judge_score, 0.0, "This exact active Arceus shell-build window should cool off Judge until the launch shell is assembled"),
	])


func test_arceus_launch_lock_cools_off_search_before_vstar_conversion() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact VSTAR conversion search timing can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V", [], [{"name": "Trinity Charge", "cost": "CC", "damage": "0"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0))
	player.hand.append(ultra_ball)
	player.hand.append(nest_ball)
	var evolve_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0)},
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
		assert_true(evolve_score > ultra_ball_score, "When active Arceus V already has DTE and Arceus VSTAR is in hand, evolving should outrank extra Ultra Ball search"),
		assert_true(evolve_score > nest_ball_score, "The same DTE->VSTAR launch window should also evolve before spending Nest Ball on extra basics"),
	])


func test_arceus_launch_lock_cools_off_search_after_backup_arceus_is_already_live() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact launch conversion search cooloff can be verified"
	var gs := _make_game_state(1)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V", [], [{"name": "Trinity Charge", "cost": "CC", "damage": "0"}]), 0)
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0))
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var dte := CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0)
	player.hand.append(ultra_ball)
	player.hand.append(nest_ball)
	player.hand.append(dte)
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
	var dte_attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": dte, "target_slot": active_arceus},
		gs,
		0
	)
	return run_checks([
		assert_eq(ultra_ball_score, 0.0, "Once backup Arceus is already live and hand DTE still turns on the active launch line, Ultra Ball should cool off"),
		assert_eq(nest_ball_score, 0.0, "The same exact launch conversion window should also cool off extra Nest Ball search"),
		assert_true(dte_attach_score > ultra_ball_score, "With backup Arceus already on board, the active DTE attach should clearly outrank off-plan search"),
	])


func test_arceus_post_judge_benches_giratina_before_redundant_ultra_ball_search() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-Judge exact shell ordering can be verified"
	var gs := _make_game_state(5)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Radiant Gardevoir", "Basic", "P", 130, "", "Radiant"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var giratina_bench_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)},
		gs,
		0
	)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(giratina_bench_score > ultra_ball_score, "After Judge, if Giratina V is already in hand, Arceus should bench it before spending another Ultra Ball on redundant shell search"),
		assert_true(giratina_bench_score >= 900.0, "That exact in-hand Giratina shell progress should become a real top-priority action"),
	])


func test_arceus_rebuild_window_benches_in_hand_giratina_before_judge() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before rebuild redraw ordering can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.damage_counters = 100
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0))
	var giratina := CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	var judge := CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)
	player.hand.append(giratina)
	player.hand.append(judge)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var giratina_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": giratina},
		gs,
		0
	)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": judge},
		gs,
		0
	)
	return run_checks([
		assert_true(giratina_score > judge_score, "In the exact rebuild redraw window, an in-hand Giratina should be benched before Judge redraws it away (bench=%f judge=%f)" % [giratina_score, judge_score]),
		assert_eq(judge_score, 0.0, "Judge should stay dead until the in-hand Giratina shell piece is actually benched in this exact rebuild window"),
	])


func test_arceus_pre_redraw_rebuild_cools_off_starbirth_until_backup_progress_and_judge_resolve() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before pre-redraw Starbirth timing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.damage_counters = 100
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var judge := CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)
	player.hand.append(ultra_ball)
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0))
	player.hand.append(judge)
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost City", "Stadium"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var starbirth_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": active_arceus, "ability_index": 0},
		gs,
		0
	)
	return run_checks([
		assert_eq(starbirth_score, 0.0, "When the rebuild line still needs backup VSTAR progress and a redraw is already in hand, Starbirth should stay dead until that exact shell sequence resolves"),
	])


func test_arceus_pre_starbirth_rebuild_prefers_ultra_ball_before_judge_and_starbirth() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before pre-Starbirth rebuild sequencing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.damage_counters = 100
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var judge := CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)
	player.hand.append(ultra_ball)
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0))
	player.hand.append(judge)
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost City", "Stadium"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": ultra_ball},
		gs,
		0
	)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": judge},
		gs,
		0
	)
	var starbirth_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": active_arceus, "ability_index": 0},
		gs,
		0
	)
	return run_checks([
		assert_true(ultra_ball_score > judge_score, "Before Starbirth cashes in the exact rebuild payload, Ultra Ball should progress the backup line before Judge redraws it (ultra=%f judge=%f)" % [ultra_ball_score, judge_score]),
		assert_true(ultra_ball_score > starbirth_score, "The same pre-Starbirth rebuild window should take Ultra Ball before early Starbirth (ultra=%f starbirth=%f)" % [ultra_ball_score, starbirth_score]),
		assert_eq(judge_score, 0.0, "Judge should stay dead until backup progress resolves in this pre-Starbirth rebuild window"),
		assert_eq(starbirth_score, 0.0, "Starbirth should also stay dead until the backup progress piece resolves first in this exact window"),
	])


func test_arceus_pre_starbirth_rebuild_search_prefers_backup_vstar_before_giratina() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before pre-Starbirth rebuild search priorities can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.damage_counters = 100
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost City", "Stadium"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var options: Array = [
		CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
	]
	var picked := _best_card_name(strategy, options, "search_pokemon", {"game_state": gs, "player_index": 0, "all_items": options})
	return assert_eq(picked, "Arceus VSTAR", "Before Starbirth cashes in the rest of the shell, the exact rebuild window should search the backup Arceus VSTAR before Giratina or engine basics")


func test_arceus_post_backup_vstar_judge_outranks_starbirth_until_redraw_resolves() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-backup redraw sequencing can be verified"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.damage_counters = 100
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0))
	var judge := CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)
	player.hand.append(judge)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": judge},
		gs,
		0
	)
	var starbirth_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": active_arceus, "ability_index": 0},
		gs,
		0
	)
	return run_checks([
		assert_true(judge_score > starbirth_score, "Once backup Arceus VSTAR is already online and Judge is the exact redraw bridge, it should outrank early Starbirth (judge=%f starbirth=%f)" % [judge_score, starbirth_score]),
		assert_eq(starbirth_score, 0.0, "Starbirth should stay dead until the exact Judge redraw bridge resolves in this narrow shell-finish window"),
	])


func test_arceus_post_judge_search_still_prefers_giratina_before_engine_basics() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-Judge exact search ordering can be verified"
	var gs := _make_game_state(5)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Radiant Gardevoir", "Basic", "P", 130, "", "Radiant"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var options: Array = [
		CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0),
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
		CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0),
	]
	var picked := _best_card_name(strategy, options, "search_pokemon", {"game_state": gs, "player_index": 0, "all_items": options})
	return assert_eq(picked, "Giratina V", "After Judge, if the shell still lacks Giratina, exact search should keep the attacker lane ahead of extra engine padding")


func test_arceus_post_judge_does_not_cool_off_search_behind_in_hand_skwovet() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-Judge shell priority gating can be verified"
	var gs := _make_game_state(5)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var skwovet_bench_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(ultra_ball_score > 0.0, "If Giratina is still missing, Ultra Ball should stay live even when Skwovet is already in hand"),
		assert_true(ultra_ball_score > skwovet_bench_score, "When Giratina is still the highest-priority missing shell piece, search should stay ahead of benching an in-hand Skwovet"),
	])


func test_arceus_post_judge_in_hand_shell_finish_cools_off_starbirth_until_free_progress_resolves() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-Judge in-hand shell-finish timing can be verified"
	var gs := _make_game_state(5)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var starbirth_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": active_arceus, "ability_index": 0},
		gs,
		0
	)
	var grass_attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0), "target_slot": active_arceus},
		gs,
		0
	)
	var skwovet_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var giratina_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_eq(starbirth_score, 0.0, "After Judge, if the shell-finish pieces are already in hand, Starbirth should stay dead until those free progress actions resolve"),
		assert_true(grass_attach_score > starbirth_score, "The active Grass attach should happen before Starbirth in this exact post-Judge shell-finish window"),
		assert_true(skwovet_score > starbirth_score, "An in-hand Skwovet should be benched before Starbirth in this exact post-Judge shell-finish window"),
		assert_true(giratina_score > starbirth_score, "An in-hand Giratina V should also be benched before Starbirth in this exact post-Judge shell-finish window"),
	])


func test_arceus_post_judge_in_hand_shell_finish_cools_off_search_until_free_progress_is_spent() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-Judge search gating can be verified"
	var gs := _make_game_state(5)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0
	)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0), "target_slot": active_arceus},
		gs,
		0
	)
	return run_checks([
		assert_eq(ultra_ball_score, 0.0, "Search should stay dead while the exact post-Judge shell-finish still has free in-hand progress available"),
		assert_true(attach_score > ultra_ball_score, "The active Grass attach should outrank extra search in that same exact shell-finish window"),
	])


func test_arceus_post_giratina_search_prefers_bidoof_before_extra_padding() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before post-Giratina shell-finish search can be verified"
	var gs := _make_game_state(5)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(_make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var options: Array = [
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
		CardInstance.create(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0),
		CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0),
	]
	var picked := _best_card_name(strategy, options, "search_cards", {"game_state": gs, "player_index": 0, "all_items": options})
	return assert_eq(picked, "Bidoof", "Once Giratina is already online and the shell still lacks the draw engine, exact search should prioritize Bidoof before extra padding")


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


func test_arceus_opponent_switch_target_prefers_convertible_miraidon_ex_over_unconvertible_iron_hands() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before gust target ordering can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_tool = CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0)
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0))
	player.bench.append(backup_arceus)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 280, "", "ex"), 1)
	var miraidon := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(iron_hands)
	opponent.bench.append(miraidon)
	var picked := _best_slot_name(strategy, [iron_hands, miraidon], "opponent_switch_target", {"game_state": gs, "player_index": 0})
	return assert_eq(picked, "Miraidon ex", "Boss-like target selection should prefer the bench ex that active Arceus VSTAR can actually convert into a knockout")


func test_arceus_opponent_bench_target_prefers_convertible_miraidon_ex_over_unconvertible_iron_hands() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Boss's Orders bench target ordering can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_tool = CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0)
	player.active_pokemon = active_arceus
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 280, "", "ex"), 1)
	var miraidon := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(iron_hands)
	opponent.bench.append(miraidon)
	var picked := _best_slot_name(strategy, [iron_hands, miraidon], "opponent_bench_target", {"game_state": gs, "player_index": 0})
	return assert_eq(picked, "Miraidon ex", "Boss's Orders uses opponent_bench_target in live runtime, so that prompt id should also prefer the convertible Miraidon ex line")


func test_arceus_bridge_attach_scores_above_attack_when_it_keeps_same_turn_attack_and_fixes_giratina_type() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before bridge attach ordering can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_tool = CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0), "target_slot": giratina},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 250},
		gs,
		0
	)
	return assert_true(attach_score > attack_score, "When active Arceus can still attack this turn, the exact bridge attach that completes Giratina's missing Psychic should outrank attacking first")


func test_arceus_bridge_attach_scores_above_attack_when_it_sets_backup_arceus_dte_before_same_turn_attack() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before backup-Arceus bridge attach ordering can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_tool = CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0))
	player.bench.append(backup_arceus)
	player.hand.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0), "target_slot": backup_arceus},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 250},
		gs,
		0
	)
	return assert_true(attach_score > attack_score, "When active Arceus can still attack, the exact DTE bridge attach into the backup Arceus line should outrank attacking first")


func test_arceus_backup_vstar_evolve_scores_above_attack_after_exact_dte_bridge_attach() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact backup evolve ordering can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(_make_slot(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 280, "", "ex"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1))
	var evolve_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": player.hand[0], "target_slot": backup_arceus},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 250},
		gs,
		0
	)
	return assert_true(evolve_score > attack_score, "Once backup Arceus already has DTE and the active can still attack, evolving into Arceus VSTAR should outrank spending the turn on the current active attack line")


func test_arceus_exact_bridge_iono_redraw_outranks_attack_when_shell_is_thin() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact bridge redraw ordering can be verified"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var iono_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": player.hand[0]},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 250},
		gs,
		0
	)
	return assert_true(iono_score > attack_score, "When the bridge shell is still thin and Iono is the only redraw, exact redraw should outrank cashing the current attack first")


func test_arceus_exact_rebuild_judge_redraw_outranks_nonlethal_attack_when_double_vstar_shell_is_still_thin() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact rebuild redraw ordering can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.damage_counters = 100
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.hand.append(CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0))
	player.discard_pile.append(CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": player.hand[0]},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 180},
		gs,
		0
	)
	return run_checks([
		assert_true(judge_score > attack_score, "When both Arceus VSTARs are online but Giratina and the shell engine are still missing, Judge should outrank a nonlethal Trinity Nova (judge=%f attack=%f)" % [judge_score, attack_score]),
		assert_true(judge_score >= 900.0, "This exact rebuild-redraw window should treat Judge as a first-class shell repair action"),
	])


func test_arceus_exact_post_redraw_shell_convert_search_outranks_nonlethal_attack() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact post-redraw shell convert ordering can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0))
	gs.supporter_used_this_turn = true
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var ultra_ball_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0
	)
	var giratina_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 180},
		gs,
		0
	)
	return run_checks([
		assert_eq(ultra_ball_score, 0.0, "Once Giratina is already in hand in the post-redraw shell-finish window, extra search should stay dead until that free progress resolves"),
		assert_true(giratina_score > attack_score, "The same post-redraw convert window should also let benching Giratina outrank the immediate attack (giratina=%f attack=%f)" % [giratina_score, attack_score]),
	])


func test_arceus_exact_post_giratina_shell_finish_progress_outranks_nonlethal_attack() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact post-Giratina shell finish ordering can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	backup_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(giratina)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Choice Belt", "Tool"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0))
	gs.supporter_used_this_turn = true
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var bidoof_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var belt_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd("Choice Belt", "Tool"), 0), "target_slot": active_arceus},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 180},
		gs,
		0
	)
	return run_checks([
		assert_true(bidoof_score > attack_score, "After Giratina is already benched, Bidoof shell completion should outrank another nonlethal Trinity Nova (bidoof=%f attack=%f)" % [bidoof_score, attack_score]),
		assert_true(belt_score > attack_score, "The same shell-finish window should also let Choice Belt land before the nonlethal attack (belt=%f attack=%f)" % [belt_score, attack_score]),
	])


func test_arceus_exact_post_redraw_shell_finish_starbirth_fetches_bidoof_and_maximum_belt() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact post-redraw Starbirth payloads can be verified"
	var gs := _make_game_state(3)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(giratina)
	player.deck.append(CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
		CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0),
		CardInstance.create(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V"), 0),
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
	]
	var picked: Array = strategy.pick_interaction_items(
		items,
		{"id": "search_cards", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var picked_names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance and (item as CardInstance).card_data != null:
			picked_names.append(str((item as CardInstance).card_data.name))
	return run_checks([
		assert_eq(picked.size(), 2, "The exact post-redraw shell-finish Starbirth payload should stay a 2-card package"),
		assert_true("Bidoof" in picked_names, "Once Giratina and Skwovet are already online, Starbirth should fetch the missing Bidoof shell piece"),
		assert_true("Maximum Belt" in picked_names, "The same exact shell-finish payload should also fetch Maximum Belt for the backup Arceus lane"),
		assert_true(not ("Giratina VSTAR" in picked_names), "This exact shell-finish payload should not drift back into Giratina VSTAR padding"),
	])


func test_arceus_exact_post_redraw_shell_finish_maximum_belt_prefers_backup_arceus() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact post-redraw Maximum Belt routing can be verified"
	var gs := _make_game_state(3)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(backup_arceus)
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(giratina)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var belt := CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0)
	var backup_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": belt, "target_slot": backup_arceus},
		gs,
		0
	)
	var active_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd("Maximum Belt", "Tool"), 0), "target_slot": active_arceus},
		gs,
		0
	)
	return run_checks([
		assert_true(backup_score > active_score, "In the exact post-redraw shell-finish window, Maximum Belt should move to the backup Arceus lane instead of the already-online active"),
		assert_true(backup_score >= 900.0, "That exact shell-finish Maximum Belt route should become a first-class tool attachment"),
		assert_eq(active_score, 0.0, "The same exact shell-finish window should keep Maximum Belt off the active Arceus"),
	])


func test_arceus_exact_post_redraw_rebuild_finish_evolves_and_benches_before_nonlethal_attack() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact post-redraw rebuild-finish ordering can be verified"
	var gs := _make_game_state(5)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var giratina_evolve_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": player.hand[0], "target_slot": giratina},
		gs,
		0
	)
	var bibarel_evolve_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": player.hand[1], "target_slot": player.bench[2]},
		gs,
		0
	)
	var bench_arceus_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": player.hand[2]},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 180},
		gs,
		0
	)
	return run_checks([
		assert_true(giratina_evolve_score > attack_score, "After redraw, finishing Giratina VSTAR should outrank a nonlethal Trinity Nova in the rebuild-finish window"),
		assert_true(bibarel_evolve_score > attack_score, "The same window should evolve Bibarel before cashing the current attack"),
		assert_true(bench_arceus_score > attack_score, "The same window should also bench the backup Arceus before the nonlethal attack"),
	])


func test_arceus_exact_post_redraw_rebuild_finish_psychic_attach_prefers_backup_arceus() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact post-redraw rebuild-finish attach ordering can be verified"
	var gs := _make_game_state(5)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"), 0)
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var backup_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	player.active_pokemon = active_arceus
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0))
	player.bench.append(backup_arceus)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	player.hand.append(psychic)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": psychic, "target_slot": backup_arceus},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 180},
		gs,
		0
	)
	return run_checks([
		assert_true(attach_score > attack_score, "After redraw, the first Psychic attach should go to the new backup Arceus before the nonlethal Trinity Nova"),
		assert_true(attach_score >= 900.0, "The backup-Arceus Psychic attach should be treated as a first-class rebuild-finish action"),
	])


func test_arceus_exact_post_giratina_rebuild_finish_keeps_bibarel_and_backup_arceus_ahead_of_attack() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before exact post-Giratina rebuild-finish ordering can be verified"
	var gs := _make_game_state(5)
	gs.supporter_used_this_turn = true
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_arceus := _make_slot(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V", [], [{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]), 0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var giratina_vstar := _make_slot(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	giratina_vstar.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	giratina_vstar.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var bidoof := _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	player.active_pokemon = active_arceus
	player.bench.append(giratina_vstar)
	player.bench.append(_make_slot(_make_pokemon_cd("Skwovet", "Basic", "C", 70), 0))
	player.bench.append(bidoof)
	var bibarel := CardInstance.create(_make_pokemon_cd("Bibarel", "Stage1", "C", 120, "Bidoof"), 0)
	var arceus_v := CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	player.hand.append(bibarel)
	player.hand.append(arceus_v)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var bibarel_evolve_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": bibarel, "target_slot": bidoof},
		gs,
		0
	)
	var bench_arceus_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": arceus_v},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_arceus, "attack_name": "Trinity Nova", "projected_damage": 180},
		gs,
		0
	)
	return run_checks([
		assert_true(bibarel_evolve_score > attack_score, "After Giratina is already online, Bibarel evolve should still outrank a nonlethal Trinity Nova while rebuild-finish is incomplete"),
		assert_true(bench_arceus_score > attack_score, "The same post-Giratina rebuild-finish window should bench the backup Arceus before the nonlethal attack"),
	])


func test_arceus_giratina_vstar_stays_cool_until_bench_arceus_owner_is_online() -> String:
	var strategy := _new_strategy(ARCEUS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should exist before Giratina VSTAR evolve timing can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var active_giratina := _make_slot(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V", [], [{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]), 0)
	var bench_arceus := _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V", [], [{"name": "Trinity Charge", "cost": "CC", "damage": "0"}]), 0)
	bench_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_giratina
	player.bench.append(bench_arceus)
	var giratina_vstar := CardInstance.create(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "P", 280, "Giratina V", "V"), 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.hand.append(giratina_vstar)
	player.hand.append(grass)
	var evolve_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": giratina_vstar, "target_slot": active_giratina},
		gs,
		0
	)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": grass, "target_slot": bench_arceus},
		gs,
		0
	)
	return run_checks([
		assert_true(attach_score > evolve_score, "When active Giratina still cannot attack and bench Arceus is one step from owner online, attach to Arceus should outrank evolving Giratina VSTAR"),
		assert_true(evolve_score <= 200.0, "In that exact owner-online window, Giratina VSTAR evolve should cool off sharply"),
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
