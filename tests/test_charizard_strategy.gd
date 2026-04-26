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


func _pick_top_item_names(strategy: RefCounted, items: Array, step: Dictionary, context: Dictionary, count: int) -> Array[String]:
	var scored: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is CardInstance):
			continue
		scored.append({
			"name": str((item as CardInstance).card_data.name),
			"score": strategy.score_interaction_target(item, step, context),
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var picked: Array[String] = []
	for i: int in range(mini(count, scored.size())):
		picked.append(str(scored[i].get("name", "")))
	return picked


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


func test_opening_setup_prefers_charmander_active_in_strong_fixed_opening_window() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before strong-opening active priorities can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	return assert_eq(active_name, "Charmander",
		"When the strong fixed opening already has Nest Ball + Buddy-Buddy Poffin + Fire, Charmander should lead so the first Fire powers the main line")


func test_fire_attach_avoids_pidgeot_line_in_strong_fixed_opening_window() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before strong-opening Fire routing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	var charmander_attach: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0),
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var pidgey_attach: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0),
		"target_slot": player.bench[0],
	}, gs, 0)
	return run_checks([
		assert_true(charmander_attach > pidgey_attach,
			"Strong-opening Fire should stay on the Charizard line instead of drifting into the Pidgeot lane"),
		assert_true(pidgey_attach <= 0.0,
			"Pidgey should not be a positive Fire attach target in the strong fixed-opening window (got %f)" % pidgey_attach),
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


func test_ultra_ball_becomes_premium_when_rare_candy_is_in_hand_and_stage2_piece_is_missing() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Ultra Ball combo completion timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Super Rod"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0)
	var rod := CardInstance.create(_make_trainer_cd("Super Rod"), 0)
	var ultra_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": ultra_ball}, gs, 0)
	var vacuum_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": vacuum}, gs, 0)
	var rod_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": rod}, gs, 0)
	return run_checks([
		assert_true(ultra_score >= 520.0,
			"When Rare Candy is already in hand and both stage-2 lanes are live on board, Ultra Ball should become a premium combo-completion action (got %f)" % ultra_score),
		assert_true(ultra_score > vacuum_score,
			"Ultra Ball should outrank dead utility items in this combo window"),
		assert_true(ultra_score > rod_score,
			"Ultra Ball should outrank empty recovery lines in this combo window"),
	])


func test_ultra_ball_opening_combo_window_keeps_rare_candy_and_discards_dead_cards() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Ultra Ball discard priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	var rare_candy := CardInstance.create(_make_trainer_cd("Rare Candy"), 0)
	var ultra_ball_a := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var ultra_ball_b := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0)
	var rod := CardInstance.create(_make_trainer_cd("Super Rod"), 0)
	player.hand.append(rare_candy)
	player.hand.append(ultra_ball_a)
	player.hand.append(ultra_ball_b)
	player.hand.append(vacuum)
	player.hand.append(rod)
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	var discard_step := {"id": "discard_cards", "max_select": 2}
	var discard_context := {"game_state": gs, "player_index": 0}
	var top_discards := _pick_top_item_names(strategy, [rare_candy, ultra_ball_b, vacuum, rod], discard_step, discard_context, 2)
	return run_checks([
		assert_true("Lost Vacuum" in top_discards,
			"Ultra Ball discard selection should throw dead utility first in the opening combo window"),
		assert_true("Super Rod" in top_discards,
			"Ultra Ball discard selection should prefer empty recovery over Rare Candy in the opening combo window"),
		assert_false("Rare Candy" in top_discards,
			"Rare Candy should be preserved while Ultra Ball assembles the first Charizard/Pidgeot combo"),
	])


func test_ultra_ball_premium_combo_window_turns_off_after_opening() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Ultra Ball throttling can be verified"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Super Rod"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	var ultra_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)}, gs, 0)
	return run_checks([
		assert_true(ultra_score < 520.0,
			"The premium Ultra Ball combo window should be limited to the opening turns instead of staying on all game (got %f)" % ultra_score),
		assert_eq(ultra_score, 320.0,
			"Outside the opening combo window, Ultra Ball should fall back to normal stage-2 setup scoring"),
	])


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


func test_search_pokemon_prefers_pidgey_over_charizard_ex_while_opening_shell_is_thin() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before early Charizard search timing can be verified"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var candidates: Array = [
		CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0),
		CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		candidates,
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0, "all_items": candidates}
	)
	return assert_eq(picked_name, "Pidgey",
		"When the opening shell is still missing Pidgey, search should stabilize the combo shell before taking Charizard ex")


func test_search_pokemon_prefers_second_charmander_over_charizard_ex_until_combo_shell_is_ready() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before early Charizard search timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var candidates: Array = [
		CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0),
		CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		candidates,
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0, "all_items": candidates}
	)
	return assert_eq(picked_name, "Charmander",
		"Until the early combo shell is ready, search should keep building the second Charmander lane before taking Charizard ex")


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


func test_radiant_charizard_bench_stays_dead_before_finish_window() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before early Radiant Charizard bench timing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.prizes = []
	opponent.prizes = []
	for i: int in range(6):
		player.prizes.append(CardInstance.create(_make_pokemon_cd("Prize %d" % i), 0))
		opponent.prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i), 1))
	var radiant := CardInstance.create(_make_pokemon_cd("Radiant Charizard", "Basic", "R", 160), 0)
	var score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": radiant}, gs, 0)
	return assert_true(score <= 20.0,
		"Before the prize race and finisher window are live, Radiant Charizard should stay dead in hand instead of being benched early (got %f)" % score)


