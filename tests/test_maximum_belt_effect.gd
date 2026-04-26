class_name TestMaximumBeltEffect
extends TestBase


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
	return cd


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		var active_cd := _make_basic_pokemon_data("Active_%d" % pi, "C", 120)
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(active_cd, pi))
		active.turn_played = 0
		player.active_pokemon = active
		state.players.append(player)

	return state


func test_maximum_belt_boosts_real_arceus_damage_into_ex_targets() -> String:
	var arceus_cd := CardDatabase.get_card("CS5aC", "107")
	var miraidon_cd := CardDatabase.get_card("CSV1C", "050")
	var max_belt_cd := CardDatabase.get_card("CSV7C", "189")
	if arceus_cd == null or miraidon_cd == null or max_belt_cd == null:
		return "Missing Maximum Belt / Arceus VSTAR / Miraidon ex real card data"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.pokemon_stack.clear()
	attacker.pokemon_stack.append(CardInstance.create(arceus_cd, 0))
	attacker.attached_tool = CardInstance.create(max_belt_cd, 0)

	var defender := gsm.game_state.players[1].active_pokemon
	defender.pokemon_stack.clear()
	defender.pokemon_stack.append(CardInstance.create(miraidon_cd, 1))

	var preview_damage := gsm.get_attack_preview_damage(0, 0)
	var actual_damage := gsm._calculate_attack_damage(attacker, defender, arceus_cd.attacks[0], 0)

	return run_checks([
		assert_eq(preview_damage, 250, "Maximum Belt should raise Trinity Nova preview damage from 200 to 250 against Pokemon ex"),
		assert_eq(actual_damage, 250, "Maximum Belt should raise Trinity Nova actual damage from 200 to 250 against Pokemon ex"),
	])


func test_maximum_belt_does_not_boost_real_arceus_damage_into_non_ex_targets() -> String:
	var arceus_cd := CardDatabase.get_card("CS5aC", "107")
	var max_belt_cd := CardDatabase.get_card("CSV7C", "189")
	if arceus_cd == null or max_belt_cd == null:
		return "Missing Maximum Belt / Arceus VSTAR real card data"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.pokemon_stack.clear()
	attacker.pokemon_stack.append(CardInstance.create(arceus_cd, 0))
	attacker.attached_tool = CardInstance.create(max_belt_cd, 0)

	var non_ex_cd := _make_basic_pokemon_data("Non-ex Target", "W", 220)
	var defender := gsm.game_state.players[1].active_pokemon
	defender.pokemon_stack.clear()
	defender.pokemon_stack.append(CardInstance.create(non_ex_cd, 1))

	var preview_damage := gsm.get_attack_preview_damage(0, 0)
	var actual_damage := gsm._calculate_attack_damage(attacker, defender, arceus_cd.attacks[0], 0)

	return run_checks([
		assert_eq(preview_damage, 200, "Maximum Belt should not boost Trinity Nova against non-ex targets"),
		assert_eq(actual_damage, 200, "Maximum Belt should not boost actual damage against non-ex targets"),
	])


func test_maximum_belt_and_double_turbo_still_knock_out_teal_mask_ogerpon_ex() -> String:
	var arceus_cd := CardDatabase.get_card("CS5aC", "107")
	var ogerpon_cd := CardDatabase.get_card("CSV8C", "028")
	var max_belt_cd := CardDatabase.get_card("CSV7C", "189")
	var dte_cd := CardDatabase.get_card("CSNC", "024")
	if arceus_cd == null or ogerpon_cd == null or max_belt_cd == null or dte_cd == null:
		return "Missing Arceus VSTAR / Teal Mask Ogerpon ex / Maximum Belt / Double Turbo Energy real card data"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.pokemon_stack.clear()
	attacker.pokemon_stack.append(CardInstance.create(arceus_cd, 0))
	attacker.attached_tool = CardInstance.create(max_belt_cd, 0)
	attacker.attached_energy.append(CardInstance.create(dte_cd, 0))

	var grass_cd := CardData.new()
	grass_cd.name = "Grass Energy"
	grass_cd.card_type = "Basic Energy"
	grass_cd.energy_provides = "G"
	attacker.attached_energy.append(CardInstance.create(grass_cd, 0))

	var defender := gsm.game_state.players[1].active_pokemon
	defender.pokemon_stack.clear()
	defender.pokemon_stack.append(CardInstance.create(ogerpon_cd, 1))

	var preview_damage := gsm.get_attack_preview_damage(0, 0)
	var actual_damage := gsm._calculate_attack_damage(attacker, defender, arceus_cd.attacks[0], 0)
	var knock_out := actual_damage >= ogerpon_cd.hp

	return run_checks([
		assert_eq(preview_damage, 230, "Double Turbo should reduce Trinity Nova by 20, then Maximum Belt should add 50 for a total of 230 into Ogerpon ex"),
		assert_eq(actual_damage, 230, "Actual damage should also be 230 into Teal Mask Ogerpon ex"),
		assert_true(knock_out, "230 damage should knock out Teal Mask Ogerpon ex with 210 HP"),
	])
