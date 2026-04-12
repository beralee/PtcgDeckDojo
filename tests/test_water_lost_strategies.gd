class_name TestWaterLostStrategies
extends TestBase


const PALKIA_GHOLDENGO_SCRIPT_PATH := "res://scripts/ai/DeckStrategyPalkiaGholdengo.gd"
const LOST_BOX_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLostBox.gd"


func _load_strategy(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_strategy(script_path: String) -> RefCounted:
	CardInstance.reset_id_counter()
	var script := _load_strategy(script_path)
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


func _make_energy_cd(pname: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Basic Energy"
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


func _add_lost_zone_cards(player: PlayerState, count: int) -> void:
	for i: int in count:
		player.lost_zone.append(CardInstance.create(_make_trainer_cd("Lost%d" % i), player.player_index))


func test_palkia_gholdengo_setup_prefers_palkia_active() -> String:
	var s := _new_strategy(PALKIA_GHOLDENGO_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyPalkiaGholdengo.gd should load before setup behavior can be tested"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Gimmighoul", "Basic", "M", 60), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Origin Forme Palkia V", "Basic", "W", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0))
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	var bench_indices: Array = choice.get("bench_hand_indices", [])
	return run_checks([
		assert_eq(active_name, "Origin Forme Palkia V", "Palkia/Gholdengo should lead with Palkia V when available"),
		assert_true(bench_indices.size() >= 1, "Palkia/Gholdengo opening plan should still bench support basics"),
	])


func test_palkia_gholdengo_resource_loop_scores_above_setup_cards() -> String:
	var s := _new_strategy(PALKIA_GHOLDENGO_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyPalkiaGholdengo.gd should load before resource-loop scoring can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gholdengo ex",
		"Stage 1",
		"M",
		260,
		"Gimmighoul",
		"ex",
		[{"name": "Coin Bonus", "text": "test"}],
		[{"name": "Make It Rain", "cost": "M", "damage": "50x"}],
		2
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Metal Energy", "M"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Origin Forme Palkia VSTAR", "VSTAR", "W", 280, "Origin Forme Palkia V", "V"), 0))
	for _i: int in 3:
		player.discard_pile.append(CardInstance.create(_make_energy_cd("Metal Energy", "M"), 0))
	var score_ser: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Superior Energy Retrieval"), 0)},
		gs,
		0
	)
	var score_poffin: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_ser > score_poffin, "Palkia/Gholdengo should prefer energy loop pieces over extra setup once the engine is online"),
		assert_true(score_ser >= 300.0, "Superior Energy Retrieval should become a high-value resource-loop action (got %f)" % score_ser),
	])


func test_palkia_gholdengo_burst_turn_scores_attack_over_setup() -> String:
	var s := _new_strategy(PALKIA_GHOLDENGO_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyPalkiaGholdengo.gd should load before burst-turn scoring can be tested"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gholdengo ex",
		"Stage 1",
		"M",
		260,
		"Gimmighoul",
		"ex",
		[{"name": "Coin Bonus", "text": "test"}],
		[{"name": "Make It Rain", "cost": "M", "damage": "50x"}],
		2
	), 0)
	for _i: int in 2:
		player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Metal Energy", "M"), 0))
	for _i: int in 4:
		player.hand.append(CardInstance.create(_make_energy_cd("Metal Energy", "M"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Defender ex", "Basic", "C", 220, "", "ex"), 1)
	var score_attack: float = s.score_action_absolute(
		{"kind": "attack", "attack_index": 0, "projected_damage": 240},
		gs,
		0
	)
	var score_setup: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_attack > score_setup, "Palkia/Gholdengo should switch from setup to burst damage when enough metal energy is available"),
		assert_true(score_attack >= 700.0, "Burst-turn Gholdengo attacks should receive a decisive score (got %f)" % score_attack),
	])


func test_lost_box_setup_prefers_comfey_active() -> String:
	var s := _new_strategy(LOST_BOX_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyLostBox.gd should load before setup behavior can be tested"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Comfey", "Basic", "P", 70, "", "", [{"name": "Flower Selecting", "text": "test"}], [], 1), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Cramorant", "Basic", "W", 110, "", "", [{"name": "Lost Provisions", "text": "test"}], [], 1), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	return assert_eq(active_name, "Comfey", "Lost Box should lead with Comfey to start lost-zone progress")


func test_lost_box_colress_scores_above_generic_item_early() -> String:
	var s := _new_strategy(LOST_BOX_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyLostBox.gd should load before lost-zone progress scoring can be tested"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Comfey", "Basic", "P", 70, "", "", [{"name": "Flower Selecting", "text": "test"}], [], 1), 0)
	_add_lost_zone_cards(player, 2)
	var score_colress: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Colress's Experiment", "Supporter"), 0)},
		gs,
		0
	)
	var score_potion: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Potion"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_colress > score_potion, "Lost Box should strongly prefer Colress to advance the lost zone"),
		assert_true(score_colress >= 450.0, "Colress should be a premier early-game action for Lost Box (got %f)" % score_colress),
	])