func test_infernal_reign_energy_target_prioritizes_active_pivot_once_benched_charizard_is_ready() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Infernal Reign pivot routing can be verified"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var active_rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V", [], [], 1), 0)
	var ready_charizard := _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}],
		2
	), 0)
	ready_charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	ready_charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	var pidgeot := _make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0)
	player.active_pokemon = active_rotom
	player.bench.clear()
	player.bench.append(ready_charizard)
	player.bench.append(pidgeot)
	var step := {"id": "attach_energy_target"}
	var context := {"game_state": gs, "player_index": 0}
	var pivot_score: float = strategy.score_interaction_target(active_rotom, step, context)
	var charizard_score: float = strategy.score_interaction_target(ready_charizard, step, context)
	var pidgeot_score: float = strategy.score_interaction_target(pidgeot, step, context)
	return run_checks([
		assert_true(pivot_score >= 500.0,
			"Once benched Charizard ex is already ready, Infernal Reign should strongly value attaching the retreat-enabling Fire Energy to the active pivot (got %f)" % pivot_score),
		assert_true(pivot_score > pidgeot_score,
			"Infernal Reign should prefer the active retreat pivot over non-attacking bench support when that pivot unlocks the ready Charizard line"),
		assert_true(pivot_score >= charizard_score,
			"When Charizard ex is already ready, the active pivot should become the premium Infernal Reign attachment target"),
	])


func test_infernal_reign_ability_becomes_premium_once_charizard_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Infernal Reign ability timing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	var charizard := _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[{"name": "Infernal Reign", "text": "attach fire"}],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	player.active_pokemon = charizard
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Fire A", "R"), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Fire B", "R"), 0))
	var score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": charizard}, gs, 0)
	return assert_true(score >= 420.0,
		"Once Charizard ex is online with Fire Energy still in deck, Infernal Reign should become a premium action (got %f)" % score)


func test_infernal_reign_assignment_prefers_charizard_over_pidgeot_engine() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Infernal Reign assignment targets can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	var charizard := _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[{"name": "Infernal Reign", "text": "attach fire"}],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	var pidgeot := _make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0)
	player.active_pokemon = charizard
	player.bench.append(pidgeot)
	var fire := CardInstance.create(_make_energy_cd("Fire A", "R"), 0)
	var charizard_score: float = strategy.score_interaction_target(
		charizard,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": fire, "all_items": [charizard, pidgeot]}
	)
	var pidgeot_score: float = strategy.score_interaction_target(
		pidgeot,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": fire, "all_items": [charizard, pidgeot]}
	)
	return run_checks([
		assert_true(charizard_score >= 300.0,
			"Infernal Reign assignment should treat Charizard ex as a real energy target once it is online (got %f)" % charizard_score),
		assert_true(charizard_score > pidgeot_score,
			"Infernal Reign should prefer powering Charizard ex over feeding the Pidgeot ex engine"),
	])


func test_infernal_reign_assignment_prefers_retreat_pivot_once_benched_charizard_is_ready() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Infernal Reign headless pivot routing can be verified"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var active_rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V", [], [], 1), 0)
	var ready_charizard := _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[{"name": "Infernal Reign", "text": "attach fire"}],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	ready_charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	var pidgeot := _make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0)
	player.active_pokemon = active_rotom
	player.bench.append(ready_charizard)
	player.bench.append(pidgeot)
	var fire := CardInstance.create(_make_energy_cd("Fire A", "R"), 0)
	var pivot_score: float = strategy.score_interaction_target(
		active_rotom,
		{"id": "energy_assignments"},
		{
			"game_state": gs,
			"player_index": 0,
			"source_card": fire,
			"all_items": [active_rotom, ready_charizard, pidgeot],
			"pending_assignment_counts": {ready_charizard.get_instance_id(): 1},
		}
	)
	var pidgeot_score: float = strategy.score_interaction_target(
		pidgeot,
		{"id": "energy_assignments"},
		{
			"game_state": gs,
			"player_index": 0,
			"source_card": fire,
			"all_items": [active_rotom, ready_charizard, pidgeot],
			"pending_assignment_counts": {ready_charizard.get_instance_id(): 1},
		}
	)
	return run_checks([
		assert_true(pivot_score >= 500.0,
			"Once a prior Infernal Reign assignment makes benched Charizard ex ready, the next Fire Energy should strongly value the active retreat pivot (got %f)" % pivot_score),
		assert_true(pivot_score > pidgeot_score,
			"Infernal Reign headless routing should prefer the retreat pivot over the Pidgeot engine"),
	])


func test_retreat_prefers_rotom_pivot_into_ready_charizard_over_engine_piece() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Charizard transition retreat timing can be verified"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var active_rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V", [], [], 1), 0)
	active_rotom.attached_energy.append(CardInstance.create(_make_energy_cd("Fire pivot", "R"), 0))
	var ready_charizard := _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}],
		2
	), 0)
	ready_charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	ready_charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	var pidgeot := _make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0)
	player.active_pokemon = active_rotom
	player.bench.clear()
	player.bench.append(ready_charizard)
	player.bench.append(pidgeot)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var retreat_to_charizard: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": ready_charizard}, gs, 0)
	var retreat_to_pidgeot: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": pidgeot}, gs, 0)
	return run_checks([
		assert_true(retreat_to_charizard >= 450.0,
			"With a retreat-ready Rotom V and a fully online benched Charizard ex, retreat should become a premium transition action (got %f)" % retreat_to_charizard),
		assert_true(retreat_to_charizard > retreat_to_pidgeot,
			"Retreat should prefer the ready Charizard ex finisher over an engine-only bench target"),
	])


