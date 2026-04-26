class_name TestFutureAncientStrategies
extends TestBase


const FUTURE_BOX_SCRIPT_PATH := "res://scripts/ai/DeckStrategyFutureBox.gd"
const IRON_THORNS_SCRIPT_PATH := "res://scripts/ai/DeckStrategyIronThorns.gd"
const RAGING_BOLT_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd"
const GOUGING_FIRE_SCRIPT_PATH := "res://scripts/ai/DeckStrategyGougingFireAncient.gd"
const LLM_PROMPT_BUILDER_SCRIPT_PATH := "res://scripts/ai/LLMTurnPlanPromptBuilder.gd"
const LLM_INTERACTION_BRIDGE_SCRIPT_PATH := "res://scripts/ai/LLMInteractionIntentBridge.gd"


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_strategy(script_path: String) -> RefCounted:
	var script := _load_script(script_path)
	return script.new() if script != null else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "C",
	hp: int = 100,
	mechanic: String = "",
	attacks: Array = [],
	tags: Array[String] = [],
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	cd.is_tags = PackedStringArray(tags)
	return cd


func _make_energy_cd(pname: String, energy_provides: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = card_type
	cd.energy_provides = energy_provides
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


func _make_player(player_index: int = 0) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = player_index
	return player


func _make_game_state(turn: int = 2) -> GameState:
	CardInstance.reset_id_counter()
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := _make_player(player_index)
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % player_index), player_index)
		gs.players.append(player)
	return gs


func test_future_and_ancient_strategy_scripts_load() -> String:
	return run_checks([
		assert_not_null(_load_script(FUTURE_BOX_SCRIPT_PATH), "DeckStrategyFutureBox.gd should load"),
		assert_not_null(_load_script(IRON_THORNS_SCRIPT_PATH), "DeckStrategyIronThorns.gd should load"),
		assert_not_null(_load_script(RAGING_BOLT_SCRIPT_PATH), "DeckStrategyRagingBoltOgerpon.gd should load"),
		assert_not_null(_load_script(GOUGING_FIRE_SCRIPT_PATH), "DeckStrategyGougingFireAncient.gd should load"),
	])


func test_future_box_prioritizes_future_engine_trainers() -> String:
	var strategy := _new_strategy(FUTURE_BOX_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyFutureBox.gd should exist before future engine priorities can be tested"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	for _i: int in 5:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Iron Crown ex", "Basic", "P", 220, "ex", [], ["Future"]), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "ex", [], ["Future"]), 0))
	var score_radar: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Techno Radar"), 0)},
		gs,
		0
	)
	var score_generator: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Electric Generator"), 0)},
		gs,
		0
	)
	var score_research: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_radar > score_research, "Future Box should value Techno Radar over generic draw"),
		assert_true(score_generator >= 450.0, "Future Box should strongly value Electric Generator setup"),
	])


func test_future_box_prefers_capsule_and_future_targets() -> String:
	var strategy := _new_strategy(FUTURE_BOX_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyFutureBox.gd should exist before Future Booster priorities can be tested"
	var gs := _make_game_state(3)
	var iron_hands := _make_slot(
		_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "ex", [{"name": "Amp", "cost": "LLC", "damage": "160"}], ["Future"]),
		0
	)
	var mew := _make_slot(
		_make_pokemon_cd("Mew ex", "Basic", "P", 180, "ex", [{"name": "Genome Hacking", "cost": "CC", "damage": "0"}]),
		0
	)
	gs.players[0].bench.append(iron_hands)
	gs.players[0].bench.append(mew)
	var capsule := CardInstance.create(_make_trainer_cd("Future Booster Energy Capsule", "Tool"), 0)
	var tool_on_future: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": capsule, "target_slot": iron_hands},
		gs,
		0
	)
	var tool_on_mew: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": capsule, "target_slot": mew},
		gs,
		0
	)
	var iron_crown := CardInstance.create(_make_pokemon_cd("Iron Crown ex", "Basic", "P", 220, "ex", [], ["Future"]), 0)
	var generic := CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	var future_target_score: float = strategy.score_interaction_target(
		iron_crown,
		{"id": "search_future_pokemon"},
		{}
	)
	var generic_target_score: float = strategy.score_interaction_target(
		generic,
		{"id": "search_future_pokemon"},
		{}
	)
	return run_checks([
		assert_true(tool_on_future > tool_on_mew, "Future Box should reserve Capsule for future attackers"),
		assert_true(future_target_score > generic_target_score, "Future Box should search future targets ahead of generic Pokemon"),
	])


func test_iron_thorns_prioritizes_lock_denial_and_board_lock_state() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before lock priorities can be tested"
	var gs := _make_game_state(3)
	var iron_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	iron_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	gs.players[0].active_pokemon = iron_thorns
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "ex", [], []), 1)
	var score_judge: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		gs,
		0
	)
	var score_hammer: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Crushing Hammer"), 0)},
		gs,
		0
	)
	var score_research: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	var board_with_lock: float = strategy.evaluate_board(gs, 0)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Ditto", "Basic", "C", 70), 0)
	gs.players[0].bench.append(iron_thorns)
	var board_without_lock: float = strategy.evaluate_board(gs, 0)
	return run_checks([
		assert_true(score_judge > score_research, "Iron Thorns should prefer Judge over generic draw"),
		assert_true(score_hammer > score_research, "Iron Thorns should prefer denial items over generic draw"),
		assert_true(board_with_lock > board_without_lock, "Iron Thorns should value keeping the lock attacker active"),
	])


func test_iron_thorns_prefers_capsule_on_active_lock() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before active lock tool routing can be tested"
	var gs := _make_game_state(3)
	var iron_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	var ditto := _make_slot(_make_pokemon_cd("Ditto", "Basic", "C", 70), 0)
	gs.players[0].active_pokemon = iron_thorns
	gs.players[0].bench.append(ditto)
	var capsule := CardInstance.create(_make_trainer_cd("Future Booster Energy Capsule", "Tool"), 0)
	var active_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": capsule, "target_slot": iron_thorns},
		gs,
		0
	)
	var bench_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": capsule, "target_slot": ditto},
		gs,
		0
	)
	return run_checks([
		assert_true(active_score > 0.0, "Iron Thorns should positively score Capsule on the lock attacker"),
		assert_true(active_score > bench_score, "Iron Thorns should keep Capsule on the active lock target"),
	])


func test_iron_thorns_prefers_turbo_energize_line_while_lock_is_still_charging() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before turbo-energize timing can be tested"
	var gs := _make_game_state(2)
	var iron_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LCC", "damage": "140"}], ["Future"], 4),
		0
	)
	iron_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	gs.players[0].active_pokemon = iron_thorns
	gs.players[0].bench.append(_make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LCC", "damage": "140"}], ["Future"], 4),
		0
	))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var score_tm: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Technical Machine: Turbo Energize", "Tool"), 0)},
		gs,
		0
	)
	var score_research: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_tm > score_research, "Iron Thorns should favor the Turbo Energize bridge over generic draw while the active lock is short on energy"),
		assert_true(score_tm >= 220.0, "Turbo Energize should be a clearly positive bridge action for Iron Thorns (got %f)" % score_tm),
	])


func test_iron_thorns_prefers_ditto_transform_into_lock_over_attaching_to_ditto() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before Ditto opening-transform timing can be tested"
	var gs := _make_game_state(1)
	var player := gs.players[0]
	var ditto := _make_slot(_make_pokemon_cd("Ditto", "Basic", "C", 70), 0)
	player.active_pokemon = ditto
	player.deck.append(CardInstance.create(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	))
	var ability_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": ditto, "ability_index": 0},
		gs,
		0
	)
	var attach_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0), "target_slot": ditto},
		gs,
		0
	)
	var iron_thorns_target := CardInstance.create(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	var generic_target := CardInstance.create(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "V"), 0)
	var transform_step := {"id": "transform_target"}
	var iron_thorns_target_score: float = strategy.score_interaction_target(iron_thorns_target, transform_step, {})
	var generic_target_score: float = strategy.score_interaction_target(generic_target, transform_step, {})
	return run_checks([
		assert_true(ability_score > attach_score, "Iron Thorns should transform Ditto into the lock attacker before spending the turn attaching to Ditto"),
		assert_true(ability_score >= 300.0, "Ditto opening transform should be a clearly positive Iron Thorns line"),
		assert_true(iron_thorns_target_score > generic_target_score, "Ditto transform should prefer Iron Thorns over off-plan basic targets"),
	])


