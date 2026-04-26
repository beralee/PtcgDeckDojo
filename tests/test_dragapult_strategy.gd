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


func test_dusknoir_opening_prefers_bridge_pivot_active_over_exposing_dreepy() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before opening pivot priorities can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Tatsugiri", "Basic", "W", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	var bench_names: Array[String] = []
	for index_variant: Variant in choice.get("bench_hand_indices", []):
		var hand_index: int = int(index_variant)
		if hand_index >= 0 and hand_index < player.hand.size():
			bench_names.append(str(player.hand[hand_index].card_data.name))
	return run_checks([
		assert_eq(active_name, "Tatsugiri", "The Dusknoir shell should prefer a bridge pivot active so Dreepy survives to evolve"),
		assert_true("Dreepy" in bench_names, "The Dragapult shell should still bench Dreepy behind the bridge pivot"),
		assert_true("Duskull" in bench_names, "The Dusknoir shell should still bench Duskull behind the bridge pivot"),
	])


func test_dusknoir_tm_devolution_stays_low_without_real_evolution_window() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before TM Devolution timing can be verified"
	var gs := _make_game_state(4)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Tatsugiri", "Basic", "W", 70), 0)
	gs.players[0].bench.clear()
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	gs.players[1].bench.clear()
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1))
	var tm_card := CardInstance.create(_make_trainer_cd("Technical Machine: Devolution", "Tool"), 0)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": tm_card, "target_slot": gs.players[0].active_pokemon},
		gs,
		0
	)
	var search_score: float = strategy.score_interaction_target(
		tm_card,
		{"id": "search_tool"},
		{"game_state": gs, "player_index": 0, "all_items": [tm_card]}
	)
	return run_checks([
		assert_true(attach_score <= 0.0, "The shell should not attach TM Devolution into a Miraidon board with no evolution payoff"),
		assert_true(search_score <= 0.0, "The shell should not search TM Devolution into a Miraidon board with no evolution payoff"),
	])


func test_dusknoir_boss_orders_stays_low_without_immediate_attack_window() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before gust timing can be verified"
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Tatsugiri", "Basic", "W", 70), 0)
	gs.players[0].bench.clear()
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	gs.players[1].bench.clear()
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1))
	var score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 40.0,
		"The Dusknoir shell should not spend Boss's Orders before it can actually convert the gust into damage")


func test_dusknoir_forest_seal_stone_prefers_rotom_in_opening_shell() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before Forest Seal Stone routing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var rotom_slot := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var lumineon_slot := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Tatsugiri", "Basic", "W", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.bench.append(rotom_slot)
	player.bench.append(lumineon_slot)
	var stone := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	stone.card_data.effect_id = "9fa9943ccda36f417ac3cb675177c216"
	var rotom_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": stone, "target_slot": rotom_slot}, gs, 0)
	var lumineon_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": stone, "target_slot": lumineon_slot}, gs, 0)
	return run_checks([
		assert_true(rotom_score >= 500.0,
			"Forest Seal Stone should strongly prefer Rotom V in the opening shell (got %f)" % rotom_score),
		assert_true(rotom_score > lumineon_score,
			"Forest Seal Stone should prefer Rotom V over Lumineon V while the first Dragapult ex is still missing"),
	])


func test_dusknoir_forest_seal_stone_ability_becomes_premium_when_first_dragapult_is_missing() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before Forest Seal Stone ability timing can be verified"
	var gs := _make_game_state(3)
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
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0))
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
		assert_true(stone_score >= 560.0,
			"Forest Seal Stone should become a premium action when the first Dragapult ex line is one tutor away (got %f)" % stone_score),
		assert_true(stone_score > native_draw_score,
			"Forest Seal Stone should outrank Rotom's native draw when it can close the first Dragapult gap"),
	])


func test_dusknoir_turn_plan_forces_first_dragapult_before_dusknoir_shell_completion() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before turn-plan prioritization can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Tatsugiri", "Basic", "W", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	var plan: Dictionary = strategy.build_turn_plan(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = plan.get("flags", {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "force_first_dragapult",
			"Once the Dreepy lane is online and the Dragapult jump is live, the turn intent should force the first Dragapult before finishing Dusknoir setup"),
		assert_true(bool(flags.get("shell_ready", false)),
			"The first Dragapult push should treat the Dreepy shell as ready even if Duskull is still missing"),
		assert_false(bool(flags.get("support_shell_ready", true)),
			"The same position should still record that the Dusknoir support shell is missing"),
	])