func test_opening_shell_does_not_retreat_active_charmander_into_non_attacking_bench() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Charizard opening retreat discipline can be verified"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	var active_charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70, "", "", [], [], 1), 0)
	active_charmander.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	var pidgey := _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60, "", "", [], [], 1), 0)
	var bench_charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70, "", "", [], [], 1), 0)
	player.active_pokemon = active_charmander
	player.bench.clear()
	player.bench.append(pidgey)
	player.bench.append(bench_charmander)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var retreat_to_pidgey: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": pidgey}, gs, 0)
	var retreat_to_bench_charmander: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": bench_charmander}, gs, 0)
	return run_checks([
		assert_true(retreat_to_pidgey <= 0.0,
			"In the opening shell, Charmander should not burn tempo retreating into a non-attacking Pidgey after setup (got %f)" % retreat_to_pidgey),
		assert_true(retreat_to_bench_charmander <= 0.0,
			"In the opening shell, Charmander should not burn tempo retreating into a second non-attacking Charmander (got %f)" % retreat_to_bench_charmander),
	])


func test_opening_fire_attach_does_not_feed_deferred_duskull_lane() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Duskull opening attach timing can be verified"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	player.active_pokemon = duskull
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": fire, "target_slot": duskull},
		gs,
		0
	)
	return assert_true(attach_score < 0.0,
		"When the opening shell is absent, manual Fire attachment should not feed the deferred Duskull lane (got %f)" % attach_score)


func test_rare_candy_does_not_force_dusknoir_before_combo_shell_exists() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Dusknoir Rare Candy timing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 150, "Dusclops"), 0))
	var rare_candy := CardInstance.create(_make_trainer_cd("Rare Candy"), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	var candy_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": rare_candy}, gs, 0)
	var iono_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": iono}, gs, 0)
	return run_checks([
		assert_true(candy_score <= 80.0,
			"Before the Charizard-Pidgeot combo shell exists, Rare Candy should not behave like a premium Dusknoir line (got %f)" % candy_score),
		assert_true(candy_score < iono_score,
			"Before the combo shell exists, forcing Dusknoir should stay behind generic hand recovery / disruption"),
	])


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


func test_dusknoir_ability_stays_dead_when_combo_shell_is_absent() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before opening Dusknoir ability timing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	var dusknoir := _make_slot(_make_pokemon_cd(
		"Dusknoir",
		"Stage 2",
		"P",
		150,
		"Dusclops",
		"",
		[{"name": "Cursed Blast", "text": "spread"}]
	), 0)
	player.active_pokemon = dusknoir
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Zapdos", "Basic", "L", 110), 1)
	var score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": dusknoir},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the Charizard combo shell is absent and there is no lethal conversion, Dusknoir ability should stay dead (got %f)" % score)


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


func test_dusknoir_ability_stays_dead_without_immediate_follow_up_even_when_shell_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Dusknoir conversion timing can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0))
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
	return assert_true(score <= 0.0,
		"Even with the shell online, Dusknoir should stay dead if there is no immediate self-KO lethal or same-turn follow-up lethal (got %f)" % score)


func test_dusknoir_target_prefers_clean_self_ko_knockout_over_bulky_rule_box() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Dusknoir target priorities can be verified"
	var gs := _make_game_state(4)
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
	var doomed := _make_slot(_make_pokemon_cd("Latias ex", "Basic", "P", 50, "", "ex"), 1)
	var bulky := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var step := {"id": "self_ko_target"}
	var context := {"game_state": gs, "player_index": 0}
	var doomed_score: float = strategy.score_interaction_target(doomed, step, context)
	var bulky_score: float = strategy.score_interaction_target(bulky, step, context)
	return run_checks([
		assert_true(doomed_score >= 500.0,
			"Dusknoir should strongly prioritize a clean self-KO knockout target (got %f)" % doomed_score),
		assert_true(doomed_score > bulky_score,
			"Dusknoir should prefer a guaranteed self-KO knockout over a bulky target that survives"),
	])


func test_dusknoir_target_prefers_attack_plus_self_ko_lethal_over_nonlethal_setup() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Dusknoir combo target priorities can be verified"
	var gs := _make_game_state(4)
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
	var combo_target := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 230, "", "ex"), 1)
	var nonlethal_target := _make_slot(_make_pokemon_cd("Pikachu ex", "Basic", "L", 300, "", "ex"), 1)
	gs.players[1].active_pokemon = combo_target
	gs.players[1].bench.clear()
	gs.players[1].bench.append(nonlethal_target)
	var step := {"id": "self_ko_target"}
	var context := {"game_state": gs, "player_index": 0}
	var combo_score: float = strategy.score_interaction_target(combo_target, step, context)
	var nonlethal_score: float = strategy.score_interaction_target(nonlethal_target, step, context)
	return run_checks([
		assert_true(combo_score >= 350.0,
			"Dusknoir should treat self-KO plus Charizard follow-up lethal as a real conversion line (got %f)" % combo_score),
		assert_true(combo_score > nonlethal_score,
			"Dusknoir should prefer a target that dies to self-KO plus the current attacker over one that still survives"),
	])


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


func test_forest_seal_stone_ability_on_rotom_is_high_priority_for_combo_completion() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Forest Seal Stone ability timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var rotom := _make_slot(_make_pokemon_cd(
		"Rotom V",
		"Basic",
		"L",
		190,
		"",
		"V",
		[{"name": "Instant Charge", "text": "draw"}]
	), 0)
	rotom.attached_tool = CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	rotom.attached_tool.card_data.effect_id = "9fa9943ccda36f417ac3cb675177c216"
	player.active_pokemon = rotom
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	var native_draw_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": rotom, "ability_index": 0},
		gs,
		0
	)
	var stone_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": rotom, "ability_index": 1},
		gs,
		0
	)
	return run_checks([
		assert_true(stone_score >= 500.0,
			"Once Rotom V is carrying Forest Seal Stone with the full opening shell online, opening the Stone should become a premium action (got %f)" % stone_score),
		assert_true(stone_score > native_draw_score,
			"Forest Seal Stone should outrank Rotom's normal draw ability when it can tutor combo pieces directly"),
	])