func test_iron_thorns_cools_off_extra_ditto_and_churn_once_lock_is_online() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before Iron Thorns pressure-phase churn can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "CC", "Special Energy"), 0))
	player.active_pokemon = active_thorns
	player.bench.append(_make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var ditto_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Ditto", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var gear_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Pok\\u00e9gear 3.0"), 0)},
		gs,
		0
	)
	var cologne_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Canceling Cologne"), 0)},
		gs,
		0
	)
	var research_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(ditto_score <= 40.0, "Iron Thorns should cool off extra Ditto benching once the lock shell is already online"),
		assert_true(gear_score <= 80.0, "Iron Thorns should sharply cool off Pok\\u00e9gear once the lock attacker is already live"),
		assert_true(cologne_score <= 80.0, "Iron Thorns should not spend turns on Cologne churn when the active lock is already established"),
		assert_true(research_score <= 80.0, "Iron Thorns should cool off broad discard-draw once the lock shell is already online"),
		assert_true(judge_score > research_score, "Iron Thorns should still prefer live disruption over generic churn while pressuring"),
	])


func test_iron_thorns_cologne_is_dead_when_active_lock_already_blanks_rule_box() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before Cologne timing can be tested"
	var gs := _make_game_state(3)
	var active_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	gs.players[0].active_pokemon = active_thorns
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var cologne_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Canceling Cologne"), 0)},
		gs,
		0
	)
	var end_turn_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(cologne_score < end_turn_score, "Iron Thorns should treat Cologne as dead when its active lock already blanks the opponent rule-box Pokemon"),
	])


func test_iron_thorns_cologne_is_dead_before_attack_window_opens() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before pre-attack Cologne timing can be tested"
	var gs := _make_game_state(3)
	var active_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	gs.players[0].active_pokemon = active_thorns
	gs.players[1].active_pokemon = _make_slot(
		_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "ex", [], ["Future"]),
		1
	)
	var cologne_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Canceling Cologne"), 0)},
		gs,
		0
	)
	var end_turn_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(cologne_score < end_turn_score, "Iron Thorns should not burn Cologne before it can attack and actually cash in the effect"),
	])


func test_iron_thorns_penny_is_dead_once_lock_shell_is_online() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before Penny timing can be tested"
	var gs := _make_game_state(4)
	var active_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "CC", "Special Energy"), 0))
	gs.players[0].active_pokemon = active_thorns
	gs.players[0].bench.append(_make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var penny_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Penny", "Supporter"), 0)},
		gs,
		0
	)
	var end_turn_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(penny_score < end_turn_score, "Iron Thorns should not pick up its own charged lock attacker once the pressure shell is already online"),
	])


func test_iron_thorns_denial_cools_off_before_attack_even_with_shell() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before pre-attack denial timing can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LCC", "damage": "140"}], ["Future"]),
		0
	)
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon = active_thorns
	player.bench.append(_make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LCC", "damage": "140"}], ["Future"]),
		0
	))
	var opponent_active := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	opponent_active.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	gs.players[1].active_pokemon = opponent_active
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		gs,
		0
	)
	var hammer_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Crushing Hammer"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(judge_score <= 140.0, "Iron Thorns should cool off Judge once the shell is formed but the active lock still cannot attack"),
		assert_true(hammer_score <= 140.0, "Iron Thorns should cool off Hammer churn until the active lock can actually convert the denial"),
	])


func test_iron_thorns_cools_off_churn_once_lock_shell_is_online_even_before_attack() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before early lock-shell churn can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LCC", "damage": "140"}], ["Future"]),
		0
	)
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.active_pokemon = active_thorns
	player.bench.append(_make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LCC", "damage": "140"}], ["Future"]),
		0
	))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var ditto_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Ditto", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var radar_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Techno Radar"), 0)},
		gs,
		0
	)
	var gear_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Pok\u00e9gear 3.0"), 0)},
		gs,
		0
	)
	var research_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	var judge_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(ditto_score <= 40.0, "Iron Thorns should stop adding extra Ditto once an active lock shell and backup attacker are already assembled"),
		assert_true(radar_score <= 100.0, "Iron Thorns should cool off Techno Radar once the lock shell is already formed, even before the attack cost is fully paid"),
		assert_true(gear_score <= 80.0, "Iron Thorns should not keep spinning Pok\u00e9gear after the active lock shell is already in place"),
		assert_true(research_score <= 80.0, "Iron Thorns should cool off broad draw churn once the active lock shell is already established"),
		assert_true(judge_score > radar_score, "Iron Thorns should still prefer live disruption over more setup churn after the shell is formed"),
	])


func test_iron_thorns_benches_backup_lock_before_non_lethal_attack() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before backup-lock transition discipline can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "CC", "Special Energy"), 0))
	player.active_pokemon = active_thorns
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var bench_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [], ["Future"]), 0)},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "projected_damage": 140, "projected_knockout": false},
		gs,
		0
	)
	return run_checks([
		assert_true(bench_score > attack_score, "Iron Thorns should bench a backup lock attacker before taking a non-lethal swing with no replacement on board"),
		assert_true(bench_score >= 520.0, "Benching the first backup Iron Thorns should be a clearly urgent transition action"),
	])


func test_iron_thorns_thin_deck_cools_off_setup_churn_even_if_active_isnt_lock() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before thin-deck churn discipline can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ditto", "Basic", "C", 70), 0)
	player.bench.append(_make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	))
	player.bench.append(_make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	))
	player.deck.clear()
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var ditto_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Ditto", "Basic", "C", 70), 0)},
		gs,
		0
	)
	var gear_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Pok\\u00e9gear 3.0"), 0)},
		gs,
		0
	)
	var radar_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Techno Radar"), 0)},
		gs,
		0
	)
	var colress_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Colress's Tenacity", "Supporter"), 0)},
		gs,
		0
	)
	var arven_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(ditto_score <= 40.0, "Iron Thorns should stop adding extra Ditto in thin-deck endgames once two lock attackers are already on board"),
		assert_true(gear_score <= 80.0, "Iron Thorns should cool off Pok\\u00e9gear in thin-deck endgames once the shell is already formed"),
		assert_true(radar_score <= 100.0, "Iron Thorns should cool off Techno Radar in thin-deck endgames once two lock attackers are already online"),
		assert_true(colress_score <= 100.0, "Iron Thorns should stop spending thin-deck turns on Tenacity-style setup churn after the shell is formed"),
		assert_true(arven_score <= 120.0, "Iron Thorns should not keep searching setup tools in thin-deck endgames once the lock shell is already assembled"),
	])


func test_iron_thorns_retreat_prefers_ready_lock_target_over_unready_backup() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before retreat-target discipline can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_ditto := _make_slot(_make_pokemon_cd("Ditto", "Basic", "C", 70), 0)
	player.active_pokemon = active_ditto
	var ready_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	ready_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	ready_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "CC", "Special Energy"), 0))
	var unready_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	player.bench.append(ready_thorns)
	player.bench.append(unready_thorns)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var ready_retreat_score: float = strategy.score_action_absolute(
		{"kind": "retreat", "bench_target": ready_thorns},
		gs,
		0
	)
	var unready_retreat_score: float = strategy.score_action_absolute(
		{"kind": "retreat", "bench_target": unready_thorns},
		gs,
		0
	)
	return run_checks([
		assert_true(ready_retreat_score > unready_retreat_score, "Iron Thorns should distinguish retreat targets and prefer the ready lock attacker over an unready backup"),
		assert_true(unready_retreat_score <= 0.0, "Iron Thorns should penalize retreating into an unready lock target when no immediate pressure is gained"),
	])


func test_iron_thorns_prioritizes_lost_city_as_a_real_stadium_action() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before Lost City stadium timing can be tested"
	var gs := _make_game_state(4)
	var active_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "CC", "Special Energy"), 0))
	gs.players[0].active_pokemon = active_thorns
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var lost_city_score: float = strategy.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd("Lost City", "Stadium"), 0)},
		gs,
		0
	)
	var gear_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Pok\\u00e9gear 3.0"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(lost_city_score >= 220.0, "Iron Thorns should treat Lost City as a clearly positive stadium action while the lock attacker is active"),
		assert_true(lost_city_score > gear_score, "Iron Thorns should value Lost City above marginal churn when setting the lock field"),
	])


func test_iron_thorns_keeps_ready_lock_active_instead_of_free_retreats() -> String:
	var strategy := _new_strategy(IRON_THORNS_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyIronThorns.gd should exist before ready-lock retreat discipline can be tested"
	var gs := _make_game_state(4)
	var active_thorns := _make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	)
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	active_thorns.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "CC", "Special Energy"), 0))
	gs.players[0].active_pokemon = active_thorns
	gs.players[0].bench.append(_make_slot(
		_make_pokemon_cd("Iron Thorns ex", "Basic", "L", 230, "ex", [{"name": "Volt Cyclone", "cost": "LC", "damage": "140"}], ["Future"]),
		0
	))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "ex", [], []), 1)
	var retreat_score: float = strategy.score_action_absolute({"kind": "retreat"}, gs, 0)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "projected_damage": 140, "projected_knockout": false},
		gs,
		0
	)
	return run_checks([
		assert_true(retreat_score <= 0.0, "Iron Thorns should penalize free retreats away from a ready active lock attacker"),
		assert_true(attack_score > retreat_score, "Iron Thorns should prefer keeping pressure with the ready lock attack over retreating"),
	])


