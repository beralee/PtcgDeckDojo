class_name TestStateEncoder
extends TestBase

const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")


func _make_card(name: String, card_type: String, owner_index: int, extras: Dictionary = {}) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = card_type
	card_data.stage = str(extras.get("stage", ""))
	card_data.hp = int(extras.get("hp", 0))
	card_data.mechanic = str(extras.get("mechanic", ""))
	card_data.energy_type = str(extras.get("energy_type", ""))
	for attack_variant: Variant in extras.get("attacks", []):
		if attack_variant is Dictionary:
			card_data.attacks.append((attack_variant as Dictionary).duplicate(true))
	return CardInstance.create(card_data, owner_index)


func _make_game_state() -> GameState:
	var gs := GameState.new()
	gs.turn_number = 3
	gs.first_player_index = 0
	gs.current_player_index = 0
	gs.energy_attached_this_turn = false
	gs.supporter_used_this_turn = false

	for i in 2:
		var player := PlayerState.new()
		player.player_index = i

		var active_card := _make_card(
			"Pikachu ex" if i == 0 else "Gardevoir ex",
			"Pokemon",
			i,
			{
				"stage": "Basic" if i == 0 else "Stage 2",
				"hp": 200 if i == 0 else 310,
				"mechanic": "ex",
				"energy_type": "L" if i == 0 else "P",
				"attacks": [{"name": "Attack", "cost": "LC", "damage": "90", "text": ""}],
			}
		)
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack = [active_card]
		active_slot.damage_counters = 30 if i == 0 else 0
		for _e in 2:
			active_slot.attached_energy.append(_make_card(
				"Basic Energy",
				"Basic Energy",
				i,
				{"energy_type": "L" if i == 0 else "P"}
			))
		player.active_pokemon = active_slot

		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack = [
			_make_card("Bench Pokemon", "Pokemon", i, {"stage": "Basic", "hp": 60, "energy_type": "C"})
		]
		player.bench = [bench_slot]

		for _h in 5:
			player.hand.append(_make_card("Hand Fill", "Trainer", i))
		for _d in 30:
			player.deck.append(_make_card("Deck Fill", "Trainer", i))
		for _p in 5:
			player.prizes.append(_make_card("Prize Fill", "Trainer", i))

		gs.players.append(player)

	return gs


func test_encode_returns_correct_dimension() -> String:
	var gs := _make_game_state()
	var features: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_eq(features.size(), StateEncoderScript.FEATURE_DIM, "feature vector size should match FEATURE_DIM"),
	])


func test_encode_values_in_expected_range() -> String:
	var gs := _make_game_state()
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(absf(f[0] - 0.85) < 0.01, "active_hp_ratio should be 0.85"),
		assert_true(absf(f[1] - 0.15) < 0.01, "active_damage_ratio should be 0.15"),
		assert_true(absf(f[2] - 0.4) < 0.01, "active_energy_count should be 0.4"),
		assert_true(f[4] == 1.0, "active_is_ex should be 1.0"),
		assert_true(f[5] == 0.0, "active_stage should be 0.0 for Basic"),
		assert_true(absf(f[6] - 0.2) < 0.01, "bench_count should be 0.2"),
		assert_true(absf(f[9] - 0.25) < 0.01, "hand_size should be 0.25"),
		assert_true(absf(f[10] - 0.75) < 0.01, "deck_size should be 0.75"),
		assert_true(f[12] == 1.0, "supporter_available should be 1.0"),
		assert_true(f[13] == 1.0, "energy_available should be 1.0"),
	])


func test_encode_symmetry() -> String:
	var gs := _make_game_state()
	var f0: Array[float] = StateEncoderScript.encode(gs, 0)
	var f1: Array[float] = StateEncoderScript.encode(gs, 1)
	var symmetric := true
	for i in 20:
		if absf(f0[i] - f1[20 + i]) > 0.001:
			symmetric = false
			break
	return run_checks([
		assert_true(symmetric, "perspective encoding should stay symmetric across the two player blocks"),
	])