func test_forest_seal_stone_ability_waits_until_primary_setup_is_established() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Forest Seal Stone timing windows can be verified"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	var rotom := _make_slot(_make_pokemon_cd(
		"Rotom V",
		"Basic",
		"L",
		190,
		"",
		"V",
		[{"name": "Instant Charge", "text": "draw"}]
	), 0)
	rotom.attached_tool = CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	rotom.attached_tool.card_data.effect_id = "9fa9943ccda36f417ac3cb675177c216"
	player.active_pokemon = rotom
	var stone_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": rotom, "ability_index": 1},
		gs,
		0
	)
	return assert_true(stone_score <= 240.0,
		"Forest Seal Stone should not be blown before Charmander and Pidgey are both established (got %f)" % stone_score)


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


func test_rotom_v_ability_shuts_off_once_charizard_is_online_past_setup_even_without_pidgeot() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before post-setup Rotom V churn can be verified"
	var gs := _make_game_state(7)
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
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	for i: int in range(10):
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck Card %d" % i), 0))
	var score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": player.active_pokemon},
		gs,
		0
	)
	return assert_true(score <= -60.0,
		"Once Charizard ex is already online and the setup window has passed, Rotom V should stop midgame draw churn even without Pidgeot ex (got %f)" % score)


func test_pidgeot_quick_search_shuts_off_under_deck_out_pressure_without_live_conversion() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Quick Search deck-out protection can be verified"
	var gs := _make_game_state(18)
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
	var pidgeot := _make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0)
	player.bench.append(pidgeot)
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Super Rod"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.deck.clear()
	for i: int in range(4):
		player.deck.append(CardInstance.create(_make_trainer_cd("Dead Card %d" % i), 0))
	player.discard_pile.clear()
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	opponent.bench.clear()
	var score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": pidgeot},
		gs,
		0
	)
	return assert_true(score <= 40.0,
		"When deck-out pressure is high and there is no live conversion line, Pidgeot ex should stop automatic Quick Search churn (got %f)" % score)


func test_pidgeot_quick_search_stays_live_under_deck_out_pressure_when_backup_charizard_lane_is_unfinished() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before backup Charizard lane Quick Search timing can be verified"
	var gs := _make_game_state(18)
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
	var pidgeot := _make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0)
	player.bench.append(pidgeot)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Dead Card A"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Dead Card B"), 0))
	player.discard_pile.clear()
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	opponent.bench.clear()
	var score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": pidgeot},
		gs,
		0
	)
	return assert_true(score >= 500.0,
		"Even under low-deck pressure, Quick Search should stay live while a benched Charmander still needs the backup Charizard line (got %f)" % score)


func test_fezandipiti_ability_shuts_off_once_combo_core_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Fezandipiti churn can be verified"
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
	var fez_slot := _make_slot(_make_pokemon_cd(
		"Fezandipiti ex",
		"Basic",
		"D",
		210,
		"",
		"ex",
		[{"name": "Flip the Script", "text": "draw"}]
	), 0)
	player.bench.append(fez_slot)
	for i: int in range(3):
		player.hand.append(CardInstance.create(_make_trainer_cd("Card %d" % i), 0))
	var score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": fez_slot},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once Charizard ex and Pidgeot ex are already online, Fezandipiti ex should stop positive-value draw churn (got %f)" % score)


func test_rotom_v_bench_stays_low_once_combo_core_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Rotom V bench timing can be verified"
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
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": rotom}, gs, 0)
	return assert_true(score <= 20.0,
		"Once Charizard ex and Pidgeot ex are already online, late Rotom V benching should stay near-dead (got %f)" % score)


func test_fezandipiti_bench_stays_low_once_combo_core_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Fezandipiti bench timing can be verified"
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
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var fez := CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	var score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": fez}, gs, 0)
	return assert_true(score <= 20.0,
		"Once Charizard ex and Pidgeot ex are already online, late Fezandipiti ex benching should stay near-dead (got %f)" % score)


func test_lumineon_v_bench_stays_dead_once_combo_core_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Lumineon V bench timing can be verified"
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
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var lumineon := CardInstance.create(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	var score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": lumineon}, gs, 0)
	return assert_true(score <= 0.0,
		"Once Charizard ex and Pidgeot ex are already online, late Lumineon V benching should stay dead instead of reopening the supporter bridge (got %f)" % score)


func test_nest_ball_stays_live_for_rotom_once_core_lines_exist_early() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before early Rotom search priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
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


func test_search_item_prefers_nest_ball_over_second_poffin_once_rotom_is_the_missing_piece() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Rotom-first Arven priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var candidates: Array = [
		CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0),
		CardInstance.create(_make_trainer_cd("Nest Ball"), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		candidates,
		{"id": "search_item"},
		{"game_state": gs, "player_index": 0, "all_items": candidates}
	)
	return assert_eq(picked_name, "Nest Ball",
		"Once Charmander and Pidgey are already down, Arven should pivot to Nest Ball for Rotom V instead of looping into a second Buddy-Buddy Poffin")


func test_search_item_does_not_chase_rotom_when_rotom_is_not_available() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Rotom availability gating can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var candidates: Array = [
		CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0),
		CardInstance.create(_make_trainer_cd("Nest Ball"), 0),
	]
	var picked_name := _pick_best_item_name(
		strategy,
		candidates,
		{"id": "search_item"},
		{"game_state": gs, "player_index": 0, "all_items": candidates}
	)
	return assert_eq(picked_name, "Buddy-Buddy Poffin",
		"If Rotom V is not actually available in hand or deck, Arven should not chase Nest Ball as if the Rotom line were live")


func test_search_pokemon_prefers_rotom_v_over_duskull_when_shell_is_ready_but_draw_engine_is_missing() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Rotom search priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
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