func test_dusknoir_turn_plan_does_not_fall_back_to_launch_shell_after_first_dragapult_is_online() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before online Dragapult turn-intent can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "R"
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	var plan: Dictionary = strategy.build_turn_plan(gs, 0, {"prompt_kind": "action_selection"})
	return assert_true(str(plan.get("intent", "")) in ["bridge_to_attack", "convert_attack", "rebuild_dragapult"],
		"Once the first Dragapult ex is online, the turn intent should not fall back to launch_shell")


func test_dusknoir_poffin_cools_once_first_dragapult_is_online() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before post-Dragapult churn can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "R"
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	var poffin_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0)},
		gs,
		0
	)
	return assert_true(poffin_score <= 40.0,
		"Once the first Dragapult ex is already online, Buddy-Buddy Poffin should cool off instead of re-entering the shell loop (got %f)" % poffin_score)


func test_dusknoir_rotom_draw_goes_dead_once_ready_dragapult_and_support_shell_are_online() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before late-game churn control can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "R"
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	player.bench.append(_make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
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
		"Once a ready Dragapult ex and support shell are online, Rotom V draw should stop positive-value churn (got %f)" % score)


func test_dusknoir_extra_support_benching_goes_dead_once_ready_dragapult_is_online() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before late-game bench discipline can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "R"
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	player.bench.append(_make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once Dragapult ex is already converting and the support shell exists, extra support basics should stop looking like productive setup (got %f)" % score)


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


func test_dusknoir_phantom_dive_decisively_outranks_jet_head_once_online() -> String:
	var strategy := _new_strategy(DUSKNOIR_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should exist before Dragapult attack choice can be verified"
	var gs := _make_game_state(5)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[
			{"name": "Jet Head", "cost": "P", "damage": "70"},
			{"name": "Phantom Dive", "cost": "RP", "damage": "200"}
		]
	), 0)
	gs.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	gs.players[0].active_pokemon.attached_energy[-1].card_data.energy_provides = "R"
	gs.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	gs.players[0].active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	var phantom_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Phantom Dive", "projected_damage": 200},
		gs,
		0
	)
	var jet_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Jet Head", "projected_damage": 70},
		gs,
		0
	)
	return run_checks([
		assert_true(phantom_score > jet_score,
			"Once Dragapult ex can use Phantom Dive, the Dusknoir shell should not fall back to Jet Head"),
		assert_true(phantom_score - jet_score >= 300.0,
			"Phantom Dive should have a decisive margin over Jet Head once both Energy are online"),
	])


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


func test_hybrid_single_search_pivots_into_first_charmander_once_dragapult_shell_exists() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before transition search priorities can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0),
		CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0),
	]
	var picked_name := _best_card_name(
		strategy,
		items,
		"search_pokemon",
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Charmander",
		"Once the Dragapult shell already has Drakloak online, the next single Pokemon search should pivot into the first Charmander instead of another Dreepy")


func test_hybrid_opening_search_prefers_first_dreepy_over_charizard_stage2_without_direct_finish() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before opening owner search can be verified"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0),
		CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0),
	]
	var picked_name := _best_card_name(
		strategy,
		items,
		"search_pokemon",
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Dreepy",
		"When the fire lane is only a lone Charmander and no direct Charizard finish exists, the first opening Pokemon search should establish the Dragapult owner")