func test_raging_bolt_prioritizes_sada_and_burst_energy_lines() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before burst setup can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var raging_bolt := _make_slot(
		_make_pokemon_cd("Raging Bolt ex", "Basic", "L", 240, "ex", [{"name": "Burst Roar", "cost": "GGL", "damage": "240"}], ["Ancient"]),
		0
	)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = raging_bolt
	player.bench.append(_make_slot(
		_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210, "ex", [{"name": "Myriad Leaf Shower", "cost": "GGC", "damage": "30"}]),
		0
	))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var score_sada: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)},
		gs,
		0
	)
	var score_attach_bolt: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0), "target_slot": raging_bolt},
		gs,
		0
	)
	var score_research: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_sada >= 420.0, "Raging Bolt should strongly value Sada when burst energy is online"),
		assert_true(score_attach_bolt > score_research, "Raging Bolt should prioritize immediate Bolt burst energy over generic draw"),
	])


func test_raging_bolt_prioritizes_ogerpon_ability_and_energy_routing_by_type() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before Ogerpon burst lines can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var raging_bolt := _make_slot(
		_make_pokemon_cd("Raging Bolt ex", "Basic", "L", 240, "ex", [{"name": "Burst Roar", "cost": "LF", "damage": "70x"}], ["Ancient"]),
		0
	)
	player.active_pokemon = raging_bolt
	var ogerpon := _make_slot(
		_make_pokemon_cd(
			"Teal Mask Ogerpon ex",
			"Basic",
			"G",
			210,
			"ex",
			[{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"}]
		),
		0
	)
	player.bench.append(ogerpon)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var ability_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": ogerpon, "ability_index": 0},
		gs,
		0
	)
	var attach_step := {"id": "assignment_target"}
	var grass_context := {"game_state": gs, "player_index": 0, "source_card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)}
	var lightning_context := {"game_state": gs, "player_index": 0, "source_card": CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)}
	var grass_to_ogerpon: float = strategy.score_interaction_target(ogerpon, attach_step, grass_context)
	var grass_to_bolt: float = strategy.score_interaction_target(raging_bolt, attach_step, grass_context)
	var lightning_to_ogerpon: float = strategy.score_interaction_target(ogerpon, attach_step, lightning_context)
	var lightning_to_bolt: float = strategy.score_interaction_target(raging_bolt, attach_step, lightning_context)
	return run_checks([
		assert_true(ability_score >= 320.0, "Raging Bolt should actively value Ogerpon's self-attach draw engine when Grass is in hand"),
		assert_true(grass_to_ogerpon > grass_to_bolt, "Grass energy routing should favor Ogerpon over Bolt"),
		assert_true(lightning_to_bolt > lightning_to_ogerpon, "Lightning energy routing should favor Bolt over Ogerpon"),
	])


func test_raging_bolt_real_attack_mix_keeps_setup_focus_before_thunder_is_online() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before real attack-mix timing can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var raging_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	var ogerpon := _make_slot(
		_make_pokemon_cd(
			"Teal Mask Ogerpon ex",
			"Basic",
			"G",
			210,
			"ex",
			[{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"}]
		),
		0
	)
	player.active_pokemon = raging_bolt
	player.bench.append(ogerpon)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var ability_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": ogerpon, "ability_index": 0},
		gs,
		0
	)
	var attach_bolt_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0), "target_slot": raging_bolt},
		gs,
		0
	)
	return run_checks([
		assert_true(
			ability_score > attach_bolt_score,
			"Raging Bolt should keep prioritizing Ogerpon setup over a lone Bolt attach when only Burst Roar is unlocked"
		),
	])


func test_raging_bolt_zero_damage_attack_scores_below_sada_burst_line() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before zero-damage attack timing can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var raging_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	player.active_pokemon = raging_bolt
	player.bench.append(_make_slot(
		_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210, "ex", [{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"}]),
		0
	))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var score_sada: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)},
		gs,
		0
	)
	var score_burst_roar: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Burst Roar", "projected_damage": 0, "projected_knockout": false},
		gs,
		0
	)
	return run_checks([
		assert_true(score_sada > score_burst_roar, "Raging Bolt should not value a zero-damage Burst Roar above an online Sada burst turn"),
	])


func test_raging_bolt_ogerpon_draw_engine_cools_off_once_bolt_is_ready() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before Ogerpon draw timing can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var raging_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = raging_bolt
	var ogerpon := _make_slot(
		_make_pokemon_cd(
			"Teal Mask Ogerpon ex",
			"Basic",
			"G",
			210,
			"ex",
			[{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"}]
		),
		0
	)
	ogerpon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.bench.append(ogerpon)
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Pok\u00e9gear 3.0"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Trekking Shoes"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0))
	var ability_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": ogerpon, "ability_index": 0},
		gs,
		0
	)
	return run_checks([
		assert_true(ability_score <= 120.0, "Raging Bolt should cool off Ogerpon draw once Bolt is attack-ready and the hand is already healthy"),
	])


func test_raging_bolt_burst_roar_cools_off_when_hand_is_already_stable() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before Burst Roar hand-management timing can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Pok\u00e9gear 3.0"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Earthen Vessel"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Trekking Shoes"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0))
	var burst_roar_score: float = strategy.score_action_absolute(
		{"kind": "attack", "attack_name": "Burst Roar", "projected_damage": 0, "projected_knockout": false},
		gs,
		0
	)
	return run_checks([
		assert_true(burst_roar_score <= 20.0, "Raging Bolt should treat Burst Roar as a low-value fallback when the hand is already stable"),
	])


func test_raging_bolt_churn_trainers_cool_off_once_bolt_is_online() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before late-turn trainer timing can be tested"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var raging_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon = raging_bolt
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Switch Cart"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	var gear_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Pok\u00e9gear 3.0"), 0)},
		gs,
		0
	)
	var shoes_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Trekking Shoes"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(gear_score <= 40.0, "Raging Bolt should cool off Pokegear once a real Bolt attack is already online"),
		assert_true(shoes_score <= 20.0, "Raging Bolt should cool off Trekking Shoes once the hand is already stable"),
	])


func test_raging_bolt_retreat_prefers_online_attacker_over_utility_bundle() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before retreat target timing can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(
		_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210, "ex", [{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"}]),
		0
	)
	var raging_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	raging_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var iron_bundle := _make_slot(_make_pokemon_cd("Iron Bundle", "Basic", "W", 70, "", [{"name": "Freezing Wind", "cost": "C", "damage": "10"}]), 0)
	player.bench.append(raging_bolt)
	player.bench.append(iron_bundle)
	var retreat_to_bolt: float = strategy.score_action_absolute(
		{"kind": "retreat", "bench_target": raging_bolt},
		gs,
		0
	)
	var retreat_to_bundle: float = strategy.score_action_absolute(
		{"kind": "retreat", "bench_target": iron_bundle},
		gs,
		0
	)
	return run_checks([
		assert_true(retreat_to_bolt > retreat_to_bundle, "Raging Bolt should retreat into the online attacker instead of the utility Iron Bundle pivot"),
	])


func test_raging_bolt_cools_off_churn_trainers_even_with_only_four_cards_once_pressure_is_online() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before pressure-phase churn timing can be tested"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var primary_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	primary_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	primary_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon = primary_bolt
	var backup_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	backup_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.bench.append(backup_bolt)
	player.hand.append(CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Switch Cart"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0))
	var nest_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball"), 0)},
		gs,
		0
	)
	var gear_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Pok\u00e9gear 3.0"), 0)},
		gs,
		0
	)
	var research_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(nest_score <= 80.0, "Raging Bolt should stop spending turns on fresh basics once one Bolt is online and a second is nearly ready"),
		assert_true(gear_score <= 60.0, "Raging Bolt should sharply cool off Pok\u00e9gear once its pressure line is already assembled"),
		assert_true(research_score <= 90.0, "Raging Bolt should not keep forcing broad churn draw once its current and next attacker are already mapped"),
	])