func test_search_pokemon_prefers_lumineon_v_over_duskull_when_arven_bridge_is_missing() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Lumineon V bridge timing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0))
	var lumineon := CardInstance.create(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var step := {"id": "search_pokemon"}
	var context := {"game_state": gs, "player_index": 0}
	var lumineon_score: float = strategy.score_interaction_target(lumineon, step, context)
	var duskull_score: float = strategy.score_interaction_target(duskull, step, context)
	return run_checks([
		assert_true(lumineon_score >= 260.0,
			"When the opening shell is down but the Arven bridge is still missing, Lumineon V should become a live search target (got %f)" % lumineon_score),
		assert_true(lumineon_score > duskull_score,
			"Lumineon V should outrank Duskull while the combo still needs a supporter bridge"),
	])


func test_search_pokemon_shuts_off_lumineon_v_once_combo_core_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Lumineon V search timing can be verified"
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
	var lumineon := CardInstance.create(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var step := {"id": "search_pokemon"}
	var context := {"game_state": gs, "player_index": 0}
	var lumineon_score: float = strategy.score_interaction_target(lumineon, step, context)
	var duskull_score: float = strategy.score_interaction_target(duskull, step, context)
	return run_checks([
		assert_true(lumineon_score <= 40.0,
			"Once Charizard ex and Pidgeot ex are already online, late Lumineon V should stop behaving like a live search bridge (got %f)" % lumineon_score),
		assert_true(lumineon_score < duskull_score,
			"Late Lumineon V churn should stay below even the deferred Dusk lane when the combo core is already running"),
	])


func test_search_pokemon_keeps_duskull_as_fifth_piece_behind_second_charmander_and_rotom() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Duskull opening priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var second_charmander := CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var step := {"id": "search_pokemon"}
	var context := {"game_state": gs, "player_index": 0}
	var charmander_score: float = strategy.score_interaction_target(second_charmander, step, context)
	var rotom_score: float = strategy.score_interaction_target(rotom, step, context)
	var duskull_score: float = strategy.score_interaction_target(duskull, step, context)
	return run_checks([
		assert_true(charmander_score > rotom_score,
			"The second Charmander should stay ahead of Rotom V while the opening combo still needs the backup fire lane"),
		assert_true(rotom_score > duskull_score,
			"Duskull should stay behind Rotom V until the opening combo shell is complete"),
		assert_true(duskull_score <= 180.0,
			"Duskull should not be treated like a premium early search piece before the main combo is assembled (got %f)" % duskull_score),
	])


func test_search_pokemon_prefers_rotom_over_second_charmander_when_poffin_can_cover_backup_lane() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Rotom-first strong opening priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var second_charmander := CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "search_pokemon"}
	var charmander_score: float = strategy.score_interaction_target(second_charmander, step, context)
	var rotom_score: float = strategy.score_interaction_target(rotom, step, context)
	return run_checks([
		assert_true(rotom_score > charmander_score,
			"When Buddy-Buddy Poffin already covers the backup Charmander lane, Nest Ball should pivot to Rotom V first (got %f vs %f)" % [rotom_score, charmander_score]),
		assert_true(rotom_score >= 700.0,
			"Rotom V should become a premium search target in the strong opening window (got %f)" % rotom_score),
	])


func test_search_pokemon_prefers_rotom_over_second_charmander_in_direct_double_stage2_window() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before direct double-stage2 Rotom priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var second_charmander := CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "search_pokemon"}
	var charmander_score: float = strategy.score_interaction_target(second_charmander, step, context)
	var rotom_score: float = strategy.score_interaction_target(rotom, step, context)
	return run_checks([
		assert_true(rotom_score > charmander_score,
			"When both Stage 2s and both Rare Candies are already in hand, Nest Ball should pivot to Rotom V before a second Charmander (got %f vs %f)" % [rotom_score, charmander_score]),
		assert_true(rotom_score >= 900.0,
			"Rotom V should become a top-tier search target in the direct double-stage2 opening window (got %f)" % rotom_score),
	])


func test_search_pokemon_prefers_rotom_in_strong_opening_bridge_window_with_pidgeot_piece_in_hand() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before strong-opening Rotom bridge priorities can be verified"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var second_charmander := CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "search_pokemon"}
	var rotom_score: float = strategy.score_interaction_target(rotom, step, context)
	var charmander_score: float = strategy.score_interaction_target(second_charmander, step, context)
	return run_checks([
		assert_true(rotom_score > charmander_score,
			"When Pidgeot ex is already in hand and the opening only lacks Rotom V, Nest Ball should bridge into Rotom before a second Charmander (got %f vs %f)" % [rotom_score, charmander_score]),
		assert_true(rotom_score >= 940.0,
			"Rotom V should become an almost forced search target in the strong-opening bridge window (got %f)" % rotom_score),
	])


func test_search_pokemon_prefers_pidgeot_ex_over_charizard_ex_once_charizard_piece_is_already_in_hand() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Pidgeot-completion search priorities can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	var pidgeot := CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0)
	var charizard := CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "search_pokemon"}
	var pidgeot_score: float = strategy.score_interaction_target(pidgeot, step, context)
	var charizard_score: float = strategy.score_interaction_target(charizard, step, context)
	return run_checks([
		assert_true(pidgeot_score > charizard_score,
			"When Charizard ex is already in hand and the Pidgey + Rare Candy lane is ready, search should finish Pidgeot ex first (got %f vs %f)" % [pidgeot_score, charizard_score]),
		assert_true(pidgeot_score >= 950.0,
			"Pidgeot ex should become the top search target in the direct completion window (got %f)" % pidgeot_score),
	])