func test_hybrid_opening_prefers_dreepy_active_over_support_rule_box() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before hybrid opening setup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := "" if active_idx < 0 else str(player.hand[active_idx].card_data.name)
	var bench_names: Array[String] = []
	for index_variant: Variant in choice.get("bench_hand_indices", []):
		var hand_index: int = int(index_variant)
		if hand_index >= 0 and hand_index < player.hand.size():
			bench_names.append(str(player.hand[hand_index].card_data.name))
	return run_checks([
		assert_eq(active_name, "Dreepy", "The hybrid shell should open on Dreepy when the main pressure lane is available"),
		assert_true("Charmander" in bench_names, "The hybrid shell should still bench Charmander behind the Dragapult opener"),
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


func test_hybrid_search_cards_prefers_charizard_ex_under_lightning_pressure() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before any-card search payload can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	iron_hands.damage_counters = 20
	opponent.bench.append(iron_hands)
	var cards: Array = [
		CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0),
		CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0),
	]
	var picked_name := _best_card_name(
		strategy,
		cards,
		"search_cards",
		{"game_state": gs, "player_index": 0, "all_items": cards}
	)
	return assert_eq(picked_name, "Charizard ex",
		"Against live Lightning pressure, any-card search should break the early Dragapult tie in favor of the direct Charizard conversion line")


func test_hybrid_forest_seal_stone_does_not_route_to_fezandipiti_ex() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before Forest Seal Stone routing can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	var fez_slot := _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	var rotom_slot := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.bench.clear()
	player.bench.append(fez_slot)
	player.bench.append(rotom_slot)
	var stone := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	stone.card_data.effect_id = "9fa9943ccda36f417ac3cb675177c216"
	var fez_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": stone, "target_slot": fez_slot}, gs, 0)
	var rotom_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": stone, "target_slot": rotom_slot}, gs, 0)
	return run_checks([
		assert_true(fez_score < 0.0, "Forest Seal Stone should not treat Fezandipiti ex as a live seal target (got %f)" % fez_score),
		assert_true(rotom_score > fez_score, "Forest Seal Stone should prefer a true Pokemon V carrier over Fezandipiti ex"),
	])


func test_hybrid_search_tool_cools_forest_seal_stone_when_only_fezandipiti_ex_is_live() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before hybrid tool-search priorities can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var forest_seal := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	forest_seal.card_data.effect_id = "9fa9943ccda36f417ac3cb675177c216"
	var tm_evo := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var items: Array = [forest_seal, tm_evo]
	var picked_name := _best_card_name(
		strategy,
		items,
		"search_tool",
		{"game_state": gs, "player_index": 0, "all_items": items}
	)
	return assert_eq(picked_name, "Technical Machine: Evolution",
		"When only Fezandipiti ex is live, hybrid tool search should not waste the slot on Forest Seal Stone")


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


func test_hybrid_attach_energy_pivots_to_charizard_when_dragapult_lane_is_already_online() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before late-game energy routing can be verified"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	dragapult.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	dragapult.attached_energy[-1].card_data.energy_provides = "P"
	dragapult.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	dragapult.attached_energy[-1].card_data.energy_provides = "R"
	player.active_pokemon = dragapult
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
	charizard.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy A", "Basic Energy"), 0))
	charizard.attached_energy[-1].card_data.energy_provides = "R"
	player.bench.append(charizard)
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.bench.append(dreepy)
	var fire_energy := CardInstance.create(_make_trainer_cd("Fire Energy B", "Basic Energy"), 0)
	fire_energy.card_data.energy_provides = "R"
	var charizard_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": fire_energy, "target_slot": charizard}, gs, 0)
	var dreepy_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": fire_energy, "target_slot": dreepy}, gs, 0)
	return assert_true(charizard_score > dreepy_score,
		"Once Dragapult is already online, the next manual Fire attachment should pivot into the Charizard closer")


