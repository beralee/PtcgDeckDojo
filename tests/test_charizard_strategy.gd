class_name TestCharizardStrategy
extends TestBase


const CHARIZARD_SCRIPT_PATH := "res://scripts/ai/DeckStrategyCharizardEx.gd"
const REQUIRED_METHODS := [
	"get_strategy_id",
	"get_signature_names",
	"get_state_encoder_class",
	"load_value_net",
	"get_value_net",
	"get_mcts_config",
	"plan_opening_setup",
	"score_action_absolute",
	"score_action",
	"evaluate_board",
	"predict_attacker_damage",
	"get_discard_priority",
	"get_discard_priority_contextual",
	"get_search_priority",
	"score_interaction_target",
]


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script := _load_script(CHARIZARD_SCRIPT_PATH)
	return script.new() if script != null else null


func _missing_methods(instance: Object, required_methods: Array) -> Array[String]:
	var methods: Dictionary = {}
	for method_info: Dictionary in instance.get_method_list():
		methods[str(method_info.get("name", ""))] = true
	var missing: Array[String] = []
	for method_name: String in required_methods:
		if not methods.has(method_name):
			missing.append(method_name)
	return missing


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
	cd.card_type = card_type
	return cd


func _make_energy_cd(pname: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Basic Energy"
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
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi), pi)
		gs.players.append(player)
	return gs


func _pick_best_item_name(strategy: RefCounted, items: Array, step: Dictionary, context: Dictionary) -> String:
	var best_name := ""
	var best_score := -INF
	for item: Variant in items:
		var score: float = strategy.score_interaction_target(item, step, context)
		if score > best_score:
			best_score = score
			if item is CardInstance:
				best_name = str((item as CardInstance).card_data.name)
	return best_name


func _pick_best_slot_name(strategy: RefCounted, slots: Array, step: Dictionary, context: Dictionary) -> String:
	var best_name := ""
	var best_score := -INF
	for slot_variant: Variant in slots:
		var score: float = strategy.score_interaction_target(slot_variant, step, context)
		if score > best_score and slot_variant is PokemonSlot:
			best_score = score
			best_name = (slot_variant as PokemonSlot).get_pokemon_name()
	return best_name


func test_charizard_strategy_script_loads_and_implements_contract() -> String:
	var script := _load_script(CHARIZARD_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyCharizardEx.gd should exist before Charizard strategy behavior can be tested"
	var strategy = script.new()
	return run_checks([
		assert_eq(_missing_methods(strategy, REQUIRED_METHODS), [], "Charizard strategy should implement the unified contract"),
		assert_eq(str(strategy.get_strategy_id()), "charizard_ex", "Charizard strategy id should match registry design"),
	])


func test_opening_setup_prefers_pidgey_active_and_benches_charmander() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before opening setup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70, "", "", [], [], 1), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60, "", "", [], [], 1), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Rotom", "Basic", "L", 70), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var bench_indices: Array = choice.get("bench_hand_indices", [])
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	var bench_names: Array[String] = []
	for index_variant: Variant in bench_indices:
		var hand_index: int = int(index_variant)
		if hand_index >= 0 and hand_index < player.hand.size():
			bench_names.append(str(player.hand[hand_index].card_data.name))
	return run_checks([
		assert_eq(active_name, "Pidgey", "Opening setup should protect Charmander and lead with Pidgey"),
		assert_true("Charmander" in bench_names, "Opening setup should still bench Charmander to start the Stage 2 line"),
	])


func test_opening_setup_keeps_duskull_as_third_lane_once_core_lines_exist() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Charizard shell setup depth can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var bench_names: Array[String] = []
	for index_variant: Variant in choice.get("bench_hand_indices", []):
		var hand_index: int = int(index_variant)
		if hand_index >= 0 and hand_index < player.hand.size():
			bench_names.append(str(player.hand[hand_index].card_data.name))
	return run_checks([
		assert_true("Charmander" in bench_names, "Charmander should stay the first bench priority"),
		assert_true("Duskull" in bench_names, "The Dusknoir prize-trade lane should be benched once the main engine pieces are present"),
	])