func test_buddy_buddy_poffin_picks_pidgey_before_second_charmander_when_pidgey_is_missing() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Buddy-Buddy Poffin opening priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Night Stretcher Holder", "Basic", "C", 60), 0)
	player.bench.clear()
	var first_charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(first_charmander)
	var candidates: Array = [
		CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0),
		CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0),
		CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0),
		CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0),
	]
	var picked := _pick_top_item_names(
		strategy,
		candidates,
		{"id": "buddy_poffin_pokemon"},
		{"game_state": gs, "player_index": 0},
		2
	)
	return run_checks([
		assert_true("Pidgey" in picked,
			"When Pidgey is still missing, Buddy-Buddy Poffin should reserve one slot for Pidgey instead of taking two Charmander"),
		assert_eq(picked[0], "Pidgey",
			"When the shell still lacks Pidgey, Buddy-Buddy Poffin should rank Pidgey ahead of the backup second Charmander"),
	])


func test_buddy_buddy_poffin_skips_duskull_when_rotom_and_backup_lane_are_still_missing() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Buddy-Buddy Poffin Duskull timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var picked: Array = strategy.pick_interaction_items(
		[duskull],
		{"id": "buddy_poffin_pokemon", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	return assert_eq(picked, [],
		"Before Rotom and the second Charmander are online, Buddy-Buddy Poffin should not spend itself just to bench Duskull")


func test_buddy_buddy_poffin_stays_low_when_only_duskull_targets_remain() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Buddy-Buddy Poffin dead-window scoring can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var poffin := CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0)
	var poffin_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": poffin}, gs, 0)
	return assert_true(poffin_score < 0.0,
		"When Buddy-Buddy Poffin can only find the deferred Duskull lane, it should stay near-dead instead of outranking end-turn/setup pivots (got %f)" % poffin_score)


func test_buddy_buddy_poffin_stays_dead_once_combo_core_is_online_and_only_duskull_targets_remain() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Buddy-Buddy Poffin churn can be verified"
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
	player.bench.clear()
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
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var poffin := CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0)
	var poffin_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": poffin}, gs, 0)
	return assert_true(poffin_score <= 20.0,
		"Once Charizard ex and Pidgeot ex are online, Buddy-Buddy Poffin should not wake up just to fetch the Duskull side lane (got %f)" % poffin_score)


func test_buddy_buddy_poffin_keeps_duskull_out_of_post_core_backup_selection() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Buddy-Buddy Poffin target selection can be verified"
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
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0))
	var charmander := CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var picked: Array = strategy.pick_interaction_items(
		[charmander, duskull],
		{"id": "buddy_poffin_pokemon", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var picked_names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance:
			picked_names.append(str((item as CardInstance).card_data.name))
	return run_checks([
		assert_true("Charmander" in picked_names,
			"Once the combo core is online, Buddy-Buddy Poffin can still pick the missing backup Charmander lane"),
		assert_true(not ("Duskull" in picked_names),
			"Once the combo core is online, Buddy-Buddy Poffin should not burn its second slot on the deferred Duskull lane"),
	])


func test_arven_stays_dead_when_only_late_setup_targets_remain() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Arven churn can be verified"
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
	player.bench.clear()
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
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	var arven := CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	var arven_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": arven}, gs, 0)
	var iono_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": iono}, gs, 0)
	return run_checks([
		assert_true(arven_score <= 80.0,
			"Once only late setup items remain, Arven should stop spending full supporter turns on dead shell padding (got %f)" % arven_score),
		assert_true(arven_score < iono_score,
			"Late Arven churn should stay behind live disruption when the combo core is already online"),
	])


func test_opening_setup_keeps_duskull_last_after_two_charmanders_pidgey_and_rotom() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before opening bench order can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var bench_names: Array[String] = []
	for index_variant: Variant in choice.get("bench_hand_indices", []):
		var hand_index: int = int(index_variant)
		if hand_index >= 0 and hand_index < player.hand.size():
			bench_names.append(str(player.hand[hand_index].card_data.name))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	return run_checks([
		assert_eq(active_name, "Rotom V",
			"Rotom V should lead when two Charmander and Pidgey can all stay protected on bench"),
		assert_eq(bench_names.slice(0, 3), ["Charmander", "Charmander", "Pidgey"],
			"The opening combo shell should bench two Charmander and one Pidgey before the Duskull lane"),
		assert_eq(bench_names[-1], "Duskull",
			"Duskull should be the fifth setup piece, not an earlier bench priority"),
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


func test_forest_seal_stone_stays_dead_without_any_live_v_target() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before empty Forest Seal Stone timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.active_pokemon = charmander
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	var stone := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	var attach_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": stone, "target_slot": charmander}, gs, 0)
	var search_score: float = strategy.score_interaction_target(
		stone,
		{"id": "search_tool"},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_true(attach_score <= 0.0,
			"Forest Seal Stone should stay dead when there is no live Pokemon V target, not get attached to Charmander (got %f)" % attach_score),
		assert_true(search_score <= 40.0,
			"Arven should not fetch Forest Seal Stone when no live Pokemon V target exists (got %f)" % search_score),
	])


func test_defiance_band_does_not_attach_to_opening_pivot_before_attackers_are_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Defiance Band opening timing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	var rotom_slot := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.active_pokemon = rotom_slot
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	var band := CardInstance.create(_make_trainer_cd("Defiance Band", "Tool"), 0)
	var band_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": band, "target_slot": rotom_slot}, gs, 0)
	return assert_true(band_score <= 0.0,
		"Before Charizard is online, Defiance Band should stay off opening pivots like Rotom V (got %f)" % band_score)


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


func test_lightning_pressure_does_not_force_direct_charizard_without_conversion_window() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Lightning pressure transition timing can be verified"
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
	]
	opponent.prizes = [
		CardInstance.create(_make_pokemon_cd("Prize X"), 1),
		CardInstance.create(_make_pokemon_cd("Prize Y"), 1),
		CardInstance.create(_make_pokemon_cd("Prize Z"), 1),
		CardInstance.create(_make_pokemon_cd("Prize W"), 1),
	]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	var charizard := CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0)
	var pidgeot := CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0)
	var step := {"id": "search_pokemon"}
	var context := {"game_state": gs, "player_index": 0}
	var charizard_score: float = strategy.score_interaction_target(charizard, step, context)
	var pidgeot_score: float = strategy.score_interaction_target(pidgeot, step, context)
	return run_checks([
		assert_true(pidgeot_score > charizard_score,
			"When the Charizard player is not behind on prizes and Miraidon has not opened a convertible bench target, Lightning pressure alone should not shut off the Pidgeot line"),
		assert_true(charizard_score <= 900.0,
			"Direct Charizard should stay below the all-in pressure threshold when there is no immediate conversion window (got %f)" % charizard_score),
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


func test_boss_orders_stays_dead_when_attack_is_soon_but_gust_is_not_immediately_convertible() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before near-ready Boss timing can be verified"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0)
	player.bench.clear()
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
	charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	player.bench.append(charizard)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1))
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	var boss_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": boss}, gs, 0)
	var iono_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": iono}, gs, 0)
	return run_checks([
		assert_true(boss_score <= 20.0,
			"When Charizard is only nearly ready and no bench gust converts right now, Boss's Orders should stay dead instead of being floated for tempo loss (got %f)" % boss_score),
		assert_true(boss_score < iono_score,
			"Non-convertible Boss's Orders should stay behind live disruption while the attack line is still one step away"),
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


func test_counter_catcher_stays_low_when_ready_charizard_still_cannot_take_a_bench_prize() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before ready-but-nonconvertible Counter Catcher timing can be verified"
	var gs := _make_game_state(6)
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
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	player.prizes = [
		CardInstance.create(_make_pokemon_cd("Prize A"), 0),
		CardInstance.create(_make_pokemon_cd("Prize B"), 0),
		CardInstance.create(_make_pokemon_cd("Prize C"), 0),
		CardInstance.create(_make_pokemon_cd("Prize D"), 0),
	]
	opponent.prizes = [
		CardInstance.create(_make_pokemon_cd("Prize X"), 1),
		CardInstance.create(_make_pokemon_cd("Prize Y"), 1),
	]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1))
	var counter_catcher := CardInstance.create(_make_trainer_cd("Counter Catcher"), 0)
	var arven := CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0)
	var catcher_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": counter_catcher}, gs, 0)
	var arven_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": arven}, gs, 0)
	return run_checks([
		assert_true(catcher_score <= 60.0,
			"Even with a ready Charizard ex, Counter Catcher should stay low if no bench gust converts into an immediate prize (got %f)" % catcher_score),
		assert_true(catcher_score < arven_score,
			"When the gust is not directly convertible, Counter Catcher should stay behind live setup/conversion trainers"),
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


func test_play_stadium_uses_charizard_strategy_scoring_for_collapsed_stadium() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before stadium play timing can be verified"
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
	player.bench.append(_make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	opponent.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 1))
	opponent.bench.append(_make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 1))
	var collapsed := CardInstance.create(_make_trainer_cd("Collapsed Stadium", "Stadium"), 0)
	var trainer_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": collapsed}, gs, 0)
	var play_score: float = strategy.score_action_absolute({"kind": "play_stadium", "card": collapsed}, gs, 0)
	return run_checks([
		assert_true(trainer_score >= 220.0,
			"Collapsed Stadium should keep its existing liability-cleanup value on Charizard boards (got %f)" % trainer_score),
		assert_true(play_score >= 160.0,
			"Playing Collapsed Stadium from hand should become a real option once it clears Rotom V and trims a wide opponent bench (got %f)" % play_score),
		assert_true(play_score < trainer_score,
			"Direct stadium timing should stay stricter than generic trainer-search desirability"),
	])