func test_hybrid_attach_energy_prefers_live_charizard_over_partial_drakloak_in_late_conversion() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before late-conversion Fire routing can be verified"
	var gs := _make_game_state(13)
	var player: PlayerState = gs.players[0]
	var active_drakloak := _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0)
	var psychic := CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0)
	psychic.card_data.energy_provides = "P"
	active_drakloak.attached_energy.append(psychic)
	player.active_pokemon = active_drakloak
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
	var fire_a := CardInstance.create(_make_trainer_cd("Fire Energy A", "Basic Energy"), 0)
	fire_a.card_data.energy_provides = "R"
	charizard.attached_energy.append(fire_a)
	player.bench.append(charizard)
	player.bench.append(_make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var fire_b := CardInstance.create(_make_trainer_cd("Fire Energy B", "Basic Energy"), 0)
	fire_b.card_data.energy_provides = "R"
	var charizard_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": fire_b, "target_slot": charizard}, gs, 0)
	var drakloak_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": fire_b, "target_slot": active_drakloak}, gs, 0)
	return run_checks([
		assert_true(charizard_score >= 500.0,
			"Late in the game, once Charizard ex is the live closer, manual Fire should strongly finish that lane (got %f)" % charizard_score),
		assert_true(charizard_score > drakloak_score,
			"Late-conversion manual Fire should not keep feeding a partial Drakloak lane over the live Charizard ex closer"),
	])


func test_hybrid_attack_prefers_phantom_dive_once_it_is_live() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before Dragapult attack priorities can be verified"
	var gs := _make_game_state(5)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[
			{"name": "Jet Head", "cost": "P", "damage": "70"},
			{"name": "Phantom Dive", "cost": "RP", "damage": "200"}
		]
	), 0)
	gs.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	gs.players[0].active_pokemon.attached_energy[-1].card_data.energy_provides = "R"
	gs.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	gs.players[0].active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	var phantom_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Phantom Dive", "projected_damage": 200},
		gs,
		0
	)
	var jet_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Jet Head", "projected_damage": 70},
		gs,
		0
	)
	return run_checks([
		assert_true(phantom_score > jet_score,
			"Once Dragapult ex can use Phantom Dive, the hybrid shell should not fall back to its lower-pressure first attack"),
		assert_true(phantom_score - jet_score >= 300.0,
			"Phantom Dive should have a decisive margin over the first attack once both Energy are online"),
	])


func test_hybrid_attack_cools_when_charizard_finish_window_is_live() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before finish-shell attack discipline can be verified"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "R"
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0))
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Phantom Dive", "projected_damage": 200},
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
			"A ready Dragapult ex should still cool its first Phantom Dive if closing Charizard this turn is the higher-value conversion"),
	])


func test_hybrid_infernal_reign_ability_becomes_premium_once_charizard_is_online() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before Infernal Reign timing can be verified"
	var gs := _make_game_state(5)
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
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	player.bench.append(charizard)
	player.deck.append(CardInstance.create(_make_trainer_cd("Fire A", "Basic Energy"), 0))
	player.deck[-1].card_data.energy_provides = "R"
	player.deck.append(CardInstance.create(_make_trainer_cd("Fire B", "Basic Energy"), 0))
	player.deck[-1].card_data.energy_provides = "R"
	var ability_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": charizard}, gs, 0)
	var tm_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0), "target_slot": charizard},
		gs,
		0
	)
	return run_checks([
		assert_true(ability_score >= 420.0,
			"Once Charizard ex is online with Fire still in deck, Infernal Reign should become a premium hybrid action (got %f)" % ability_score),
		assert_true(ability_score > tm_score,
			"Infernal Reign should outrank attaching TM Evolution once the Charizard line is already online"),
	])


func test_hybrid_infernal_reign_assignment_prefers_readying_charizard() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before Infernal Reign assignment targets can be verified"
	var gs := _make_game_state(5)
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
	var dragapult := _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	dragapult.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic A", "Basic Energy"), 0))
	dragapult.attached_energy[-1].card_data.energy_provides = "P"
	player.active_pokemon = dragapult
	player.bench.append(charizard)
	var fire := CardInstance.create(_make_trainer_cd("Fire A", "Basic Energy"), 0)
	fire.card_data.energy_provides = "R"
	var charizard_score: float = strategy.score_interaction_target(
		charizard,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_slot": charizard, "source_card": fire, "all_items": [dragapult, charizard]}
	)
	var dragapult_score: float = strategy.score_interaction_target(
		dragapult,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_slot": charizard, "source_card": fire, "all_items": [dragapult, charizard]}
	)
	return run_checks([
		assert_true(charizard_score >= 500.0,
			"Infernal Reign should treat benched Charizard ex as a premium readying target in the hybrid shell (got %f)" % charizard_score),
		assert_true(charizard_score > dragapult_score,
			"When Dragapult is already carrying the Psychic half, Infernal Reign should finish Charizard before feeding extra Fire into Dragapult"),
	])