func test_lost_box_pivot_item_scores_high_with_comfey_active() -> String:
	var s := _new_strategy(LOST_BOX_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyLostBox.gd should load before pivot scoring can be tested"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Comfey", "Basic", "P", 70, "", "", [{"name": "Flower Selecting", "text": "test"}], [], 1), 0)
	var cramorant := _make_slot(_make_pokemon_cd("Cramorant", "Basic", "W", 110, "", "", [{"name": "Lost Provisions", "text": "test"}], [{"name": "Spit Innocently", "cost": "WWC", "damage": "110"}], 1), 0)
	player.bench.append(cramorant)
	_add_lost_zone_cards(player, 4)
	var score_switch_cart: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Switch Cart"), 0)},
		gs,
		0
	)
	var score_nest_ball: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_switch_cart > score_nest_ball, "Lost Box should value pivot cards above extra setup when Comfey can cycle into pressure"),
		assert_true(score_switch_cart >= 320.0, "Switch Cart should get a strong score in Comfey pivot turns (got %f)" % score_switch_cart),
	])


func test_lost_box_board_eval_rewards_progress_and_single_prize_pressure() -> String:
	var s := _new_strategy(LOST_BOX_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyLostBox.gd should load before board evaluation can be tested"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Comfey", "Basic", "P", 70, "", "", [{"name": "Flower Selecting", "text": "test"}], [], 1), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Cramorant", "Basic", "W", 110, "", "", [{"name": "Lost Provisions", "text": "test"}], [{"name": "Spit Innocently", "cost": "WWC", "damage": "110"}], 1), 0))
	var score_low_progress: float = s.evaluate_board(gs, 0)
	_add_lost_zone_cards(player, 5)
	var score_ready_pressure: float = s.evaluate_board(gs, 0)
	return run_checks([
		assert_true(score_ready_pressure > score_low_progress, "Lost Box board evaluation should improve as lost-zone progress unlocks single-prize pressure"),
		assert_true(score_ready_pressure >= 150.0, "Lost Box should see a meaningful board-eval bump once pressure thresholds are met (got %f)" % score_ready_pressure),
	])


func test_palkia_gholdengo_irida_beats_generic_draw_when_engine_is_missing() -> String:
	var s := _new_strategy(PALKIA_GHOLDENGO_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyPalkiaGholdengo.gd should load before Irida timing can be tested"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Origin Forme Palkia V", "Basic", "W", 220, "", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gimmighoul", "Basic", "M", 60), 0))
	var score_irida: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Irida", "Supporter"), 0)},
		gs,
		0
	)
	var score_research: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_irida > score_research, "Palkia/Gholdengo should prefer Irida over generic draw while the engine is still missing pieces"),
		assert_true(score_irida >= 260.0, "Irida should be a premium setup line when Gholdengo/Bibarel pieces are still missing (got %f)" % score_irida),
	])


func test_lost_box_mirage_gate_prefers_iron_hands_finisher_targets() -> String:
	var s := _new_strategy(LOST_BOX_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyLostBox.gd should load before Mirage Gate targeting can be tested"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	_add_lost_zone_cards(player, 7)
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex", [], [{"name": "Amp You Very Much", "cost": "LLC", "damage": "160"}]), 0)
	var cramorant := _make_slot(_make_pokemon_cd("Cramorant", "Basic", "W", 110, "", "", [], [{"name": "Spit Innocently", "cost": "", "damage": "110"}], 1), 0)
	var step := {"id": "energy_target"}
	var lightning := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var score_hands: float = s.score_interaction_target(iron_hands, step, {"game_state": gs, "player_index": 0, "source_card": lightning})
	var score_cramorant: float = s.score_interaction_target(cramorant, step, {"game_state": gs, "player_index": 0, "source_card": lightning})
	return run_checks([
		assert_true(score_hands > score_cramorant, "Lost Box should route Mirage Gate lightning into Iron Hands when the lost zone is online"),
		assert_true(score_hands >= 300.0, "Mirage Gate finisher targets should receive a strong positive score (got %f)" % score_hands),
	])


func test_lost_box_finisher_attack_outranks_small_pressure_once_mirage_gate_is_online() -> String:
	var s := _new_strategy(LOST_BOX_SCRIPT_PATH)
	if s == null:
		return "DeckStrategyLostBox.gd should load before finisher attack timing can be tested"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	_add_lost_zone_cards(player, 7)
	var iron_hands := _make_slot(_make_pokemon_cd(
		"Iron Hands ex",
		"Basic",
		"L",
		230,
		"",
		"ex",
		[],
		[{"name": "Amp You Very Much", "cost": "LLC", "damage": "160"}],
		3
	), 0)
	for _i: int in 3:
		iron_hands.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var comfey := _make_slot(_make_pokemon_cd(
		"Comfey",
		"Basic",
		"P",
		70,
		"",
		"",
		[{"name": "Flower Selecting", "text": "test"}],
		[{"name": "Spin Attack", "cost": "CC", "damage": "30"}],
		1
	), 0)
	for _i: int in 2:
		comfey.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	player.active_pokemon = iron_hands
	var score_hands_attack: float = s.score_action_absolute(
		{"kind": "attack", "attack_index": 0, "projected_damage": 160, "projected_knockout": true},
		gs,
		0
	)
	player.active_pokemon = comfey
	var score_comfey_attack: float = s.score_action_absolute(
		{"kind": "attack", "attack_index": 0, "projected_damage": 30, "projected_knockout": false},
		gs,
		0
	)
	return run_checks([
		assert_true(score_hands_attack > score_comfey_attack, "Lost Box should prefer the two-prize finisher attack once Mirage Gate lines are online"),
		assert_true(score_hands_attack >= 700.0, "Online finisher attacks should receive a decisive score (got %f)" % score_hands_attack),
	])