func test_play_stadium_stays_dead_while_rotom_is_still_an_opening_engine_piece() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before early Collapsed Stadium timing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	var collapsed := CardInstance.create(_make_trainer_cd("Collapsed Stadium", "Stadium"), 0)
	var play_score: float = strategy.score_action_absolute({"kind": "play_stadium", "card": collapsed}, gs, 0)
	return assert_true(play_score <= 20.0,
		"Before Charizard ex is online, Collapsed Stadium should not treat live Rotom V as cleanup liability (got %f)" % play_score)


func test_play_stadium_stays_dead_in_opening_without_cleanup_value() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before empty Collapsed Stadium timing can be verified"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.clear()
	gs.stadium_card = null
	var collapsed := CardInstance.create(_make_trainer_cd("Collapsed Stadium", "Stadium"), 0)
	var play_score: float = strategy.score_action_absolute({"kind": "play_stadium", "card": collapsed}, gs, 0)
	return assert_true(play_score <= 20.0,
		"When there is no bench cleanup value on either side, opening Collapsed Stadium should stay dead instead of becoming a generic turn-one play (got %f)" % play_score)


func test_super_rod_stays_low_when_only_dusk_lane_is_in_discard_after_combo_core_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Super Rod churn can be verified"
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
	player.bench.clear()
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
	player.discard_pile.clear()
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var super_rod := CardInstance.create(_make_trainer_cd("Super Rod"), 0)
	var rod_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": super_rod}, gs, 0)
	return assert_true(rod_score <= 40.0,
		"Once the combo core is online, Super Rod should not start a dead Dusk lane just because Duskull is in discard (got %f)" % rod_score)


