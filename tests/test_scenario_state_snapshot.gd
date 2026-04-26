class_name TestScenarioStateSnapshot
extends TestBase


const ScenarioStateSnapshotScript = preload("res://scripts/engine/scenario/ScenarioStateSnapshot.gd")


func _make_game_state() -> GameState:
	CardInstance.reset_id_counter()

	var state := GameState.new()
	state.turn_number = 7
	state.current_player_index = 1
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	state.energy_attached_this_turn = true
	state.supporter_used_this_turn = true
	state.stadium_played_this_turn = false
	state.retreat_used_this_turn = false
	state.stadium_owner_index = 0
	state.stadium_effect_used_turn = 6
	state.stadium_effect_used_player = 0
	state.stadium_effect_used_effect_id = "town_store"
	state.vstar_power_used = [true, false]
	state.last_knockout_turn_against = [5, -999]
	state.shared_turn_flags = {"used_legacy_switch": true}

	for player_index: int in range(2):
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)

	state.stadium_card = _make_trainer_card("Town Store", 0, "Stadium")
	state.stadium_card.face_up = true

	var p0: PlayerState = state.players[0]
	var p1: PlayerState = state.players[1]

	p0.active_pokemon = _make_slot(
		[
			_make_pokemon_card("Charmander", 0, "Basic", 70, "R"),
			_make_pokemon_card("Charmeleon", 0, "Stage 1", 100, "R", "Charmander")
		],
		[
			_make_energy_card("Fire Energy A", 0, "R"),
			_make_energy_card("Fire Energy B", 0, "R")
		],
		_make_trainer_card("Defiance Band", 0, "Tool"),
		60,
		3,
		5
	)
	p0.active_pokemon.status_conditions["burned"] = true
	p0.bench.append(_make_slot(
		[_make_pokemon_card("Pidgey", 0, "Basic", 60, "C")],
		[_make_energy_card("Jet Energy", 0, "C", "Special Energy")],
		null,
		20,
		2,
		-1
	))
	p0.hand.append_array([
		_make_trainer_card("Rare Candy", 0, "Item"),
		_make_pokemon_card("Pidgeotto", 0, "Stage 1", 90, "C", "Pidgey")
	])
	p0.deck.append_array([
		_make_trainer_card("Ultra Ball", 0, "Item"),
		_make_trainer_card("Boss's Orders", 0, "Supporter")
	])
	p0.discard_pile.append(_make_trainer_card("Earthen Vessel", 0, "Item"))
	p0.lost_zone.append(_make_trainer_card("Lost Vacuum", 0, "Item"))
	p0.prizes.append_array([
		_make_trainer_card("Prize Map", 0, "Item"),
		_make_pokemon_card("Prize Charmander", 0, "Basic", 70, "R")
	])
	p0.prize_layout = [null, p0.prizes[0], p0.prizes[1], null, null, null]
	p0.shuffle_count = 2

	p1.active_pokemon = _make_slot(
		[_make_pokemon_card("Miraidon ex", 1, "Basic", 220, "L", "", "ex", ["Future"])],
		[
			_make_energy_card("Lightning Energy A", 1, "L"),
			_make_energy_card("Lightning Energy B", 1, "L"),
			_make_energy_card("Generator Energy", 1, "L", "Special Energy")
		],
		_make_trainer_card("Bravery Charm", 1, "Tool"),
		10,
		4,
		-1
	)
	p1.bench.append(_make_slot(
		[_make_pokemon_card("Iron Hands ex", 1, "Basic", 230, "L", "", "ex", ["Future"])],
		[_make_energy_card("Lightning Energy C", 1, "L")],
		null,
		0,
		4,
		-1
	))
	p1.hand.append_array([
		_make_trainer_card("Electric Generator", 1, "Item"),
		_make_energy_card("Lightning Energy Hand", 1, "L")
	])
	p1.deck.append(_make_pokemon_card("Raikou V", 1, "Basic", 200, "L", "", "V"))
	p1.discard_pile.append(_make_trainer_card("Nest Ball", 1, "Item"))
	p1.prizes.append_array([
		_make_pokemon_card("Prize Iron Bundle", 1, "Basic", 70, "W", "", "", ["Future"]),
		_make_trainer_card("Prize Generator", 1, "Item")
	])
	p1.prize_layout = [p1.prizes[0], null, p1.prizes[1], null, null, null]
	p1.shuffle_count = 1

	return state