func test_opening_setup_prefers_rotom_v_active_when_core_basics_are_already_available() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Charizard opening resilience can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var bench_names: Array[String] = []
	for index_variant: Variant in choice.get("bench_hand_indices", []):
		var hand_index: int = int(index_variant)
		if hand_index >= 0 and hand_index < player.hand.size():
			bench_names.append(str(player.hand[hand_index].card_data.name))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	return run_checks([
		assert_eq(active_name, "Rotom V", "When Charmander and Pidgey can both stay protected on bench, Rotom V should take the active slot"),
		assert_true("Charmander" in bench_names, "Charmander should still be benched behind the Rotom V lead"),
		assert_true("Pidgey" in bench_names, "Pidgey should still be benched behind the Rotom V lead"),
	])


func test_rare_candy_scores_higher_than_generic_item_when_stage2_line_is_live() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Rare Candy priorities can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	var rare_candy := CardInstance.create(_make_trainer_cd("Rare Candy"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var candy_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": rare_candy}, gs, 0)
	var generic_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	return run_checks([
		assert_true(candy_score >= 450.0, "Rare Candy should be a high-priority Charizard action when the Stage 2 is in hand (got %f)" % candy_score),
		assert_true(candy_score > generic_score, "Rare Candy should outrank a generic setup item in Charizard boards"),
	])


func test_charizard_evolution_scores_above_pidgeot_and_generic_lines() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before evolution priorities can be verified"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	var charizard_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0)},
		gs,
		0
	)
	var pidgeot_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0)},
		gs,
		0
	)
	var generic_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Pidgeotto", "Stage 1", "C", 80, "Pidgey"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(charizard_score > pidgeot_score, "The main attacker evolution should outrank the support line"),
		assert_true(pidgeot_score > generic_score, "Pidgeot support evolution should still outrank a generic line"),
	])


func test_board_evaluation_rewards_online_charizard_and_pidgeot_engine() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before board evaluation can be verified"
	var gs := _make_game_state(5)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var weak_score: float = strategy.evaluate_board(gs, 0)
	gs.players[0].bench.clear()
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]), 0))
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex",
		[{"name": "Quick Search", "text": "test"}]), 0))
	var strong_score: float = strategy.evaluate_board(gs, 0)
	return assert_true(strong_score > weak_score,
		"Board evaluation should improve once Charizard ex and Pidgeot ex are online (%f vs %f)" % [strong_score, weak_score])


func test_search_item_prefers_rare_candy_when_stage2_piece_is_already_in_hand() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before interaction target scoring can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	var items: Array = [
		CardInstance.create(_make_trainer_cd("Nest Ball"), 0),
		CardInstance.create(_make_trainer_cd("Potion"), 0),
		CardInstance.create(_make_trainer_cd("Rare Candy"), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		items,
		{"id": "search_item"},
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Rare Candy",
		"Charizard search targeting should prefer Rare Candy when it unlocks the Stage 2 immediately")


func test_search_item_prefers_poffin_over_rare_candy_when_shell_is_thin() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Arven opening item priorities can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.clear()
	player.deck.append(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	var items: Array = [
		CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0),
		CardInstance.create(_make_trainer_cd("Nest Ball"), 0),
		CardInstance.create(_make_trainer_cd("Rare Candy"), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		items,
		{"id": "search_item"},
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Buddy-Buddy Poffin",
		"When the opening shell still lacks Pidgey and bench depth, Arven should prefer Buddy-Buddy Poffin over Rare Candy")


func test_search_pokemon_prefers_second_charmander_over_duskull_before_engine_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Charizard search priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var cards: Array = [
		CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0),
		CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		cards,
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0, "all_items": cards}
	)
	return assert_eq(picked_name, "Charmander",
		"When Charizard ex and Pidgeot ex are still offline, search should favor the second Charmander over the Duskull side lane")


func test_search_tool_prefers_forest_seal_stone_before_pidgeot_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before tool search priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var items: Array = [
		CardInstance.create(_make_trainer_cd("Defiance Band", "Tool"), 0),
		CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		items,
		{"id": "search_tool"},
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Forest Seal Stone",
		"Before Pidgeot ex is online, Charizard should value Forest Seal Stone as the most reliable consistency tool")


