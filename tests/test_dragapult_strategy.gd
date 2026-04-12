class_name TestDragapultStrategy
extends TestBase


const DUSKNOIR_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultDusknoir.gd"
const BANETTE_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultBanette.gd"
const HYBRID_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultCharizard.gd"
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


func _new_strategy(script_path: String) -> RefCounted:
	CardInstance.reset_id_counter()
	var script := _load_script(script_path)
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
	energy_type: String = "P",
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
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi, "Basic", "C"), pi)
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


func test_dragapult_strategy_scripts_load_and_implement_contract() -> String:
	var checks: Array[String] = []
	for entry: Dictionary in [
		{"label": "Dusknoir", "path": DUSKNOIR_SCRIPT_PATH, "id": "dragapult_dusknoir"},
		{"label": "Banette", "path": BANETTE_SCRIPT_PATH, "id": "dragapult_banette"},
		{"label": "Hybrid", "path": HYBRID_SCRIPT_PATH, "id": "dragapult_charizard"},
	]:
		var script := _load_script(str(entry.get("path", "")))
		checks.append(assert_not_null(script, "%s Dragapult strategy script should load" % str(entry.get("label", ""))))
		if script == null:
			continue
		var strategy = script.new()
		checks.append(assert_eq(_missing_methods(strategy, REQUIRED_METHODS), [], "%s strategy should implement the unified contract" % str(entry.get("label", ""))))
		checks.append(assert_eq(str(strategy.get_strategy_id()), str(entry.get("id", "")), "%s strategy id should match the planned family id" % str(entry.get("label", ""))))
	return run_checks(checks)


func test_dusknoir_opening_prefers_dreepy_active_and_keeps_duskull_on_bench() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before opening setup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Fezandipiti", "Basic", "D", 110), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	var bench_names: Array[String] = []
	for index_variant: Variant in choice.get("bench_hand_indices", []):
		var hand_index: int = int(index_variant)
		if hand_index >= 0 and hand_index < player.hand.size():
			bench_names.append(str(player.hand[hand_index].card_data.name))
	return run_checks([
		assert_eq(active_name, "Dreepy", "Dragapult shells should usually open with the main attacker line, not the support shell"),
		assert_true("Duskull" in bench_names, "The Dusknoir shell should still bench Duskull for prize-tempo follow-up"),
	])


func test_dusknoir_scores_dragapult_and_dusknoir_progress_above_generic_evolution() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before evolution priorities can be verified"
	var gs := _make_game_state(4)
	var dragapult_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0)},
		gs,
		0
	)
	var dusknoir_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops"), 0)},
		gs,
		0
	)
	var generic_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Pidgeotto", "Stage 1", "C", 80, "Pidgey"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(dragapult_score > dusknoir_score, "The main Dragapult payoff should outrank the support evolution"),
		assert_true(dusknoir_score > generic_score, "The Dusknoir support line should still outrank generic evolutions"),
	])


func test_dusknoir_search_item_prefers_rare_candy_when_dragapult_jump_is_live() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before item search priorities can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var items: Array = [
		CardInstance.create(_make_trainer_cd("Nest Ball"), 0),
		CardInstance.create(_make_trainer_cd("Rare Candy"), 0),
	]
	var picked_name := _best_card_name(
		strategy,
		items,
		"search_item",
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Rare Candy",
		"The Dusknoir shell should use Arven/item search to jump straight into Dragapult ex when the payoff is already available")


func test_dusknoir_search_tool_prefers_sparkling_crystal_when_dragapult_needs_one_attachment() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before tool search priorities can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var items: Array = [
		CardInstance.create(_make_trainer_cd("Rescue Board", "Tool"), 0),
		CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0),
	]
	var picked_name := _best_card_name(
		strategy,
		items,
		"search_tool",
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Sparkling Crystal",
		"When Dragapult ex is the main pressure line, the deck should search the tool that unlocks Phantom Dive fastest")


func test_dusknoir_counter_distribution_prefers_damaged_bench_pickoff() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before bench-target scoring can be verified"
	var gs := _make_game_state(5)
	var weak_bench := _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 1)
	weak_bench.damage_counters = 50
	var healthy_bench := _make_slot(_make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 1)
	var targets: Array = [healthy_bench, weak_bench]
	var picked_name := _best_slot_name(
		strategy,
		targets,
		"bench_damage_counters",
		{"game_state": gs, "player_index": 0, "all_items": targets}
	)
	return assert_eq(picked_name, "Pidgey",
		"The Dusknoir shell should spend spread counters to finish a damaged bench prize first")


func test_dusknoir_attack_values_phantom_dive_when_bench_pickoffs_exist() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before attack timing can be verified"
	var gs := _make_game_state(4)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)
	var weak_bench := _make_slot(_make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 1)
	weak_bench.damage_counters = 50
	gs.players[1].bench.append(weak_bench)
	var phantom_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Phantom Dive", "projected_damage": 200},
		gs,
		0
	)
	var poke_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Jet Head", "projected_damage": 70},
		gs,
		0
	)
	return assert_true(phantom_score > poke_score,
		"Phantom Dive should outrank low-pressure attacks when its bench counters can set up or finish a 2-prize target")