func test_capture_preserves_primary_scenario_dimensions_for_both_players() -> String:
	var snapshot: Dictionary = ScenarioStateSnapshotScript.capture(_make_game_state())
	var validation_errors: Array[String] = ScenarioStateSnapshotScript.validate(snapshot)
	var p0: Dictionary = snapshot.get("players", [])[0]
	var p1: Dictionary = snapshot.get("players", [])[1]
	var p0_active: Dictionary = p0.get("active", {})
	var p1_active: Dictionary = p1.get("active", {})

	return run_checks([
		assert_eq(validation_errors.size(), 0, "Snapshot should validate cleanly"),
		assert_eq(int(snapshot.get("turn_number", -1)), 7, "Snapshot should keep turn number"),
		assert_eq(str(snapshot.get("phase", "")), "main", "Snapshot should normalize phase names"),
		assert_eq((p0.get("hand", []) as Array).size(), 2, "Snapshot should preserve player 0 hand contents"),
		assert_eq((p1.get("bench", []) as Array).size(), 1, "Snapshot should preserve player 1 bench contents"),
		assert_eq(str((p0_active.get("attached_tool", {}) as Dictionary).get("card_name", "")), "Defiance Band", "Snapshot should keep tool names"),
		assert_eq(int(p0_active.get("damage_counters", -1)), 60, "Snapshot should keep exact damage"),
		assert_eq((p1_active.get("attached_energy", []) as Array).size(), 3, "Snapshot should keep exact energy counts"),
		assert_eq(str((((p1_active.get("pokemon_stack", []) as Array)[0]) as Dictionary).get("mechanic", "")), "ex", "Snapshot should keep mechanic metadata"),
		assert_eq(str((((p1_active.get("pokemon_stack", []) as Array)[0]) as Dictionary).get("is_tags", [])[0]), "Future", "Snapshot should keep card tags"),
		assert_eq(str((((p0.get("prize_layout", []) as Array)[1]) as Dictionary).get("card_name", "")), "Prize Map", "Snapshot should preserve prize layout identities"),
	])


func test_validate_rejects_missing_required_shape() -> String:
	var invalid_snapshot := {
		"turn_number": 1,
		"players": [],
	}
	var errors: Array[String] = ScenarioStateSnapshotScript.validate(invalid_snapshot)
	return run_checks([
		assert_true(errors.size() > 0, "Invalid snapshots should report validation errors"),
		assert_true(errors.any(func(msg: String) -> bool: return "players" in msg), "Validation should mention the malformed player payload"),
	])


func _make_slot(
	pokemon_stack: Array[CardInstance],
	attached_energy: Array[CardInstance],
	attached_tool: CardInstance,
	damage_counters: int,
	turn_played: int,
	turn_evolved: int
) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack = pokemon_stack
	slot.attached_energy = attached_energy
	slot.attached_tool = attached_tool
	slot.damage_counters = damage_counters
	slot.turn_played = turn_played
	slot.turn_evolved = turn_evolved
	return slot


func _make_pokemon_card(
	card_name: String,
	owner_index: int,
	stage: String,
	hp: int,
	energy_type: String,
	evolves_from: String = "",
	mechanic: String = "",
	tags: Array[String] = []
) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.card_type = "Pokemon"
	card_data.stage = stage
	card_data.hp = hp
	card_data.energy_type = energy_type
	card_data.evolves_from = evolves_from
	card_data.mechanic = mechanic
	card_data.attacks = [{
		"name": "Test Attack",
		"text": "",
		"cost": energy_type,
		"damage": "30",
		"is_vstar_power": false,
	}]
	card_data.is_tags = PackedStringArray(tags)
	return CardInstance.create(card_data, owner_index)


func _make_energy_card(card_name: String, owner_index: int, energy_type: String, card_type: String = "Basic Energy") -> CardInstance:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.card_type = card_type
	card_data.energy_provides = energy_type
	return CardInstance.create(card_data, owner_index)


func _make_trainer_card(card_name: String, owner_index: int, card_type: String) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.card_type = card_type
	return CardInstance.create(card_data, owner_index)