func test_hybrid_infernal_reign_assignment_prefers_active_pivot_once_charizard_is_ready() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before Infernal Reign pivot routing can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	var active_lumineon := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V", [], [], 1), 0)
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
	ready_charizard.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire 1", "Basic Energy"), 0))
	ready_charizard.attached_energy[-1].card_data.energy_provides = "R"
	ready_charizard.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire 2", "Basic Energy"), 0))
	ready_charizard.attached_energy[-1].card_data.energy_provides = "R"
	var dragapult := _make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0)
	player.active_pokemon = active_lumineon
	player.bench.append(ready_charizard)
	player.bench.append(dragapult)
	var fire := CardInstance.create(_make_trainer_cd("Fire 3", "Basic Energy"), 0)
	fire.card_data.energy_provides = "R"
	var pivot_score: float = strategy.score_interaction_target(
		active_lumineon,
		{"id": "energy_assignments"},
		{
			"game_state": gs,
			"player_index": 0,
			"source_slot": ready_charizard,
			"source_card": fire,
			"all_items": [active_lumineon, ready_charizard, dragapult],
			"pending_assignment_counts": {ready_charizard.get_instance_id(): 0},
		}
	)
	var dragapult_score: float = strategy.score_interaction_target(
		dragapult,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_slot": ready_charizard, "source_card": fire, "all_items": [active_lumineon, ready_charizard, dragapult]}
	)
	return run_checks([
		assert_true(pivot_score >= 500.0,
			"Once benched Charizard ex is already ready, Infernal Reign should strongly value the active pivot that unlocks the attack (got %f)" % pivot_score),
		assert_true(pivot_score > dragapult_score,
			"With a ready Charizard ex waiting on bench, Infernal Reign should route extra Fire to the active pivot over feeding the other Stage 2 lane"),
	])


func test_hybrid_infernal_reign_does_not_dump_fire_into_raw_dreepy_before_charizard_is_ready() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before Infernal Reign setup routing can be verified"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var active_charizard := _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[{"name": "Infernal Reign", "text": "attach fire"}],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	player.active_pokemon = active_charizard
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.bench.append(dreepy)
	var fire := CardInstance.create(_make_trainer_cd("Fire A", "Basic Energy"), 0)
	fire.card_data.energy_provides = "R"
	var charizard_score: float = strategy.score_interaction_target(
		active_charizard,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_slot": active_charizard, "source_card": fire, "all_items": [active_charizard, dreepy]}
	)
	var dreepy_score: float = strategy.score_interaction_target(
		dreepy,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_slot": active_charizard, "source_card": fire, "all_items": [active_charizard, dreepy]}
	)
	return run_checks([
		assert_true(charizard_score >= 500.0,
			"When Charizard ex still needs Fire to attack, Infernal Reign should keep feeding the Charizard line itself (got %f)" % charizard_score),
		assert_true(dreepy_score <= 80.0,
			"Infernal Reign should not dump Fire into raw Dreepy while the Charizard line is still unfinished (got %f)" % dreepy_score),
		assert_true(charizard_score > dreepy_score,
			"An unfinished Charizard ex should outrank raw Dreepy as an Infernal Reign target"),
	])


func test_hybrid_energy_assignments_use_charizard_routing_without_source_slot_context() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before headless Infernal Reign routing can be verified"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var active_charizard := _make_slot(_make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[{"name": "Infernal Reign", "text": "attach fire"}],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	), 0)
	player.active_pokemon = active_charizard
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.bench.append(dreepy)
	var fire := CardInstance.create(_make_trainer_cd("Fire A", "Basic Energy"), 0)
	fire.card_data.energy_provides = "R"
	var charizard_score: float = strategy.score_interaction_target(
		active_charizard,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": fire, "all_items": [active_charizard, dreepy]}
	)
	var dreepy_score: float = strategy.score_interaction_target(
		dreepy,
		{"id": "energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": fire, "all_items": [active_charizard, dreepy]}
	)
	return run_checks([
		assert_true(charizard_score > dreepy_score,
			"Headless energy_assignments should still use Charizard routing even when source_slot is absent"),
		assert_true(dreepy_score <= 80.0,
			"Headless Infernal Reign routing should keep raw Dreepy low even without source_slot context (got %f)" % dreepy_score),
	])


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


func test_hybrid_rotom_draw_goes_dead_once_two_lane_pressure_is_online() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before late-game churn control can be verified"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "R"
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
		"Once both Dragapult ex and Charizard ex are online, Rotom V draw should stop positive-value churn (got %f)" % score)


