class_name TestFutureAncientStrategies
extends TestBase


const FUTURE_BOX_SCRIPT_PATH := "res://scripts/ai/DeckStrategyFutureBox.gd"
const IRON_THORNS_SCRIPT_PATH := "res://scripts/ai/DeckStrategyIronThorns.gd"
const RAGING_BOLT_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd"
const GOUGING_FIRE_SCRIPT_PATH := "res://scripts/ai/DeckStrategyGougingFireAncient.gd"


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
	player.hand.append(CardInstance.create(_make_trainer_cd("Pokegear 3.0"), 0))
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
	player.hand.append(CardInstance.create(_make_trainer_cd("Pokegear 3.0"), 0))
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
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Pokegear 3.0"), 0)},
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
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Pok茅gear 3.0"), 0)},
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
		assert_true(gear_score <= 60.0, "Raging Bolt should sharply cool off Pok茅gear once its pressure line is already assembled"),
		assert_true(research_score <= 90.0, "Raging Bolt should not keep forcing broad churn draw once its current and next attacker are already mapped"),
	])


func test_raging_bolt_prefers_grass_to_backup_bolt_over_extra_ogerpon_once_primary_is_ready() -> String:
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
			backup_score > ogerpon_score,
			"Raging Bolt should use spare Grass to finish the next Bolt before overfeeding Ogerpon once the primary attacker is already live"
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