func test_energy_target_prefers_charmander_over_radiant_charizard_early() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before energy routing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var radiant_zard := _make_slot(_make_pokemon_cd("Radiant Charizard", "Basic", "R", 160), 0)
	player.bench.append(charmander)
	player.bench.append(radiant_zard)
	var picked_name := _pick_best_slot_name(
		strategy,
		[charmander, radiant_zard],
		{"id": "energy_target"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_eq(picked_name, "Charmander",
		"Early manual attachments should build the main Charizard line before the Radiant Charizard closer")


func test_dusknoir_ability_waits_when_no_follow_up_pressure_exists() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Dusknoir timing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	var dusknoir := _make_slot(_make_pokemon_cd(
		"Dusknoir",
		"Stage 2",
		"P",
		150,
		"Dusclops",
		"",
		[{"name": "Cursed Blast", "text": "spread"}]
	), 0)
	player.bench.append(dusknoir)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": dusknoir},
		gs,
		0
	)
	return assert_true(score < 200.0,
		"Dusknoir should not throw away a prize unless the Charizard side can pressure immediately afterward (got %f)" % score)


func test_dusknoir_ability_is_high_once_charizard_can_follow_up() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Dusknoir conversion timing can be verified"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var charizard := _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.active_pokemon = charizard
	var dusknoir := _make_slot(_make_pokemon_cd(
		"Dusknoir",
		"Stage 2",
		"P",
		150,
		"Dusclops",
		"",
		[{"name": "Cursed Blast", "text": "spread"}]
	), 0)
	player.bench.append(dusknoir)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": dusknoir},
		gs,
		0
	)
	return assert_true(score >= 350.0,
		"Once Charizard ex can attack right away, the Dusknoir damage setup should become a high-priority conversion line (got %f)" % score)


func test_rotom_v_ability_stays_high_priority_early_even_with_a_large_hand() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Rotom V draw timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Rotom V",
		"Basic",
		"L",
		190,
		"",
		"V",
		[{"name": "Instant Charge", "text": "draw"}]
	), 0)
	for i: int in range(6):
		player.hand.append(CardInstance.create(_make_trainer_cd("Card %d" % i), 0))
	var score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": player.active_pokemon},
		gs,
		0
	)
	return assert_true(score >= 300.0,
		"Before Pidgeot ex is online, Rotom V should still strongly value its early draw ability even with six cards in hand (got %f)" % score)


func test_rotom_v_ability_shuts_off_once_charizard_and_pidgeot_are_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Rotom V churn can be verified"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire A", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire B", "R"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0))
	var rotom_slot := _make_slot(_make_pokemon_cd(
		"Rotom V",
		"Basic",
		"L",
		190,
		"",
		"V",
		[{"name": "Instant Charge", "text": "draw"}]
	), 0)
	player.bench.append(rotom_slot)
	for i: int in range(6):
		player.hand.append(CardInstance.create(_make_trainer_cd("Card %d" % i), 0))
	var score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": rotom_slot},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once Charizard ex and Pidgeot ex are already online, Rotom V should stop positive-value draw churn (got %f)" % score)


func test_nest_ball_stays_live_for_rotom_once_core_lines_exist_early() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before early Rotom search priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var night_stretcher := CardInstance.create(_make_trainer_cd("Night Stretcher"), 0)
	var score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	var stretcher_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": night_stretcher}, gs, 0)
	return run_checks([
		assert_true(score >= 260.0,
			"Once Charmander and Pidgey are already down in the opening, Nest Ball should stay live to find Rotom V (got %f)" % score),
		assert_true(score > stretcher_score,
			"Nest Ball should outrank dead recovery items when the shell still needs Rotom V"),
	])


func test_search_pokemon_prefers_rotom_v_over_duskull_when_shell_is_ready_but_draw_engine_is_missing() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Rotom search priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var step := {"id": "search_pokemon"}
	var context := {"game_state": gs, "player_index": 0}
	var rotom_score: float = strategy.score_interaction_target(rotom, step, context)
	var duskull_score: float = strategy.score_interaction_target(duskull, step, context)
	return run_checks([
		assert_true(rotom_score >= 550.0,
			"With Charmander and Pidgey already established, Rotom V should become a premium early search target (got %f)" % rotom_score),
		assert_true(rotom_score > duskull_score,
			"Rotom V should outrank Duskull while the shell still lacks its early draw engine"),
	])