func test_hybrid_extra_benching_goes_dead_once_two_lane_pressure_is_online() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before late-game bench discipline can be verified"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "R"
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
	var score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once both finishers are online, extra support basics should stop looking like productive setup (got %f)" % score)


func test_hybrid_dead_opening_trainers_stay_below_setup_without_targets() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before opening dead-card timing can be verified"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	gs.stadium_card = null
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var lost_vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0)
	var rod := CardInstance.create(_make_trainer_cd("Super Rod"), 0)
	var setup_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	var boss_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": boss}, gs, 0)
	var vacuum_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": lost_vacuum}, gs, 0)
	var rod_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": rod}, gs, 0)
	return run_checks([
		assert_true(boss_score <= 40.0,
			"Boss's Orders should stay near-dead when the hybrid shell cannot attack soon (got %f)" % boss_score),
		assert_true(vacuum_score <= 20.0,
			"Lost Vacuum should stay near-dead when there is no stadium to clear (got %f)" % vacuum_score),
		assert_true(rod_score <= 40.0,
			"Super Rod should stay near-dead with an empty discard and no recovery need (got %f)" % rod_score),
		assert_true(boss_score < setup_score,
			"Boss's Orders should not outrank opening setup while the board is still empty"),
		assert_true(vacuum_score < setup_score,
			"Lost Vacuum should not outrank opening setup"),
		assert_true(rod_score < setup_score,
			"Super Rod should not outrank opening setup"),
	])


func test_hybrid_boss_orders_goes_dead_while_shell_missing_and_no_attack_ready() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before opening gust suppression can be verified"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var arven := CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0)
	var boss_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": boss,
		"targets": [{"opponent_bench_target": [opponent.bench[0]]}],
	}, gs, 0)
	var arven_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": arven}, gs, 0)
	return run_checks([
		assert_true(boss_score <= 25.0,
			"Boss's Orders should go nearly dead when the shell is missing and there is no live attack conversion (got %f)" % boss_score),
		assert_true(boss_score < arven_score,
			"Opening gust should stay below shell-building supporter lines"),
	])


func test_hybrid_boss_orders_goes_negative_when_midgame_shell_is_still_missing() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before midgame gust suppression can be verified"
	var gs := _make_game_state(9)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1))
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var boss_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": boss,
		"targets": [{"opponent_bench_target": [opponent.bench[0]]}],
	}, gs, 0)
	var nest_ball_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	return run_checks([
		assert_true(boss_score < 0.0,
			"Boss's Orders should go negative when neither lane is actually converting yet (got %f)" % boss_score),
		assert_true(boss_score < nest_ball_score,
			"Dead midgame gust should stay below shell-restoring search lines"),
	])




func test_hybrid_boss_orders_goes_negative_without_immediate_gust_conversion() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before immediate gust conversion can be verified"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)
	var dragapult := _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	var psychic := CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0)
	psychic.card_data.energy_provides = "P"
	dragapult.attached_energy.append(psychic)
	player.bench.append(dragapult)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 1))
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var boss_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": boss,
		"targets": [{"opponent_bench_target": [opponent.bench[0]]}],
	}, gs, 0)
	var nest_ball_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	return run_checks([
		assert_true(boss_score < 0.0,
			"Boss's Orders should go negative when only a one-step-short bench attacker exists and the active pivot cannot convert immediately (got %f)" % boss_score),
		assert_true(boss_score < nest_ball_score,
			"Non-converting gust should stay below setup search"),
	])


func test_hybrid_lost_vacuum_goes_dead_when_it_only_self_breaks_shell() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before Lost Vacuum self-sabotage can be verified"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	var tm := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	player.active_pokemon.attached_tool = tm
	var charizard_ex := CardInstance.create(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 0)
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0)
	var poffin := CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0)
	var vacuum_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": vacuum,
		"targets": [{
			"discard_cards": [charizard_ex],
			"lost_vacuum_target": [tm],
		}],
	}, gs, 0)
	var poffin_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": poffin}, gs, 0)
	return run_checks([
		assert_true(vacuum_score < 0.0,
			"Lost Vacuum should be dead when it only self-breaks TM/FSS lines and bins a core Stage 2 (got %f)" % vacuum_score),
		assert_true(vacuum_score < poffin_score,
			"Self-sabotaging Lost Vacuum should stay below real setup"),
	])