func test_search_pokemon_shuts_off_dusk_lane_without_immediate_conversion_even_post_core() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before late Dusknoir search suppression can be verified"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var dusknoir := CardInstance.create(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 150, "Dusclops"), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var step := {"id": "search_pokemon"}
	var context := {"game_state": gs, "player_index": 0}
	var dusknoir_score: float = strategy.score_interaction_target(dusknoir, step, context)
	var duskull_score: float = strategy.score_interaction_target(duskull, step, context)
	return run_checks([
		assert_true(dusknoir_score <= 80.0,
			"Once the combo core is online but there is no immediate conversion, Dusknoir should not restart a dead prize-trade lane through search (got %f)" % dusknoir_score),
		assert_true(duskull_score <= 80.0,
			"Without an immediate conversion window, Duskull should also stay cold in late Quick Search windows (got %f)" % duskull_score),
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


func test_attack_waits_for_pidgeot_ex_when_early_double_stage2_window_is_live() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before early double-stage2 finishing can be verified"
	var gs := _make_game_state(3)
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
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Burning Darkness", "projected_damage": 180},
		gs,
		0
	)
	var candy_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Rare Candy"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(candy_score > attack_score,
			"Before the first Charizard attack in the early setup window, finishing Pidgeot ex should outrank swinging immediately (got %f vs %f)" % [candy_score, attack_score]),
		assert_true(candy_score >= 700.0,
			"Rare Candy should become a premium setup-finishing action when Pidgeot ex is the last missing engine piece (got %f)" % candy_score),
	])


func test_arven_stays_low_when_double_stage2_finish_is_already_in_hand() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before direct double-stage2 finish windows can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	var arven_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0)},
		gs,
		0
	)
	var candy_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Rare Candy"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(arven_score < candy_score,
			"When both Stage 2 pieces and two Rare Candy are already in hand, Arven should stay behind direct evolution (got %f vs %f)" % [arven_score, candy_score]),
		assert_true(arven_score <= 120.0,
			"Arven should stop reopening the bridge when the full double-stage2 finish is already available in hand (got %f)" % arven_score),
	])


func test_infernal_reign_stops_overfilling_charizard_while_pidgeot_ex_is_still_missing() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before early Infernal Reign caps can be verified"
	var gs := _make_game_state(3)
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
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	var target_score: float = strategy.score_interaction_target(
		player.active_pokemon,
		{"id": "manual_attach_energy_target"},
		{"game_state": gs, "player_index": 0, "source_card": CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)}
	)
	return assert_true(target_score <= 30.0,
		"Once Charizard ex is already attack-ready and Pidgeot ex is still the missing engine piece, extra Fire attachments should stay near-dead (got %f)" % target_score)


func test_infernal_reign_stops_overfilling_charizard_once_both_stage2s_are_online_early() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before early double-stage2 Infernal Reign caps can be verified"
	var gs := _make_game_state(3)
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
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	var backup_charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(backup_charmander)
	var charizard_score: float = strategy.score_interaction_target(
		player.active_pokemon,
		{"id": "manual_attach_energy_target"},
		{"game_state": gs, "player_index": 0, "source_card": CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)}
	)
	return assert_true(charizard_score <= 0.0,
		"Once both Stage 2 lines are already online early and Charizard ex is attack-ready, extra Fire should stop going into the active Charizard (got %f)" % charizard_score)


func test_handoff_target_prefers_rotom_v_for_early_send_out_when_shell_basics_are_already_down() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Charizard handoff routing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Knocked Out Lead", "Basic", "C", 60), 0)
	player.bench.clear()
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var pidgey := _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(rotom)
	player.bench.append(charmander)
	player.bench.append(pidgey)
	var rotom_score: float = strategy.score_handoff_target(rotom, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var charmander_score: float = strategy.score_handoff_target(charmander, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var pidgey_score: float = strategy.score_handoff_target(pidgey, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(rotom_score > charmander_score,
			"In early launch-shell handoffs, Rotom V should outrank Charmander as the send-out pivot (got %f vs %f)" % [rotom_score, charmander_score]),
		assert_true(rotom_score > pidgey_score,
			"In early launch-shell handoffs, Rotom V should outrank Pidgey as the send-out pivot (got %f vs %f)" % [rotom_score, pidgey_score]),
	])


func test_handoff_target_prefers_ready_charizard_for_self_switch_target() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before self-switch handoff routing can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Pivot Fire", "R"), 0))
	var ready_charizard := _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	ready_charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	ready_charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	var pidgeot := _make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0)
	var rotom_bench := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.clear()
	player.bench.append(ready_charizard)
	player.bench.append(pidgeot)
	player.bench.append(rotom_bench)
	var zard_score: float = strategy.score_handoff_target(ready_charizard, {"id": "self_switch_target"}, {"game_state": gs, "player_index": 0})
	var pidgeot_score: float = strategy.score_handoff_target(pidgeot, {"id": "self_switch_target"}, {"game_state": gs, "player_index": 0})
	var rotom_score: float = strategy.score_handoff_target(rotom_bench, {"id": "self_switch_target"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(zard_score > pidgeot_score,
			"Self-switch handoff should route attack ownership to the ready Charizard ex over the Pidgeot engine (got %f vs %f)" % [zard_score, pidgeot_score]),
		assert_true(zard_score > rotom_score,
			"Self-switch handoff should route attack ownership to the ready Charizard ex over a support pivot (got %f vs %f)" % [zard_score, rotom_score]),
	])


func test_thorton_stays_dead_without_stage2_reentry_target() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Thorton timing can be verified"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	player.discard_pile.clear()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Thorton", "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 10.0,
		"Without a live stage-2 reentry target in discard, Thorton should stay effectively dead (got %f)" % score)


func test_turo_stays_dead_in_early_shell_without_rule_box_rescue_or_cleanup_target() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before Turo timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor Turo's Scenario", "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 10.0,
		"In the early shell, Turo should stay effectively dead when there is no damaged rule-box rescue or spent support-pivot cleanup (got %f)" % score)


func test_turo_stays_live_for_spent_rotom_cleanup_once_combo_core_is_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist before combo-core Turo cleanup timing can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.clear()
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
	charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	charizard.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	player.bench.append(charizard)
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search"}]
	), 0))
	var score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor Turo's Scenario", "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score >= 180.0,
		"Once the combo core is online, Turo should stay live as a cleanup card for a spent Rotom pivot (got %f)" % score)