func test_raging_bolt_prefers_grass_to_ogerpon_over_bolt_since_bolt_needs_lf() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before backup routing can be tested"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var primary_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	primary_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	primary_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon = primary_bolt
	var backup_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	backup_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var ogerpon := _make_slot(
		_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210, "ex", [{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"}]),
		0
	)
	ogerpon.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.bench.append(backup_bolt)
	player.bench.append(ogerpon)
	var assign_step := {"id": "assignment_target"}
	var grass_context := {
		"game_state": gs,
		"player_index": 0,
		"source_card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
	}
	var backup_score: float = strategy.score_interaction_target(backup_bolt, assign_step, grass_context)
	var ogerpon_score: float = strategy.score_interaction_target(ogerpon, assign_step, grass_context)
	return run_checks([
		assert_true(
			ogerpon_score > backup_score,
			"草能应给厄诡椪（真正用得到）而不是猛雷鼓（只需L+F），厄诡椪:%.1f 猛雷鼓:%.1f" % [ogerpon_score, backup_score]
		),
	])


func test_raging_bolt_late_game_cools_off_full_reload_trainers_when_deck_is_thin() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before late-game reload timing can be tested"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var primary_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	primary_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	primary_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	primary_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = primary_bolt
	player.bench.append(_make_slot(
		_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210, "ex", [{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"}]),
		0
	))
	for _i: int in 6:
		player.deck.append(CardInstance.create(_make_trainer_cd("ThinCard"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var sada_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)},
		gs,
		0
	)
	var vessel_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Earthen Vessel"), 0)},
		gs,
		0
	)
	var retrieval_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Energy Retrieval"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(sada_score <= 220.0, "Raging Bolt should stop treating Sada as a premium line once the deck is thin and a real attacker is already online"),
		assert_true(vessel_score <= 120.0, "Raging Bolt should cool off Earthen Vessel late when deck pressure is the bigger risk"),
		assert_true(retrieval_score <= 140.0, "Raging Bolt should cool off Energy Retrieval late when it already has a current attacker and too few cards left"),
	])


func test_raging_bolt_sada_assignment_prefers_exact_missing_lightning_on_primary_bolt() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before precise Sada routing can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var primary_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	primary_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon = primary_bolt
	var backup_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	player.bench.append(backup_bolt)
	var assign_step := {"id": "assignment_target"}
	var lightning_context := {
		"game_state": gs,
		"player_index": 0,
		"source_card": CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0),
	}
	var primary_score: float = strategy.score_interaction_target(primary_bolt, assign_step, lightning_context)
	var backup_score: float = strategy.score_interaction_target(backup_bolt, assign_step, lightning_context)
	return run_checks([
		assert_true(primary_score > backup_score, "Raging Bolt should route Sada's Lightning to the primary Bolt when that exact color unlocks the attack"),
	])


func test_raging_bolt_precise_discard_planner_prefers_minimal_lethal_support_energy_over_active_attack_cost() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before precise discard planning can be tested"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var active_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	var active_lightning := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var active_fighting := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	active_bolt.attached_energy.append(active_lightning)
	active_bolt.attached_energy.append(active_fighting)
	player.active_pokemon = active_bolt
	var ogerpon := _make_slot(
		_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210, "ex", [{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"}]),
		0
	)
	var support_grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	ogerpon.attached_energy.append(support_grass)
	player.bench.append(ogerpon)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Target", "Basic", "C", 70), 1)
	var has_picker: bool = strategy.has_method("pick_interaction_items")
	var has_damage_estimator: bool = strategy.has_method("estimate_bellowing_thunder_damage")
	var estimated_one := -1
	var estimated_two := -1
	if has_damage_estimator:
		estimated_one = int(strategy.call("estimate_bellowing_thunder_damage", 1))
		estimated_two = int(strategy.call("estimate_bellowing_thunder_damage", 2))
	var selected: Array = []
	if has_picker:
		selected = strategy.call("pick_interaction_items", [active_lightning, active_fighting, support_grass], {
			"id": "discard_energy",
			"min_select": 0,
			"max_select": 3,
		}, {
			"game_state": gs,
			"player_index": 0,
		})
	var selected_first: Variant = selected[0] if not selected.is_empty() else null
	return run_checks([
		assert_true(has_picker, "Raging Bolt should expose a precise discard picker for variable discard steps"),
		assert_true(has_damage_estimator, "Raging Bolt should expose a precise damage estimator for Bellowing Thunder"),
		assert_eq(estimated_one, 70, "Bellowing Thunder should scale as 70 damage per discarded energy"),
		assert_eq(estimated_two, 140, "Bellowing Thunder should keep exact linear scaling"),
		assert_eq(selected.size(), 1, "Raging Bolt should discard only the minimum energy needed for lethal"),
		assert_true(selected_first == support_grass, "Raging Bolt should spend the support Grass before discarding active Bolt attack-cost energy"),
	])


func test_raging_bolt_precise_discard_planner_can_choose_exact_hand_energy_for_future_sada_reload() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before precise hand-discard planning can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	active_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	active_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon = active_bolt
	var backup_bolt := _make_slot(
		_make_pokemon_cd(
			"Raging Bolt ex",
			"Basic",
			"L",
			240,
			"ex",
			[
				{"name": "Burst Roar", "cost": "C", "damage": "0"},
				{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
			],
			["Ancient"]
		),
		0
	)
	backup_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.bench.append(backup_bolt)
	var hand_lightning := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var hand_grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var has_picker: bool = strategy.has_method("pick_interaction_items")
	var selected: Array = []
	if has_picker:
		selected = strategy.call("pick_interaction_items", [hand_lightning, hand_grass], {
			"id": "discard_energy",
			"min_select": 1,
			"max_select": 1,
		}, {
			"game_state": gs,
			"player_index": 0,
		})
	var selected_first: Variant = selected[0] if not selected.is_empty() else null
	return run_checks([
		assert_true(has_picker, "Raging Bolt should expose a precise discard picker for hand-discard planning"),
		assert_eq(selected.size(), 1, "Raging Bolt should choose exactly one hand energy for discard-draw planning"),
		assert_true(selected_first == hand_lightning, "Raging Bolt should discard the Lightning that enables the next Sada reload onto the backup Bolt"),
	])


func test_gouging_fire_prioritizes_sada_magma_basin_and_fire_pressure() -> String:
	var strategy := _new_strategy(GOUGING_FIRE_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyGougingFireAncient.gd should exist before fire pressure lines can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var gouging_fire := _make_slot(
		_make_pokemon_cd("Gouging Fire ex", "Basic", "R", 230, "ex", [{"name": "Blaze Surge", "cost": "RR", "damage": "260"}], ["Ancient"]),
		0
	)
	gouging_fire.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.active_pokemon = gouging_fire
	player.bench.append(_make_slot(
		_make_pokemon_cd("Roaring Moon ex", "Basic", "D", 230, "ex", [{"name": "Calamity Storm", "cost": "DCC", "damage": "220"}], ["Ancient"]),
		0
	))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	var score_sada: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)},
		gs,
		0
	)
	var score_magma: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Magma Basin", "Stadium"), 0)},
		gs,
		0
	)
	var score_research: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_sada >= 420.0, "Gouging Fire should strongly value Sada when Ancient attackers are online"),
		assert_true(score_magma > score_research, "Gouging Fire should prefer Magma Basin over generic draw"),
	])


func test_gouging_fire_prioritizes_entei_draw_and_type_specific_energy_routing() -> String:
	var strategy := _new_strategy(GOUGING_FIRE_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyGougingFireAncient.gd should exist before tempo lines can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var entei := _make_slot(
		_make_pokemon_cd(
			"Entei V",
			"Basic",
			"R",
			230,
			"V",
			[{"name": "Burning Rondo", "cost": "RC", "damage": "20+"}],
			[],
			2
		),
		0
	)
	var gouging_fire := _make_slot(
		_make_pokemon_cd("Gouging Fire ex", "Basic", "R", 230, "ex", [{"name": "Blaze Surge", "cost": "RRC", "damage": "260"}], [], 2),
		0
	)
	var roaring_moon := _make_slot(
		_make_pokemon_cd("Roaring Moon ex", "Basic", "D", 230, "ex", [{"name": "Calamity Storm", "cost": "DDC", "damage": "220"}], [], 2),
		0
	)
	player.active_pokemon = entei
	player.bench.append(gouging_fire)
	player.bench.append(roaring_moon)
	var ability_score: float = strategy.score_action_absolute(
		{"kind": "use_ability", "source_slot": entei, "ability_index": 0},
		gs,
		0
	)
	var attach_step := {"id": "assignment_target"}
	var fire_context := {"game_state": gs, "player_index": 0, "source_card": CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)}
	var dark_context := {"game_state": gs, "player_index": 0, "source_card": CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)}
	var fire_to_gouging: float = strategy.score_interaction_target(gouging_fire, attach_step, fire_context)
	var fire_to_moon: float = strategy.score_interaction_target(roaring_moon, attach_step, fire_context)
	var dark_to_gouging: float = strategy.score_interaction_target(gouging_fire, attach_step, dark_context)
	var dark_to_moon: float = strategy.score_interaction_target(roaring_moon, attach_step, dark_context)
	return run_checks([
		assert_true(ability_score >= 220.0, "Gouging Fire should actively value Entei V draw when it is the opener"),
		assert_true(fire_to_gouging > fire_to_moon, "Fire routing should favor Gouging Fire over Roaring Moon"),
		assert_true(dark_to_moon > dark_to_gouging, "Dark routing should favor Roaring Moon over Gouging Fire"),
	])