func test_hybrid_lost_vacuum_goes_negative_when_it_only_hits_self_targets_midgame() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before midgame Lost Vacuum suppression can be verified"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0)
	var tm := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	player.active_pokemon.attached_tool = tm
	player.bench.append(_make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "P", 320, "Drakloak", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0)
	var fire_energy := CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0)
	fire_energy.card_data.energy_provides = "R"
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball"), 0)
	var vacuum_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": vacuum,
		"targets": [{
			"discard_cards": [fire_energy],
			"lost_vacuum_target": [tm],
		}],
	}, gs, 0)
	var nest_ball_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest_ball}, gs, 0)
	return run_checks([
		assert_true(vacuum_score < 0.0,
			"Lost Vacuum should go negative when it only hits self attachments and the shell still cannot convert (got %f)" % vacuum_score),
		assert_true(vacuum_score < nest_ball_score,
			"Midgame self-only Lost Vacuum should stay below shell-fixing search lines"),
	])


func test_hybrid_lost_vacuum_recognizes_cloned_self_tool_target() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before cloned Lost Vacuum targets can be verified"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var attached_fss := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	player.active_pokemon.attached_tool = attached_fss
	var cloned_target := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	cloned_target.instance_id = attached_fss.instance_id
	var tm := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum"), 0)
	var poffin := CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0)
	var vacuum_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": vacuum,
		"targets": [{
			"discard_cards": [tm],
			"lost_vacuum_target": [cloned_target],
		}],
	}, gs, 0)
	var poffin_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": poffin}, gs, 0)
	return run_checks([
		assert_true(vacuum_score < 0.0,
			"Lost Vacuum should stay dead when a cloned runtime target still points at our own Forest Seal Stone (got %f)" % vacuum_score),
		assert_true(vacuum_score < poffin_score,
			"Cloned self-only Lost Vacuum should still stay below productive setup"),
	])


func test_hybrid_retreats_from_underdeveloped_active_into_ready_finisher() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before retreat conversion can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0)
	var dragapult := _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	dragapult.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	dragapult.attached_energy[-1].card_data.energy_provides = "P"
	dragapult.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	dragapult.attached_energy[-1].card_data.energy_provides = "R"
	player.bench.append(dragapult)
	var retreat_score: float = strategy.score_action_absolute({"kind": "retreat"}, gs, 0)
	return assert_true(retreat_score >= 180.0,
		"When Drakloak is stranded active and a ready finisher is on the bench, the hybrid shell should aggressively pivot (got %f)" % retreat_score)


func test_hybrid_self_switch_prefers_ready_dragapult_over_setup_basic() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before self-switch ownership can be verified"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	var active_rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.active_pokemon = active_rotom
	var ready_dragapult := _make_slot(_make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"P",
		320,
		"Drakloak",
		"ex",
		[],
		[{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	), 0)
	ready_dragapult.attached_energy.append(CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0))
	ready_dragapult.attached_energy[-1].card_data.energy_provides = "R"
	ready_dragapult.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	ready_dragapult.attached_energy[-1].card_data.energy_provides = "P"
	var charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(ready_dragapult)
	player.bench.append(charmander)
	var dragapult_score: float = strategy.score_handoff_target(
		ready_dragapult,
		{"id": "self_switch_target"},
		{"game_state": gs, "player_index": 0}
	)
	var charmander_score: float = strategy.score_handoff_target(
		charmander,
		{"id": "self_switch_target"},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_true(dragapult_score >= 700.0,
			"When a bridge pivot is active, self-switch should strongly prefer the ready Dragapult ex finisher (got %f)" % dragapult_score),
		assert_true(dragapult_score > charmander_score,
			"Self-switch should not fall back to setup basics while a ready attacker already exists"),
	])