func test_banette_search_prefers_banette_shell_over_dusknoir_shell() -> String:
	var strategy := _new_strategy(BANETTE_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultBanette.gd should exist before shell-specific search priorities can be verified"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Banette ex", "Stage 1", "P", 250, "Shuppet", "ex"), 0),
		CardInstance.create(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops"), 0),
	]
	var picked_name := _best_card_name(
		strategy,
		items,
		"search_pokemon",
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Banette ex",
		"The Banette shell should search for its disruption partner instead of the Dusknoir package")


func test_banette_opening_prefers_shuppet_active_for_item_lock_line() -> String:
	var strategy := _new_strategy(BANETTE_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultBanette.gd should exist before opening setup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Shuppet", "Basic", "P", 60), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	var bench_names: Array[String] = []
	for index_variant: Variant in choice.get("bench_hand_indices", []):
		var hand_index: int = int(index_variant)
		if hand_index >= 0 and hand_index < player.hand.size():
			bench_names.append(str(player.hand[hand_index].card_data.name))
	return run_checks([
		assert_eq(active_name, "Shuppet", "The Banette shell should lead Shuppet when it can threaten a Salvatore item-lock start"),
		assert_true("Dreepy" in bench_names, "The Dragapult lane should still be benched behind the disruption lead"),
	])


func test_banette_attack_values_early_item_lock_pressure() -> String:
	var strategy := _new_strategy(BANETTE_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultBanette.gd should exist before attack timing can be verified"
	var gs := _make_game_state(2)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Banette ex", "Stage 1", "P", 250, "Shuppet", "ex"), 0)
	var lock_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Everlasting Darkness", "projected_damage": 30},
		gs,
		0
	)
	var poke_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Poltergeist", "projected_damage": 60},
		gs,
		0
	)
	return assert_true(lock_score > poke_score,
		"Against fast setup decks, Banette should value early item lock pressure above small generic damage upgrades")


func test_banette_board_evaluation_rewards_disruption_shell_presence() -> String:
	var strategy := _new_strategy(BANETTE_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultBanette.gd should exist before board evaluation can be verified"
	var gs := _make_game_state(5)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0))
	var base_score: float = strategy.evaluate_board(gs, 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Banette ex", "Stage 1", "P", 250, "Shuppet", "ex"), 0))
	var improved_score: float = strategy.evaluate_board(gs, 0)
	return assert_true(improved_score > base_score,
		"The Banette shell should value having its disruption partner online (%f vs %f)" % [improved_score, base_score])


func test_hybrid_search_shifts_between_dragapult_and_charizard_finishers() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before hybrid search priorities can be verified"
	var dragapult_board := _make_game_state(4)
	dragapult_board.players[0].bench.append(_make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0))
	var charizard_board := _make_game_state(4)
	charizard_board.players[0].bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	charizard_board.players[0].bench.append(_make_slot(_make_pokemon_cd("Charmeleon", "Stage 1", "R", 90, "Charmander"), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0),
		CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0),
	]
	var dragapult_pick := _best_card_name(
		strategy,
		items,
		"search_pokemon",
		{"game_state": dragapult_board, "player_index": 0, "all_items": items}
	)
	var charizard_pick := _best_card_name(
		strategy,
		items,
		"search_pokemon",
		{"game_state": charizard_board, "player_index": 0, "all_items": items}
	)
	return run_checks([
		assert_eq(dragapult_pick, "Dragapult ex", "The hybrid shell should keep pressing the Dragapult line when that side is already developed"),
		assert_eq(charizard_pick, "Charizard ex", "The hybrid shell should pivot to Charizard when the fire line is the closer payoff"),
	])


func test_hybrid_scores_rare_candy_for_charizard_stabilization() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before trainer priorities can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	var rare_candy_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Rare Candy"), 0)},
		gs,
		0
	)
	var switch_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Switch"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(rare_candy_score >= 350.0, "The hybrid shell should respect Charizard stabilization lines when they are ready (got %f)" % rare_candy_score),
		assert_true(rare_candy_score > switch_score, "Rare Candy should outrank generic trainer usage in the hybrid shell"),
	])


func test_hybrid_search_item_prefers_tm_evolution_when_two_stage1_lines_can_jump() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before TM Evolution priorities can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var items: Array = [
		CardInstance.create(_make_trainer_cd("Switch"), 0),
		CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0),
	]
	var picked_name := _best_card_name(
		strategy,
		items,
		"search_item",
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Technical Machine: Evolution",
		"The hybrid shell should search TM Evolution when it can advance both Stage 2 lanes at once")


func test_hybrid_attach_energy_prefers_dragapult_lane_before_charizard_finisher() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before energy routing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(dreepy)
	player.bench.append(charmander)
	var fire_energy := CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0)
	fire_energy.card_data.energy_provides = "R"
	var dragapult_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": fire_energy, "target_slot": dreepy}, gs, 0)
	var charizard_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": fire_energy, "target_slot": charmander}, gs, 0)
	return assert_true(dragapult_score > charizard_score,
		"Before Charizard is stabilized, the hybrid shell should invest early manual energy into the Dragapult pressure lane")


func test_hybrid_board_evaluation_rewards_two_lane_pressure() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before board evaluation can be verified"
	var gs := _make_game_state(5)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0))
	var one_lane_score: float = strategy.evaluate_board(gs, 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	var two_lane_score: float = strategy.evaluate_board(gs, 0)
	return assert_true(two_lane_score > one_lane_score,
		"The hybrid shell should value boards where both Stage 2 lanes are online (%f vs %f)" % [two_lane_score, one_lane_score])