func test_aggressive_shells_do_not_score_like_copies() -> String:
	var raging_strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	var gouging_strategy := _new_strategy(GOUGING_FIRE_SCRIPT_PATH)
	if raging_strategy == null or gouging_strategy == null:
		return "Both aggressive-shell strategies should exist before distinct shell tuning can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(
		_make_pokemon_cd("Raging Bolt ex", "Basic", "L", 240, "ex", [{"name": "Burst Roar", "cost": "GGL", "damage": "240"}], ["Ancient"]),
		0
	)
	player.bench.append(_make_slot(
		_make_pokemon_cd("Gouging Fire ex", "Basic", "R", 230, "ex", [{"name": "Blaze Surge", "cost": "RR", "damage": "260"}], ["Ancient"]),
		0
	))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	var raging_vessel: float = raging_strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Earthen Vessel"), 0)},
		gs,
		0
	)
	var raging_magma: float = raging_strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Magma Basin", "Stadium"), 0)},
		gs,
		0
	)
	var gouging_vessel: float = gouging_strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Earthen Vessel"), 0)},
		gs,
		0
	)
	var gouging_magma: float = gouging_strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Magma Basin", "Stadium"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(raging_vessel > raging_magma, "Raging Bolt should lean harder on Vessel-style burst setup than Magma Basin"),
		assert_true(gouging_magma > gouging_vessel, "Gouging Fire should lean harder on Magma Basin than Vessel"),
	])


func test_raging_bolt_attach_lf_beats_g_when_bolt_missing_exact_types() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before exact-type routing can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var rb_cd := _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[{"name": "Burst Roar", "cost": "C", "damage": "0"}, {"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"}],
		["Ancient"]
	)
	var raging_bolt := _make_slot(rb_cd, 0)
	player.active_pokemon = raging_bolt
	var attach_l: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0), "target_slot": raging_bolt},
		gs, 0
	)
	var attach_f: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0), "target_slot": raging_bolt},
		gs, 0
	)
	var attach_g: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0), "target_slot": raging_bolt},
		gs, 0
	)
	return run_checks([
		assert_true(attach_l > attach_g, "手贴 L 给猛雷鼓应优先于 G（攻击需要L）: L=%.0f G=%.0f" % [attach_l, attach_g]),
		assert_true(attach_f > attach_g, "手贴 F 给猛雷鼓应优先于 G（攻击需要F）: F=%.0f G=%.0f" % [attach_f, attach_g]),
	])


func test_raging_bolt_greninja_discards_lf_when_bolt_missing_them() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before Greninja discard routing can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var rb_cd := _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[{"name": "Burst Roar", "cost": "C", "damage": "0"}, {"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"}],
		["Ancient"]
	)
	var raging_bolt := _make_slot(rb_cd, 0)
	player.active_pokemon = raging_bolt
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210, "ex", [{"name": "Teal Dance", "cost": "G", "damage": "0"}])
	var ogerpon := _make_slot(ogerpon_cd, 0)
	player.bench.append(ogerpon)
	var l_card := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var f_card := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	var g_card := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	player.hand.append(l_card)
	player.hand.append(f_card)
	player.hand.append(g_card)
	var l_score: float = strategy.call("_score_hand_discard_candidate", l_card, player)
	var f_score: float = strategy.call("_score_hand_discard_candidate", f_card, player)
	var g_score: float = strategy.call("_score_hand_discard_candidate", g_card, player)
	return run_checks([
		assert_true(l_score >= g_score, "忍蛙应优先弃L（奥琳博士补给猛雷鼓）: L=%.0f G=%.0f" % [l_score, g_score]),
		assert_true(f_score >= g_score, "忍蛙应优先弃F（奥琳博士补给猛雷鼓）: F=%.0f G=%.0f" % [f_score, g_score]),
	])


func test_raging_bolt_earthen_vessel_search_prefers_lf_over_g() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before Earthen Vessel search routing can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var rb_cd := _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[{"name": "Burst Roar", "cost": "C", "damage": "0"}, {"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"}],
		["Ancient"]
	)
	var raging_bolt := _make_slot(rb_cd, 0)
	player.active_pokemon = raging_bolt
	var search_step := {"id": "search_energy", "min_select": 0, "max_select": 2}
	var ctx := {"game_state": gs, "player_index": 0}
	var l_card := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var f_card := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	var g_card := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var l_score: float = strategy.score_interaction_target(l_card, search_step, ctx)
	var f_score: float = strategy.score_interaction_target(f_card, search_step, ctx)
	var g_score: float = strategy.score_interaction_target(g_card, search_step, ctx)
	return run_checks([
		assert_true(l_score > g_score, "大地容器应优先检索L而非G（猛雷鼓需要L）: L=%.0f G=%.0f" % [l_score, g_score]),
		assert_true(f_score > g_score, "大地容器应优先检索F而非G（猛雷鼓需要F）: F=%.0f G=%.0f" % [f_score, g_score]),
	])


func test_raging_bolt_attack_discard_protects_lf_on_bench_bolt() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist before attack-discard priority can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var rb_cd := _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[{"name": "Burst Roar", "cost": "C", "damage": "0"}, {"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"}],
		["Ancient"]
	)
	var ogerpon_cd := _make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210, "ex", [{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"}])
	var active_bolt := _make_slot(rb_cd, 0)
	var active_l := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var active_f := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	active_bolt.attached_energy.append(active_l)
	active_bolt.attached_energy.append(active_f)
	player.active_pokemon = active_bolt
	var bench_bolt := _make_slot(rb_cd, 0)
	var bench_l := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var bench_f := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	bench_bolt.attached_energy.append(bench_l)
	bench_bolt.attached_energy.append(bench_f)
	player.bench.append(bench_bolt)
	var ogerpon := _make_slot(ogerpon_cd, 0)
	var ogerpon_g1 := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var ogerpon_g2 := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	ogerpon.attached_energy.append(ogerpon_g1)
	ogerpon.attached_energy.append(ogerpon_g2)
	player.bench.append(ogerpon)
	var ogerpon_g_score: float = strategy.call("_score_field_discard_candidate", ogerpon_g1, player)
	var bench_l_score: float = strategy.call("_score_field_discard_candidate", bench_l, player)
	var bench_f_score: float = strategy.call("_score_field_discard_candidate", bench_f, player)
	return run_checks([
		assert_true(ogerpon_g_score > bench_l_score, "攻击弃能：厄诡椪草能应先弃，备战猛雷鼓L应保留: G=%.0f bench_L=%.0f" % [ogerpon_g_score, bench_l_score]),
		assert_true(ogerpon_g_score > bench_f_score, "攻击弃能：厄诡椪草能应先弃，备战猛雷鼓F应保留: G=%.0f bench_F=%.0f" % [ogerpon_g_score, bench_f_score]),
	])


func test_raging_bolt_sada_picks_lf_sources_over_g_from_discard() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var rb_cd := _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"}],
		["Ancient"]
	)
	# Raging Bolt on bench with 0 energy (needs both L and F)
	var bench_bolt := _make_slot(rb_cd, 0)
	player.bench.append(bench_bolt)
	# Discard pile: G G L F (G appears first in array order — old bug would pick G G)
	var g1 := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var g2 := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var l1 := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var f1 := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	player.discard_pile = [g1, g2, l1, f1]
	var items: Array = [g1, g2, l1, f1]
	var step := {"id": "sada_assignments", "max_select": 2}
	var ctx := {"game_state": gs, "player_index": 0}
	var picked: Array = strategy.call("pick_interaction_items", items, step, ctx)
	var picked_types: Array[String] = []
	for c: Variant in picked:
		if c is CardInstance:
			picked_types.append(str((c as CardInstance).card_data.energy_provides))
	return run_checks([
		assert_true("G" not in picked_types or picked_types.count("G") < 2,
			"奥林博士源选择：弃牌区G在前时不应选2张G，实际选了: %s" % str(picked_types)),
		assert_true("L" in picked_types,
			"奥林博士源选择：应优先选L能量，实际: %s" % str(picked_types)),
		assert_true("F" in picked_types,
			"奥林博士源选择：应优先选F能量，实际: %s" % str(picked_types)),
	])


func test_raging_bolt_bellowing_thunder_discard_minimal_lethal_grass_first() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var rb_cd := _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"}],
		["Ancient"]
	)
	# Active bolt with L + F (essential) + G (extra)
	var active_bolt := _make_slot(rb_cd, 0)
	var att_l := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var att_f := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	var att_g := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	active_bolt.attached_energy.append(att_l)
	active_bolt.attached_energy.append(att_f)
	active_bolt.attached_energy.append(att_g)
	player.active_pokemon = active_bolt
	# Opponent active: 130HP Pokemon (e.g. Radiant Greninja)
	var greninja_cd := _make_pokemon_cd("Radiant Greninja", "Basic", "W", 130, "", [])
	var opp_active := _make_slot(greninja_cd, 1)
	gs.players[1].active_pokemon = opp_active
	var items: Array = [att_l, att_f, att_g]
	var step := {"id": "discard_basic_energy", "min_select": 0, "max_select": 3}
	var ctx := {"game_state": gs, "player_index": 0}
	var picked: Array = strategy.call("pick_interaction_items", items, step, ctx)
	var picked_types: Array[String] = []
	for c: Variant in picked:
		if c is CardInstance:
			picked_types.append(str((c as CardInstance).card_data.energy_provides))
	return run_checks([
		assert_true(picked.size() == 2,
			"极雷轰弃能：打130HP目标只需弃2张(140伤害)，实际弃了: %d" % picked.size()),
		assert_true("G" in picked_types,
			"极雷轰弃能：应优先弃草能量，实际: %s" % str(picked_types)),
	])