func test_hybrid_retreat_prefers_live_charizard_over_rotom_in_late_conversion() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before late-conversion retreat ownership can be verified"
	var gs := _make_game_state(13)
	var player: PlayerState = gs.players[0]
	var active_drakloak := _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0)
	var psychic := CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0)
	psychic.card_data.energy_provides = "P"
	active_drakloak.attached_energy.append(psychic)
	player.active_pokemon = active_drakloak
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
	var fire_a := CardInstance.create(_make_trainer_cd("Fire Energy A", "Basic Energy"), 0)
	fire_a.card_data.energy_provides = "R"
	charizard.attached_energy.append(fire_a)
	player.bench.append(charizard)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.append(rotom)
	var charizard_retreat_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": charizard}, gs, 0)
	var rotom_retreat_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": rotom}, gs, 0)
	return run_checks([
		assert_true(charizard_retreat_score > rotom_retreat_score,
			"Late-conversion retreat should prefer the live Charizard ex closer over cycling into Rotom V"),
		assert_true(rotom_retreat_score < 0.0,
			"Retreating into Rotom V after Charizard ex is already live should go negative (got %f)" % rotom_retreat_score),
	])


func test_hybrid_refuses_low_value_retreat_when_only_setup_basics_wait_on_bench() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before low-value retreat discipline can be verified"
	var gs := _make_game_state(9)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Drakloak",
		"Stage 1",
		"P",
		90,
		"Dreepy",
		"",
		[],
		[{"name": "Tail Swing", "cost": "P", "damage": "70"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_trainer_cd("Psychic Energy", "Basic Energy"), 0))
	player.active_pokemon.attached_energy[-1].card_data.energy_provides = "P"
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	var retreat_score: float = strategy.score_action_absolute({"kind": "retreat"}, gs, 0)
	return assert_true(retreat_score <= 30.0,
		"When Drakloak can still pressure and the bench only holds more setup basics, retreat should stay low-value instead of burning tempo (got %f)" % retreat_score)


func test_hybrid_blocks_early_retreat_into_support_basic_from_half_ready_stage1() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before early retreat blocks can be verified"
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	var active_charmeleon := _make_slot(_make_pokemon_cd(
		"Charmeleon",
		"Stage 1",
		"R",
		90,
		"Charmander",
		"",
		[],
		[{"name": "Flare", "cost": "R", "damage": "50"}]
	), 0)
	var fire := CardInstance.create(_make_trainer_cd("Fire Energy", "Basic Energy"), 0)
	fire.card_data.energy_provides = "R"
	active_charmeleon.attached_energy.append(fire)
	player.active_pokemon = active_charmeleon
	var manaphy := _make_slot(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)
	player.bench.append(manaphy)
	var retreat_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": manaphy}, gs, 0)
	return assert_true(retreat_score < 0.0,
		"Early retreat should not throw a half-ready Stage 1 into a pure support basic (got %f)" % retreat_score)


func test_hybrid_tm_evolution_goes_dead_on_stage2_target_in_late_conversion() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before late-conversion TM discipline can be verified"
	var gs := _make_game_state(13)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0)
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
	var fire := CardInstance.create(_make_trainer_cd("Fire Energy A", "Basic Energy"), 0)
	fire.card_data.energy_provides = "R"
	charizard.attached_energy.append(fire)
	player.bench.append(charizard)
	player.bench.append(_make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var tm := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var tm_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": tm, "target_slot": charizard}, gs, 0)
	return assert_true(tm_score < 0.0,
		"TM Evolution should go dead when the target is already a Stage 2 in a late conversion window (got %f)" % tm_score)


func test_hybrid_rotom_draw_cools_once_late_charizard_conversion_is_live() -> String:
	var strategy := _new_strategy(HYBRID_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyDragapultCharizard.gd should exist before late-conversion Rotom discipline can be verified"
	var gs := _make_game_state(13)
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
	player.active_pokemon = rotom
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
	var fire := CardInstance.create(_make_trainer_cd("Fire Energy A", "Basic Energy"), 0)
	fire.card_data.energy_provides = "R"
	charizard.attached_energy.append(fire)
	player.bench.append(charizard)
	player.bench.append(_make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "P", 90, "Dreepy"), 0))
	var rotom_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": rotom, "ability_index": 0}, gs, 0)
	return assert_true(rotom_score < 0.0,
		"Rotom V draw should cool below zero once late Charizard conversion is already live (got %f)" % rotom_score)