func test_forest_seal_stone_prefers_rotom_v_as_the_early_target() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Forest Seal Stone routing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var rotom_slot := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var lumineon_slot := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	var fez_slot := _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(rotom_slot)
	player.bench.append(lumineon_slot)
	player.bench.append(fez_slot)
	var stone := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	var rotom_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": stone, "target_slot": rotom_slot}, gs, 0)
	var lumineon_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": stone, "target_slot": lumineon_slot}, gs, 0)
	var fez_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": stone, "target_slot": fez_slot}, gs, 0)
	return run_checks([
		assert_true(rotom_score >= 500.0,
			"Forest Seal Stone should strongly prefer Rotom V in the opening shell (got %f)" % rotom_score),
		assert_true(rotom_score > lumineon_score,
			"Forest Seal Stone should prefer Rotom V over Lumineon V in the early game"),
		assert_true(rotom_score > fez_score,
			"Forest Seal Stone should prefer Rotom V over Fezandipiti ex in the early game"),
	])


func test_forest_seal_stone_does_not_route_to_fezandipiti_in_the_opening() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Forest Seal Stone dead-target filtering can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var fez_slot := _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(fez_slot)
	var stone := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	var stone_attach_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": stone, "target_slot": fez_slot}, gs, 0)
	var search_score: float = strategy.score_interaction_target(
		stone,
		{"id": "search_tool"},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_true(stone_attach_score <= 80.0,
			"Forest Seal Stone should not be routed onto Fezandipiti ex in the opening shell (got %f)" % stone_attach_score),
		assert_true(search_score <= 120.0,
			"Arven should not prioritize Forest Seal Stone when Fezandipiti ex is the only target (got %f)" % search_score),
	])


func test_lightning_pressure_prioritizes_direct_charizard_over_early_pidgeot_search() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Miraidon pressure sequencing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.prizes = [
		CardInstance.create(_make_pokemon_cd("Prize A"), 0),
		CardInstance.create(_make_pokemon_cd("Prize B"), 0),
		CardInstance.create(_make_pokemon_cd("Prize C"), 0),
		CardInstance.create(_make_pokemon_cd("Prize D"), 0),
		CardInstance.create(_make_pokemon_cd("Prize E"), 0),
	]
	opponent.prizes = [
		CardInstance.create(_make_pokemon_cd("Prize X"), 1),
		CardInstance.create(_make_pokemon_cd("Prize Y"), 1),
		CardInstance.create(_make_pokemon_cd("Prize Z"), 1),
		CardInstance.create(_make_pokemon_cd("Prize W"), 1),
	]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(_make_slot(_make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1))
	var charizard := CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0)
	var pidgeot := CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0)
	var step := {"id": "search_pokemon"}
	var context := {"game_state": gs, "player_index": 0}
	var charizard_score: float = strategy.score_interaction_target(charizard, step, context)
	var pidgeot_score: float = strategy.score_interaction_target(pidgeot, step, context)
	return run_checks([
		assert_true(charizard_score >= 900.0,
			"Under Lightning pressure, Charizard ex should become the premium immediate search target (got %f)" % charizard_score),
		assert_true(charizard_score >= pidgeot_score + 180.0,
			"Against Miraidon pressure, direct Charizard should clearly outrank the early Pidgeot line"),
	])


func test_boss_orders_waits_until_charizard_can_convert_the_gust() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Boss's Orders timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var boss_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": boss}, gs, 0)
	var setup_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	return run_checks([
		assert_true(boss_score <= 60.0, "Boss's Orders should stay low when the board cannot punish the gust immediately (got %f)" % boss_score),
		assert_true(boss_score < setup_score, "Boss's Orders should not outrank setup cards before Charizard can convert the gust"),
	])