func test_encode_turn_and_first_player() -> String:
	var gs := _make_game_state()
	gs.turn_number = 15
	gs.first_player_index = 0
	var f0: Array[float] = StateEncoderScript.encode(gs, 0)
	var f1: Array[float] = StateEncoderScript.encode(gs, 1)
	return run_checks([
		assert_true(absf(f0[40] - 0.5) < 0.01, "turn feature should normalize to 0.5 at turn 15"),
		assert_true(f0[41] == 1.0, "player 0 should encode as first player"),
		assert_true(f1[41] == 0.0, "player 1 should encode as not first player"),
	])


func test_encode_empty_bench() -> String:
	var gs := _make_game_state()
	gs.players[0].bench.clear()
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(f[6] == 0.0, "empty bench should zero bench_count"),
		assert_true(f[7] == 0.0, "empty bench should zero bench_total_hp"),
		assert_true(f[8] == 0.0, "empty bench should zero bench_total_energy"),
	])


func test_encode_no_active_pokemon() -> String:
	var gs := _make_game_state()
	gs.players[0].active_pokemon = null
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(f[0] == 0.0, "missing active should zero active_hp_ratio"),
		assert_true(f[1] == 0.0, "missing active should zero active_damage_ratio"),
		assert_true(f[2] == 0.0, "missing active should zero active_energy_count"),
	])


func test_encode_status_and_discard_features() -> String:
	var gs := _make_game_state()
	gs.players[0].active_pokemon.status_conditions["poisoned"] = true
	for _i in 10:
		gs.players[0].discard_pile.append(_make_card("Discard Fill", "Trainer", 0))
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(f[14] == 1.0, "poison should set poisoned_or_burned"),
		assert_true(f[15] == 0.0, "locked-status flag should stay zero when not asleep/paralyzed/confused"),
		assert_true(absf(f[19] - 0.25) < 0.01, "discard size 10 should normalize to 0.25"),
		assert_true(f[42] == 0.0, "no stadium should keep stadium flag at 0"),
	])


func test_encode_miraidon_focus_resource_features() -> String:
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	player.hand.append(_make_card("Arven", "Supporter", 0))
	player.hand.append(_make_card("Electric Generator", "Item", 0))

	for i in 2:
		player.hand.append(_make_card(
			"Lightning Basic %d" % i,
			"Pokemon",
			0,
			{"stage": "Basic", "energy_type": "L", "hp": 90}
		))

	for i in 3:
		player.hand.append(_make_card(
			"Lightning Energy %d" % i,
			"Basic Energy",
			0,
			{"energy_type": "L"}
		))

	for i in 4:
		player.deck.append(_make_card(
			"Deck Lightning %d" % i,
			"Basic Energy",
			0,
			{"energy_type": "L"}
		))

	for _i in 2:
		player.deck.append(_make_card("Electric Generator", "Item", 0))

	for i in 2:
		player.discard_pile.append(_make_card(
			"Discard Lightning %d" % i,
			"Basic Energy",
			0,
			{"energy_type": "L"}
		))
	player.discard_pile.append(_make_card("Electric Generator", "Item", 0))

	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_eq(f[44], 1.0, "hand_has_arven should be set"),
		assert_eq(f[45], 1.0, "hand_has_electric_generator should be set"),
		assert_true(absf(f[46] - 0.5) < 0.01, "2 lightning basics in hand should normalize to 0.5"),
		assert_true(absf(f[47] - 0.75) < 0.01, "3 lightning energy in hand should normalize to 0.75"),
		assert_eq(f[48], 1.0, "4 lightning energy in deck should clamp to 1.0"),
		assert_true(absf(f[49] - 0.5) < 0.01, "2 generators in deck should normalize to 0.5"),
		assert_true(absf(f[50] - 0.5) < 0.01, "2 lightning energy in discard should normalize to 0.5"),
		assert_true(absf(f[51] - 0.25) < 0.01, "1 generator in discard should normalize to 0.25"),
	])
