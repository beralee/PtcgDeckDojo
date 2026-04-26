class_name TestMunkidoriLuminousEnergy
extends TestBase

const AbilityMoveDamageCountersToOpponent = preload("res://scripts/effects/pokemon_effects/AbilityMoveDamageCountersToOpponent.gd")


func _make_basic_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	effect_id: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	cd.attacks = [{"name": "Test Attack", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	cd.effect_id = effect_id
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_basic_pokemon_data("Active%d" % pi, "P", 120), pi)
		for bi: int in 2:
			player.bench.append(_make_slot(_make_basic_pokemon_data("Bench%d_%d" % [pi, bi], "P", 90), pi))
		state.players.append(player)
	return state


func test_munkidori_luminous_energy_counts_as_dark() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var munki_cd := _make_basic_pokemon_data("Munkidori", "P", 110, "Basic", "", "66fee12502043db7d92b97b0d62b0f59")
	munki_cd.abilities = [{"name": "亢奋脑力"}]
	var munki_slot := _make_slot(munki_cd, 0)
	munki_slot.attached_energy.append(CardInstance.create(_make_energy_data("Luminous Energy", "", "Special Energy", "540ee48bb93584e4bfe3d7f5d0ee0efc"), 0))
	player.active_pokemon = munki_slot
	player.active_pokemon.damage_counters = 30

	var effect := AbilityMoveDamageCountersToOpponent.new(3)
	return run_checks([
		assert_true(effect.can_use_ability(munki_slot, state), "Munkidori should treat Luminous Energy as attached Dark Energy"),
	])


func test_munkidori_luminous_energy_downgrades_with_other_special_energy() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var munki_cd := _make_basic_pokemon_data("Munkidori", "P", 110, "Basic", "", "66fee12502043db7d92b97b0d62b0f59")
	munki_cd.abilities = [{"name": "亢奋脑力"}]
	var munki_slot := _make_slot(munki_cd, 0)
	munki_slot.attached_energy.append(CardInstance.create(_make_energy_data("Luminous Energy", "", "Special Energy", "540ee48bb93584e4bfe3d7f5d0ee0efc"), 0))
	munki_slot.attached_energy.append(CardInstance.create(_make_energy_data("Gift Energy", "", "Special Energy", "e743e30dbebcadb0d15f5538198c2861"), 0))
	player.active_pokemon = munki_slot
	player.active_pokemon.damage_counters = 30

	var effect := AbilityMoveDamageCountersToOpponent.new(3)
	return run_checks([
		assert_false(effect.can_use_ability(munki_slot, state), "Luminous Energy should downgrade to Colorless when another Special Energy is attached"),
	])


func test_munkidori_ability_logs_counter_transfer_vfx_payload() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var munki_cd := _make_basic_pokemon_data("Munkidori", "P", 110, "Basic", "", "munkidori_vfx_test")
	munki_cd.abilities = [{"name": "亢奋脑力"}]
	var munki_slot := _make_slot(munki_cd, 0)
	munki_slot.attached_energy.append(CardInstance.create(_make_energy_data("Darkness Energy", "D"), 0))
	player.active_pokemon = munki_slot
	var source_slot: PokemonSlot = player.bench[0]
	source_slot.damage_counters = 40
	var target_slot: PokemonSlot = opponent.active_pokemon
	gsm.effect_processor.register_effect("munkidori_vfx_test", AbilityMoveDamageCountersToOpponent.new(3))

	var used := gsm.use_ability(0, munki_slot, 0, [{
		"source_pokemon": [source_slot],
		"target_damage_counters": [{
			"target": target_slot,
			"amount": 30,
		}],
	}])
	var action: GameAction = gsm.action_log.back() if not gsm.action_log.is_empty() else null
	var source_spec: Dictionary = action.data.get("source", {}) if action != null else {}
	var target_spec: Dictionary = action.data.get("target", {}) if action != null else {}
	var caster_spec: Dictionary = action.data.get("caster", {}) if action != null else {}

	return run_checks([
		assert_true(used, "Munkidori ability should resolve with a valid dark energy and source target"),
		assert_eq(source_slot.damage_counters, 10, "Ability should remove three counters from the selected own Pokemon"),
		assert_eq(target_slot.damage_counters, 30, "Ability should add three counters to the selected opponent Pokemon"),
		assert_eq(str(action.data.get("ability_vfx", "")) if action != null else "", "counter_transfer", "Ability action should carry a counter-transfer VFX marker"),
		assert_eq(int(action.data.get("counter_count", 0)) if action != null else 0, 3, "VFX payload should preserve the actual moved counter count"),
		assert_eq(str(source_spec.get("slot_kind", "")), "bench", "VFX source should point at the damaged bench Pokemon"),
		assert_eq(int(source_spec.get("slot_index", -1)), 0, "VFX source should include the bench index"),
		assert_eq(str(target_spec.get("slot_kind", "")), "active", "VFX target should point at the opponent active Pokemon"),
		assert_eq(str(caster_spec.get("pokemon_name", "")), "Munkidori", "VFX caster should identify the ability user"),
	])


func test_munkidori_ability_uses_counter_distribution_followup_ui() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var munki_cd := _make_basic_pokemon_data("Munkidori", "P", 110, "Basic", "", "munkidori_ui_test")
	munki_cd.abilities = [{"name": "亢奋脑力"}]
	var munki_slot := _make_slot(munki_cd, 0)
	munki_slot.attached_energy.append(CardInstance.create(_make_energy_data("Darkness Energy", "D"), 0))
	player.active_pokemon = munki_slot
	var source_slot: PokemonSlot = player.bench[0]
	source_slot.damage_counters = 20
	var effect := AbilityMoveDamageCountersToOpponent.new(3)
	var initial_steps := effect.get_interaction_steps(munki_slot.get_top_card(), state)
	var followup_steps := effect.get_followup_interaction_steps(munki_slot.get_top_card(), state, {
		"source_pokemon": [source_slot],
	})
	var followup: Dictionary = followup_steps[0] if not followup_steps.is_empty() else {}

	return run_checks([
		assert_eq(initial_steps.size(), 1, "Munkidori should first ask only for the damaged own source Pokemon"),
		assert_eq(str(initial_steps[0].get("id", "")), "source_pokemon", "Initial Munkidori step should select the source Pokemon"),
		assert_eq(str(followup.get("id", "")), "target_damage_counters", "Follow-up should store counter placement assignments"),
		assert_eq(str(followup.get("ui_mode", "")), "counter_distribution", "Follow-up should reuse Dragapult-style counter distribution UI"),
		assert_eq(int(followup.get("total_counters", 0)), 2, "Follow-up should cap available counters by source damage"),
		assert_true(bool(followup.get("allow_partial", false)), "Munkidori should allow moving fewer than the maximum counters"),
		assert_eq(int(followup.get("max_assignments", 0)), 1, "Munkidori should finish after one target assignment"),
	])