func test_counter_catcher_waits_until_the_gust_is_immediately_convertible() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Counter Catcher timing can be verified"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	player.prizes = [CardInstance.create(_make_pokemon_cd("Prize A"), 0), CardInstance.create(_make_pokemon_cd("Prize B"), 0), CardInstance.create(_make_pokemon_cd("Prize C"), 0), CardInstance.create(_make_pokemon_cd("Prize D"), 0)]
	opponent.prizes = [CardInstance.create(_make_pokemon_cd("Prize X"), 1), CardInstance.create(_make_pokemon_cd("Prize Y"), 1)]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	var counter_catcher := CardInstance.create(_make_trainer_cd("Counter Catcher"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var catcher_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": counter_catcher}, gs, 0)
	var setup_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	return run_checks([
		assert_true(catcher_score <= 120.0,
			"Counter Catcher should stay controlled when Charizard is still one Energy short of converting the gust (got %f)" % catcher_score),
		assert_true(catcher_score < setup_score,
			"Counter Catcher should not outrank setup while the gust is not immediately convertible"),
	])


func test_dead_utility_items_do_not_outrank_setup_in_opening() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before dead item timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.discard_pile.clear()
	gs.stadium_card = null
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var super_rod := CardInstance.create(_make_trainer_cd("Super Rod"), 0)
	var lost_vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0)
	var setup_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	var rod_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": super_rod}, gs, 0)
	var vacuum_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": lost_vacuum}, gs, 0)
	return run_checks([
		assert_true(rod_score <= 40.0, "Super Rod should stay near-dead with an empty discard (got %f)" % rod_score),
		assert_true(vacuum_score <= 20.0, "Lost Vacuum should stay near-dead when there is no stadium to clear (got %f)" % vacuum_score),
		assert_true(rod_score < setup_score, "Super Rod should not outrank opening setup"),
		assert_true(vacuum_score < setup_score, "Lost Vacuum should not outrank opening setup"),
	])


func test_extra_charmander_search_shuts_off_once_engine_and_backup_lane_are_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Charmander search timing can be verified"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var charmander := CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var step := {"id": "search_pokemon"}
	var context := {"game_state": gs, "player_index": 0}
	var charmander_score: float = strategy.score_interaction_target(charmander, step, context)
	var duskull_score: float = strategy.score_interaction_target(duskull, step, context)
	return run_checks([
		assert_true(charmander_score <= 160.0,
			"Once Charizard ex, Pidgeot ex, and a backup Charmander are already online, another Charmander should stop being a premium search (got %f)" % charmander_score),
		assert_true(charmander_score < duskull_score,
			"Late-game Quick Search should prefer live conversion pieces over a third Charmander line"),
	])


func test_extra_charmander_bench_shuts_off_once_engine_and_backup_lane_are_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Charmander bench timing can be verified"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var extra_charmander := CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var bench_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": extra_charmander}, gs, 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var nest_ball_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	return run_checks([
		assert_true(bench_score <= 40.0,
			"Once the engine and backup lane are already online, benching another Charmander should nearly shut off (got %f)" % bench_score),
		assert_true(nest_ball_score <= 80.0,
			"Nest Ball should stop behaving like a live setup card once the engine and backup Charmander are already online (got %f)" % nest_ball_score),
	])


func test_search_cards_prefers_conversion_item_over_extra_charmander_once_engine_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before generic search-card priorities can be verified"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var candidates: Array = [
		CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0),
		CardInstance.create(_make_trainer_cd("Rare Candy"), 0),
		CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		candidates,
		{"id": "search_cards"},
		{"game_state": gs, "player_index": 0, "all_items": candidates}
	)
	return assert_eq(picked_name, "Rare Candy",
		"Once Charizard ex, Pidgeot ex, and a backup Charmander are already online, generic search should pivot to conversion cards instead of another Charmander")


func test_search_cards_prefers_direct_rare_candy_over_arven_once_pidgeot_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Pidgeot Quick Search conversion priorities can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.prizes = [
		CardInstance.create(_make_pokemon_cd("Prize A"), 0),
		CardInstance.create(_make_pokemon_cd("Prize B"), 0),
		CardInstance.create(_make_pokemon_cd("Prize C"), 0),
		CardInstance.create(_make_pokemon_cd("Prize D"), 0),
	]
	gs.players[1].prizes = [
		CardInstance.create(_make_pokemon_cd("Prize X"), 1),
		CardInstance.create(_make_pokemon_cd("Prize Y"), 1),
	]
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Defiance Band", "Tool"), 0))
	var candidates: Array = [
		CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0),
		CardInstance.create(_make_trainer_cd("Rare Candy"), 0),
		CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		candidates,
		{"id": "search_cards"},
		{"game_state": gs, "player_index": 0, "all_items": candidates}
	)
	return assert_eq(picked_name, "Rare Candy",
		"Once Pidgeot ex is already online, Quick Search should prefer the direct Rare Candy piece over routing through Arven again")
