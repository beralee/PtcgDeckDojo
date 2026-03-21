class_name TestAttackSearchAndAttachRegression
extends TestBase

const AttackSearchAndAttachEffect = preload("res://scripts/effects/pokemon_effects/AttackSearchAndAttach.gd")


func test_future_energy_attachment_uses_assignment_ui_and_selected_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]

	var active_cd := _make_basic_pokemon_data("Future Active", "L", 110)
	active_cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	player.active_pokemon.pokemon_stack.clear()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(active_cd, 0))

	var future_bench_cd := _make_basic_pokemon_data("Future Bench", "P", 100)
	future_bench_cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	player.bench[0].pokemon_stack.clear()
	player.bench[0].pokemon_stack.append(CardInstance.create(future_bench_cd, 0))

	var normal_bench_cd := _make_basic_pokemon_data("Normal Bench", "W", 100)
	player.bench[1].pokemon_stack.clear()
	player.bench[1].pokemon_stack.append(CardInstance.create(normal_bench_cd, 0))

	player.deck.clear()
	var lightning_a := CardInstance.create(_make_energy_data("Lightning A", "L"), 0)
	var lightning_b := CardInstance.create(_make_energy_data("Lightning B", "L"), 0)
	var psychic_a := CardInstance.create(_make_energy_data("Psychic A", "P"), 0)
	player.deck.append(lightning_a)
	player.deck.append(lightning_b)
	player.deck.append(psychic_a)

	var effect := AttackSearchAndAttachEffect.new("", 2, "deck_search", 0, "any", CardData.FUTURE_TAG)
	var steps := effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), {"name": "巅峰加速"}, state)
	effect.set_attack_interaction_context([{
		"energy_assignments": [
			{"source": lightning_a, "target": player.active_pokemon},
			{"source": lightning_b, "target": player.active_pokemon},
		],
	}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	var step_targets: Array = steps[0].get("target_items", []) if not steps.is_empty() else []
	return run_checks([
		assert_eq(steps.size(), 1, "AttackSearchAndAttach should emit one interaction step"),
		assert_eq(str(steps[0].get("ui_mode", "")), "card_assignment", "AttackSearchAndAttach should use card_assignment UI"),
		assert_eq(int(steps[0].get("max_select", -1)), 2, "AttackSearchAndAttach should allow assigning up to the attack count"),
		assert_eq(step_targets.size(), 2, "Only valid future targets should be offered in the assignment UI"),
		assert_eq(player.active_pokemon.attached_energy.size(), 2, "Selected target should receive both assigned Energy cards"),
		assert_eq(player.bench[0].attached_energy.size(), 0, "Unselected future target should not receive Energy automatically"),
		assert_eq(player.bench[1].attached_energy.size(), 0, "Non-future targets should never receive Energy"),
		assert_false(lightning_a in player.deck, "Selected Energy should leave the deck"),
		assert_false(lightning_b in player.deck, "Selected Energy should leave the deck"),
		assert_true(psychic_a in player.deck, "Unselected non-matching Energy should stay in the deck"),
	])


func _make_state() -> GameState:
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.current_player_index = 0
	state.turn_number = 2
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Active %d" % pi, "C"), pi))
		player.active_pokemon = active_slot
		if pi == 0:
			for i: int in 2:
				var bench_slot := PokemonSlot.new()
				bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Bench %d" % i, "C"), pi))
				player.bench.append(bench_slot)
		state.players.append(player)
	return state


func _make_basic_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic"
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	return cd


func _make_energy_data(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return cd