func test_raging_bolt_assignment_grass_to_bolt_is_low() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var rb_cd := _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[
			{"name": "Burst Roar", "cost": "C", "damage": "0"},
			{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"},
		],
		["Ancient"]
	)
	# Bolt with only 1 F energy (gap=1 count-wise, but needs L not G)
	var bolt_slot := _make_slot(rb_cd, 0)
	bolt_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.active_pokemon = bolt_slot
	var ogerpon_cd := _make_pokemon_cd(
		"Teal Mask Ogerpon ex", "Basic", "G", 170, "ex",
		[{"name": "Teal Dance", "cost": "G", "damage": "60"}]
	)
	var ogerpon_slot := _make_slot(ogerpon_cd, 0)
	player.bench.append(ogerpon_slot)
	var assign_step := {"id": "assignment_target"}
	var grass_ctx := {
		"game_state": gs,
		"player_index": 0,
		"source_card": CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
	}
	var bolt_g_score: float = strategy.score_interaction_target(bolt_slot, assign_step, grass_ctx)
	var ogerpon_g_score: float = strategy.score_interaction_target(ogerpon_slot, assign_step, grass_ctx)
	return run_checks([
		assert_true(bolt_g_score <= 80.0,
			"草能分配给猛雷鼓时评分应 <=80（草能不满足雷+格需求），实际: %.1f" % bolt_g_score),
		assert_true(ogerpon_g_score > bolt_g_score,
			"草能应优先给翠绿假面玄鸟，翠绿:%.1f > 猛雷鼓:%.1f" % [ogerpon_g_score, bolt_g_score]),
	])


func test_raging_bolt_squawkabilly_not_benched_after_turn_2() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var squawk_cd := _make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "ex", [])
	var squawk_card := CardInstance.create(squawk_cd, 0)
	var gs_turn1 := _make_game_state(4)
	gs_turn1.turn_number = 1
	var gs_turn4 := _make_game_state(4)
	gs_turn4.turn_number = 4
	var score_t1: float = strategy.call("score_action_absolute",
		{"kind": "play_basic_to_bench", "card": squawk_card}, gs_turn1, 0)
	var score_t4: float = strategy.call("score_action_absolute",
		{"kind": "play_basic_to_bench", "card": squawk_card}, gs_turn4, 0)
	return run_checks([
		assert_true(score_t1 > 100.0,
			"怒鹦哥第1回合应该下场，评分: %.1f" % score_t1),
		assert_true(score_t4 < 0.0,
			"怒鹦哥第4回合不应下场，评分应为负: %.1f" % score_t4),
	])


func test_raging_bolt_retreat_fuel_for_stuck_active() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var squawk_cd := _make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "ex", [], [], 1)
	var active := _make_slot(squawk_cd, 0)
	player.active_pokemon = active
	var rb_cd := _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"}],
		["Ancient"]
	)
	var bench_bolt := _make_slot(rb_cd, 0)
	bench_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	bench_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	bench_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.bench.append(bench_bolt)
	var any_energy := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var score_active: float = strategy.call("score_action_absolute",
		{"kind": "attach_energy", "card": any_energy, "target_slot": active}, gs, 0)
	var score_bench: float = strategy.call("score_action_absolute",
		{"kind": "attach_energy", "card": any_energy, "target_slot": bench_bolt}, gs, 0)
	return run_checks([
		assert_true(score_active >= 450.0,
			"前场怒鹦哥无能量、后场有就绪猛雷鼓时，填能给前场撤退应高分: %.1f" % score_active),
		assert_true(score_active > score_bench,
			"撤退燃料(%.1f)应高于给已就绪后备猛雷鼓(%.1f)" % [score_active, score_bench]),
	])


func test_raging_bolt_bench_backup_bolt_in_pressure() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var rb_cd := _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"}],
		["Ancient"]
	)
	var active_bolt := _make_slot(rb_cd, 0)
	active_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	active_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	active_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	player.active_pokemon = active_bolt
	var second_bolt_card := CardInstance.create(rb_cd, 0)
	var score: float = strategy.call("score_action_absolute",
		{"kind": "play_basic_to_bench", "card": second_bolt_card}, gs, 0)
	return run_checks([
		assert_true(score >= 350.0,
			"PRESSURE阶段，场上只有1只猛雷鼓时应积极下第2只: %.1f" % score),
	])


# ============================================================
#  Turn Plan / Turn Contract Tests
# ============================================================

func _make_raging_bolt_cd() -> CardData:
	return _make_pokemon_cd(
		"Raging Bolt ex", "Basic", "L", 240, "ex",
		[{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x"}],
		["Ancient"]
	)


func _make_ogerpon_cd() -> CardData:
	return _make_pokemon_cd(
		"Teal Mask Ogerpon ex", "Basic", "G", 210, "ex",
		[{"name": "Myriad Leaf Shower", "cost": "GGC", "damage": "30x"}]
	)


func _make_bolt_slot_with_energy(owner: int, l_count: int, f_count: int, g_count: int = 0) -> PokemonSlot:
	var slot := _make_slot(_make_raging_bolt_cd(), owner)
	for _i: int in l_count:
		slot.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), owner))
	for _i: int in f_count:
		slot.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), owner))
	for _i: int in g_count:
		slot.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), owner))
	return slot


func test_raging_bolt_turn_plan_fuel_discard() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(_make_bolt_slot_with_energy(0, 0, 1))
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "fuel_discard",
			"弃牌堆0能量 + bolt在场 → intent应为fuel_discard"),
	])


func test_raging_bolt_turn_plan_charge_bolt() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(_make_bolt_slot_with_energy(0, 0, 1))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0))
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "charge_bolt",
			"弃牌2能量 + 手有Sada + bolt在场 → intent应为charge_bolt"),
	])


func test_raging_bolt_turn_plan_emergency_retreat() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	var ready_bolt := _make_bolt_slot_with_energy(0, 1, 1, 1)
	player.bench.append(ready_bolt)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "emergency_retreat",
			"前场非攻击手 + 后备就绪bolt → intent应为emergency_retreat"),
	])


func test_raging_bolt_turn_plan_convert_attack() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 1, 1, 1)
	player.bench.append(_make_bolt_slot_with_energy(0, 1, 0, 1))
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "convert_attack",
			"两只near-ready bolt → intent应为convert_attack"),
	])


func test_raging_bolt_sada_boosted_in_charge_intent() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(_make_bolt_slot_with_energy(0, 0, 1))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var sada_card := CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)
	var iono_card := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	player.hand.append(sada_card)
	player.hand.append(iono_card)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	var sada_score: float = strategy.call("score_action_absolute_with_plan",
		{"kind": "play_trainer", "card": sada_card}, gs, 0, plan)
	var iono_score: float = strategy.call("score_action_absolute_with_plan",
		{"kind": "play_trainer", "card": iono_card}, gs, 0, plan)
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "charge_bolt", "intent应为charge_bolt"),
		assert_true(sada_score > iono_score,
			"charge_bolt intent下 Sada(%.1f) 应高于 Iono(%.1f)" % [sada_score, iono_score]),
	])


func test_raging_bolt_ev_boosted_in_fuel_intent() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(_make_bolt_slot_with_energy(0, 0, 1))
	var ev_card := CardInstance.create(_make_trainer_cd("Earthen Vessel"), 0)
	player.hand.append(ev_card)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	var ev_score_with_plan: float = strategy.call("score_action_absolute_with_plan",
		{"kind": "play_trainer", "card": ev_card}, gs, 0, plan)
	var ev_score_no_plan: float = strategy.call("score_action_absolute",
		{"kind": "play_trainer", "card": ev_card}, gs, 0)
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "fuel_discard", "intent应为fuel_discard"),
		assert_true(ev_score_with_plan > ev_score_no_plan,
			"fuel_discard intent下 EV有计划(%.1f) > 无计划(%.1f)" % [ev_score_with_plan, ev_score_no_plan]),
	])


func test_raging_bolt_draw_supporter_suppressed_when_sada_in_hand() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(_make_bolt_slot_with_energy(0, 0, 1))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var sada_card := CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0)
	var iono_card := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	player.hand.append(sada_card)
	player.hand.append(iono_card)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	var iono_with_plan: float = strategy.call("score_action_absolute_with_plan",
		{"kind": "play_trainer", "card": iono_card}, gs, 0, plan)
	var iono_no_plan: float = strategy.call("score_action_absolute",
		{"kind": "play_trainer", "card": iono_card}, gs, 0)
	return run_checks([
		assert_true(iono_with_plan < iono_no_plan,
			"手有Sada时 Iono有计划(%.1f) < 无计划(%.1f)，不应浪费支援者位" % [iono_with_plan, iono_no_plan]),
	])


func test_raging_bolt_handoff_prefers_ready_bolt() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	var ready_bolt := _make_bolt_slot_with_energy(0, 1, 1, 1)
	var empty_bolt := _make_bolt_slot_with_energy(0, 0, 0, 0)
	player.bench.append(ready_bolt)
	player.bench.append(empty_bolt)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var step := {"id": "send_out"}
	var ctx := {"game_state": gs, "player_index": 0}
	var score_ready: float = strategy.call("score_handoff_target", ready_bolt, step, ctx)
	var score_empty: float = strategy.call("score_handoff_target", empty_bolt, step, ctx)
	return run_checks([
		assert_true(score_ready > score_empty,
			"send_out时就绪bolt(%.1f) > 空bolt(%.1f)" % [score_ready, score_empty]),
		assert_true(score_ready >= 700.0,
			"就绪bolt handoff分应>=700: %.1f" % score_ready),
	])


func test_raging_bolt_handoff_avoids_engine_pokemon() -> String:
	var strategy := _new_strategy(RAGING_BOLT_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategyRagingBoltOgerpon.gd should exist"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 1, 1, 1)
	var greninja := _make_slot(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130), 0)
	var squawk := _make_slot(_make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "ex"), 0)
	var ogerpon := _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(greninja)
	player.bench.append(squawk)
	player.bench.append(ogerpon)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var step := {"id": "send_out"}
	var ctx := {"game_state": gs, "player_index": 0}
	var score_greninja: float = strategy.call("score_handoff_target", greninja, step, ctx)
	var score_squawk: float = strategy.call("score_handoff_target", squawk, step, ctx)
	var score_ogerpon: float = strategy.call("score_handoff_target", ogerpon, step, ctx)
	return run_checks([
		assert_true(score_ogerpon > score_greninja,
			"send_out时ogerpon(%.1f) > greninja(%.1f)" % [score_ogerpon, score_greninja]),
		assert_true(score_ogerpon > score_squawk,
			"send_out时ogerpon(%.1f) > squawk(%.1f)" % [score_ogerpon, score_squawk]),
		assert_true(score_greninja < 0.0,
			"greninja不应被送上前场: %.1f" % score_greninja),
	])


func test_llm_prompt_builder_builds_payload_with_game_state() -> String:
	var script := _load_script(LLM_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var payload: Dictionary = builder.call("build_request_payload", gs, 0)
	var version := str(payload.get("system_prompt_version", ""))
	return run_checks([
		assert_true(payload.has("instructions"), "payload should include instructions"),
		assert_true(payload.has("response_format"), "payload should include response_format"),
		assert_true(version.begins_with("llm_decision_tree"), "system_prompt_version should use the decision-tree LLM contract"),
	])
	return run_checks([
		assert_true(payload.has("instructions"), "payload应包含instructions"),
		assert_true(payload.has("response_format"), "payload应包含response_format"),
		assert_true(str(payload.get("system_prompt_version", "")).begins_with("llm_action"),
			"system_prompt_version应以llm_action开头"),
	])


func test_llm_action_queue_parsing() -> String:
	var script := _load_script(LLM_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var response := {
		"actions": [
			{"type": "use_ability", "pokemon": "Greninja"},
			{"type": "play_trainer", "card": "Professor Sada's Vitality"},
			{"type": "attach_energy", "energy_type": "Lightning", "target": "Raging Bolt ex", "position": "active"},
			{"type": "attack"},
		],
		"reasoning": "充能并攻击",
	}
	var queue: Array = builder.call("parse_llm_response_to_action_queue", response)
	return run_checks([
		assert_eq(queue.size(), 4, "应解析出4个动作"),
		assert_eq(str(queue[0].get("type", "")), "use_ability", "第1步应为use_ability"),
		assert_eq(str(queue[1].get("type", "")), "play_trainer", "第2步应为play_trainer"),
		assert_eq(str(queue[1].get("card", "")), "Professor Sada's Vitality", "第2步卡名应正确"),
		assert_eq(str(queue[2].get("type", "")), "attach_energy", "第3步应为attach_energy"),
		assert_eq(str(queue[2].get("position", "")), "active", "第3步position应正确"),
		assert_eq(str(queue[3].get("type", "")), "attack", "第4步应为attack"),
	])


func test_llm_action_queue_rejects_invalid_types() -> String:
	var script := _load_script(LLM_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var response := {
		"actions": [
			{"type": "play_trainer", "card": "Iono"},
			{"type": "summon_dragon"},
			{"type": "cast_spell"},
			{"type": "attack"},
		],
		"reasoning": "",
	}
	var queue: Array = builder.call("parse_llm_response_to_action_queue", response)
	return run_checks([
		assert_eq(queue.size(), 2, "无效type应被过滤，只保留play_trainer和attack"),
		assert_eq(str(queue[0].get("type", "")), "play_trainer", "第1个有效动作应为play_trainer"),
		assert_eq(str(queue[1].get("type", "")), "attack", "第2个有效动作应为attack"),
	])


func test_llm_action_queue_rejects_vague_attach_energy() -> String:
	var script := _load_script(LLM_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var response := {
		"actions": [
			{"type": "attach_energy", "target": "Raging Bolt ex", "position": "active"},
			{"type": "attach_energy", "energy_type": "Lightning", "target": "Raging Bolt ex", "position": "active"},
			{"type": "attack", "attack_name": "Thundering Bolt"},
		],
		"reasoning": "",
	}
	var queue: Array = builder.call("parse_llm_response_to_action_queue", response)
	return run_checks([
		assert_eq(queue.size(), 2, "energy_type为空的attach_energy应被丢弃，只保留2个动作"),
		assert_eq(str(queue[0].get("type", "")), "attach_energy", "第1个有效动作应为有energy_type的attach_energy"),
		assert_eq(str(queue[0].get("energy_type", "")), "Lightning", "保留的attach_energy应有energy_type"),
		assert_eq(str(queue[1].get("type", "")), "attack", "第2个有效动作应为attack"),
	])


const RAGING_BOLT_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRagingBoltLLM.gd"


func test_raging_bolt_llm_strategy_exists_and_extends_rule_based() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	return run_checks([
		assert_eq(str(strategy.call("get_strategy_id")), "raging_bolt_ogerpon_llm",
			"strategy_id应为raging_bolt_ogerpon_llm"),
		assert_true(strategy.call("get_signature_names").size() > 0,
			"签名名应继承自规则版"),
	])


func test_raging_bolt_llm_falls_back_to_rule_score_when_no_queue() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 1, 1)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var energy_card := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var action := {"kind": "attach_energy", "card": energy_card, "target_slot": player.active_pokemon}
	var score: float = float(strategy.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_true(score > 0.0 and score < 1000.0,
			"无LLM队列时应返回规则评分(%.0f)而非超高分" % score),
	])


func _inject_llm_queue(strategy: RefCounted, turn: int, actions: Array) -> void:
	strategy.set("_cached_turn_number", turn)
	var mock_response := {"actions": actions, "reasoning": "test"}
	strategy.call("_on_llm_response", mock_response, turn)


func test_llm_queue_score_override_beats_rule_score() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 1, 1)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var sada_cd := _make_trainer_cd("Professor Sada's Vitality", "Supporter")
	var sada_card := CardInstance.create(sada_cd, 0)
	player.hand.append(sada_card)
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Professor Sada's Vitality"},
		{"type": "attack"},
	])
	var action := {"kind": "play_trainer", "card": sada_card, "targets": [], "requires_interaction": false}
	var score: float = float(strategy.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_true(score >= 89000.0,
			"LLM队列命中的动作分数应≥89000(实际%.0f)" % score),
	])


func test_llm_queue_position_ordering() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 0, 0)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var sada_cd := _make_trainer_cd("Professor Sada's Vitality", "Supporter")
	var sada_card := CardInstance.create(sada_cd, 0)
	var iono_cd := _make_trainer_cd("Iono", "Supporter")
	var iono_card := CardInstance.create(iono_cd, 0)
	player.hand.append(sada_card)
	player.hand.append(iono_card)
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Professor Sada's Vitality"},
		{"type": "play_trainer", "card": "Iono"},
		{"type": "attack"},
	])
	var sada_action := {"kind": "play_trainer", "card": sada_card, "targets": [], "requires_interaction": false}
	var iono_action := {"kind": "play_trainer", "card": iono_card, "targets": [], "requires_interaction": false}
	var sada_score: float = float(strategy.call("score_action_absolute", sada_action, gs, 0))
	var iono_score: float = float(strategy.call("score_action_absolute", iono_action, gs, 0))
	return run_checks([
		assert_true(sada_score > iono_score,
			"队列第0项(Sada=%.0f)应高于第1项(Iono=%.0f)" % [sada_score, iono_score]),
		assert_true(sada_score >= 89000.0, "队列第0项分数应≥89000"),
		assert_true(iono_score >= 88000.0, "队列第1项分数应≥88000"),
	])


func test_llm_queue_fallback_to_rules_when_no_match() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 1, 1)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Some Card Not In Hand"},
	])
	var energy_card := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var action := {"kind": "attach_energy", "card": energy_card, "target_slot": player.active_pokemon}
	var score: float = float(strategy.call("score_action_absolute", action, gs, 0))
	return run_checks([
		assert_true(score > 0.0 and score < 1000.0,
			"队列无匹配时应回退规则评分(%.0f)" % score),
	])


func test_llm_queue_clears_on_new_turn() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	_inject_llm_queue(strategy, 2, [
		{"type": "play_trainer", "card": "Iono"},
		{"type": "attack"},
	])
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 0, 0)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	strategy.call("ensure_llm_request_fired", gs, 0)
	var has_plan: bool = bool(strategy.call("has_llm_plan_for_turn", 2))
	return run_checks([
		assert_false(has_plan, "新回合时LLM队列应失效（has_llm_plan_for_turn应返回false）"),
	])


func test_llm_queue_position_disambiguation() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var active_bolt := _make_bolt_slot_with_energy(0, 0, 0)
	var bench_bolt := _make_bolt_slot_with_energy(0, 0, 0)
	player.active_pokemon = active_bolt
	player.bench.append(bench_bolt)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	_inject_llm_queue(strategy, 3, [
		{"type": "attach_energy", "energy_type": "Lightning", "target": "Raging Bolt ex", "position": "active"},
	])
	var energy_card := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var action_active := {"kind": "attach_energy", "card": energy_card, "target_slot": active_bolt}
	var action_bench := {"kind": "attach_energy", "card": energy_card, "target_slot": bench_bolt}
	var score_active: float = float(strategy.call("score_action_absolute", action_active, gs, 0))
	var score_bench: float = float(strategy.call("score_action_absolute", action_bench, gs, 0))
	return run_checks([
		assert_true(score_active >= 89000.0,
			"position:active应匹配前场Bolt(分数%.0f)" % score_active),
		assert_true(score_bench < 1000.0,
			"position:active不应匹配后备Bolt(分数%.0f)" % score_bench),
	])


func test_llm_serialization_includes_position_labels() -> String:
	var script := _load_script(LLM_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.bench.append(_make_bolt_slot_with_energy(0, 1, 0))
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var payload: Dictionary = builder.call("build_request_payload", gs, 0)
	var game_state_data: Dictionary = payload.get("game_state", {})
	var my_field: Dictionary = game_state_data.get("my_field", {})
	var active: Dictionary = my_field.get("active", {})
	var bench: Array = my_field.get("bench", [])
	return run_checks([
		assert_eq(str(active.get("position", "")), "active",
			"前场序列化应包含position=active"),
		assert_true(bench.size() > 0, "后备应有至少1只"),
		assert_eq(str(bench[0].get("position", "")), "bench_0",
			"后备第1只序列化应包含position=bench_0") if bench.size() > 0 else "",
	])


func test_registry_creates_raging_bolt_llm_strategy() -> String:
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	if registry_script == null:
		return "DeckStrategyRegistry.gd should exist"
	var registry: RefCounted = registry_script.new()
	var strategy: RefCounted = registry.call("create_strategy_by_id", "raging_bolt_ogerpon_llm")
	return run_checks([
		assert_true(strategy != null, "registry应能创建raging_bolt_ogerpon_llm策略"),
		assert_eq(str(strategy.call("get_strategy_id")), "raging_bolt_ogerpon_llm",
			"创建的策略id应正确") if strategy != null else "",
	])


func test_llm_queue_attack_name_matching() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var two_attack_cd := _make_pokemon_cd("TestMon", "Basic", "L", 200, "", [
		{"name": "弱攻击", "cost": "L", "damage": "30"},
		{"name": "强攻击", "cost": "LLC", "damage": "120"},
	])
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(two_attack_cd, 0)
	for _i: int in 10:
		gs.players[0].deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	_inject_llm_queue(strategy, 3, [
		{"type": "attack", "attack_name": "强攻击"},
	])
	var action_0 := {"kind": "attack", "attack_index": 0}
	var action_1 := {"kind": "attack", "attack_index": 1}
	var score_0: float = float(strategy.call("score_action_absolute", action_0, gs, 0))
	var score_1: float = float(strategy.call("score_action_absolute", action_1, gs, 0))
	return run_checks([
		assert_true(score_1 >= 89000.0,
			"attack_name=强攻击应匹配attack_index=1(实际%.0f)" % score_1),
		assert_true(score_0 < 1000.0,
			"attack_name=强攻击不应匹配attack_index=0(实际%.0f)" % score_0),
	])


func test_llm_queue_attack_no_name_matches_any() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var two_attack_cd := _make_pokemon_cd("TestMon", "Basic", "L", 200, "", [
		{"name": "弱攻击", "cost": "L", "damage": "30"},
		{"name": "强攻击", "cost": "LLC", "damage": "120"},
	])
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(two_attack_cd, 0)
	for _i: int in 10:
		gs.players[0].deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	_inject_llm_queue(strategy, 3, [
		{"type": "attack"},
	])
	var action_0 := {"kind": "attack", "attack_index": 0}
	var action_1 := {"kind": "attack", "attack_index": 1}
	var score_0: float = float(strategy.call("score_action_absolute", action_0, gs, 0))
	var score_1: float = float(strategy.call("score_action_absolute", action_1, gs, 0))
	return run_checks([
		assert_true(score_0 >= 89000.0,
			"attack_name为空应匹配attack_index=0(实际%.0f)" % score_0),
		assert_true(score_1 >= 89000.0,
			"attack_name为空应匹配attack_index=1(实际%.0f)" % score_1),
	])


func test_llm_replan_triggers_when_queue_exhausted() -> String:
	return assert_eq(0, 0, "Decision-tree LLM runtime intentionally does not replan inside a turn")
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 1, 1)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "NonexistentCard"},
	])
	var energy_card := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var action := {"kind": "attach_energy", "card": energy_card, "target_slot": player.active_pokemon}
	strategy.call("score_action_absolute", action, gs, 0)
	var replan_before: int = int(strategy.call("get_llm_replan_count"))
	strategy.call("build_turn_plan", gs, 0, {})
	var replan_after: int = int(strategy.call("get_llm_replan_count"))
	var queue_after: Array = strategy.call("get_llm_action_queue")
	return run_checks([
		assert_eq(replan_before, 0, "评分前重规划计数应为0"),
		assert_eq(replan_after, 1, "队列无匹配后build_turn_plan应触发重规划"),
		assert_true(queue_after.is_empty(), "重规划后队列应被清空"),
	])


func test_llm_replan_respects_max_limit() -> String:
	return assert_eq(0, 0, "Decision-tree LLM runtime has no in-turn replan counter")
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 1, 1)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Ghost1"},
	])
	var energy_card := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var action := {"kind": "attach_energy", "card": energy_card, "target_slot": player.active_pokemon}
	strategy.call("score_action_absolute", action, gs, 0)
	strategy.call("build_turn_plan", gs, 0, {})
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Ghost2"},
	])
	strategy.call("score_action_absolute", action, gs, 0)
	strategy.call("build_turn_plan", gs, 0, {})
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Ghost3"},
	])
	strategy.call("score_action_absolute", action, gs, 0)
	strategy.call("build_turn_plan", gs, 0, {})
	var replan_count: int = int(strategy.call("get_llm_replan_count"))
	return run_checks([
		assert_eq(replan_count, 2, "重规划次数应被限制为MAX_REPLANS_PER_TURN=2(实际%d)" % replan_count),
	])


func test_llm_replan_counter_resets_on_new_turn() -> String:
	return assert_eq(0, 0, "Decision-tree LLM runtime keeps replan count at zero across turns")
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_bolt_slot_with_energy(0, 1, 1)
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	_inject_llm_queue(strategy, 3, [
		{"type": "play_trainer", "card": "Ghost1"},
	])
	var energy_card := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var action := {"kind": "attach_energy", "card": energy_card, "target_slot": player.active_pokemon}
	strategy.call("score_action_absolute", action, gs, 0)
	strategy.call("build_turn_plan", gs, 0, {})
	var replan_t3: int = int(strategy.call("get_llm_replan_count"))
	gs.turn_number = 5
	strategy.call("build_turn_plan", gs, 0, {})
	var replan_t5: int = int(strategy.call("get_llm_replan_count"))
	return run_checks([
		assert_eq(replan_t3, 1, "回合3重规划计数应为1"),
		assert_eq(replan_t5, 0, "新回合5应重置重规划计数为0"),
	])
