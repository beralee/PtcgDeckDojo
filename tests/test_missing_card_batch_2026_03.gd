class_name TestMissingCardBatch202603
extends TestBase

const EffectRoxanne = preload("res://scripts/effects/trainer_effects/EffectRoxanne.gd")
const EffectCyllene = preload("res://scripts/effects/trainer_effects/EffectCyllene.gd")
const EffectTrekkingShoes = preload("res://scripts/effects/trainer_effects/EffectTrekkingShoes.gd")
const EffectPokemonCatcher = preload("res://scripts/effects/trainer_effects/EffectPokemonCatcher.gd")
const EffectEnergySwitch = preload("res://scripts/effects/trainer_effects/EffectEnergySwitch.gd")
const EffectNightStretcher = preload("res://scripts/effects/trainer_effects/EffectNightStretcher.gd")
const EffectUnfairStamp = preload("res://scripts/effects/trainer_effects/EffectUnfairStamp.gd")
const EffectCarmine = preload("res://scripts/effects/trainer_effects/EffectCarmine.gd")
const AbilityMoveOpponentDamageCounters = preload("res://scripts/effects/pokemon_effects/AbilityMoveOpponentDamageCounters.gd")
const AbilityBenchDamageOnPlay = preload("res://scripts/effects/pokemon_effects/AbilityBenchDamageOnPlay.gd")
const AbilityPrizeCountColorlessReduction = preload("res://scripts/effects/pokemon_effects/AbilityPrizeCountColorlessReduction.gd")
const AttackCoinFlipApplyStatus = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipApplyStatus.gd")
const AttackCoinFlipOrFail = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipOrFail.gd")
const AbilitySelfHealVSTAR = preload("res://scripts/effects/pokemon_effects/AbilitySelfHealVSTAR.gd")
const AbilityMillDeckRecoverToHand = preload("res://scripts/effects/pokemon_effects/AbilityMillDeckRecoverToHand.gd")
const AttackAttachBasicEnergyFromDiscard = preload("res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromDiscard.gd")
const AbilityAttachBasicEnergyFromHandDraw = preload("res://scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandDraw.gd")
const AbilityLookTopToHand = preload("res://scripts/effects/pokemon_effects/AbilityLookTopToHand.gd")
const AbilityDrawIfKnockoutLastTurn = preload("res://scripts/effects/pokemon_effects/AbilityDrawIfKnockoutLastTurn.gd")
const AttackLostZoneEnergy = preload("res://scripts/effects/pokemon_effects/AttackLostZoneEnergy.gd")
const AttackLookTopPickHandRestLostZone = preload("res://scripts/effects/pokemon_effects/AttackLookTopPickHandRestLostZone.gd")
const AttackAnyTargetDamage = preload("res://scripts/effects/pokemon_effects/AttackAnyTargetDamage.gd")
const AttackKnockoutDefenderThenSelfDamage = preload("res://scripts/effects/pokemon_effects/AttackKnockoutDefenderThenSelfDamage.gd")
const AttackDefenderRetreatLockNextTurn = preload("res://scripts/effects/pokemon_effects/AttackDefenderRetreatLockNextTurn.gd")
const EffectGiftEnergy = preload("res://scripts/effects/energy_effects/EffectGiftEnergy.gd")
const EffectMistEnergy = preload("res://scripts/effects/energy_effects/EffectMistEnergy.gd")
const EffectVGuardEnergy = preload("res://scripts/effects/energy_effects/EffectVGuardEnergy.gd")


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		if _results.is_empty():
			return false
		var result: bool = _results.pop_front()
		coin_flipped.emit(result)
		return result


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
	cd.attacks = [{"name": "Test Attack", "cost": "CCC", "damage": "60", "text": "", "is_vstar_power": false}]
	return cd


func _make_trainer_data(name: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
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

		var active_cd := _make_basic_pokemon_data("Active%d" % pi, "C", 130)
		var active := _make_slot(active_cd, pi)
		player.active_pokemon = active

		for bi: int in 2:
			var bench_cd := _make_basic_pokemon_data("Bench%d_%d" % [pi, bi], "C", 90)
			var bench := _make_slot(bench_cd, pi)
			player.bench.append(bench)

		for di: int in 4:
			player.deck.append(CardInstance.create(_make_basic_pokemon_data("Deck%d_%d" % [pi, di], "C"), pi))

		for hi: int in 3:
			player.hand.append(CardInstance.create(_make_basic_pokemon_data("Hand%d_%d" % [pi, hi], "C"), pi))

		for pri: int in 6:
			player.prizes.append(CardInstance.create(_make_basic_pokemon_data("Prize%d_%d" % [pi, pri], "C"), pi))

		state.players.append(player)

	return state


func test_cs5_5c_065_roxanne_shuffle_draws_6_and_2() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	opponent.hand.clear()
	for i: int in 3:
		player.hand.append(CardInstance.create(_make_basic_pokemon_data("PHand_%d" % i, "C"), 0))
		opponent.hand.append(CardInstance.create(_make_basic_pokemon_data("OHand_%d" % i, "C"), 1))
	for i: int in 8:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("PDeck_%d" % i, "C"), 0))
		opponent.deck.append(CardInstance.create(_make_basic_pokemon_data("ODeck_%d" % i, "C"), 1))
	opponent.prizes.resize(3)

	var effect: EffectRoxanne = EffectRoxanne.new()
	var card := CardInstance.create(_make_trainer_data("CS5.5C_065 Roxanne", "Supporter"), 0)
	effect.execute(card, [], state)

	return run_checks([
		assert_true(effect.can_execute(card, state), "CS5.5C_065 should be playable when opponent has 3 or fewer prizes"),
		assert_eq(player.hand.size(), 6, "CS5.5C_065 should draw 6 for the user"),
		assert_eq(opponent.hand.size(), 2, "CS5.5C_065 should draw 2 for the opponent"),
	])


func test_cs5dc_140_cyllene_returns_selected_cards_to_top() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.discard_pile.clear()
	player.deck.clear()
	var keep := CardInstance.create(_make_basic_pokemon_data("Keep", "C"), 0)
	var top_a := CardInstance.create(_make_basic_pokemon_data("TopA", "C"), 0)
	var top_b := CardInstance.create(_make_basic_pokemon_data("TopB", "C"), 0)
	player.discard_pile.append(top_a)
	player.discard_pile.append(top_b)
	player.deck.append(keep)

	var effect: EffectCyllene = EffectCyllene.new(RiggedCoinFlipper.new([true, true]))
	var card := CardInstance.create(_make_trainer_data("CS5DC_140 Cyllene", "Supporter"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{"discard_to_top": [top_a, top_b]}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "CS5DC_140 should ask the player to choose cards from discard"),
		assert_eq(player.deck[0], top_a, "CS5DC_140 should place the first chosen card on top"),
		assert_eq(player.deck[1], top_b, "CS5DC_140 should place the second chosen card next"),
		assert_false(top_a in player.discard_pile, "CS5DC_140 should remove chosen cards from discard"),
	])


func test_cs6_5c_063_trekking_shoes_take_or_discard_top() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	var top := CardInstance.create(_make_basic_pokemon_data("TopCard", "C"), 0)
	player.deck.append(top)
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("DrawAfterDiscard", "C"), 0))

	var effect: EffectTrekkingShoes = EffectTrekkingShoes.new()
	var card := CardInstance.create(_make_trainer_data("CS6.5C_063 Trekking Shoes"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{"trekking_choice": ["discard"]}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "CS6.5C_063 should ask whether to keep or discard the top card"),
		assert_true(top in player.discard_pile, "CS6.5C_063 should discard the revealed card when declined"),
		assert_eq(player.hand.size(), 1, "CS6.5C_063 should draw one replacement card after discarding"),
	])


func test_csvh1c_047_pokemon_catcher_switches_only_on_heads() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var chosen: PokemonSlot = opponent.bench[1]
	var original_active := opponent.active_pokemon

	var effect: EffectPokemonCatcher = EffectPokemonCatcher.new(RiggedCoinFlipper.new([true]))
	var card := CardInstance.create(_make_trainer_data("CSVH1C_047 Pokemon Catcher"), 0)
	effect.execute(card, [{"opponent_bench_target": [chosen]}], state)
	var switched_on_heads: bool = opponent.active_pokemon == chosen and original_active in opponent.bench

	var tail_state := _make_state()
	var tail_opponent: PlayerState = tail_state.players[1]
	var tail_original := tail_opponent.active_pokemon
	var tail_effect: EffectPokemonCatcher = EffectPokemonCatcher.new(RiggedCoinFlipper.new([false]))
	tail_effect.execute(card, [{"opponent_bench_target": [tail_opponent.bench[0]]}], tail_state)

	return run_checks([
		assert_true(switched_on_heads, "CSVH1C_047 should gust on heads"),
		assert_eq(tail_opponent.active_pokemon, tail_original, "CSVH1C_047 should do nothing on tails"),
	])


func test_csvh1ac_008_energy_switch_moves_basic_energy() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var source := player.active_pokemon
	var target := player.bench[0]
	var energy := CardInstance.create(_make_energy_data("Basic Lightning", "L"), 0)
	source.attached_energy.clear()
	source.attached_energy.append(energy)
	target.attached_energy.clear()

	var effect: EffectEnergySwitch = EffectEnergySwitch.new()
	var card := CardInstance.create(_make_trainer_data("CSVH1aC_008 Energy Switch"), 0)
	effect.execute(card, [{
		"energy_assignment": [{"source": energy, "target": target}],
	}], state)

	return run_checks([
		assert_false(energy in source.attached_energy, "CSVH1aC_008 should remove the chosen Basic Energy from the source"),
		assert_true(energy in target.attached_energy, "CSVH1aC_008 should attach the chosen Basic Energy to the target"),
	])


func test_csv8c_183_night_stretcher_recovers_pokemon_or_energy_to_hand() -> String:
	# 卡牌描述：选择自己弃牌区中的1张宝可梦或1张基本能量，加入手牌。
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()
	var basic_pokemon := CardInstance.create(_make_basic_pokemon_data("Recovered Basic", "G"), 0)
	var basic_energy := CardInstance.create(_make_energy_data("Recovered Energy", "G"), 0)
	player.discard_pile.append(basic_pokemon)
	player.discard_pile.append(basic_energy)

	var effect: EffectNightStretcher = EffectNightStretcher.new()
	var card := CardInstance.create(_make_trainer_data("CSV8C_183 Night Stretcher"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	# 测试1：回收宝可梦到手牌
	effect.execute(card, [{
		"night_stretcher_choice": [basic_pokemon],
	}], state)
	var pokemon_to_hand_ok: bool = basic_pokemon in player.hand and basic_pokemon not in player.discard_pile

	# 测试2：回收基本能量到手牌（新状态）
	var hand_state := _make_state()
	var hand_player: PlayerState = hand_state.players[0]
	hand_player.hand.clear()
	hand_player.discard_pile.clear()
	var hand_energy := CardInstance.create(_make_energy_data("Recovered Energy 2", "W"), 0)
	hand_player.discard_pile.append(hand_energy)
	effect.execute(card, [{
		"night_stretcher_choice": [hand_energy],
	}], hand_state)
	var energy_to_hand_ok: bool = hand_energy in hand_player.hand and hand_energy not in hand_player.discard_pile

	# 测试3：不能选择物品卡（弃牌区只有物品时不可使用）
	var fail_state := _make_state()
	var fail_player: PlayerState = fail_state.players[0]
	fail_player.discard_pile.clear()
	fail_player.discard_pile.append(CardInstance.create(_make_trainer_data("Some Item"), 0))
	var cannot_use_with_only_trainer: bool = not effect.can_execute(card, fail_state)

	return run_checks([
		assert_eq(steps.size(), 1, "CSV8C_183 should present 1 selection step"),
		assert_true(pokemon_to_hand_ok, "CSV8C_183 should recover a Pokemon from discard to hand"),
		assert_true(energy_to_hand_ok, "CSV8C_183 should recover a Basic Energy from discard to hand"),
		assert_true(cannot_use_with_only_trainer, "CSV8C_183 should not be usable when discard has no Pokemon or Basic Energy"),
	])


func test_csv8c_173_unfair_stamp_requires_recent_knockout() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	opponent.hand.clear()
	for i: int in 3:
		player.hand.append(CardInstance.create(_make_basic_pokemon_data("PHand_%d" % i, "C"), 0))
		opponent.hand.append(CardInstance.create(_make_basic_pokemon_data("OHand_%d" % i, "C"), 1))
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("PDraw_%d" % i, "C"), 0))
		opponent.deck.append(CardInstance.create(_make_basic_pokemon_data("ODraw_%d" % i, "C"), 1))
	state.last_knockout_turn_against[0] = state.turn_number - 1

	var effect: EffectUnfairStamp = EffectUnfairStamp.new()
	var card := CardInstance.create(_make_trainer_data("CSV8C_173 Unfair Stamp"), 0)
	effect.execute(card, [], state)

	var fail_state := _make_state()
	var fail_effect: EffectUnfairStamp = EffectUnfairStamp.new()

	return run_checks([
		assert_true(effect.can_execute(card, state), "CSV8C_173 should require one of your Pokemon to have been KO'd during the opponent's last turn"),
		assert_eq(player.hand.size(), 5, "CSV8C_173 should draw 5 for the user"),
		assert_eq(opponent.hand.size(), 2, "CSV8C_173 should draw 2 for the opponent"),
		assert_false(fail_effect.can_execute(card, fail_state), "CSV8C_173 should not be playable without the knockout condition"),
	])


func test_csv8c_199_carmine_allows_first_turn_supporter_play() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.game_state.turn_number = 1
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.supporter_used_this_turn = false

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	for i: int in 4:
		player.hand.append(CardInstance.create(_make_basic_pokemon_data("Discard_%d" % i, "C"), 0))
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Draw_%d" % i, "C"), 0))
	var card_data := _make_trainer_data("CSV8C_199 Carmine", "Supporter", "8150af4062192998497e376ad931bea4")
	var card := CardInstance.create(card_data, 0)
	player.hand.append(card)
	gsm.effect_processor.register_effect(card_data.effect_id, EffectCarmine.new())

	var success := gsm.play_trainer(0, card, [])

	return run_checks([
		assert_true(success, "CSV8C_199 should be playable on the first turn going first"),
		assert_eq(player.hand.size(), 5, "CSV8C_199 should discard the old hand and draw 5"),
		assert_true(gsm.game_state.supporter_used_this_turn, "CSV8C_199 should still count as the supporter for the turn"),
	])


func test_csv6c_125_professor_turos_scenario_exposes_required_interaction_steps() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()

	var card_data := _make_trainer_data(
		"CSV6C_125 Professor Turo's Scenario",
		"Supporter",
		"73d5f46ecf3a6d71b23ce7bc1a28d4f4"
	)
	var card := CardInstance.create(card_data, 0)
	player.hand.append(card)
	var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	var target_items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var replacement_items: Array = steps[1].get("items", []) if steps.size() > 1 else []
	var first_step_id: String = str(steps[0].get("id", "")) if not steps.is_empty() else ""
	var second_step_id: String = str(steps[1].get("id", "")) if steps.size() > 1 else ""

	return run_checks([
		assert_eq(steps.size(), 2, "CSV6C_125 should ask for a target and, when active is eligible, a replacement"),
		assert_eq(first_step_id, "prof_turo_target", "CSV6C_125 target step id should be stable"),
		assert_true(player.active_pokemon in target_items, "CSV6C_125 should allow selecting the active Pokemon when a bench replacement exists"),
		assert_true(player.bench[0] in target_items and player.bench[1] in target_items, "CSV6C_125 should allow selecting benched Pokemon"),
		assert_eq(second_step_id, "prof_turo_replacement", "CSV6C_125 replacement step id should be stable"),
		assert_eq(replacement_items.size(), player.bench.size(), "CSV6C_125 replacement step should offer all benched Pokemon"),
	])


func test_csv6c_125_professor_turos_scenario_respects_selection_and_returns_entire_pokemon_stack_to_hand() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.discard_pile.clear()

	var basic_data := _make_basic_pokemon_data("Turo Basic", "P", 70)
	var stage1_data := _make_basic_pokemon_data("Turo Stage 1", "P", 120, "Stage 1")
	stage1_data.evolves_from = "Turo Basic"
	var basic := CardInstance.create(basic_data, 0)
	var stage1 := CardInstance.create(stage1_data, 0)
	var attached_energy := CardInstance.create(_make_energy_data("Psychic Energy", "P"), 0)
	var attached_tool := CardInstance.create(_make_trainer_data("Rescue Board", "Tool"), 0)
	var active := PokemonSlot.new()
	active.pokemon_stack.append(basic)
	active.pokemon_stack.append(stage1)
	active.attached_energy.append(attached_energy)
	active.attached_tool = attached_tool
	active.turn_played = 0
	player.active_pokemon = active

	var bench_a: PokemonSlot = player.bench[0]
	var bench_b: PokemonSlot = player.bench[1]
	var card_data := _make_trainer_data(
		"CSV6C_125 Professor Turo's Scenario",
		"Supporter",
		"73d5f46ecf3a6d71b23ce7bc1a28d4f4"
	)
	var card := CardInstance.create(card_data, 0)
	player.hand.append(card)

	var success := gsm.play_trainer(0, card, [{
		"prof_turo_target": [active],
		"prof_turo_replacement": [bench_b],
	}])

	return run_checks([
		assert_true(success, "CSV6C_125 should resolve through GameStateMachine"),
		assert_eq(player.active_pokemon, bench_b, "CSV6C_125 should promote the selected replacement when the active Pokemon is returned"),
		assert_true(bench_a in player.bench, "CSV6C_125 should leave unselected benched Pokemon in place"),
		assert_false(bench_b in player.bench, "CSV6C_125 should remove the promoted replacement from the bench"),
		assert_true(basic in player.hand and stage1 in player.hand, "CSV6C_125 should return every Pokemon card in the selected stack to hand"),
		assert_false(basic in player.discard_pile or stage1 in player.discard_pile, "CSV6C_125 should not discard Pokemon cards from the selected stack"),
		assert_true(attached_energy in player.discard_pile, "CSV6C_125 should discard attached Energy"),
		assert_true(attached_tool in player.discard_pile, "CSV6C_125 should discard attached Tools"),
		assert_true(card in player.discard_pile, "CSV6C_125 should discard the Supporter after use"),
		assert_eq(active.pokemon_stack.size(), 0, "CSV6C_125 should clear the returned slot's Pokemon stack"),
		assert_eq(active.attached_energy.size(), 0, "CSV6C_125 should clear the returned slot's attached Energy"),
		assert_eq(active.attached_tool, null, "CSV6C_125 should clear the returned slot's attached Tool"),
	])


func test_cs6bc_028_radiant_alakazam_moves_selected_damage_counters() -> String:
	var state := _make_state()
	var opponent: PlayerState = state.players[1]
	var source := opponent.active_pokemon
	var target := opponent.bench[0]
	source.damage_counters = 50
	target.damage_counters = 10
	var ability: AbilityMoveOpponentDamageCounters = AbilityMoveOpponentDamageCounters.new()

	ability.execute_ability(_make_slot(_make_basic_pokemon_data("CS6bC_028 Radiant Alakazam", "P"), 0), 0, [{
		"source_pokemon": [source],
		"target_pokemon": [target],
		"counter_count": [2],
	}], state)

	return run_checks([
		assert_eq(source.damage_counters, 30, "CS6bC_028 should move up to 2 counters off the source"),
		assert_eq(target.damage_counters, 30, "CS6bC_028 should add the moved counters to the target"),
	])


func test_csv1c_079_hawlucha_places_counters_on_two_bench_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var ability: AbilityBenchDamageOnPlay = AbilityBenchDamageOnPlay.new(10, 2)
	var hawlucha_slot := _make_slot(_make_basic_pokemon_data("CSV1C_079 Hawlucha", "F"), 0)
	hawlucha_slot.turn_played = state.turn_number
	player.bench.append(hawlucha_slot)
	state.current_player_index = 1
	var cannot_use_on_opponent_turn: bool = not ability.can_use_ability(hawlucha_slot, state)
	state.current_player_index = 0

	ability.execute_ability(hawlucha_slot, 0, [{
		"opponent_bench_targets": [opponent.bench[0], opponent.bench[1]],
	}], state)

	return run_checks([
		assert_true(cannot_use_on_opponent_turn, "CSV1C_079 should only be usable during its controller's turn"),
		assert_eq(opponent.bench[0].damage_counters, 10, "CSV1C_079 should place 1 counter on the first chosen bench target"),
		assert_eq(opponent.bench[1].damage_counters, 10, "CSV1C_079 should place 1 counter on the second chosen bench target"),
	])


func test_csv8c_172_bloodmoon_ursaluna_reduces_colorless_cost() -> String:
	var state := _make_state()
	# 对手（玩家1）已获得4张奖赏卡，剩余2张
	state.players[1].prizes.resize(2)
	var player: PlayerState = state.players[0]
	var bloodmoon_cd := _make_basic_pokemon_data(
		"CSV8C_172 Bloodmoon Ursaluna ex",
		"C",
		260,
		"Basic",
		"ex",
		"f2afef80b13b8f6a071facbcade0251c"
	)
	bloodmoon_cd.abilities = [{"name": "老练招式"}]
	bloodmoon_cd.attacks = [{"name": "Blood Moon", "cost": "CCCCC", "damage": "240", "text": "", "is_vstar_power": false}]
	var slot := _make_slot(bloodmoon_cd, 0)
	slot.attached_energy.clear()
	slot.attached_energy.append(CardInstance.create(_make_energy_data("C1", "C"), 0))
	player.active_pokemon = slot

	var processor := EffectProcessor.new()
	processor.register_effect(bloodmoon_cd.effect_id, AbilityPrizeCountColorlessReduction.new("Blood Moon"))
	var validator := RuleValidator.new()
	var can_attack := validator.can_use_attack(state, 0, 0, processor)

	return run_checks([
		assert_true(can_attack, "对手已获得4张奖赏卡时，血月只需1个无色能量即可使用"),
		assert_eq(processor.get_attack_colorless_cost_modifier(slot, bloodmoon_cd.attacks[0], state), -4, "对手已获得4张奖赏卡时，无色能量减少4个"),
	])


func test_cs5_5c_032_duskull_confuses_on_heads() -> String:
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	var defender := state.players[1].active_pokemon
	var effect := AttackCoinFlipApplyStatus.new("confused", RiggedCoinFlipper.new([true]))

	effect.execute_attack(attacker, defender, 0, state)

	return run_checks([
		assert_true(defender.status_conditions.get("confused", false), "CS5.5C_032 should confuse on heads"),
	])


func test_cs5_5c_053_goodra_vstar_heals_all_damage() -> String:
	var state := _make_state()
	var slot := state.players[0].active_pokemon
	slot.damage_counters = 140
	var ability := AbilitySelfHealVSTAR.new()

	ability.execute_ability(slot, 0, [], state)

	return run_checks([
		assert_eq(slot.damage_counters, 0, "CS5.5C_053 should heal all damage"),
		assert_true(state.vstar_power_used[0], "CS5.5C_053 should consume the player's VSTAR power"),
	])


func test_cs6_5c_055_regidrago_vstar_mills_and_recovers() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.discard_pile.clear()
	player.hand.clear()
	var existing_discard := CardInstance.create(_make_basic_pokemon_data("Existing Recover", "C"), 0)
	var deck_a := CardInstance.create(_make_basic_pokemon_data("Recover A", "C"), 0)
	var deck_b := CardInstance.create(_make_basic_pokemon_data("Recover B", "C"), 0)
	player.discard_pile.append(existing_discard)
	player.deck.append(deck_a)
	player.deck.append(deck_b)
	var ability := AbilityMillDeckRecoverToHand.new(2, 2, true)
	var slot := player.active_pokemon
	state.current_player_index = 1
	var cannot_use_on_opponent_turn: bool = not ability.can_use_ability(slot, state)
	state.current_player_index = 0

	ability.execute_ability(slot, 0, [{"recover_cards": [existing_discard, deck_a]}], state)

	return run_checks([
		assert_true(cannot_use_on_opponent_turn, "CS6.5C_055 should only be usable during its controller's turn"),
		assert_true(existing_discard in player.hand and deck_a in player.hand, "CS6.5C_055 should recover cards from the full discard pile after milling"),
		assert_true(deck_b in player.discard_pile, "CS6.5C_055 should leave unchosen milled cards in the discard pile"),
		assert_true(state.vstar_power_used[0], "CS6.5C_055 should consume the player's VSTAR power"),
	])


func test_csnc_008_dialga_v_attaches_metal_from_discard() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var attacker := player.active_pokemon
	player.discard_pile.clear()
	player.discard_pile.append(CardInstance.create(_make_energy_data("Metal A", "M"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_data("Metal B", "M"), 0))
	var effect := AttackAttachBasicEnergyFromDiscard.new("M", 2)

	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_eq(attacker.attached_energy.size(), 2, "CSNC_008 should attach up to 2 Metal Energy from discard"),
		assert_eq(player.discard_pile.size(), 0, "CSNC_008 should remove attached energy from discard"),
	])


func test_csv8c_028_teal_mask_ogerpon_attaches_grass_from_hand_and_draws() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var slot := player.active_pokemon
	player.hand.clear()
	player.deck.clear()
	var grass := CardInstance.create(_make_energy_data("Grass", "G"), 0)
	player.hand.append(grass)
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("Drawn", "C"), 0))
	var ability := AbilityAttachBasicEnergyFromHandDraw.new("G", 1)
	state.current_player_index = 1
	var cannot_use_on_opponent_turn: bool = not ability.can_use_ability(slot, state)
	state.current_player_index = 0

	ability.execute_ability(slot, 0, [{"basic_energy_from_hand": [grass]}], state)

	return run_checks([
		assert_true(cannot_use_on_opponent_turn, "CSV8C_028 should only be usable during its controller's turn"),
		assert_true(grass in slot.attached_energy, "CSV8C_028 should attach a Basic Grass Energy from hand"),
		assert_eq(player.hand.size(), 1, "CSV8C_028 should draw 1 after attaching"),
	])


func test_csv8c_158_and_csv8c_160_look_top_to_hand_families() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.hand.clear()
	var supporter := CardInstance.create(_make_trainer_data("Supporter", "Supporter"), 0)
	var item := CardInstance.create(_make_trainer_data("Item", "Item"), 0)
	player.deck.append(item)
	player.deck.append(supporter)
	var drakloak := AbilityLookTopToHand.new(2, "", false, false, true)
	var tatsugiri := AbilityLookTopToHand.new(2, "Supporter", true, true, false)
	var active := player.active_pokemon

	drakloak.execute_ability(active, 0, [{"look_top_pick": [supporter]}], state)
	var drakloak_ok: bool = supporter in player.hand and player.deck.back() == item

	player.deck.clear()
	player.hand.clear()
	player.deck.append(item)
	player.deck.append(supporter)
	tatsugiri.execute_ability(active, 0, [{"look_top_pick": [supporter]}], state)

	return run_checks([
		assert_true(drakloak_ok, "CSV8C_158 should take one card and put the rest on the bottom"),
		assert_true(supporter in player.hand, "CSV8C_160 should find a Supporter from the looked-at cards"),
	])


func test_csv8c_135_fezandipiti_draws_after_knockout_last_turn() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.hand.clear()
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Draw_%d" % i, "C"), 0))
	state.last_knockout_turn_against[0] = state.turn_number - 1
	var ability := AbilityDrawIfKnockoutLastTurn.new(3, "fezandipiti")
	state.current_player_index = 1
	var cannot_use_on_opponent_turn: bool = not ability.can_use_ability(player.active_pokemon, state)
	state.current_player_index = 0

	ability.execute_ability(player.active_pokemon, 0, [], state)

	return run_checks([
		assert_true(cannot_use_on_opponent_turn, "CSV8C_135 should only be usable during its controller's turn"),
		assert_eq(player.hand.size(), 3, "CSV8C_135 should draw 3 when your Pokemon was KO'd during the opponent's last turn"),
	])


func test_csv8c_135_fezandipiti_ability_unlocks_after_real_knockout_flow() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	state.current_player_index = 1
	state.turn_number = 3

	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Fez Draw %d" % i, "C"), 0))

	var knocked_out_active := _make_slot(_make_basic_pokemon_data("KO Target", "C", 120), 0)
	knocked_out_active.damage_counters = 120
	player.active_pokemon = knocked_out_active

	var fez_cd := _make_basic_pokemon_data("CSV8C_135 Fezandipiti ex", "D", 210, "Basic", "ex", "ab6c3357e2b8a8385a68da738f41e0c1")
	fez_cd.abilities = [{"name": "Flip the Script"}]
	fez_cd.attacks = [{"name": "Cruel Arrow", "cost": "CCC", "damage": "", "text": "", "is_vstar_power": false}]
	gsm.effect_processor.register_pokemon_card(fez_cd)

	var fez_slot := _make_slot(fez_cd, 0)
	var replacement_slot := _make_slot(_make_basic_pokemon_data("Replacement", "C", 130), 0)
	player.bench.clear()
	player.bench.append(fez_slot)
	player.bench.append(replacement_slot)

	gsm._check_all_knockouts()
	var take_prize_ok := gsm.resolve_take_prize(1, 0)
	var send_out_ok := gsm.send_out_pokemon(0, replacement_slot)
	var hand_before_ability := player.hand.size()
	var ability_ok := gsm.use_ability(0, fez_slot, 0)

	return run_checks([
		assert_eq(state.last_knockout_turn_against[0], 3, "CSV8C_135 should record the turn when your Pokemon was KO'd"),
		assert_true(take_prize_ok, "CSV8C_135 regression should still require the opponent to take a prize before replacement"),
		assert_true(send_out_ok, "CSV8C_135 regression should finish the knockout replacement flow"),
		assert_eq(state.current_player_index, 0, "CSV8C_135 regression should return to the knocked-out player's turn"),
		assert_true(ability_ok, "CSV8C_135 should become usable after a real knockout on the opponent's turn"),
		assert_eq(player.hand.size(), hand_before_ability + 3, "CSV8C_135 should draw 3 cards through GameStateMachine.use_ability"),
	])


func test_cs5bc_128_temple_of_sinnoh_turns_special_energy_into_one_colorless() -> String:
	var processor := EffectProcessor.new()
	var stadium_data := _make_trainer_data("CS5bC_128 Temple of Sinnoh", "Stadium", "53864b068a4a1e8dce3c53c884b67efa")
	var energy_data := _make_energy_data("Double Turbo", "", "Special Energy", "9c04dd0addf56a7b2c88476bc8e45c0e")
	var stadium_card := CardInstance.create(stadium_data, 0)
	var energy_card := CardInstance.create(energy_data, 0)
	var state := _make_state()
	state.stadium_card = stadium_card
	state.stadium_owner_index = 0

	return run_checks([
		assert_true(processor.has_effect(stadium_data.effect_id), "CS5bC_128 should be registered"),
		assert_eq(processor.get_energy_type(energy_card, state), "C", "CS5bC_128 should make Special Energy provide only Colorless"),
		assert_eq(processor.get_energy_colorless_count(energy_card, state), 1, "CS5bC_128 should reduce Double Turbo to one energy"),
	])


func test_csv5c_127_mela_attaches_two_fire_then_draws_to_six() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	state.last_knockout_turn_against[0] = state.turn_number - 1

	var target := player.active_pokemon
	var fire_a := CardInstance.create(_make_energy_data("Fire A", "R"), 0)
	var fire_b := CardInstance.create(_make_energy_data("Fire B", "R"), 0)
	player.discard_pile.append(fire_a)
	player.discard_pile.append(fire_b)
	for i: int in 8:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Mela Draw %d" % i, "C"), 0))

	var card := CardInstance.create(_make_trainer_data("CSV5C_127 Mela", "Supporter", "f9162d9c9d98c74523257f17dcb6053b"), 0)
	player.hand.append(card)
	var success := gsm.play_trainer(0, card, [{
		"mela_target": [target],
		"mela_energy": [fire_a],
	}])

	return run_checks([
		assert_true(success, "CSV5C_127 昏厥条件满足时应可使用"),
		assert_eq(target.attached_energy.size(), 1, "CSV5C_127 应附着1张基本火能量"),
		assert_eq(player.hand.size(), 6, "CSV5C_127 应抽卡到手牌6张"),
	])


func test_csv6c_121_sada_attaches_to_two_ancient_then_draws_three() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var ancient_a_cd := _make_basic_pokemon_data("Ancient A", "F", 120, "Basic", "", "ancient_a")
	ancient_a_cd.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	var ancient_b_cd := _make_basic_pokemon_data("Ancient B", "D", 120, "Basic", "", "ancient_b")
	ancient_b_cd.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	player.active_pokemon = _make_slot(ancient_a_cd, 0)
	player.bench.clear()
	player.bench.append(_make_slot(ancient_b_cd, 0))

	var e1 := CardInstance.create(_make_energy_data("Ancient Energy 1", "F"), 0)
	var e2 := CardInstance.create(_make_energy_data("Ancient Energy 2", "D"), 0)
	player.discard_pile.append(e1)
	player.discard_pile.append(e2)
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Sada Draw %d" % i, "C"), 0))

	var card := CardInstance.create(_make_trainer_data("CSV6C_121 Professor Sada's Vitality", "Supporter", "651276c51911345aa091c1c7b87f3f4f"), 0)
	player.hand.append(card)
	var success := gsm.play_trainer(0, card, [{
		"sada_assignments": [
			{"source": e1, "target": player.active_pokemon},
			{"source": e2, "target": player.bench[0]},
		],
	}])

	return run_checks([
		assert_true(success, "CSV6C_121 should resolve when Ancient targets and energy exist"),
		assert_eq(player.active_pokemon.attached_energy.size(), 1, "CSV6C_121 should attach to the first chosen Ancient Pokemon"),
		assert_eq(player.bench[0].attached_energy.size(), 1, "CSV6C_121 should attach to the second chosen Ancient Pokemon"),
		assert_eq(player.hand.size(), 3, "CSV6C_121 should draw 3 cards"),
	])


func test_csv6c_121_sada_recognizes_cached_ancient_cards() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var raging_bolt: CardData = CardDatabase.get_card("CSV7C", "154")
	var flutter_mane: CardData = CardDatabase.get_card("CSV7C", "109")
	if raging_bolt == null or flutter_mane == null:
		return "CSV6C_121 cached Ancient fixtures are missing"

	player.active_pokemon = _make_slot(raging_bolt, 0)
	player.bench.clear()
	player.bench.append(_make_slot(flutter_mane, 0))

	var e1 := CardInstance.create(_make_energy_data("Cached Ancient Energy 1", "F"), 0)
	var e2 := CardInstance.create(_make_energy_data("Cached Ancient Energy 2", "L"), 0)
	player.discard_pile.append(e1)
	player.discard_pile.append(e2)
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Cached Sada Draw %d" % i, "C"), 0))

	var card := CardInstance.create(_make_trainer_data("CSV6C_121 Professor Sada's Vitality", "Supporter", "651276c51911345aa091c1c7b87f3f4f"), 0)
	player.hand.append(card)
	var success := gsm.play_trainer(0, card, [{
		"sada_assignments": [
			{"source": e1, "target": player.active_pokemon},
			{"source": e2, "target": player.bench[0]},
		],
	}])

	return run_checks([
		assert_true(raging_bolt.is_ancient_pokemon(), "CSV7C_154 should be recognized as Ancient from cached data"),
		assert_true(flutter_mane.is_ancient_pokemon(), "CSV7C_109 should be recognized as Ancient from cached data"),
		assert_true(success, "CSV6C_121 should resolve against cached Ancient Pokemon"),
		assert_eq(player.active_pokemon.attached_energy.size(), 1, "CSV6C_121 should attach to cached Ancient active Pokemon"),
		assert_eq(player.bench[0].attached_energy.size(), 1, "CSV6C_121 should attach to cached Ancient bench Pokemon"),
	])


func test_csv6c_121_sada_recognizes_all_local_ancient_cards() -> String:
	var expected_uids := [
		"CSV6C_065",
		"CSV6C_082",
		"CSV6C_096",
		"CSV7C_051",
		"CSV7C_109",
		"CSV7C_154",
	]
	var checks: Array[String] = []
	for uid: String in expected_uids:
		var parts := uid.split("_")
		var card: CardData = CardDatabase.get_card(parts[0], parts[1])
		checks.append(assert_not_null(card, "%s should exist in the local card database" % uid))
		if card != null:
			checks.append(assert_true(card.is_ancient_pokemon(), "%s %s should be recognized as Ancient" % [uid, card.name_en]))
	return run_checks(checks)


func test_csv6c_121_sada_targets_roaring_moon_ex_and_scream_tail_from_cache() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var roaring_moon: CardData = CardDatabase.get_card("CSV6C", "096")
	var scream_tail: CardData = CardDatabase.get_card("CSV6C", "065")
	if roaring_moon == null or scream_tail == null:
		return "CSV6C_121 roaring_moon / scream_tail cached fixtures are missing"

	player.active_pokemon = _make_slot(roaring_moon, 0)
	player.bench.clear()
	player.bench.append(_make_slot(scream_tail, 0))

	var e1 := CardInstance.create(_make_energy_data("Roaring Sada Energy 1", "D"), 0)
	var e2 := CardInstance.create(_make_energy_data("Roaring Sada Energy 2", "P"), 0)
	player.discard_pile.append(e1)
	player.discard_pile.append(e2)
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Roaring Sada Draw %d" % i, "C"), 0))

	var card := CardInstance.create(_make_trainer_data("CSV6C_121 Professor Sada's Vitality", "Supporter", "651276c51911345aa091c1c7b87f3f4f"), 0)
	player.hand.append(card)
	var success := gsm.play_trainer(0, card, [{
		"sada_assignments": [
			{"source": e1, "target": player.active_pokemon},
			{"source": e2, "target": player.bench[0]},
		],
	}])

	return run_checks([
		assert_true(roaring_moon.is_ancient_pokemon(), "CSV6C_096 should be recognized as Ancient from cached data"),
		assert_true(scream_tail.is_ancient_pokemon(), "CSV6C_065 should be recognized as Ancient from cached data"),
		assert_true(success, "CSV6C_121 should resolve against Roaring Moon ex and Scream Tail"),
		assert_eq(player.active_pokemon.attached_energy.size(), 1, "CSV6C_121 should attach to cached Roaring Moon ex"),
		assert_eq(player.bench[0].attached_energy.size(), 1, "CSV6C_121 should attach to cached Scream Tail"),
	])


func test_csv6c_121_sada_targets_gouging_fire_ex_from_cache() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var gouging_fire: CardData = CardDatabase.get_card("CSV7C", "051")
	var raging_bolt: CardData = CardDatabase.get_card("CSV7C", "154")
	if gouging_fire == null or raging_bolt == null:
		return "CSV6C_121 gouging_fire / raging_bolt cached fixtures are missing"

	player.active_pokemon = _make_slot(gouging_fire, 0)
	player.bench.clear()
	player.bench.append(_make_slot(raging_bolt, 0))

	var e1 := CardInstance.create(_make_energy_data("Gouging Sada Energy 1", "R"), 0)
	var e2 := CardInstance.create(_make_energy_data("Gouging Sada Energy 2", "L"), 0)
	player.discard_pile.append(e1)
	player.discard_pile.append(e2)
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Gouging Sada Draw %d" % i, "C"), 0))

	var card := CardInstance.create(_make_trainer_data("CSV6C_121 Professor Sada's Vitality", "Supporter", "651276c51911345aa091c1c7b87f3f4f"), 0)
	player.hand.append(card)
	var success := gsm.play_trainer(0, card, [{
		"sada_assignments": [
			{"source": e1, "target": player.active_pokemon},
			{"source": e2, "target": player.bench[0]},
		],
	}])

	return run_checks([
		assert_true(gouging_fire.is_ancient_pokemon(), "CSV7C_051 should be recognized as Ancient from cached data"),
		assert_true(raging_bolt.is_ancient_pokemon(), "CSV7C_154 should still be recognized as Ancient from cached data"),
		assert_true(success, "CSV6C_121 should resolve against Gouging Fire ex and Raging Bolt ex"),
		assert_eq(player.active_pokemon.attached_energy.size(), 1, "CSV6C_121 should attach to cached Gouging Fire ex"),
		assert_eq(player.bench[0].attached_energy.size(), 1, "CSV6C_121 should attach to cached Raging Bolt ex"),
	])


func test_csv7c_201_gravity_mountain_reduces_stage2_hp() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var stadium_data := _make_trainer_data("CSV7C_201 Gravity Mountain", "Stadium", "aee486132c2ba880232a477fe0fe7a03")
	state.stadium_card = CardInstance.create(stadium_data, 0)
	state.stadium_owner_index = 0
	var stage2_cd := _make_basic_pokemon_data("Stage2 Target", "P", 320, "Stage 2", "ex")
	var stage2_slot := _make_slot(stage2_cd, 1)
	stage2_slot.damage_counters = 300

	return run_checks([
		assert_true(processor.has_effect(stadium_data.effect_id), "CSV7C_201 should be registered"),
		assert_eq(processor.get_effective_max_hp(stage2_slot, state), 290, "CSV7C_201 should reduce Stage 2 max HP by 30"),
		assert_true(processor.is_effectively_knocked_out(stage2_slot, state), "CSV7C_201 should make over-damaged Stage 2 Pokemon effectively knocked out"),
	])


func test_csv8c_067_wellspring_mask_ogerpon_ex_attack_family() -> String:
	var processor := EffectProcessor.new()
	var card_data := _make_basic_pokemon_data("CSV8C_067 Wellspring Mask Ogerpon ex", "W", 210, "Basic", "ex", "14cf8080c35f652fe13a579f1b50542a")
	card_data.attacks = [
		{"name": "Bind Up", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false},
		{"name": "Torrential Pump", "cost": "WCC", "damage": "100", "text": "", "is_vstar_power": false},
	]
	processor.register_pokemon_card(card_data)
	var state := _make_state()
	var attacker := _make_slot(card_data, 0)
	var defender := state.players[1].active_pokemon
	var bench_target := state.players[1].bench[0]
	var energy1 := CardInstance.create(_make_energy_data("Water", "W"), 0)
	var energy2 := CardInstance.create(_make_energy_data("Colorless1", "C"), 0)
	var energy3 := CardInstance.create(_make_energy_data("Colorless2", "C"), 0)
	attacker.attached_energy.clear()
	attacker.attached_energy.append(energy1)
	attacker.attached_energy.append(energy2)
	attacker.attached_energy.append(energy3)

	processor.execute_attack_effect(attacker, 0, defender, state)
	var lock_applied := defender.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == "retreat_lock")

	processor.execute_attack_effect(attacker, 1, defender, state, [{
		"return_energy_to_deck": [energy1, energy2, energy3],
		"bench_target": [bench_target],
	}])

	return run_checks([
		assert_true(processor.has_attack_effect(card_data.effect_id), "CSV8C_067 should register scripted attacks"),
		assert_true(lock_applied, "CSV8C_067 first attack should stop retreat next turn"),
		assert_eq(bench_target.damage_counters, 120, "CSV8C_067 second attack should place 120 on the chosen bench target when energy is returned"),
	])


func test_csv8c_083_dusknoir_attack_locks_retreat() -> String:
	var processor := EffectProcessor.new()
	var card_data := _make_basic_pokemon_data("CSV8C_083 Dusknoir", "P", 160, "Stage 2", "", "2a4178f21ba2bf13285bbb43ecaaa472")
	card_data.abilities = [{"name": "Cursed Blast"}]
	card_data.attacks = [{"name": "Shadow Bind", "cost": "PPC", "damage": "150", "text": "", "is_vstar_power": false}]
	processor.register_pokemon_card(card_data)
	var state := _make_state()
	var attacker := _make_slot(card_data, 0)
	var defender := state.players[1].active_pokemon

	processor.execute_attack_effect(attacker, 0, defender, state)

	return run_checks([
		assert_true(processor.has_attack_effect(card_data.effect_id), "CSV8C_083 should register its scripted attack"),
		assert_true(defender.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == "retreat_lock"), "CSV8C_083 should apply retreat lock"),
	])


func test_csv8c_121_cornerstone_mask_ogerpon_ex_blocks_damage_from_attackers_with_abilities() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state

	var attacker_cd := _make_basic_pokemon_data("Attacker With Ability", "F", 230, "Basic", "ex", "attacker_with_ability")
	attacker_cd.abilities = [{"name": "Has Ability"}]
	attacker_cd.attacks = [{"name": "Strike", "cost": "FCC", "damage": "140", "text": "", "is_vstar_power": false}]
	var defender_cd := _make_basic_pokemon_data("CSV8C_121 Cornerstone Mask Ogerpon ex", "F", 210, "Basic", "ex", "4f25f668ee0ab45c68f6954324c73003")
	defender_cd.abilities = [{"name": "Cornerstone Stance"}]
	defender_cd.attacks = [{"name": "Demolish", "cost": "FCC", "damage": "140", "text": "", "is_vstar_power": false}]
	gsm.effect_processor.register_pokemon_card(attacker_cd)
	gsm.effect_processor.register_pokemon_card(defender_cd)
	state.players[0].active_pokemon = _make_slot(attacker_cd, 0)
	state.players[1].active_pokemon = _make_slot(defender_cd, 1)
	state.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_energy_data("F1", "F"), 0))
	state.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_energy_data("C1", "C"), 0))
	state.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_energy_data("C2", "C"), 0))

	var success := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(success, "CSV8C_121 regression should still execute the attack flow"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 0, "CSV8C_121 should ignore damage from opponents with abilities"),
	])


func test_cancel_cologne_disables_cornerstone_mask_immunity() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN

	# 攻击方（玩家0）：有特性的宝可梦
	var attacker_cd := _make_basic_pokemon_data("Attacker With Ability", "P", 300, "Basic", "ex", "attacker_cancel_cologne")
	attacker_cd.abilities = [{"name": "Some Ability"}]
	attacker_cd.attacks = [{"name": "Shadow Claw", "cost": "P", "damage": "100", "text": "", "is_vstar_power": false}]
	# 防御方（玩家1）：础石面具 厄诡椪ex
	var defender_cd := _make_basic_pokemon_data("Cornerstone Ogerpon ex", "F", 210, "Basic", "ex", "4f25f668ee0ab45c68f6954324c73003")
	defender_cd.abilities = [{"name": "础石之姿"}]
	defender_cd.attacks = [{"name": "Demolish", "cost": "FCC", "damage": "140", "text": "", "is_vstar_power": false}]
	gsm.effect_processor.register_pokemon_card(attacker_cd)
	gsm.effect_processor.register_pokemon_card(defender_cd)

	state.players[0].active_pokemon = _make_slot(attacker_cd, 0)
	state.players[1].active_pokemon = _make_slot(defender_cd, 1)
	state.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_energy_data("P1", "P"), 0))

	# 先确认不用清除古龙水时，伤害被挡
	var blocked := gsm.effect_processor.is_damage_prevented_by_defender_ability(
		state.players[0].active_pokemon, state.players[1].active_pokemon, state)

	# 使用清除古龙水：在对手战斗宝可梦上标记 ability_disabled
	var cologne_cd := CardData.new()
	cologne_cd.name = "清除古龙水"
	cologne_cd.card_type = "Item"
	cologne_cd.effect_id = "66b2f1d77328b6578b1bf0d58d98f66b"
	var cologne := CardInstance.create(cologne_cd, 0)
	gsm.effect_processor.register_pokemon_card(cologne_cd)
	var cologne_effect := EffectCancelCologne.new()
	cologne_effect.execute(cologne, [], state)

	# 确认清除古龙水后，特性被禁用
	var disabled_after := gsm.effect_processor.is_ability_disabled(state.players[1].active_pokemon, state)

	# 确认伤害不再被挡
	var unblocked := gsm.effect_processor.is_damage_prevented_by_defender_ability(
		state.players[0].active_pokemon, state.players[1].active_pokemon, state)

	# 实际攻击验证
	var success := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(blocked, "础石之姿应挡住有特性攻击者的伤害"),
		assert_true(disabled_after, "清除古龙水应禁用对手战斗宝可梦的特性"),
		assert_false(unblocked, "清除古龙水后，础石之姿不应再挡伤害"),
		assert_true(success, "攻击应正常执行"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 100, "清除古龙水后，攻击应造成正常伤害"),
	])


func test_csv8c_165_blissey_ex_moves_basic_energy_to_another_pokemon_once_per_turn() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]

	var blissey_cd := _make_basic_pokemon_data("CSV8C_165 Blissey ex", "C", 300, "Stage 1", "ex", "4550f14d2ebd9d202a0c4ea5af9ec4d9")
	blissey_cd.abilities = [{"name": "Happy Switch", "text": ""}]
	blissey_cd.attacks = [{"name": "Happy Chance", "cost": "CCC", "damage": "180", "text": "", "is_vstar_power": false}]
	processor.register_pokemon_card(blissey_cd)

	var blissey := _make_slot(blissey_cd, 0)
	player.active_pokemon = blissey
	var target := player.bench[0]
	blissey.attached_energy.clear()
	target.attached_energy.clear()
	var basic_energy := CardInstance.create(_make_energy_data("Basic Psychic", "P"), 0)
	var special_energy := CardInstance.create(_make_energy_data("Double Turbo", "C", "Special Energy", "9c04dd0addf56a7b2c88476bc8e45c0e"), 0)
	blissey.attached_energy.append(basic_energy)
	blissey.attached_energy.append(special_energy)

	var effect: BaseEffect = processor.get_ability_effect(blissey, 0, state)
	var steps := effect.get_interaction_steps(blissey.get_top_card(), state) if effect != null else []
	var execute_ok := processor.execute_ability_effect(blissey, 0, [{
		"energy_assignment": [{"source": basic_energy, "target": target}],
	}], state)
	var reused_same_turn: bool = processor.can_use_ability(blissey, state, 0)

	return run_checks([
		assert_not_null(effect, "CSV8C_165 should register its Ability"),
		assert_eq(steps.size(), 1, "CSV8C_165 should expose one energy reassignment step"),
		assert_true(execute_ok, "CSV8C_165 should execute its Ability"),
		assert_false(basic_energy in blissey.attached_energy, "CSV8C_165 should remove the selected Basic Energy from the source Pokemon"),
		assert_contains(target.attached_energy, basic_energy, "CSV8C_165 should attach the selected Basic Energy to another Pokemon"),
		assert_contains(blissey.attached_energy, special_energy, "CSV8C_165 should not move Special Energy"),
		assert_false(reused_same_turn, "CSV8C_165 should only be usable once each turn"),
	])


func test_csv8c_165_blissey_ex_attack_draws_until_hand_has_six_cards() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var blissey_cd := _make_basic_pokemon_data("CSV8C_165 Blissey ex", "C", 300, "Stage 1", "ex", "4550f14d2ebd9d202a0c4ea5af9ec4d9")
	blissey_cd.abilities = [{"name": "Happy Switch", "text": ""}]
	blissey_cd.attacks = [{"name": "Happy Chance", "cost": "CCC", "damage": "180", "text": "", "is_vstar_power": false}]
	processor.register_pokemon_card(blissey_cd)

	var attacker := _make_slot(blissey_cd, 0)
	player.active_pokemon = attacker
	player.hand.append(CardInstance.create(_make_trainer_data("Hand A", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_data("Hand B", "Item"), 0))
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_trainer_data("Draw %d" % i, "Item"), 0))

	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state)

	return run_checks([
		assert_eq(player.hand.size(), 6, "CSV8C_165 should draw until the user's hand has 6 cards"),
		assert_eq(player.deck.size(), 2, "CSV8C_165 should draw exactly the missing cards"),
	])


func test_151c_113_chansey_lucky_bonus_benches_from_prize_and_takes_an_extra_prize_on_heads() -> String:
	var gsm := GameStateMachine.new()
	gsm.coin_flipper = RiggedCoinFlipper.new([true])
	gsm.effect_processor = EffectProcessor.new(gsm.coin_flipper)
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.prizes.clear()

	var chansey_cd := _make_basic_pokemon_data("151C_113 Chansey", "C", 110, "Basic", "", "79513e01fbf5084d23e6c60232e2338c")
	chansey_cd.abilities = [{"name": "Lucky Bonus", "text": ""}]
	gsm.effect_processor.register_pokemon_card(chansey_cd)

	var chansey := CardInstance.create(chansey_cd, 0)
	var bonus_prize := CardInstance.create(_make_trainer_data("Bonus Prize", "Item"), 0)
	player.set_prizes([chansey, bonus_prize])
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	gsm.set("_pending_prize_resume_mode", "resume_main")
	gsm.set("_pending_prize_resume_player_index", 0)

	var first_take := gsm.resolve_take_prize(0, 0)
	var second_take := gsm.resolve_take_prize(0, 1)
	var benched_chansey := false
	for slot: PokemonSlot in player.bench:
		if slot.get_top_card() == chansey:
			benched_chansey = true
			break

	return run_checks([
		assert_true(first_take, "151C_113 should resolve the first prize take"),
		assert_true(benched_chansey, "151C_113 should move itself from the Prize cards onto the Bench"),
		assert_false(chansey in player.hand, "151C_113 should not remain in hand after using Lucky Bonus"),
		assert_true(second_take, "151C_113 should grant one extra Prize on heads"),
		assert_contains(player.hand, bonus_prize, "151C_113 should let the player take one more Prize card on heads"),
	])


func test_csv8c_078_girafarig_attack_places_10_damage_on_selected_own_bench_pokemon() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]

	var girafarig_cd := _make_basic_pokemon_data("CSV8C_078 Girafarig", "P", 100, "Basic", "", "8c812520b47c53417bf960f22970dd18")
	girafarig_cd.attacks = [{"name": "Twin Shotels", "cost": "C", "damage": "30", "text": "", "is_vstar_power": false}]
	processor.register_pokemon_card(girafarig_cd)

	var attacker := _make_slot(girafarig_cd, 0)
	player.active_pokemon = attacker
	player.bench[0].damage_counters = 0
	player.bench[1].damage_counters = 0
	var steps := processor.get_attack_interaction_steps_by_id(
		girafarig_cd.effect_id,
		0,
		attacker.get_top_card(),
		girafarig_cd.attacks[0],
		state
	)
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{
		"self_bench_target": [player.bench[1]],
	}])

	return run_checks([
		assert_eq(steps.size(), 1, "CSV8C_078 should expose one self-bench target step"),
		assert_eq(player.bench[1].damage_counters, 10, "CSV8C_078 should place 10 damage on the selected Benched Pokemon"),
		assert_eq(player.bench[0].damage_counters, 0, "CSV8C_078 should not damage unselected Benched Pokemon"),
	])


func test_csv7c_141_farigiraf_ex_prevents_basic_ex_damage_and_snipes_selected_bench_target() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var farigiraf_cd := _make_basic_pokemon_data("CSV7C_141 Farigiraf ex", "D", 260, "Stage 1", "ex", "fd252ce877c709e9e3161c56ef98aff8")
	farigiraf_cd.abilities = [{"name": "Tail Armor", "text": ""}]
	farigiraf_cd.attacks = [{"name": "Cackling Charge", "cost": "PCC", "damage": "160", "text": "", "is_vstar_power": false}]
	processor.register_pokemon_card(farigiraf_cd)

	var defender := _make_slot(farigiraf_cd, 0)
	player.active_pokemon = defender
	var basic_ex_cd := _make_basic_pokemon_data("Basic ex", "F", 220, "Basic", "ex")
	var stage1_ex_cd := _make_basic_pokemon_data("Stage 1 ex", "F", 260, "Stage 1", "ex")
	var basic_ex_attacker := _make_slot(basic_ex_cd, 1)
	var stage1_ex_attacker := _make_slot(stage1_ex_cd, 1)
	opponent.active_pokemon = basic_ex_attacker

	var bench_protected := _make_slot(farigiraf_cd, 0)
	player.bench.clear()
	player.bench.append(bench_protected)
	var any_target := AttackAnyTargetDamage.new(30)
	any_target.set_attack_interaction_context([{"any_target": [bench_protected]}])
	any_target.execute_attack(basic_ex_attacker, defender, 0, state)
	any_target.clear_attack_interaction_context()

	var steps := processor.get_attack_interaction_steps_by_id(
		farigiraf_cd.effect_id,
		0,
		defender.get_top_card(),
		farigiraf_cd.attacks[0],
		state
	)
	processor.execute_attack_effect(defender, 0, basic_ex_attacker, state, [{
		"bench_target": [opponent.bench[1]],
	}])

	return run_checks([
		assert_true(processor.is_damage_prevented_by_defender_ability(basic_ex_attacker, defender, state), "CSV7C_141 should prevent damage from Basic ex attackers"),
		assert_false(processor.is_damage_prevented_by_defender_ability(stage1_ex_attacker, defender, state), "CSV7C_141 should not prevent damage from evolved ex attackers"),
		assert_eq(bench_protected.damage_counters, 0, "CSV7C_141 should also prevent direct attack damage to itself while on the Bench"),
		assert_eq(steps.size(), 1, "CSV7C_141 should expose one opponent bench target step"),
		assert_eq(opponent.bench[1].damage_counters, 30, "CSV7C_141 should place 30 damage on the selected opponent Benched Pokemon"),
	])


func test_csv8c_159_dragapult_ex_places_six_counters_on_bench() -> String:
	var processor := EffectProcessor.new()
	var card_data := _make_basic_pokemon_data("CSV8C_159 Dragapult ex", "N", 320, "Stage 2", "ex", "52a205820de799a53a689f23cbeb8622")
	card_data.attacks = [
		{"name": "Jet Headbutt", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
	]
	processor.register_pokemon_card(card_data)
	var state := _make_state()
	var attacker := _make_slot(card_data, 0)
	var bench_a := state.players[1].bench[0]
	var bench_b := state.players[1].bench[1]

	processor.execute_attack_effect(attacker, 1, state.players[1].active_pokemon, state, [{
		"bench_damage_counters": [
			{"target": bench_a, "amount": 30},
			{"target": bench_b, "amount": 30},
		],
	}])

	return run_checks([
		assert_true(processor.has_attack_effect(card_data.effect_id), "CSV8C_159 should register scripted attacks"),
		assert_eq(bench_a.damage_counters, 30, "CSV8C_159 should assign counters to the first chosen bench target"),
		assert_eq(bench_b.damage_counters, 30, "CSV8C_159 should assign counters to the second chosen bench target"),
	])


func test_csv8c_186_sparkling_crystal_reduces_any_energy_for_tera_pokemon() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var attacker_cd := _make_basic_pokemon_data("Tera Attacker", "W", 210, "Basic", "ex")
	attacker_cd.ancient_trait = "Tera"
	var attack := {"name": "Heavy Cost", "cost": "WFC", "damage": "140", "text": "", "is_vstar_power": false}
	attacker_cd.attacks = [attack]
	var attacker := _make_slot(attacker_cd, 0)
	attacker.attached_tool = CardInstance.create(_make_trainer_data("CSV8C_186 Sparkling Crystal", "Tool", "12164ed03296d2df4ef6d0fa8b5f8aae"), 0)

	return run_checks([
		assert_true(processor.has_effect(attacker.attached_tool.card_data.effect_id), "CSV8C_186 should be registered"),
		assert_eq(processor.get_attack_any_cost_modifier(attacker, attack, state), -1, "CSV8C_186 should reduce one energy of any type"),
	])


func test_csv8c_186_sparkling_crystal_allows_either_type_removal_on_dragapult() -> String:
	# 多龙巴鲁托ex 幻影潜袭费用 RP，璀璨结晶减1任意
	# 只附着1个火能量R时，应减掉P，剩R，可以攻击
	var processor := EffectProcessor.new()
	var state := _make_state()
	var dragapult_cd := _make_basic_pokemon_data("Dragapult ex", "N", 320, "Stage 2", "ex", "52a205820de799a53a689f23cbeb8622")
	dragapult_cd.ancient_trait = "Tera"
	dragapult_cd.attacks = [
		{"name": "Jet Headbutt", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
	]
	var attacker := _make_slot(dragapult_cd, 0)
	attacker.attached_tool = CardInstance.create(_make_trainer_data("Sparkling Crystal", "Tool", "12164ed03296d2df4ef6d0fa8b5f8aae"), 0)
	state.players[0].active_pokemon = attacker

	# 场景1：只有1个火能量R → 应减P，剩R，可以攻击
	attacker.attached_energy.clear()
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire", "R"), 0))
	var validator := RuleValidator.new()
	var can_attack_with_fire := validator.can_use_attack(state, 0, 1, processor)

	# 场景2：只有1个超能量P → 应减R，剩P，可以攻击
	attacker.attached_energy.clear()
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Psychic", "P"), 0))
	var can_attack_with_psychic := validator.can_use_attack(state, 0, 1, processor)

	# 场景3：没有能量 → 费用RP减1仍需1个，不能攻击
	attacker.attached_energy.clear()
	var cannot_attack_empty := not validator.can_use_attack(state, 0, 1, processor)

	# 场景4：非太晶宝可梦不应获得减费
	var normal_cd := _make_basic_pokemon_data("Normal ex", "N", 320, "Stage 2", "ex")
	normal_cd.attacks = [{"name": "Normal Attack", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false}]
	var normal_slot := _make_slot(normal_cd, 0)
	normal_slot.attached_tool = CardInstance.create(_make_trainer_data("Sparkling Crystal", "Tool", "12164ed03296d2df4ef6d0fa8b5f8aae"), 0)
	normal_slot.attached_energy.append(CardInstance.create(_make_energy_data("Fire", "R"), 0))
	state.players[0].active_pokemon = normal_slot
	var no_reduction_for_normal := not validator.can_use_attack(state, 0, 0, processor)

	return run_checks([
		assert_true(can_attack_with_fire, "CSV8C_186 should allow Phantom Dive with only Fire Energy (remove P)"),
		assert_true(can_attack_with_psychic, "CSV8C_186 should allow Phantom Dive with only Psychic Energy (remove R)"),
		assert_true(cannot_attack_empty, "CSV8C_186 should not allow Phantom Dive with no Energy"),
		assert_true(no_reduction_for_normal, "CSV8C_186 should not reduce cost for non-Tera Pokemon"),
	])


func test_csv8c_203_jamming_tower_disables_tool_effects() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	state.stadium_card = CardInstance.create(_make_trainer_data("CSV8C_203 Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	var slot := _make_slot(_make_basic_pokemon_data("Tool Target", "C"), 0)
	slot.attached_tool = CardInstance.create(_make_trainer_data("Bravery Charm", "Tool", "d1c2f018a644e662f2b6895fdfc29281"), 0)

	return run_checks([
		assert_true(processor.has_effect(state.stadium_card.card_data.effect_id), "CSV8C_203 should be registered"),
		assert_true(processor.is_tool_effect_suppressed(slot, state), "CSV8C_203 should suppress attached tool effects"),
		assert_eq(processor.get_effective_max_hp(slot, state), slot.get_max_hp(), "CSV8C_203 should stop HP tool modifiers from applying"),
	])


func test_csv1c_118_bravery_charm_only_boosts_basic_pokemon() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var basic_slot := _make_slot(_make_basic_pokemon_data("Basic Target", "P", 90), 0)
	var evolved_slot := _make_slot(_make_basic_pokemon_data("Evolved Target", "P", 140, "Stage 1"), 0)
	var charm_basic := CardInstance.create(_make_trainer_data("Bravery Charm", "Tool", "d1c2f018a644e662f2b6895fdfc29281"), 0)
	var charm_evolved := CardInstance.create(_make_trainer_data("Bravery Charm", "Tool", "d1c2f018a644e662f2b6895fdfc29281"), 0)
	basic_slot.attached_tool = charm_basic
	evolved_slot.attached_tool = charm_evolved

	return run_checks([
		assert_eq(processor.get_effective_max_hp(basic_slot, state), 140, "CSV1C_118 should grant +50 HP to Basic Pokemon"),
		assert_eq(processor.get_effective_max_hp(evolved_slot, state), 140, "CSV1C_118 should not change non-Basic Pokemon HP"),
	])


func test_cs6bc_123_lost_vacuum_removing_bravery_charm_knocks_out_immediately() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	var protected_active := _make_slot(_make_basic_pokemon_data("Scream Tail", "P", 90), 0)
	protected_active.damage_counters = 120
	protected_active.attached_tool = CardInstance.create(_make_trainer_data("Bravery Charm", "Tool", "d1c2f018a644e662f2b6895fdfc29281"), 0)
	gsm.game_state.players[0].active_pokemon = protected_active
	var replacement := _make_slot(_make_basic_pokemon_data("Replacement", "P", 90), 0)
	gsm.game_state.players[0].bench.clear()
	gsm.game_state.players[0].bench.append(replacement)

	var player := gsm.game_state.players[1]
	player.hand.clear()
	var discard_fodder := CardInstance.create(_make_trainer_data("Fodder", "Item"), 1)
	var lost_vacuum := CardInstance.create(_make_trainer_data("Lost Vacuum", "Item", "8f655fea1f90164bfbccb7a95c223e17"), 1)
	player.hand.append(discard_fodder)
	player.hand.append(lost_vacuum)

	var success := gsm.play_trainer(1, lost_vacuum, [])
	var take_prize_ok := gsm.resolve_take_prize(1, 0)
	var send_out_ok := gsm.send_out_pokemon(0, replacement)

	return run_checks([
		assert_true(success, "CS6bC_123 should resolve successfully when another hand card is available"),
		assert_true(take_prize_ok, "Removing Bravery Charm should still pause for manual prize selection"),
		assert_true(send_out_ok, "Removing Bravery Charm should immediately KO the damaged Active Pokemon and require a replacement"),
		assert_eq(gsm.game_state.players[0].active_pokemon, replacement, "The knocked out Basic Pokemon should be replaced immediately"),
		assert_eq(gsm.game_state.current_player_index, 1, "After the replacement, the Lost Vacuum user's turn should continue"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "After resolving the immediate knockout, the game should return to MAIN"),
	])


func test_csv8c_203_jamming_tower_suppressed_bravery_charm_knocks_out_immediately() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	var protected_bench := _make_slot(_make_basic_pokemon_data("Scream Tail", "P", 90), 0)
	protected_bench.damage_counters = 120
	protected_bench.attached_tool = CardInstance.create(_make_trainer_data("Bravery Charm", "Tool", "d1c2f018a644e662f2b6895fdfc29281"), 0)
	gsm.game_state.players[0].bench.clear()
	gsm.game_state.players[0].bench.append(protected_bench)

	var player := gsm.game_state.players[1]
	player.hand.clear()
	var stadium := CardInstance.create(_make_trainer_data("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 1)
	player.hand.append(stadium)

	var success := gsm.play_stadium(1, stadium)
	var take_prize_ok := gsm.resolve_take_prize(1, 0)

	return run_checks([
		assert_true(success, "CSV8C_203 should be playable"),
		assert_true(take_prize_ok, "Immediate knockout should still pause for manual prize selection"),
		assert_false(protected_bench in gsm.game_state.players[0].bench, "Suppressing Bravery Charm should immediately knock out the damaged Benched Basic Pokemon"),
		assert_eq(gsm.game_state.current_player_index, 1, "After the immediate bench knockout, the Jamming Tower user's turn should continue"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "After the immediate bench knockout, the game should return to MAIN"),
	])


func test_csv8c_207_legacy_energy_provides_any_type_and_reduces_prizes_once() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var energy := CardInstance.create(_make_energy_data("CSV8C_207 Legacy Energy", "", "Special Energy", "6f31b7241a181631016466e561f148f3"), 0)
	var slot := state.players[0].active_pokemon
	slot.attached_energy.clear()
	slot.attached_energy.append(energy)
	var attack_single := {"name": "Single Cost", "cost": "W", "damage": "60", "text": "", "is_vstar_power": false}
	var attack_double := {"name": "Mixed Cost", "cost": "WF", "damage": "120", "text": "", "is_vstar_power": false}
	var v := RuleValidator.new()

	return run_checks([
		assert_true(processor.has_effect(energy.card_data.effect_id), "CSV8C_207 should be registered"),
		assert_true(v.has_enough_energy(slot, attack_single.cost, processor, state), "CSV8C_207 1张ANY能量应满足单属性消耗"),
		assert_false(v.has_enough_energy(slot, attack_double.cost, processor, state), "CSV8C_207 1张ANY能量不应满足双属性消耗"),
		assert_eq(processor.get_knockout_prize_modifier(slot, state), -1, "CSV8C_207 should reduce prizes by 1 before being consumed"),
	])


func test_csv8c_121_cornerstone_mask_ogerpon_ex_attack_ignores_weakness_and_effects() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state

	var attacker_cd := _make_basic_pokemon_data("CSV8C_121 Cornerstone Mask Ogerpon ex", "F", 210, "Basic", "ex", "4f25f668ee0ab45c68f6954324c73003")
	attacker_cd.abilities = [{"name": "Cornerstone Stance"}]
	attacker_cd.attacks = [{"name": "Demolish", "cost": "FCC", "damage": "140", "text": "", "is_vstar_power": false}]
	var defender_cd := _make_basic_pokemon_data("Weak Defender", "G", 220, "Basic", "")
	defender_cd.weakness_energy = "F"
	defender_cd.weakness_value = "x2"

	gsm.effect_processor.register_pokemon_card(attacker_cd)
	state.players[0].active_pokemon = _make_slot(attacker_cd, 0)
	state.players[1].active_pokemon = _make_slot(defender_cd, 1)
	state.players[1].active_pokemon.effects.append({
		"type": "reduce_damage_next_turn",
		"amount": 80,
		"turn": state.turn_number - 1,
	})
	state.players[0].active_pokemon.attached_energy = [
		CardInstance.create(_make_energy_data("F1", "F"), 0),
		CardInstance.create(_make_energy_data("C1", "C"), 0),
		CardInstance.create(_make_energy_data("C2", "C"), 0),
	]

	var success := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(success, "CSV8C_121 should use its attack successfully"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 140, "CSV8C_121 attack should ignore weakness and defender effects"),
	])


func test_csv5c_120_tm_devolution_grants_attack_and_discards_at_end_of_turn() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var attacker_cd := _make_basic_pokemon_data("TM User", "C", 120)
	var attacker := _make_slot(attacker_cd, 0)
	var tm_card := CardInstance.create(_make_trainer_data("CSV5C_120 TM: Devolution", "Tool", "e228e825c541ce80e2507c557cb506c3"), 0)
	attacker.attached_tool = tm_card
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Colorless", "C"), 0))
	player.active_pokemon = attacker

	var base_cd := _make_basic_pokemon_data("Target Basic", "G", 90)
	var stage1_cd := _make_basic_pokemon_data("Target Stage1", "G", 140, "Stage 1")
	stage1_cd.evolves_from = base_cd.name
	var target := PokemonSlot.new()
	target.pokemon_stack.append(CardInstance.create(base_cd, 1))
	target.pokemon_stack.append(CardInstance.create(stage1_cd, 1))
	target.turn_played = 0
	opponent.active_pokemon = target
	opponent.hand.clear()

	var granted_attacks: Array[Dictionary] = gsm.effect_processor.get_granted_attacks(attacker, state)
	var success := false
	if not granted_attacks.is_empty():
		success = gsm.use_granted_attack(0, attacker, granted_attacks[0])

	return run_checks([
		assert_eq(granted_attacks.size(), 1, "CSV5C_120 should grant exactly one attack"),
		assert_true(success, "CSV5C_120 granted attack should be usable"),
		assert_eq(target.pokemon_stack.size(), 1, "CSV5C_120 should devolve the evolved opponent Pokemon"),
		assert_eq(target.get_pokemon_name(), base_cd.name, "CSV5C_120 should leave the lower Stage Pokemon in play"),
		assert_true(opponent.hand.any(func(card: CardInstance) -> bool: return card.card_data.name == stage1_cd.name), "CSV5C_120 should return the removed evolution card to the opponent hand"),
		assert_true(player.discard_pile.any(func(card: CardInstance) -> bool: return card == tm_card), "CSV5C_120 should be discarded at the end of the turn"),
	])


func test_csv4c_119_tm_turbo_energize_grants_attack_and_attaches_two_basic_energy_to_bench() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]

	var attacker_cd := _make_basic_pokemon_data("TM Turbo User", "C", 120)
	var attacker := _make_slot(attacker_cd, 0)
	var tm_card := CardInstance.create(_make_trainer_data("CSV4C_119 TM: Turbo Energize", "Tool", "2614722b9b28d9df8fd769b926ec82f2"), 0)
	attacker.attached_tool = tm_card
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Colorless", "C"), 0))
	player.active_pokemon = attacker

	player.deck.clear()
	var grass := CardInstance.create(_make_energy_data("Grass", "G"), 0)
	var psychic := CardInstance.create(_make_energy_data("Psychic", "P"), 0)
	var filler := CardInstance.create(_make_trainer_data("Filler", "Item"), 0)
	player.deck.append(grass)
	player.deck.append(psychic)
	player.deck.append(filler)

	var granted_attacks: Array[Dictionary] = gsm.effect_processor.get_granted_attacks(attacker, state)
	var granted_steps := []
	var success := false
	if not granted_attacks.is_empty():
		granted_steps = gsm.effect_processor.get_granted_attack_interaction_steps(attacker, granted_attacks[0], state)
		success = gsm.use_granted_attack(0, attacker, granted_attacks[0], [{
			"tm_turbo_energize": [
				{"source": grass, "target": player.bench[0]},
				{"source": psychic, "target": player.bench[1]},
			],
		}])

	return run_checks([
		assert_eq(granted_attacks.size(), 1, "CSV4C_119 should grant exactly one attack"),
		assert_eq(granted_steps.size(), 1, "CSV4C_119 should expose one assignment step"),
		assert_true(success, "CSV4C_119 granted attack should be usable"),
		assert_contains(player.bench[0].attached_energy, grass, "CSV4C_119 should attach the selected first Basic Energy to a Benched Pokemon"),
		assert_contains(player.bench[1].attached_energy, psychic, "CSV4C_119 should attach the selected second Basic Energy to a Benched Pokemon"),
		assert_contains(player.discard_pile, tm_card, "CSV4C_119 should be discarded at the end of the turn"),
	])


func test_cs5_5c_064_cherens_care_returns_damaged_colorless_pokemon_and_all_attached_cards_to_hand() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()

	var target_cd := _make_basic_pokemon_data("Cheren Target", "C", 130, "Basic")
	var target := _make_slot(target_cd, 0)
	target.damage_counters = 40
	var attached_energy := CardInstance.create(_make_energy_data("Double Turbo", "C", "Special Energy"), 0)
	var attached_tool := CardInstance.create(_make_trainer_data("Hero's Cape", "Tool"), 0)
	target.attached_energy.append(attached_energy)
	target.attached_tool = attached_tool
	player.active_pokemon = target

	var replacement := _make_slot(_make_basic_pokemon_data("Replacement", "C", 100), 0)
	player.bench.clear()
	player.bench.append(replacement)

	var card_data := _make_trainer_data("CS5.5C_064 Cheren's Care", "Supporter", "8be6a0e0835e0caba9acb7bf8e9c9ce0")
	var card := CardInstance.create(card_data, 0)
	player.hand.append(card)
	var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
	var steps := effect.get_interaction_steps(card, state) if effect != null else []
	var success := gsm.play_trainer(0, card, [{
		"cheren_target": [target],
		"cheren_replacement": [replacement],
	}])

	return run_checks([
		assert_not_null(effect, "CS5.5C_064 should be registered"),
		assert_eq(steps.size(), 2, "CS5.5C_064 should ask for the target and an Active replacement"),
		assert_true(success, "CS5.5C_064 should resolve through GameStateMachine"),
		assert_eq(player.active_pokemon, replacement, "CS5.5C_064 should promote the chosen replacement when the Active is returned"),
		assert_contains(player.hand, target.get_top_card(), "CS5.5C_064 should return the Pokemon card to hand"),
		assert_contains(player.hand, attached_energy, "CS5.5C_064 should return attached Energy to hand"),
		assert_contains(player.hand, attached_tool, "CS5.5C_064 should return the attached Tool to hand"),
		assert_eq(player.discard_pile.size(), 1, "CS5.5C_064 should only discard itself"),
	])


func test_csv7c_187_heros_cape_increases_max_hp_by_100() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var slot := _make_slot(_make_basic_pokemon_data("Cape Target", "C", 150), 0)
	var cape := CardInstance.create(_make_trainer_data("CSV7C_187 Hero's Cape", "Tool", "cd9192e99ba06596352434d53223514f"), 0)
	slot.attached_tool = cape
	player.active_pokemon = slot

	var processor := EffectProcessor.new()
	var max_hp: int = processor.get_effective_max_hp(slot, state)

	return run_checks([
		assert_eq(max_hp, 250, "CSV7C_187 should increase the holder's max HP by 100"),
		assert_eq(processor.get_hp_modifier(slot, state), 100, "CSV7C_187 should contribute a +100 HP modifier"),
	])


func test_cs6_5c_054_regidrago_v_mills_top_three_and_attaches_energy() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.discard_pile.clear()
	var attacker_cd := _make_basic_pokemon_data("CS6.5C_054 Regidrago V", "N", 220, "Basic", "V", "90c9e117fa846938024ae15eb859f1b6")
	attacker_cd.attacks = [{"name": "Apex Dragon", "cost": "C", "damage": "", "text": "", "is_vstar_power": false}]
	processor.register_pokemon_card(attacker_cd)
	var attacker := _make_slot(attacker_cd, 0)
	var basic_energy := CardInstance.create(_make_energy_data("Grass", "G"), 0)
	var special_energy := CardInstance.create(_make_energy_data("Double Turbo", "", "Special Energy", "9c04dd0addf56a7b2c88476bc8e45c0e"), 0)
	var non_energy := CardInstance.create(_make_basic_pokemon_data("Non Energy", "C"), 0)
	player.deck.append(basic_energy)
	player.deck.append(non_energy)
	player.deck.append(special_energy)

	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state)

	return run_checks([
		assert_eq(attacker.attached_energy.size(), 2, "CS6.5C_054 should attach all milled Energy to itself"),
		assert_true(non_energy in player.discard_pile, "CS6.5C_054 should discard non-Energy milled cards"),
		assert_eq(player.deck.size(), 0, "CS6.5C_054 should mill exactly the top 3 cards"),
	])


func test_csv6c_082_slither_wing_mills_then_self_damages_and_burns() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	opponent.deck.clear()
	opponent.deck.append(CardInstance.create(_make_basic_pokemon_data("Milled Card", "C"), 1))
	var attacker_cd := _make_basic_pokemon_data("CSV6C_082 Slither Wing", "F", 140, "Basic", "", "29f94ee004e4c312dbea4a7930d33544")
	attacker_cd.attacks = [
		{"name": "Stampede", "cost": "F", "damage": "", "text": "", "is_vstar_power": false},
		{"name": "Burning Rage", "cost": "FF", "damage": "120", "text": "", "is_vstar_power": false},
	]
	processor.register_pokemon_card(attacker_cd)
	var attacker := _make_slot(attacker_cd, 0)

	processor.execute_attack_effect(attacker, 0, opponent.active_pokemon, state)
	processor.execute_attack_effect(attacker, 1, opponent.active_pokemon, state)

	return run_checks([
		assert_eq(opponent.deck.size(), 0, "CSV6C_082 first attack should mill 1 from the opponent deck"),
		assert_eq(attacker.damage_counters, 90, "CSV6C_082 second attack should deal 90 damage to itself"),
		assert_true(opponent.active_pokemon.status_conditions.get("burned", false), "CSV6C_082 second attack should Burn the opponent Active"),
	])


func test_csv7c_154_raging_bolt_ex_discards_hand_and_scales_with_discarded_energy() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	for i: int in 3:
		player.hand.append(CardInstance.create(_make_basic_pokemon_data("Hand %d" % i, "C"), 0))
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Draw %d" % i, "C"), 0))
	var attacker_cd := _make_basic_pokemon_data("CSV7C_154 Raging Bolt ex", "N", 240, "Basic", "ex", "e96bb407c5f18bb9eec55487e70395fd")
	attacker_cd.attacks = [
		{"name": "Burst Roar", "cost": "C", "damage": "", "text": "", "is_vstar_power": false},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x", "text": "", "is_vstar_power": false},
	]
	processor.register_pokemon_card(attacker_cd)
	var attacker := _make_slot(attacker_cd, 0)
	var bench := player.bench[0]
	var e1 := CardInstance.create(_make_energy_data("Basic L", "L"), 0)
	var e2 := CardInstance.create(_make_energy_data("Basic F", "F"), 0)
	attacker.attached_energy.append(e1)
	bench.attached_energy.append(e2)

	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state)
	var damage_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 1)
	for effect: BaseEffect in damage_effects:
		if effect is AttackDiscardBasicEnergyFromFieldDamage:
			effect.set_attack_interaction_context([{"discard_basic_energy": [e1, e2]}])
			var bonus: int = int(effect.call("get_damage_bonus", attacker, state))
			effect.execute_attack(attacker, state.players[1].active_pokemon, 1, state)
			effect.clear_attack_interaction_context()
			return run_checks([
				assert_eq(player.hand.size(), 6, "CSV7C_154 first attack should discard the hand and draw 6"),
				assert_eq(bonus, 70, "CSV7C_154 second attack should add 70 damage when 2 Basic Energy are chosen"),
				assert_true(e1 in player.discard_pile and e2 in player.discard_pile, "CSV7C_154 second attack should discard the chosen Basic Energy from your field"),
			])
	return "CSV7C_154 missing discard-energy damage effect"


func test_csv7c_154_raging_bolt_ex_damage_uses_selected_energy_in_attack_flow() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.discard_pile.clear()
	var multiplied_damage := "70\u00D7"

	var attacker_cd := _make_basic_pokemon_data("CSV7C_154 Raging Bolt ex", "N", 240, "Basic", "ex", "e96bb407c5f18bb9eec55487e70395fd")
	attacker_cd.attacks = [
		{"name": "Burst Roar", "cost": "C", "damage": "", "text": "", "is_vstar_power": false},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": multiplied_damage, "text": "", "is_vstar_power": false},
	]
	gsm.effect_processor.register_pokemon_card(attacker_cd)

	var attacker := _make_slot(attacker_cd, 0)
	var e1 := CardInstance.create(_make_energy_data("Basic L", "L"), 0)
	var e2 := CardInstance.create(_make_energy_data("Basic F", "F"), 0)
	attacker.attached_energy.append(e1)
	attacker.attached_energy.append(e2)
	player.active_pokemon = attacker
	opponent.active_pokemon = _make_slot(_make_basic_pokemon_data("Damage Sponge", "C", 220), 1)

	var success := gsm.use_attack(0, 1, [{
		"discard_basic_energy": [e1, e2],
	}])

	return run_checks([
		assert_true(success, "CSV7C_154 second attack should resolve from the main attack flow"),
		assert_eq(opponent.active_pokemon.damage_counters, 140, "CSV7C_154 second attack should deal 140 when 2 Basic Energy are chosen"),
		assert_true(e1 in player.discard_pile and e2 in player.discard_pile, "CSV7C_154 second attack should discard the selected Basic Energy"),
		assert_eq(attacker.attached_energy.size(), 0, "CSV7C_154 second attack should remove discarded Energy from the attacker"),
	])


func test_csv8c_081_duskull_revives_from_discard_to_bench() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	player.discard_pile.clear()
	var duskull_cd := _make_basic_pokemon_data("夜巡灵", "P", 60, "Basic", "", "ce6db179c3d166130e7a637581da3aa2")
	duskull_cd.attacks = [{"name": "渡魂", "cost": "P", "damage": "", "text": "", "is_vstar_power": false}]
	processor.register_pokemon_card(duskull_cd)
	var attacker := _make_slot(duskull_cd, 0)
	# 弃牌区放入2张夜巡灵和1张其他宝可梦
	var revive_a := CardInstance.create(_make_basic_pokemon_data("夜巡灵", "P"), 0)
	var revive_b := CardInstance.create(_make_basic_pokemon_data("夜巡灵", "P"), 0)
	var other := CardInstance.create(_make_basic_pokemon_data("其他宝可梦", "P"), 0)
	player.discard_pile.append(revive_a)
	player.discard_pile.append(revive_b)
	player.discard_pile.append(other)

	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{
		"revive_from_discard": [revive_a, revive_b],
	}])

	return run_checks([
		assert_eq(player.bench.size(), 2, "渡魂应从弃牌区复活2只夜巡灵到备战区"),
		assert_true(revive_a not in player.discard_pile, "复活的夜巡灵应从弃牌区移除"),
		assert_true(other in player.discard_pile, "非夜巡灵的宝可梦不应被复活"),
	])


func test_csv8c_082_dusclops_self_ko_ability_places_five_counters() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var dusclops_cd := _make_basic_pokemon_data("CSV8C_082 Dusclops", "P", 90, "Stage 1", "", "ad031124df2ede62f945220fbbd680b3")
	dusclops_cd.abilities = [{"name": "Cursed Blast"}]
	processor.register_pokemon_card(dusclops_cd)
	var slot := _make_slot(dusclops_cd, 0)
	var target := state.players[1].active_pokemon

	processor.execute_ability_effect(slot, 0, [{"self_ko_target": [target]}], state)

	return run_checks([
		assert_eq(target.damage_counters, 50, "CSV8C_082 should place 5 damage counters on the chosen opponent Pokemon"),
		assert_true(slot.is_knocked_out(), "CSV8C_082 should Knock Itself Out after using its Ability"),
	])


func test_csv8c_083_dusknoir_self_ko_returns_to_main_phase() -> String:
	## 端到端验证：黑夜魔灵自爆后回合不结束，仍在 MAIN 阶段
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	state.current_player_index = 0

	# 将黑夜魔灵放到备战区
	var dusknoir_cd := _make_basic_pokemon_data("黑夜魔灵", "P", 160, "Stage 2", "", "2a4178f21ba2bf13285bbb43ecaaa472")
	dusknoir_cd.abilities = [{"name": "咒怨炸弹"}]
	dusknoir_cd.attacks = [{"name": "影子束缚", "cost": "PPC", "damage": "150", "text": "", "is_vstar_power": false}]
	var dusknoir_slot := _make_slot(dusknoir_cd, 0)
	state.players[0].bench.append(dusknoir_slot)
	gsm.effect_processor.register_pokemon_card(dusknoir_cd)

	# 使用高HP的对手宝可梦，避免被130伤害直接KO
	var opp_cd := _make_basic_pokemon_data("对手高HP", "C", 300)
	state.players[1].active_pokemon = _make_slot(opp_cd, 1)
	var target := state.players[1].active_pokemon
	var target_hp_before: int = target.damage_counters

	# 使用自爆特性（备战区）
	var success := gsm.use_ability(0, dusknoir_slot, 0, [{"self_ko_target": [target]}])
	var take_prize_ok := gsm.resolve_take_prize(1, 0)

	return run_checks([
		assert_true(success, "黑夜魔灵应成功使用咒怨炸弹"),
		assert_true(take_prize_ok, "自爆后应先由对手手动拿取奖赏卡"),
		assert_eq(target.damage_counters, target_hp_before + 130, "应对目标放置13个伤害指示物（130伤害）"),
		assert_true(dusknoir_slot not in state.players[0].bench, "黑夜魔灵应从备战区移除"),
		assert_eq(state.phase, GameState.GamePhase.MAIN, "自爆后应回到MAIN阶段继续操作"),
		assert_eq(state.current_player_index, 0, "仍应是玩家0的回合"),
	])


func test_csv8c_083_dusknoir_self_ko_continues_into_opponent_active_knockout() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	state.current_player_index = 0

	state.players[0].bench.clear()
	var dusknoir_cd := _make_basic_pokemon_data("Dusknoir", "P", 160, "Stage 2", "", "2a4178f21ba2bf13285bbb43ecaaa472")
	dusknoir_cd.abilities = [{"name": "Cursed Blast"}]
	var dusknoir_slot := _make_slot(dusknoir_cd, 0)
	state.players[0].bench.append(dusknoir_slot)
	gsm.effect_processor.register_pokemon_card(dusknoir_cd)

	var doomed_active_cd := _make_basic_pokemon_data("Opp Active", "C", 70)
	var doomed_active := _make_slot(doomed_active_cd, 1)
	var replacement_cd := _make_basic_pokemon_data("Opp Replacement", "C", 120)
	var replacement := _make_slot(replacement_cd, 1)
	state.players[1].active_pokemon = doomed_active
	state.players[1].bench.clear()
	state.players[1].bench.append(replacement)

	var used := gsm.use_ability(0, dusknoir_slot, 0, [{"self_ko_target": [doomed_active]}])
	var opponent_took_prize := gsm.resolve_take_prize(1, 0)
	var pending_prize_player := int(gsm.get("_pending_prize_player_index"))
	var player_took_prize := gsm.resolve_take_prize(0, 0)
	var replacement_sent := gsm.send_out_pokemon(1, replacement)

	return run_checks([
		assert_true(used, "CSV8C_083 should use Cursed Blast successfully"),
		assert_true(opponent_took_prize, "CSV8C_083 self-KO should still let the opponent take their prize first"),
		assert_eq(pending_prize_player, 0, "After the self-KO prize resolves, the opponent Active knockout should queue a prize for the current player"),
		assert_true(player_took_prize, "CSV8C_083 should still award the prize from knocking out the opponent Active"),
		assert_true(replacement_sent, "CSV8C_083 should still require the opponent to send out a replacement"),
		assert_true(dusknoir_slot not in state.players[0].bench, "CSV8C_083 should remove Dusknoir from the Bench after self-KO"),
		assert_eq(state.players[0].prizes.size(), 5, "CSV8C_083 should award 1 prize for the opponent Active knockout"),
		assert_eq(state.players[1].prizes.size(), 5, "CSV8C_083 should still give the opponent 1 prize for the self-KO"),
		assert_eq(state.players[1].active_pokemon, replacement, "CSV8C_083 should replace the knocked-out opponent Active"),
		assert_eq(state.phase, GameState.GamePhase.MAIN, "After both CSV8C_083 knockouts resolve, the turn should return to MAIN"),
		assert_eq(state.current_player_index, 0, "CSV8C_083 mid-turn knockouts should keep the turn with the current player"),
	])


func test_csv8c_153_haxorus_koes_special_energy_and_mills_three() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("Mill 1", "C"), 0))
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("Mill 2", "C"), 0))
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("Mill 3", "C"), 0))
	var haxorus_cd := _make_basic_pokemon_data("CSV8C_153 Haxorus", "N", 170, "Stage 2", "", "e45788bd7d9ffec5b3da3730d2dc806f")
	haxorus_cd.attacks = [
		{"name": "Axe Down", "cost": "F", "damage": "", "text": "", "is_vstar_power": false},
		{"name": "Dragon Pulse", "cost": "FM", "damage": "230", "text": "", "is_vstar_power": false},
	]
	processor.register_pokemon_card(haxorus_cd)
	var attacker := _make_slot(haxorus_cd, 0)
	var defender := state.players[1].active_pokemon
	defender.attached_energy.clear()
	defender.attached_energy.append(CardInstance.create(_make_energy_data("Mist Energy", "", "Special Energy", "fb0948c721db1f31767aa6cf0c2ea692"), 1))

	processor.execute_attack_effect(attacker, 0, defender, state)
	processor.execute_attack_effect(attacker, 1, defender, state)

	return run_checks([
		assert_true(defender.is_knocked_out(), "CSV8C_153 first attack should Knock Out the Defending Pokemon if it has Special Energy attached"),
		assert_eq(player.discard_pile.size(), 3, "CSV8C_153 second attack should mill the top 3 cards of your deck"),
	])


func test_cs6bc_108_giratina_vstar_lost_impact_discards_two_from_field() -> String:
	# 骑拉帝纳VSTAR 放逐冲击：选择自己场上宝可梦身上的2个能量放入放逐区
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var attacker := player.active_pokemon
	var bench_slot := player.bench[0]
	attacker.attached_energy.clear()
	bench_slot.attached_energy.clear()
	var energy_a := CardInstance.create(_make_energy_data("Grass", "G"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Psychic", "P"), 0)
	var energy_c := CardInstance.create(_make_energy_data("Water", "W"), 0)
	attacker.attached_energy.append(energy_a)
	bench_slot.attached_energy.append(energy_b)
	bench_slot.attached_energy.append(energy_c)

	var effect := AttackLostZoneEnergy.new(2, true, true)

	# 验证交互步骤列出所有场上能量
	var giratina_cd := _make_basic_pokemon_data("CS6bC_108 Giratina VSTAR", "N", 280, "Basic", "VSTAR")
	giratina_cd.attacks = [{"name": "Lost Impact", "cost": "GP", "damage": "280", "text": "", "is_vstar_power": false}]
	var card := CardInstance.create(giratina_cd, 0)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(card, giratina_cd.attacks[0], state)
	var step_items_count: int = steps[0].items.size() if not steps.is_empty() else 0

	# 选择攻击者上的1个 + 备战区上的1个
	effect.set_attack_interaction_context([{"lost_zone_energy": [energy_a, energy_b]}])
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "CS6bC_108 should present 1 energy selection step"),
		assert_eq(step_items_count, 3, "CS6bC_108 should list all 3 energy from field Pokemon"),
		assert_eq(steps[0].min_select, 2, "CS6bC_108 should require selecting exactly 2 energy"),
		assert_true(energy_a in player.lost_zone, "CS6bC_108 should send active energy to lost zone"),
		assert_true(energy_b in player.lost_zone, "CS6bC_108 should send bench energy to lost zone"),
		assert_eq(attacker.attached_energy.size(), 0, "CS6bC_108 should remove energy from attacker"),
		assert_eq(bench_slot.attached_energy.size(), 1, "CS6bC_108 should keep unselected energy on bench"),
		assert_true(energy_c in bench_slot.attached_energy, "CS6bC_108 should not remove unselected energy"),
	])


func test_cs6bc_107_giratina_v_abyss_seeking_player_chooses_cards() -> String:
	# 骑拉帝纳V 深渊探求：查看牌库顶4张，选2张加入手牌，其余放入放逐区
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	var card_a := CardInstance.create(_make_basic_pokemon_data("Card A", "G"), 0)
	var card_b := CardInstance.create(_make_basic_pokemon_data("Card B", "P"), 0)
	var card_c := CardInstance.create(_make_basic_pokemon_data("Card C", "W"), 0)
	var card_d := CardInstance.create(_make_basic_pokemon_data("Card D", "R"), 0)
	player.deck.append(card_a)
	player.deck.append(card_b)
	player.deck.append(card_c)
	player.deck.append(card_d)

	var effect := AttackLookTopPickHandRestLostZone.new(4, 2)
	var giratina_cd := _make_basic_pokemon_data("CS6bC_107 Giratina V", "N", 220, "Basic", "V")
	giratina_cd.attacks = [{"name": "Abyss Seeking", "cost": "C", "damage": "", "text": "", "is_vstar_power": false}]
	var card := CardInstance.create(giratina_cd, 0)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(card, giratina_cd.attacks[0], state)

	# 玩家选择第2和第4张（跳过第1和第3张）
	effect.set_attack_interaction_context([{"look_top_pick": [card_b, card_d]}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "CS6bC_107 should present 1 card selection step"),
		assert_eq(steps[0].items.size(), 4, "CS6bC_107 should show all 4 looked cards"),
		assert_eq(steps[0].min_select, 2, "CS6bC_107 should require selecting exactly 2 cards"),
		assert_true(card_b in player.hand, "CS6bC_107 should add selected card B to hand"),
		assert_true(card_d in player.hand, "CS6bC_107 should add selected card D to hand"),
		assert_eq(player.hand.size(), 2, "CS6bC_107 should have exactly 2 cards in hand"),
		assert_true(card_a in player.lost_zone, "CS6bC_107 should send unselected card A to lost zone"),
		assert_true(card_c in player.lost_zone, "CS6bC_107 should send unselected card C to lost zone"),
		assert_eq(player.lost_zone.size(), 2, "CS6bC_107 should have exactly 2 cards in lost zone"),
		assert_eq(player.deck.size(), 0, "CS6bC_107 should remove all looked cards from deck"),
	])


# ==================== 洛奇亚卡组审核回归测试 ====================


func test_csv8c_172_bloodmoon_ursaluna_uses_opponent_prizes() -> String:
	## 验证月月熊赫月ex的费用减免基于对手已获取的奖赏卡
	var state := _make_state()
	# 己方（玩家0）奖赏卡保持6张，对手（玩家1）已获取3张（剩余3张）
	state.players[0].prizes.resize(6)
	state.players[1].prizes.resize(3)
	var player: PlayerState = state.players[0]
	var bloodmoon_cd := _make_basic_pokemon_data(
		"Bloodmoon Ursaluna ex", "C", 260, "Basic", "ex",
		"f2afef80b13b8f6a071facbcade0251c"
	)
	bloodmoon_cd.attacks = [{"name": "Blood Moon", "cost": "CCCCC", "damage": "240", "text": "", "is_vstar_power": false}]
	var slot := _make_slot(bloodmoon_cd, 0)
	slot.attached_energy.clear()
	slot.attached_energy.append(CardInstance.create(_make_energy_data("C1", "C"), 0))
	slot.attached_energy.append(CardInstance.create(_make_energy_data("C2", "C"), 0))
	player.active_pokemon = slot

	var processor := EffectProcessor.new()
	processor.register_effect(bloodmoon_cd.effect_id, AbilityPrizeCountColorlessReduction.new("Blood Moon"))
	var modifier: int = processor.get_attack_colorless_cost_modifier(slot, bloodmoon_cd.attacks[0], state)
	var validator := RuleValidator.new()
	var can_attack := validator.can_use_attack(state, 0, 0, processor)

	return run_checks([
		assert_eq(modifier, -3, "对手获取3张奖赏卡时，无色能量减少3个"),
		assert_true(can_attack, "费用5C减3C=2C，附着2个无色能量可以攻击"),
	])


func test_vguard_energy_reduces_damage_from_v_pokemon() -> String:
	## 验证V防守能量对V宝可梦的伤害减少30
	var state := _make_state()
	var attacker_cd := _make_basic_pokemon_data("攻击V", "C", 220, "Basic", "V", "test_v_attacker")
	attacker_cd.attacks = [{"name": "Strike", "cost": "CCC", "damage": "100", "text": "", "is_vstar_power": false}]
	var attacker := _make_slot(attacker_cd, 0)
	state.players[0].active_pokemon = attacker

	var defender_cd := _make_basic_pokemon_data("防守方", "C", 200, "Basic", "", "test_defender_vguard")
	var defender := _make_slot(defender_cd, 1)
	var vguard_energy_cd := _make_energy_data("V防守能量", "C", "Special Energy", "88bf9902f1d769a667bbd3939fc757de")
	defender.attached_energy.append(CardInstance.create(vguard_energy_cd, 1))
	state.players[1].active_pokemon = defender

	var processor := EffectProcessor.new()
	var def_mod: int = processor.get_defender_modifier(defender, state, attacker)

	# 非V攻击者不应触发减伤
	var non_v_attacker_cd := _make_basic_pokemon_data("普通攻击者", "C", 100, "Basic", "", "test_non_v_attacker")
	var non_v_attacker := _make_slot(non_v_attacker_cd, 0)
	var def_mod_non_v: int = processor.get_defender_modifier(defender, state, non_v_attacker)

	return run_checks([
		assert_eq(def_mod, -30, "V防守能量应对V宝可梦攻击减少30伤害"),
		assert_eq(def_mod_non_v, 0, "V防守能量不应对非V宝可梦攻击生效"),
	])


func test_gift_energy_draws_on_knockout() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state

	var defender_cd := _make_basic_pokemon_data("Gift Holder", "C", 10, "Basic", "", "gift_test_def")
	var defender := _make_slot(defender_cd, 1)
	var gift_cd := _make_energy_data("Gift Energy", "C", "Special Energy", "dbb3f3d2ef2f3372bc8b21336e6c9bc6")
	defender.attached_energy.append(CardInstance.create(gift_cd, 1))
	state.players[1].active_pokemon = defender

	state.players[1].hand.clear()
	state.players[1].hand.append(CardInstance.create(_make_basic_pokemon_data("H1", "C"), 1))
	state.players[1].hand.append(CardInstance.create(_make_basic_pokemon_data("H2", "C"), 1))
	for i: int in 10:
		state.players[1].deck.append(CardInstance.create(_make_basic_pokemon_data("D%d" % i, "C"), 1))

	var has_gift: bool = EffectGiftEnergy.check_gift_energy_on_knockout(defender)
	var hand_before: int = state.players[1].hand.size()
	var draw_count: int = EffectGiftEnergy.trigger_on_knockout(state.players[1])
	var hand_after: int = state.players[1].hand.size()

	return run_checks([
		assert_true(has_gift, "Gift Energy should be detected on the knocked out Pokemon"),
		assert_eq(hand_before, 2, "Gift Energy fixture should start from two cards in hand"),
		assert_eq(draw_count, 5, "Gift Energy helper should report how many cards are needed to reach seven"),
		assert_eq(hand_after, hand_before, "Gift Energy helper should no longer mutate hand state directly"),
	])
func test_mist_energy_blocks_retreat_lock() -> String:
	## 验证薄雾能量阻止对手招式的撤退锁定效果
	var state := _make_state()
	var attacker_cd := _make_basic_pokemon_data("攻击者", "C", 100)
	attacker_cd.attacks = [{"name": "Bind", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	var attacker := _make_slot(attacker_cd, 0)
	state.players[0].active_pokemon = attacker

	var defender_cd := _make_basic_pokemon_data("防守方带薄雾", "C", 200, "Basic", "", "mist_test_def")
	var defender := _make_slot(defender_cd, 1)
	var mist_cd := _make_energy_data("薄雾能量", "C", "Special Energy", "fb0948c721db1f31767aa6cf0c2ea692")
	defender.attached_energy.append(CardInstance.create(mist_cd, 1))
	state.players[1].active_pokemon = defender

	var effect := AttackDefenderRetreatLockNextTurn.new(0)
	effect.execute_attack(attacker, defender, 0, state)
	var has_lock: bool = defender.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == "retreat_lock")

	return run_checks([
		assert_true(EffectMistEnergy.has_mist_energy(defender), "防守方应检测到薄雾能量"),
		assert_false(has_lock, "薄雾能量应阻止撤退锁定效果"),
	])


func test_fezandipiti_cruel_arrow_can_target_active() -> String:
	## 验证吉雉鸡ex的残忍箭矢可以选择对手的战斗宝可梦
	var state := _make_state()
	var attacker_cd := _make_basic_pokemon_data("吉雉鸡ex", "D", 210, "Basic", "ex", "ab6c3357e2b8a8385a68da738f41e0c1")
	attacker_cd.attacks = [{"name": "Cruel Arrow", "cost": "CCC", "damage": "", "text": "", "is_vstar_power": false}]
	var attacker := _make_slot(attacker_cd, 0)
	state.players[0].active_pokemon = attacker
	var defender := state.players[1].active_pokemon

	var effect := AttackAnyTargetDamage.new(100)
	effect.set_attack_interaction_context([{"any_target": [defender]}])
	effect.execute_attack(attacker, defender, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(defender.damage_counters, 100, "残忍箭矢选择战斗宝可梦时应造成100伤害"),
	])


func test_legacy_energy_reduces_prizes_e2e() -> String:
	## 端到端验证遗赠能量在昏厥时减少对手拿取的奖赏卡
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state

	# 配置一个附有遗赠能量的ex宝可梦（正常2张奖赏卡）
	var defender_cd := _make_basic_pokemon_data("带遗赠能量ex", "C", 10, "Basic", "ex", "legacy_e2e_def")
	defender_cd.attacks = [{"name": "Hit", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	var defender := _make_slot(defender_cd, 1)
	var legacy_cd := _make_energy_data("遗赠能量", "", "Special Energy", "6f31b7241a181631016466e561f148f3")
	defender.attached_energy.append(CardInstance.create(legacy_cd, 1))
	defender.attached_energy.append(CardInstance.create(_make_energy_data("C1", "C"), 1))
	state.players[1].active_pokemon = defender

	# 配置攻击方
	var attacker_cd := _make_basic_pokemon_data("攻击方", "C", 200)
	attacker_cd.attacks = [{"name": "KO Hit", "cost": "C", "damage": "200", "text": "", "is_vstar_power": false}]
	state.players[0].active_pokemon = _make_slot(attacker_cd, 0)
	state.players[0].active_pokemon.attached_energy.append(
		CardInstance.create(_make_energy_data("C1", "C"), 0)
	)

	# 确保对手（玩家0）有足够奖赏卡
	state.players[0].prizes.clear()
	for i: int in 6:
		state.players[0].prizes.append(CardInstance.create(_make_basic_pokemon_data("P%d" % i, "C"), 0))
	var prizes_before: int = state.players[0].prizes.size()

	# 执行攻击，应该击倒 defender
	gsm.use_attack(0, 0)
	gsm.resolve_take_prize(0, 0)

	var prizes_after: int = state.players[0].prizes.size()
	var prizes_taken: int = prizes_before - prizes_after

	return run_checks([
		assert_eq(prizes_taken, 1, "遗赠能量应使ex宝可梦昏厥时对手只拿1张奖赏卡（正常2张减1张）"),
	])


func test_cs5ac_107_arceus_vstar_starbirth_uses_vstar_power_and_allows_zero_cards() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var arceus_cd := _make_basic_pokemon_data("阿尔宙斯VSTAR", "C", 280, "VSTAR", "V", "9a0982e46cf9a3aaed89e6d3517e7d58")
	arceus_cd.abilities = [{"name": "星耀诞生", "text": ""}]
	var arceus_slot := _make_slot(arceus_cd, 0)
	player.active_pokemon = arceus_slot
	player.deck.append(CardInstance.create(_make_trainer_data("DeckA", "Item"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("DeckB", "Item"), 0))
	processor.register_pokemon_card(arceus_cd)

	var effect: BaseEffect = processor.get_ability_effect(arceus_slot, 0, state)
	var steps: Array[Dictionary] = effect.get_interaction_steps(arceus_slot.get_top_card(), state)
	var execute_ok: bool = processor.execute_ability_effect(arceus_slot, 0, [{"search_cards": []}], state)

	return run_checks([
		assert_true(execute_ok, "CS5aC_107 should execute Starbirth"),
		assert_eq(int(steps[0].get("min_select", -1)), 0, "CS5aC_107 should allow choosing up to 2 cards, including 0"),
		assert_true(state.vstar_power_used[0], "CS5aC_107 should mark the VSTAR power as used"),
		assert_eq(player.hand.size(), 0, "CS5aC_107 should not auto-tutor cards when the player explicitly chooses none"),
		assert_false(processor.can_use_ability(arceus_slot, state, 0), "CS5aC_107 should not be usable again after Starbirth"),
	])


func test_csnc_009_arceus_v_trinity_charge_targets_only_pokemon_v() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()

	var arceus_cd := _make_basic_pokemon_data("阿尔宙斯V", "C", 220, "Basic", "V", "94c6f72a67045857fa44962e4fbb8c27")
	arceus_cd.attacks = [{"name": "三重蓄能", "cost": "CC", "damage": "", "text": "", "is_vstar_power": false}]
	var arceus_slot := _make_slot(arceus_cd, 0)
	player.active_pokemon = arceus_slot
	player.bench.clear()

	var giratina_slot := _make_slot(_make_basic_pokemon_data("骑拉帝纳V", "N", 220, "Basic", "V"), 0)
	var iron_leaves_slot := _make_slot(_make_basic_pokemon_data("铁斑叶ex", "G", 220, "Basic", "ex"), 0)
	player.bench.append(giratina_slot)
	player.bench.append(iron_leaves_slot)
	player.deck.append(CardInstance.create(_make_energy_data("Grass", "G"), 0))
	player.deck.append(CardInstance.create(_make_energy_data("Psychic", "P"), 0))
	processor.register_pokemon_card(arceus_cd)

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(arceus_slot, 0)
	var steps: Array[Dictionary] = effects[0].get_attack_interaction_steps(arceus_slot.get_top_card(), arceus_cd.attacks[0], state)
	var target_items: Array = steps[0].get("target_items", [])

	return run_checks([
		assert_eq(steps.size(), 1, "CSNC_009 should create an assignment interaction"),
		assert_contains(target_items, arceus_slot, "CSNC_009 should still be able to attach to the attacker itself"),
		assert_contains(target_items, giratina_slot, "CSNC_009 should target Benched Pokemon V"),
		assert_false(iron_leaves_slot in target_items, "CSNC_009 should not treat ex as Pokemon V"),
	])


func test_cs5ac_107_arceus_vstar_trinity_nova_respects_energy_assignments() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.bench.clear()

	var arceus_cd := _make_basic_pokemon_data("阿尔宙斯VSTAR", "C", 280, "VSTAR", "V", "9a0982e46cf9a3aaed89e6d3517e7d58")
	arceus_cd.attacks = [{"name": "三重新星", "cost": "CCC", "damage": "200", "text": "", "is_vstar_power": false}]
	var attacker := _make_slot(arceus_cd, 0)
	player.active_pokemon = attacker

	var giratina_slot := _make_slot(_make_basic_pokemon_data("骑拉帝纳V", "N", 220, "Basic", "V"), 0)
	var ex_slot := _make_slot(_make_basic_pokemon_data("铁斑叶ex", "G", 220, "Basic", "ex"), 0)
	player.bench.append(giratina_slot)
	player.bench.append(ex_slot)

	var energy_a := CardInstance.create(_make_energy_data("GrassA", "G"), 0)
	var energy_b := CardInstance.create(_make_energy_data("GrassB", "G"), 0)
	var energy_c := CardInstance.create(_make_energy_data("PsychicA", "P"), 0)
	player.deck.append(energy_a)
	player.deck.append(energy_b)
	player.deck.append(energy_c)
	processor.register_pokemon_card(arceus_cd)

	var attack_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var steps: Array[Dictionary] = attack_effects[0].get_attack_interaction_steps(attacker.get_top_card(), arceus_cd.attacks[0], state)
	var target_items: Array = steps[0].get("target_items", [])
	var ctx := {
		"energy_assignments": [
			{"source": energy_a, "target": giratina_slot},
			{"source": energy_b, "target": attacker},
			{"source": energy_c, "target": giratina_slot},
		]
	}
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [ctx])

	return run_checks([
		assert_eq(steps.size(), 1, "CS5aC_107 should expose one assignment step for Trinity Nova"),
		assert_contains(target_items, attacker, "CS5aC_107 should be able to target itself"),
		assert_contains(target_items, giratina_slot, "CS5aC_107 should be able to target another Pokemon V"),
		assert_false(ex_slot in target_items, "CS5aC_107 should not target Pokemon ex"),
		assert_eq(attacker.attached_energy.size(), 1, "CS5aC_107 should attach the selected energy to itself"),
		assert_eq(giratina_slot.attached_energy.size(), 2, "CS5aC_107 should attach two selected energies to Giratina V"),
		assert_eq(ex_slot.attached_energy.size(), 0, "CS5aC_107 should not attach energy to Pokemon ex"),
	])


func test_csv1c_099_skwovet_nest_stash_keeps_existing_deck_top_order() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var skwovet_cd := _make_basic_pokemon_data("贪心栗鼠", "C", 60, "Basic", "", "de67a9a68f5207134be40c715c9be8ef")
	skwovet_cd.abilities = [{"name": "巢穴藏身", "text": ""}]
	var skwovet_slot := _make_slot(skwovet_cd, 0)
	player.active_pokemon = skwovet_slot

	var top_card := CardInstance.create(_make_trainer_data("Top Card", "Item"), 0)
	var next_card := CardInstance.create(_make_trainer_data("Next Card", "Item"), 0)
	var hand_a := CardInstance.create(_make_trainer_data("Hand A", "Item"), 0)
	var hand_b := CardInstance.create(_make_trainer_data("Hand B", "Item"), 0)
	player.deck.append(top_card)
	player.deck.append(next_card)
	player.hand.append(hand_a)
	player.hand.append(hand_b)
	processor.register_pokemon_card(skwovet_cd)
	processor.execute_ability_effect(skwovet_slot, 0, [], state)

	return run_checks([
		assert_eq(player.hand.size(), 1, "CSV1C_099 should draw exactly one card"),
		assert_eq(player.hand[0], top_card, "CSV1C_099 should draw the original top card, not a shuffled hand card"),
		assert_eq(player.deck[0], next_card, "CSV1C_099 should preserve the remaining deck top order"),
		assert_contains(player.deck, hand_a, "CSV1C_099 should return the original hand cards to the deck bottom"),
		assert_contains(player.deck, hand_b, "CSV1C_099 should return all hand cards to the deck bottom"),
	])


func test_cs6bc_123_lost_vacuum_uses_lost_zone_cost_and_selected_target() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.lost_zone.clear()
	var fodder := CardInstance.create(_make_trainer_data("Fodder", "Item"), 0)
	var lost_vacuum := CardInstance.create(_make_trainer_data("Lost Vacuum", "Item", "8f655fea1f90164bfbccb7a95c223e17"), 0)
	player.hand.append(fodder)
	player.hand.append(lost_vacuum)

	var opponent: PlayerState = gsm.game_state.players[1]
	var opp_tool := CardInstance.create(_make_trainer_data("Choice Belt", "Tool"), 1)
	opponent.active_pokemon.attached_tool = opp_tool
	var stadium := CardInstance.create(_make_trainer_data("Lost City", "Stadium"), 1)
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 1

	var success := gsm.play_trainer(0, lost_vacuum, [{
		"discard_cards": [fodder],
		"lost_vacuum_target": [stadium],
	}])

	return run_checks([
		assert_true(success, "CS6bC_123 should be playable when there is a valid cost and target"),
		assert_contains(player.lost_zone, fodder, "CS6bC_123 should put the chosen hand card into the lost zone as the cost"),
		assert_contains(gsm.game_state.players[1].lost_zone, stadium, "CS6bC_123 should move the selected stadium to the lost zone"),
		assert_eq(opponent.active_pokemon.attached_tool, opp_tool, "CS6bC_123 should respect the selected target instead of auto-removing a tool first"),
	])


func test_cs6bc_130_lost_city_moves_only_pokemon_cards_to_lost_zone() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	var player: PlayerState = gsm.game_state.players[0]
	player.bench.clear()
	player.discard_pile.clear()
	player.lost_zone.clear()
	var slot := _make_slot(_make_basic_pokemon_data("Knocked Out", "P", 90), 0)
	slot.damage_counters = 90
	var attached_energy := CardInstance.create(_make_energy_data("Psychic", "P"), 0)
	var attached_tool := CardInstance.create(_make_trainer_data("Maximum Belt", "Tool"), 0)
	slot.attached_energy.append(attached_energy)
	slot.attached_tool = attached_tool
	player.bench.append(slot)

	gsm.game_state.stadium_card = CardInstance.create(_make_trainer_data("Lost City", "Stadium", "7f4e493ec0d852a5bb31c02bdbdb2c4e"), 1)
	gsm.game_state.stadium_owner_index = 1

	var resolved := gsm._resolve_mid_turn_knockouts()

	return run_checks([
		assert_true(resolved, "CS6bC_130 should resolve pending knockouts"),
		assert_false(slot in player.bench, "CS6bC_130 should remove the knocked out Pokemon from the bench"),
		assert_eq(player.lost_zone.size(), 1, "CS6bC_130 should move the Pokemon card to the lost zone"),
		assert_contains(player.lost_zone, slot.get_top_card(), "CS6bC_130 should lost-zone the Pokemon card itself"),
		assert_contains(player.discard_pile, attached_energy, "CS6bC_130 should discard attached energy instead of lost-zoning it"),
		assert_contains(player.discard_pile, attached_tool, "CS6bC_130 should discard attached tools instead of lost-zoning them"),
	])


func test_cs6bc_026_cramorant_lost_zone_supply_removes_cost_and_ignores_only_weakness() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.lost_zone.clear()
	for i: int in 4:
		player.lost_zone.append(CardInstance.create(_make_basic_pokemon_data("Lost_%d" % i, "C"), 0))

	var cramorant_cd: CardData = CardDatabase.get_card("CS6bC", "026")
	var attacker := _make_slot(cramorant_cd, 0)
	attacker.attached_energy.clear()
	player.active_pokemon = attacker

	var defender_cd := _make_basic_pokemon_data("Weak Resist Target", "G", 200)
	defender_cd.weakness_energy = "W"
	defender_cd.weakness_value = "x2"
	defender_cd.resistance_energy = "W"
	defender_cd.resistance_value = "-30"
	var defender := _make_slot(defender_cd, 1)
	state.players[1].active_pokemon = defender

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(cramorant_cd)
	var validator := RuleValidator.new()
	var can_attack := validator.can_use_attack(state, 0, 0, processor)
	var ignore_weakness: bool = processor.attack_ignores_weakness(attacker, 0, state)
	var ignore_resistance: bool = processor.attack_ignores_resistance(attacker, 0, state)
	var damage := DamageCalculator.new().calculate_damage(
		attacker,
		defender,
		cramorant_cd.attacks[0],
		state,
		0,
		0,
		0,
		ignore_weakness,
		ignore_resistance
	)

	return run_checks([
		assert_not_null(cramorant_cd, "CS6bC_026 should exist in the card database"),
		assert_true(can_attack, "CS6bC_026 should attack for free with 4 cards in the Lost Zone"),
		assert_true(ignore_weakness, "CS6bC_026 should ignore Weakness"),
		assert_false(ignore_resistance, "CS6bC_026 should not ignore Resistance"),
		assert_eq(damage, 80, "CS6bC_026 should ignore Weakness but still apply Resistance to its 110 damage"),
	])


func test_cs6bc_052_comfey_flower_selecting_moves_unpicked_card_to_lost_zone() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var comfey_cd: CardData = CardDatabase.get_card("CS6bC", "052")
	var comfey_slot := _make_slot(comfey_cd, 0)
	player.active_pokemon = comfey_slot
	var card_a := CardInstance.create(_make_trainer_data("Top A", "Item"), 0)
	var card_b := CardInstance.create(_make_trainer_data("Top B", "Item"), 0)
	player.deck.append(card_a)
	player.deck.append(card_b)

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(comfey_cd)
	var effect: BaseEffect = processor.get_ability_effect(comfey_slot, 0, state)
	var steps: Array[Dictionary] = effect.get_interaction_steps(comfey_slot.get_top_card(), state)
	var execute_ok: bool = processor.execute_ability_effect(comfey_slot, 0, [{
		"flower_selecting_pick": [card_b],
	}], state)
	var reused_same_turn: bool = processor.can_use_ability(comfey_slot, state, 0)

	var bench_state := _make_state()
	var bench_player: PlayerState = bench_state.players[0]
	bench_player.deck.clear()
	bench_player.active_pokemon = _make_slot(_make_basic_pokemon_data("Other Active", "C"), 0)
	var bench_comfey := _make_slot(comfey_cd, 0)
	bench_player.bench.clear()
	bench_player.bench.append(bench_comfey)
	bench_player.deck.append(CardInstance.create(_make_trainer_data("Bench Top", "Item"), 0))
	var bench_processor := EffectProcessor.new()
	bench_processor.register_pokemon_card(comfey_cd)
	var cannot_use_on_bench: bool = not bench_processor.can_use_ability(bench_comfey, bench_state, 0)

	return run_checks([
		assert_not_null(comfey_cd, "CS6bC_052 should exist in the card database"),
		assert_eq(steps.size(), 1, "CS6bC_052 should present 1 selection step"),
		assert_true(execute_ok, "CS6bC_052 should execute Flower Selecting"),
		assert_contains(player.hand, card_b, "CS6bC_052 should put the chosen card into hand"),
		assert_contains(player.lost_zone, card_a, "CS6bC_052 should put the other looked card into the Lost Zone"),
		assert_false(reused_same_turn, "CS6bC_052 should only be usable once each turn"),
		assert_true(cannot_use_on_bench, "CS6bC_052 should only be usable while Active"),
	])


func test_cs6bc_122_mirage_gate_attaches_two_different_basic_energy_types() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.lost_zone.clear()
	for i: int in 7:
		player.lost_zone.append(CardInstance.create(_make_basic_pokemon_data("LostGate_%d" % i, "C"), 0))

	var grass_a := CardInstance.create(_make_energy_data("Grass A", "G"), 0)
	var grass_b := CardInstance.create(_make_energy_data("Grass B", "G"), 0)
	var psychic := CardInstance.create(_make_energy_data("Psychic A", "P"), 0)
	player.deck.append(grass_a)
	player.deck.append(grass_b)
	player.deck.append(psychic)

	var mirage_gate_cd: CardData = CardDatabase.get_card("CS6bC", "122")
	var mirage_gate := CardInstance.create(mirage_gate_cd, 0)
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(mirage_gate_cd.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(mirage_gate, state)
	var source_items: Array = steps[0].get("source_items", []) if not steps.is_empty() else []

	effect.execute(mirage_gate, [{
		"mirage_gate_assignments": [
			{"source": grass_a, "target": player.active_pokemon},
			{"source": psychic, "target": player.bench[0]},
		],
	}], state)

	return run_checks([
		assert_not_null(mirage_gate_cd, "CS6bC_122 should exist in the card database"),
		assert_eq(steps.size(), 1, "CS6bC_122 should present 1 assignment step"),
		assert_eq(source_items.size(), 2, "CS6bC_122 should only offer one card per Basic Energy type"),
		assert_contains(player.active_pokemon.attached_energy, grass_a, "CS6bC_122 should attach the selected Grass Energy"),
		assert_contains(player.bench[0].attached_energy, psychic, "CS6bC_122 should attach the selected Psychic Energy"),
		assert_contains(player.deck, grass_b, "CS6bC_122 should leave same-type duplicates in the deck when unselected"),
	])


func test_cs6bc_125_colress_experiment_puts_rest_in_lost_zone() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.lost_zone.clear()

	var top_cards: Array[CardInstance] = []
	for i: int in 5:
		var card := CardInstance.create(_make_trainer_data("Colress_%d" % i, "Item"), 0)
		top_cards.append(card)
		player.deck.append(card)

	var colress_cd: CardData = CardDatabase.get_card("CS6bC", "125")
	var colress := CardInstance.create(colress_cd, 0)
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(colress_cd.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(colress, state)
	effect.execute(colress, [{
		"colress_pick": [top_cards[1], top_cards[2], top_cards[4]],
	}], state)

	return run_checks([
		assert_not_null(colress_cd, "CS6bC_125 should exist in the card database"),
		assert_eq(steps.size(), 1, "CS6bC_125 should present 1 card selection step"),
		assert_eq(int(steps[0].get("min_select", -1)), 3, "CS6bC_125 should require choosing exactly 3 cards"),
		assert_contains(player.hand, top_cards[1], "CS6bC_125 should put the first chosen card into hand"),
		assert_contains(player.hand, top_cards[2], "CS6bC_125 should put the second chosen card into hand"),
		assert_contains(player.hand, top_cards[4], "CS6bC_125 should put the third chosen card into hand"),
		assert_contains(player.lost_zone, top_cards[0], "CS6bC_125 should put the first unchosen card into the Lost Zone"),
		assert_contains(player.lost_zone, top_cards[3], "CS6bC_125 should put the second unchosen card into the Lost Zone"),
		assert_eq(player.deck.size(), 0, "CS6bC_125 should remove all 5 looked cards from the deck"),
	])


func test_cs6bc_122_mirage_gate_can_whiff_when_deck_has_no_basic_energy() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	state.current_player_index = 0
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN

	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	player.lost_zone.clear()
	for i: int in 7:
		player.lost_zone.append(CardInstance.create(_make_basic_pokemon_data("Lost_%d" % i, "C"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("Deck Card", "Item"), 0))

	var mirage_gate_cd: CardData = CardDatabase.get_card("CS6bC", "122")
	var mirage_gate := CardInstance.create(mirage_gate_cd, 0)
	player.hand.append(mirage_gate)
	var effect: BaseEffect = gsm.effect_processor.get_effect(mirage_gate_cd.effect_id)
	var can_execute: bool = effect.can_execute(mirage_gate, state)
	var steps: Array[Dictionary] = effect.get_interaction_steps(mirage_gate, state)
	var success: bool = gsm.play_trainer(0, mirage_gate, [])

	return run_checks([
		assert_not_null(mirage_gate_cd, "CS6bC_122 should exist in the card database"),
		assert_true(can_execute, "CS6bC_122 should still be playable when the Lost Zone condition is met even if the deck has no Basic Energy"),
		assert_true(steps.is_empty(), "CS6bC_122 should not force an assignment step when the deck has no Basic Energy"),
		assert_true(success, "CS6bC_122 should still resolve and be discarded when it whiffs"),
		assert_contains(player.discard_pile, mirage_gate, "CS6bC_122 should be discarded after use even when no Energy is found"),
		assert_eq(player.active_pokemon.attached_energy.size(), 0, "CS6bC_122 should not attach any Energy when the deck has none"),
	])


func test_csv6c_096_roaring_moon_ex_attack_effects() -> String:
	var roaring_cd: CardData = CardDatabase.get_card("CSV6C", "096")

	var ko_state := _make_state()
	var ko_player: PlayerState = ko_state.players[0]
	var ko_attacker := _make_slot(roaring_cd, 0)
	ko_player.active_pokemon = ko_attacker
	var ko_defender := _make_slot(_make_basic_pokemon_data("KO Target", "C", 220), 1)
	ko_state.players[1].active_pokemon = ko_defender
	var ko_processor := EffectProcessor.new()
	ko_processor.register_pokemon_card(roaring_cd)
	ko_processor.execute_attack_effect(ko_attacker, 0, ko_defender, ko_state)

	var mist_state := _make_state()
	var mist_player: PlayerState = mist_state.players[0]
	var mist_attacker := _make_slot(roaring_cd, 0)
	mist_player.active_pokemon = mist_attacker
	var mist_defender := _make_slot(_make_basic_pokemon_data("Mist Target", "C", 220), 1)
	mist_defender.attached_energy.append(CardInstance.create(
		_make_energy_data("Mist Energy", "C", "Special Energy", "fb0948c721db1f31767aa6cf0c2ea692"),
		1
	))
	mist_state.players[1].active_pokemon = mist_defender
	var mist_processor := EffectProcessor.new()
	mist_processor.register_pokemon_card(roaring_cd)
	mist_processor.execute_attack_effect(mist_attacker, 0, mist_defender, mist_state)

	var bonus_state := _make_state()
	var bonus_player: PlayerState = bonus_state.players[0]
	var bonus_attacker := _make_slot(roaring_cd, 0)
	bonus_player.active_pokemon = bonus_attacker
	var bonus_defender := _make_slot(_make_basic_pokemon_data("Bonus Target", "C", 220), 1)
	bonus_state.players[1].active_pokemon = bonus_defender
	var stadium := CardInstance.create(_make_trainer_data("Temple", "Stadium"), 0)
	bonus_state.stadium_card = stadium
	bonus_state.stadium_owner_index = 0
	var bonus_gsm := GameStateMachine.new()
	bonus_gsm.game_state = bonus_state
	bonus_gsm.effect_processor = EffectProcessor.new()
	bonus_gsm.effect_processor.register_pokemon_card(roaring_cd)
	bonus_gsm.damage_calculator = DamageCalculator.new()
	var keep_damage: int = bonus_gsm._calculate_attack_damage(
		bonus_attacker,
		bonus_defender,
		roaring_cd.attacks[1],
		1,
		[{"discard_stadium_bonus": ["keep"]}]
	)
	var discard_damage: int = bonus_gsm._calculate_attack_damage(
		bonus_attacker,
		bonus_defender,
		roaring_cd.attacks[1],
		1,
		[{"discard_stadium_bonus": ["discard"]}]
	)
	bonus_gsm.effect_processor.execute_attack_effect(
		bonus_attacker,
		1,
		bonus_defender,
		bonus_state,
		[{"discard_stadium_bonus": ["discard"]}]
	)

	return run_checks([
		assert_not_null(roaring_cd, "CSV6C_096 should exist in the card database"),
		assert_eq(ko_defender.damage_counters, ko_defender.get_max_hp(), "CSV6C_096 Frenzied Gouging should Knock Out the Defending Pokemon"),
		assert_eq(ko_attacker.damage_counters, 200, "CSV6C_096 Frenzied Gouging should place 200 damage on itself"),
		assert_eq(mist_defender.damage_counters, 0, "CSV6C_096 Frenzied Gouging should respect Mist Energy and fail to Knock Out the target"),
		assert_eq(mist_attacker.damage_counters, 200, "CSV6C_096 Frenzied Gouging should still damage itself when the effect is prevented"),
		assert_eq(keep_damage, 100, "CSV6C_096 Calamity Storm should deal its printed 100 damage when the Stadium is kept"),
		assert_eq(discard_damage, 220, "CSV6C_096 Calamity Storm should gain 120 damage when the Stadium is discarded"),
		assert_null(bonus_state.stadium_card, "CSV6C_096 Calamity Storm should discard the Stadium after the player chooses to do so"),
		assert_contains(bonus_player.discard_pile, stadium, "CSV6C_096 Calamity Storm should move the discarded Stadium to its owner's discard pile"),
	])


func test_csv7c_161_dunsparce_digging_prevents_damage_and_effects() -> String:
	var state := _make_state()
	var dunsparce_cd: CardData = CardDatabase.get_card("CSV7C", "161")
	var processor := EffectProcessor.new(RiggedCoinFlipper.new([true]))
	processor.register_pokemon_card(dunsparce_cd)

	var player: PlayerState = state.players[0]
	var dunsparce := _make_slot(dunsparce_cd, 0)
	player.active_pokemon = dunsparce
	processor.execute_attack_effect(dunsparce, 1, state.players[1].active_pokemon, state)

	state.turn_number += 1
	state.current_player_index = 1
	var incoming_attacker := state.players[1].active_pokemon
	var prevented_damage: bool = processor.is_damage_prevented_by_defender_ability(incoming_attacker, dunsparce, state)

	var any_target := AttackAnyTargetDamage.new(100)
	any_target.set_attack_interaction_context([{"any_target": [dunsparce]}])
	any_target.execute_attack(incoming_attacker, dunsparce, 0, state)
	any_target.clear_attack_interaction_context()
	var damage_after_target_attack: int = dunsparce.damage_counters

	var ko_effect := AttackKnockoutDefenderThenSelfDamage.new(200, 0)
	ko_effect.execute_attack(incoming_attacker, dunsparce, 0, state)

	return run_checks([
		assert_not_null(dunsparce_cd, "CSV7C_161 should exist in the card database"),
		assert_true(prevented_damage, "CSV7C_161 should prevent attack damage during the opponent's next turn on heads"),
		assert_eq(damage_after_target_attack, 0, "CSV7C_161 should prevent direct attack damage effects such as chosen-target damage"),
		assert_eq(dunsparce.damage_counters, 0, "CSV7C_161 should prevent attack effects that would Knock it Out on the next turn"),
		assert_eq(incoming_attacker.damage_counters, 200, "CSV7C_161 should not stop the attacking Pokemon from damaging itself"),
	])


func test_csv7c_162_dudunsparce_run_away_draw_draws_and_shuffles_self() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.bench.clear()

	var dudunsparce_cd: CardData = CardDatabase.get_card("CSV7C", "162")
	var dudunsparce := _make_slot(dudunsparce_cd, 0)
	var dudunsparce_card: CardInstance = dudunsparce.get_top_card()
	var attached_energy := CardInstance.create(_make_energy_data("Basic Colorless", "C"), 0)
	var attached_tool := CardInstance.create(_make_trainer_data("Tool", "Tool"), 0)
	dudunsparce.attached_energy.append(attached_energy)
	dudunsparce.attached_tool = attached_tool
	player.active_pokemon = dudunsparce

	var replacement := _make_slot(_make_basic_pokemon_data("Replacement", "C", 110), 0)
	var other_bench := _make_slot(_make_basic_pokemon_data("Bench Mate", "C", 90), 0)
	player.bench.append(replacement)
	player.bench.append(other_bench)

	var draw_a := CardInstance.create(_make_trainer_data("Draw A", "Item"), 0)
	var draw_b := CardInstance.create(_make_trainer_data("Draw B", "Item"), 0)
	var draw_c := CardInstance.create(_make_trainer_data("Draw C", "Item"), 0)
	var deck_tail := CardInstance.create(_make_trainer_data("Deck Tail", "Item"), 0)
	player.deck.append(draw_a)
	player.deck.append(draw_b)
	player.deck.append(draw_c)
	player.deck.append(deck_tail)

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(dudunsparce_cd)
	var effect: BaseEffect = processor.get_ability_effect(dudunsparce, 0, state)
	var steps: Array[Dictionary] = effect.get_interaction_steps(dudunsparce_card, state)
	var execute_ok: bool = processor.execute_ability_effect(dudunsparce, 0, [{
		"replacement_bench": [replacement],
	}], state)

	return run_checks([
		assert_not_null(dudunsparce_cd, "CSV7C_162 should exist in the card database"),
		assert_eq(steps.size(), 1, "CSV7C_162 should ask for a replacement Active Pokemon when it is Active"),
		assert_true(execute_ok, "CSV7C_162 should execute Run Away Draw"),
		assert_eq(player.active_pokemon, replacement, "CSV7C_162 should promote the chosen Benched Pokemon to Active"),
		assert_false(replacement in player.bench, "CSV7C_162 should remove the chosen replacement from the Bench"),
		assert_false(dudunsparce in player.bench, "CSV7C_162 should remove itself from play after shuffling back"),
		assert_eq(player.hand.size(), 3, "CSV7C_162 should draw 3 cards before shuffling itself back"),
		assert_contains(player.hand, draw_a, "CSV7C_162 should draw the first card from the deck"),
		assert_contains(player.hand, draw_b, "CSV7C_162 should draw the second card from the deck"),
		assert_contains(player.hand, draw_c, "CSV7C_162 should draw the third card from the deck"),
		assert_contains(player.deck, dudunsparce_card, "CSV7C_162 should shuffle the Pokemon card back into the deck"),
		assert_contains(player.deck, attached_energy, "CSV7C_162 should shuffle attached Energy back into the deck"),
		assert_contains(player.deck, attached_tool, "CSV7C_162 should shuffle the attached Tool back into the deck"),
	])


func test_cs5bc_111_bidoof_carefree_countenance_blocks_attack_bench_damage() -> String:
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	var opponent: PlayerState = state.players[1]
	opponent.bench.clear()

	var bidoof_cd := _make_basic_pokemon_data("大牙狸", "C", 60, "Basic", "", "5a80f8eb94c6fcc27c475c10a63cf856")
	bidoof_cd.abilities = [{"name": "毫不在意", "text": ""}]
	var protected_slot := _make_slot(bidoof_cd, 1)
	var other_slot := _make_slot(_make_basic_pokemon_data("Other Bench", "C", 90), 1)
	opponent.bench.append(protected_slot)
	opponent.bench.append(other_slot)

	var effect := EffectBenchDamage.new(30, true, "opponent")
	effect.execute_attack(attacker, opponent.active_pokemon, 0, state)

	return run_checks([
		assert_eq(protected_slot.damage_counters, 0, "CS5bC_111 should ignore attack damage while on the bench"),
		assert_eq(other_slot.damage_counters, 30, "CS5bC_111 should not block damage for other Benched Pokemon"),
	])


func test_cs5bc_111_and_cs5ac_105_coin_flip_attacks_map_to_fail_on_tails() -> String:
	var processor := EffectProcessor.new()

	var bidoof_cd := _make_basic_pokemon_data("大牙狸", "C", 60, "Basic", "", "5a80f8eb94c6fcc27c475c10a63cf856")
	bidoof_cd.attacks = [{"name": "终结门牙", "cost": "CC", "damage": "30", "text": "", "is_vstar_power": false}]
	processor.register_pokemon_card(bidoof_cd)
	var bidoof_slot := _make_slot(bidoof_cd, 0)

	var bibarel_cd := _make_basic_pokemon_data("大尾狸", "C", 120, "Stage 1", "", "d8e81bf574a9d7a0f42ff33e15b0522c")
	bibarel_cd.attacks = [{"name": "长尾粉碎", "cost": "CCC", "damage": "100", "text": "", "is_vstar_power": false}]
	processor.register_pokemon_card(bibarel_cd)
	var bibarel_slot := _make_slot(bibarel_cd, 0)

	var bidoof_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(bidoof_slot, 0)
	var bibarel_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(bibarel_slot, 0)

	return run_checks([
		assert_true(bidoof_effects[0] is AttackCoinFlipOrFail, "CS5bC_111 should use the fail-on-tails effect"),
		assert_eq((bidoof_effects[0] as AttackCoinFlipOrFail).base_damage, 30, "CS5bC_111 should only cancel its printed 30 damage"),
		assert_true(bibarel_effects[0] is AttackCoinFlipOrFail, "CS5aC_105 should fail on tails instead of adding bonus damage"),
		assert_eq((bibarel_effects[0] as AttackCoinFlipOrFail).base_damage, 100, "CS5aC_105 should cancel its printed 100 damage on tails"),
	])


func test_csv1c_053_shuppet_shadowy_surrounding_heads_locks_items_only_for_next_turn() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.coin_flipper = RiggedCoinFlipper.new([true])
	var state := gsm.game_state

	var shuppet_cd := _make_basic_pokemon_data("CSV1C_053 Shuppet", "P", 60, "Basic", "", "82911221bcf50febdb02c331ccb793f4")
	shuppet_cd.attacks = [{
		"name": "阴影包围",
		"cost": "P",
		"damage": "10",
		"text": "抛掷1次硬币如果为正面，则在下一个对手的回合，对手无法从手牌使出物品。",
		"is_vstar_power": false,
	}]
	gsm.effect_processor.register_pokemon_card(shuppet_cd)
	var attacker := _make_slot(shuppet_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Psychic", "P"), 0))
	state.players[0].active_pokemon = attacker

	var opponent: PlayerState = state.players[1]
	opponent.hand.clear()
	var locked_item := CardInstance.create(_make_trainer_data("Locked Item", "Item"), 1)
	var open_supporter := CardInstance.create(_make_trainer_data("Open Supporter", "Supporter"), 1)
	opponent.hand.append(locked_item)
	opponent.hand.append(open_supporter)

	var attacked := gsm.use_attack(0, 0)
	var item_blocked := not gsm.play_trainer(1, locked_item, [])
	var supporter_allowed := gsm.play_trainer(1, open_supporter, [])

	gsm.end_turn(1)
	gsm.end_turn(0)

	var unlocked_item := CardInstance.create(_make_trainer_data("Unlocked Item", "Item"), 1)
	opponent.hand.append(unlocked_item)
	var item_unlocked := gsm.play_trainer(1, unlocked_item, [])

	return run_checks([
		assert_true(gsm.effect_processor.has_attack_effect(shuppet_cd.effect_id), "CSV1C_053 should register its scripted attack"),
		assert_true(attacked, "CSV1C_053 should use Shadowy Surrounding successfully"),
		assert_true(item_blocked, "CSV1C_053 heads should stop the opponent from playing Item cards next turn"),
		assert_true(supporter_allowed, "CSV1C_053 should only lock Items, not Supporters"),
		assert_true(item_unlocked, "CSV1C_053 item lock should expire after the opponent's next turn"),
	])


func test_csv1c_053_shuppet_shadowy_surrounding_tails_does_not_lock_items() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.coin_flipper = RiggedCoinFlipper.new([false])
	var state := gsm.game_state

	var shuppet_cd := _make_basic_pokemon_data("CSV1C_053 Shuppet", "P", 60, "Basic", "", "82911221bcf50febdb02c331ccb793f4")
	shuppet_cd.attacks = [{
		"name": "阴影包围",
		"cost": "P",
		"damage": "10",
		"text": "抛掷1次硬币如果为正面，则在下一个对手的回合，对手无法从手牌使出物品。",
		"is_vstar_power": false,
	}]
	gsm.effect_processor.register_pokemon_card(shuppet_cd)
	var attacker := _make_slot(shuppet_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Psychic", "P"), 0))
	state.players[0].active_pokemon = attacker

	var opponent: PlayerState = state.players[1]
	opponent.hand.clear()
	var item := CardInstance.create(_make_trainer_data("Unlocked Item", "Item"), 1)
	opponent.hand.append(item)

	var attacked := gsm.use_attack(0, 0)
	var item_allowed := gsm.play_trainer(1, item, [])

	return run_checks([
		assert_true(attacked, "CSV1C_053 should still deal damage when tails"),
		assert_true(item_allowed, "CSV1C_053 tails should not create an Item lock"),
	])


func test_csv1c_054_banette_ex_everlasting_darkness_locks_items() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state

	var banette_cd := _make_basic_pokemon_data("CSV1C_054 Banette ex", "P", 250, "Stage 1", "ex", "ffe8874ed7810f9ecd8209d4a09ade59")
	banette_cd.evolves_from = "怨影娃娃"
	banette_cd.attacks = [
		{
			"name": "暗夜难明",
			"cost": "P",
			"damage": "30",
			"text": "在下一个对手的回合，对手无法从手牌使出物品。",
			"is_vstar_power": false,
		},
		{
			"name": "灵骚",
			"cost": "P",
			"damage": "60×",
			"text": "查看对手的手牌，造成其中训练家张数×60伤害。",
			"is_vstar_power": false,
		},
	]
	gsm.effect_processor.register_pokemon_card(banette_cd)
	var attacker := _make_slot(banette_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Psychic", "P"), 0))
	state.players[0].active_pokemon = attacker

	var opponent: PlayerState = state.players[1]
	opponent.hand.clear()
	var item := CardInstance.create(_make_trainer_data("Locked Item", "Item"), 1)
	opponent.hand.append(item)

	var attacked := gsm.use_attack(0, 0)
	var item_blocked := not gsm.play_trainer(1, item, [])

	return run_checks([
		assert_true(gsm.effect_processor.has_attack_effect(banette_cd.effect_id), "CSV1C_054 should register scripted attacks"),
		assert_true(attacked, "CSV1C_054 should use Everlasting Darkness successfully"),
		assert_true(item_blocked, "CSV1C_054 should lock Item cards during the opponent's next turn"),
	])


func test_csv1c_054_banette_ex_poltergeist_counts_only_trainer_cards() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state

	var banette_cd := _make_basic_pokemon_data("CSV1C_054 Banette ex", "P", 250, "Stage 1", "ex", "ffe8874ed7810f9ecd8209d4a09ade59")
	banette_cd.evolves_from = "怨影娃娃"
	banette_cd.attacks = [
		{
			"name": "暗夜难明",
			"cost": "P",
			"damage": "30",
			"text": "在下一个对手的回合，对手无法从手牌使出物品。",
			"is_vstar_power": false,
		},
		{
			"name": "灵骚",
			"cost": "P",
			"damage": "60×",
			"text": "查看对手的手牌，造成其中训练家张数×60伤害。",
			"is_vstar_power": false,
		},
	]
	gsm.effect_processor.register_pokemon_card(banette_cd)
	var attacker := _make_slot(banette_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Psychic", "P"), 0))
	state.players[0].active_pokemon = attacker

	var opponent: PlayerState = state.players[1]
	opponent.hand.clear()
	opponent.hand.append(CardInstance.create(_make_trainer_data("Item A", "Item"), 1))
	opponent.hand.append(CardInstance.create(_make_trainer_data("Supporter B", "Supporter"), 1))
	opponent.hand.append(CardInstance.create(_make_basic_pokemon_data("Pokemon C", "C"), 1))
	opponent.hand.append(CardInstance.create(_make_energy_data("Energy D", "P"), 1))

	var attacked := gsm.use_attack(0, 1)
	var expected_damage := 120

	return run_checks([
		assert_true(attacked, "CSV1C_054 should use Poltergeist successfully"),
		assert_eq(state.players[1].active_pokemon.damage_counters, expected_damage, "CSV1C_054 should deal 60 damage for each Trainer card in the opponent hand"),
	])


func test_csv1c_054_banette_ex_everlasting_darkness_does_not_gain_poltergeist_bonus() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state

	var banette_cd: CardData = CardDatabase.get_card("CSV1C", "054")
	gsm.effect_processor.register_pokemon_card(banette_cd)
	var attacker := _make_slot(banette_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Psychic", "P"), 0))
	state.players[0].active_pokemon = attacker

	var opponent: PlayerState = state.players[1]
	opponent.hand.clear()
	opponent.hand.append(CardInstance.create(_make_trainer_data("Item A", "Item"), 1))
	opponent.hand.append(CardInstance.create(_make_trainer_data("Supporter B", "Supporter"), 1))
	opponent.hand.append(CardInstance.create(_make_basic_pokemon_data("Pokemon C", "C"), 1))

	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(banette_cd, "CSV1C_054 should exist in the card database"),
		assert_true(attacked, "CSV1C_054 should use Everlasting Darkness successfully"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 30, "CSV1C_054 Everlasting Darkness should only deal its printed 30 damage"),
	])


func test_csv1c_054_banette_ex_poltergeist_does_not_lock_items() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state

	var banette_cd: CardData = CardDatabase.get_card("CSV1C", "054")
	gsm.effect_processor.register_pokemon_card(banette_cd)
	var attacker := _make_slot(banette_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Psychic", "P"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Colorless", "C"), 0))
	state.players[0].active_pokemon = attacker

	var opponent: PlayerState = state.players[1]
	opponent.hand.clear()
	var item := CardInstance.create(_make_trainer_data("Item A", "Item"), 1)
	opponent.hand.append(item)
	opponent.hand.append(CardInstance.create(_make_trainer_data("Supporter B", "Supporter"), 1))
	opponent.hand.append(CardInstance.create(_make_basic_pokemon_data("Pokemon C", "C"), 1))
	opponent.hand.append(CardInstance.create(_make_energy_data("Energy D", "P"), 1))

	var attacked := gsm.use_attack(0, 1)
	var item_allowed := gsm.play_trainer(1, item, [])

	return run_checks([
		assert_not_null(banette_cd, "CSV1C_054 should exist in the card database"),
		assert_true(attacked, "CSV1C_054 should use Poltergeist successfully"),
		assert_true(item_allowed, "CSV1C_054 Poltergeist should not create an Item lock"),
	])


func test_csv6c_116_techno_radar_can_play_with_one_other_hand_card() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var radar_cd: CardData = CardDatabase.get_card("CSV6C", "116")
	var radar := CardInstance.create(radar_cd, 0)
	var discard_card := CardInstance.create(_make_basic_pokemon_data("Radar Fodder", "C"), 0)
	player.hand.append_array([radar, discard_card])

	var future_a := CardInstance.create(_make_basic_pokemon_data("Future A", "L"), 0)
	future_a.card_data.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	var future_b := CardInstance.create(_make_basic_pokemon_data("Future B", "P"), 0)
	future_b.card_data.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	var normal := CardInstance.create(_make_basic_pokemon_data("Normal C", "W"), 0)
	player.deck.append_array([future_a, future_b, normal])

	var played := gsm.play_trainer(0, radar, [{
		"discard_cards": [discard_card],
		"search_future_pokemon": [future_a, future_b],
	}])

	return run_checks([
		assert_not_null(radar_cd, "CSV6C_116 should exist in the card database"),
		assert_true(played, "CSV6C_116 should be playable when the hand only has one other card"),
		assert_true(discard_card in player.discard_pile, "CSV6C_116 should discard exactly the selected card"),
		assert_true(radar in player.discard_pile, "CSV6C_116 itself should go to the discard pile after use"),
		assert_true(future_a in player.hand and future_b in player.hand, "CSV6C_116 should add up to two Future Pokemon to hand"),
		assert_false(normal in player.hand, "CSV6C_116 should not add non-Future Pokemon"),
	])


func test_cs6_5c_070_lance_searches_selected_dragon_pokemon() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var lance_cd: CardData = CardDatabase.get_card("CS6.5C", "070")
	var lance := CardInstance.create(lance_cd, 0)
	player.hand.append(lance)

	var dreepy_cd: CardData = CardDatabase.get_card("CSV8C", "157")
	var drakloak_cd: CardData = CardDatabase.get_card("CSV8C", "158")
	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var manaphy_cd: CardData = CardDatabase.get_card("CS5bC", "052")
	var dreepy := CardInstance.create(dreepy_cd, 0)
	var drakloak := CardInstance.create(drakloak_cd, 0)
	var dragapult := CardInstance.create(dragapult_cd, 0)
	var manaphy := CardInstance.create(manaphy_cd, 0)
	player.deck.append_array([manaphy, dreepy, drakloak, dragapult])

	var played := gsm.play_trainer(0, lance, [{
		"dragon_pokemon": [dragapult, dreepy],
	}])

	return run_checks([
		assert_not_null(lance_cd, "CS6.5C_070 should exist in the card database"),
		assert_true(played, "CS6.5C_070 should be playable when the deck contains Dragon Pokemon"),
		assert_true(lance in player.discard_pile, "CS6.5C_070 itself should go to the discard pile after use"),
		assert_true(dreepy in player.hand and dragapult in player.hand, "CS6.5C_070 should add the selected Dragon Pokemon to hand"),
		assert_true(drakloak in player.deck, "CS6.5C_070 should leave unselected Dragon Pokemon in the deck"),
		assert_true(manaphy in player.deck, "CS6.5C_070 should not add non-Dragon Pokemon"),
	])


func test_csvh1c_035_energy_search_adds_one_basic_energy_to_hand() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var energy_search_cd: CardData = CardDatabase.get_card("CSVH1C", "035")
	var energy_search := CardInstance.create(energy_search_cd, 0)
	player.hand.append(energy_search)

	var basic_fire := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	var basic_psychic := CardInstance.create(_make_energy_data("Psychic Energy", "P"), 0)
	var special_energy := CardInstance.create(_make_energy_data("Jet Energy", "C", "Special Energy"), 0)
	player.deck.append_array([special_energy, basic_fire, basic_psychic])

	var played := gsm.play_trainer(0, energy_search, [{
		"search_energy": [basic_fire],
	}])

	return run_checks([
		assert_not_null(energy_search_cd, "CSVH1C_035 should exist in the card database"),
		assert_true(played, "CSVH1C_035 should be playable when the deck contains Basic Energy"),
		assert_true(energy_search in player.discard_pile, "CSVH1C_035 itself should go to the discard pile after use"),
		assert_true(basic_fire in player.hand, "CSVH1C_035 should add the selected Basic Energy to hand"),
		assert_true(basic_psychic in player.deck, "CSVH1C_035 should leave unselected Basic Energy in the deck"),
		assert_false(special_energy in player.hand, "CSVH1C_035 should not add Special Energy"),
	])


func test_cs4dac_056_entei_v_fleet_footed_and_burning_rondo() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	player.deck.clear()

	var entei_cd: CardData = CardDatabase.get_card("CS4DaC", "056")
	gsm.effect_processor.register_pokemon_card(entei_cd)
	var attacker := _make_slot(entei_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire A", "R"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire B", "R"), 0))
	player.active_pokemon = attacker
	player.deck.append(CardInstance.create(_make_trainer_data("Drawn Card", "Item"), 0))

	var can_use_ability := gsm.effect_processor.can_use_ability(attacker, state, 0)
	var used_ability := gsm.use_ability(0, attacker, 0)
	var attacked := gsm.use_attack(0, 0)
	var expected_damage := 20 + 20 * (player.bench.size() + opponent.bench.size())

	return run_checks([
		assert_not_null(entei_cd, "CS4DaC_056 should exist in the card database"),
		assert_true(can_use_ability, "CS4DaC_056 should be able to use Fleet-Footed while Active"),
		assert_true(used_ability, "CS4DaC_056 should draw 1 card with Fleet-Footed"),
		assert_eq(player.hand.size(), 1, "CS4DaC_056 Fleet-Footed should draw exactly 1 card"),
		assert_true(attacked, "CS4DaC_056 should use Burning Rondo successfully"),
		assert_eq(opponent.active_pokemon.damage_counters, expected_damage, "CS4DaC_056 Burning Rondo should add 20 for each Benched Pokemon in play"),
	])


func test_cs5dc_126_dark_patch_attaches_to_benched_dark_pokemon() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()

	var dark_patch_cd: CardData = CardDatabase.get_card("CS5DC", "126")
	var dark_patch := CardInstance.create(dark_patch_cd, 0)
	player.hand.append(dark_patch)

	var dark_target := player.bench[0]
	dark_target.pokemon_stack.clear()
	dark_target.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Dark Bench", "D", 120), 0))
	var non_dark_target := player.bench[1]
	non_dark_target.pokemon_stack.clear()
	non_dark_target.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Fire Bench", "R", 120), 0))

	var dark_energy := CardInstance.create(_make_energy_data("Darkness Energy", "D"), 0)
	var fire_energy := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	player.discard_pile.append_array([dark_energy, fire_energy])

	var played := gsm.play_trainer(0, dark_patch, [{
		"dark_patch_assignment": [{
			"source": dark_energy,
			"target": dark_target,
		}],
	}])

	return run_checks([
		assert_not_null(dark_patch_cd, "CS5DC_126 should exist in the card database"),
		assert_true(played, "CS5DC_126 should be playable with a Basic Darkness Energy in discard and a Benched Darkness Pokemon"),
		assert_true(dark_patch in player.discard_pile, "CS5DC_126 itself should go to the discard pile after use"),
		assert_true(dark_energy in dark_target.attached_energy, "CS5DC_126 should attach the selected Basic Darkness Energy to the chosen Benched Darkness Pokemon"),
		assert_true(fire_energy in player.discard_pile, "CS5DC_126 should leave non-Dark Energy in the discard pile"),
		assert_true(non_dark_target.attached_energy.is_empty(), "CS5DC_126 should not attach Energy to non-Dark Benched Pokemon"),
	])


func test_cs6_5c_012_delphox_v_strange_flames_applies_burned_and_confused() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.coin_flipper = RiggedCoinFlipper.new([false])
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var delphox_cd: CardData = CardDatabase.get_card("CS6.5C", "012")
	gsm.effect_processor.register_pokemon_card(delphox_cd)
	var attacker := _make_slot(delphox_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire Energy", "R"), 0))
	player.active_pokemon = attacker

	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(delphox_cd, "CS6.5C_012 should exist in the card database"),
		assert_true(attacked, "CS6.5C_012 should use Strange Flames successfully"),
		assert_true(opponent.active_pokemon.status_conditions.get("burned", false), "CS6.5C_012 should Burn the opponent Active Pokemon"),
		assert_true(opponent.active_pokemon.status_conditions.get("confused", false), "CS6.5C_012 should Confuse the opponent Active Pokemon"),
	])


func test_cs6_5c_012_delphox_v_magical_fire_lost_zones_two_energy_and_hits_selected_bench() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.lost_zone.clear()

	var delphox_cd: CardData = CardDatabase.get_card("CS6.5C", "012")
	gsm.effect_processor.register_pokemon_card(delphox_cd)
	var attacker := _make_slot(delphox_cd, 0)
	var energy_a := CardInstance.create(_make_energy_data("Fire A", "R"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Fire B", "R"), 0)
	var energy_c := CardInstance.create(_make_energy_data("Fire C", "R"), 0)
	attacker.attached_energy.append_array([energy_a, energy_b, energy_c])
	player.active_pokemon = attacker

	var attack_effects: Array[BaseEffect] = gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in attack_effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), delphox_cd.attacks[1], state))

	var chosen_bench := opponent.bench[1]
	var untouched_bench := opponent.bench[0]
	var attacked := gsm.use_attack(0, 1, [{
		"delphox_v_lost_zone_energy": [energy_a, energy_b],
		"delphox_v_bench_target": [chosen_bench],
	}])

	return run_checks([
		assert_true(attacked, "CS6.5C_012 should use Magical Fire successfully"),
		assert_eq(steps.size(), 2, "CS6.5C_012 Magical Fire should ask for Energy and a Benched target"),
		assert_eq(int(steps[0].get("min_select", -1)), 2, "CS6.5C_012 Magical Fire should require selecting exactly 2 attached Energy"),
		assert_eq(int(steps[1].get("max_select", -1)), 1, "CS6.5C_012 Magical Fire should only allow 1 Benched target"),
		assert_true(energy_a in player.lost_zone and energy_b in player.lost_zone, "CS6.5C_012 Magical Fire should put 2 chosen Energy into the Lost Zone"),
		assert_true(energy_c in attacker.attached_energy, "CS6.5C_012 Magical Fire should leave unchosen attached Energy in place"),
		assert_eq(opponent.active_pokemon.damage_counters, 120, "CS6.5C_012 Magical Fire should still deal its printed 120 to the opponent Active Pokemon"),
		assert_eq(chosen_bench.damage_counters, 120, "CS6.5C_012 Magical Fire should deal 120 to the selected Benched Pokemon"),
		assert_eq(untouched_bench.damage_counters, 0, "CS6.5C_012 Magical Fire should not damage unselected Benched Pokemon"),
	])


func test_csv7c_051_gouging_fire_ex_blazing_charge_locks_until_it_leaves_active() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]

	var gouging_cd: CardData = CardDatabase.get_card("CSV7C", "051")
	gsm.effect_processor.register_pokemon_card(gouging_cd)
	var attacker := _make_slot(gouging_cd, 0)
	var energy_a := CardInstance.create(_make_energy_data("Fire A", "R"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Fire B", "R"), 0)
	var energy_c := CardInstance.create(_make_energy_data("Fire C", "R"), 0)
	attacker.attached_energy.append_array([energy_a, energy_b, energy_c])
	player.active_pokemon = attacker
	state.players[1].active_pokemon.damage_counters = 0
	state.players[1].active_pokemon.pokemon_stack[0].card_data.hp = 400

	var first_attack := gsm.use_attack(0, 1)
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	var locked_reason := gsm.get_attack_unusable_reason(0, 1)

	var retreat_target: PokemonSlot = player.bench[0]
	var retreated := gsm.retreat(0, [energy_a, energy_b], retreat_target)
	var benched_attacker: PokemonSlot = player.bench.back()
	EffectSwitchPokemon.new("self").execute(
		CardInstance.create(_make_trainer_data("Switch", "Item"), 0),
		[{"self_switch_target": [benched_attacker]}],
		state
	)
	benched_attacker.attached_energy.append(CardInstance.create(_make_energy_data("Refill A", "R"), 0))
	benched_attacker.attached_energy.append(CardInstance.create(_make_energy_data("Refill B", "R"), 0))
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	var unlocked_reason := gsm.get_attack_unusable_reason(0, 1)

	return run_checks([
		assert_not_null(gouging_cd, "CSV7C_051 should exist in the card database"),
		assert_true(first_attack, "CSV7C_051 should use Blazing Charge successfully the first time"),
		assert_str_contains(locked_reason, "离开战斗场前", "CSV7C_051 should block Blazing Charge while it remains Active"),
		assert_true(retreated, "CSV7C_051 should be able to retreat and leave the Active Spot"),
		assert_eq(unlocked_reason, "", "CSV7C_051 should be able to use Blazing Charge again after leaving the Active Spot"),
	])


func test_cs5dc_152_magma_basin_attaches_fire_from_discard_once_per_turn() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()

	var magma_cd: CardData = CardDatabase.get_card("CS5DC", "152")
	var magma_basin := CardInstance.create(magma_cd, 0)
	player.hand.append(magma_basin)

	var fire_target := player.bench[0]
	fire_target.pokemon_stack.clear()
	fire_target.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Fire Bench", "R", 130), 0))
	var fire_energy := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	player.discard_pile.append(fire_energy)

	var played := gsm.play_stadium(0, magma_basin)
	var first_use := gsm.use_stadium_effect(0, [{
		"magma_basin_assignment": [{
			"source": fire_energy,
			"target": fire_target,
		}],
	}])
	var second_use_same_turn := gsm.use_stadium_effect(0)

	return run_checks([
		assert_not_null(magma_cd, "CS5DC_152 should exist in the card database"),
		assert_true(played, "CS5DC_152 should be playable as a Stadium"),
		assert_true(first_use, "CS5DC_152 should let the current player use the Stadium effect once"),
		assert_true(fire_energy in fire_target.attached_energy, "CS5DC_152 should attach the selected Basic Fire Energy from discard"),
		assert_eq(fire_target.damage_counters, 20, "CS5DC_152 should place 2 damage counters on the chosen Pokemon"),
		assert_false(second_use_same_turn, "CS5DC_152 should not be reusable by the same player in the same turn"),
	])


func test_cs5dc_152_magma_basin_remains_usable_after_a_different_stadium_effect_same_turn() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	player.bench.clear()

	var tool_card := CardInstance.create(_make_trainer_data("Tool A", "Tool"), 0)
	player.deck.append(tool_card)

	var town_store := CardInstance.create(_make_trainer_data("Town Store", "Stadium", "13b3caaa408a85dfd1e2a5ad797e8b8a"), 0)
	state.stadium_card = town_store
	state.stadium_owner_index = 0
	var used_town_store := gsm.use_stadium_effect(0, [{
		"town_store_tool": [tool_card],
	}])

	var magma_cd: CardData = CardDatabase.get_card("CS5DC", "152")
	var magma_basin := CardInstance.create(magma_cd, 0)
	player.hand.append(magma_basin)

	var fire_target := _make_slot(_make_basic_pokemon_data("Fire Bench", "R", 130), 0)
	player.bench.append(fire_target)
	var fire_energy := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	player.discard_pile.append(fire_energy)

	var played_magma_basin := gsm.play_stadium(0, magma_basin)
	var used_magma_basin := gsm.use_stadium_effect(0, [{
		"magma_basin_assignment": [{
			"source": fire_energy,
			"target": fire_target,
		}],
	}])

	return run_checks([
		assert_not_null(magma_cd, "CS5DC_152 should exist in the card database"),
		assert_true(used_town_store, "A different Stadium effect should still be usable earlier in the turn"),
		assert_true(played_magma_basin, "CS5DC_152 should be playable after another Stadium was already in play"),
		assert_true(used_magma_basin, "CS5DC_152 should remain usable after a different Stadium effect was used this turn"),
		assert_true(fire_energy in fire_target.attached_energy, "CS5DC_152 should still attach the selected Basic Fire Energy after switching from another Stadium"),
		assert_eq(fire_target.damage_counters, 20, "CS5DC_152 should still place 2 damage counters after another Stadium effect"),
	])


func test_cs55c_007_radiant_charizard_reduces_cost_without_discarding_energy() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var radiant_charizard_cd: CardData = CardDatabase.get_card("CS5.5C", "007")
	if radiant_charizard_cd == null:
		return "未找到缓存卡 CS5.5C/007"
	gsm.effect_processor.register_pokemon_card(radiant_charizard_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(radiant_charizard_cd, 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire Energy", "R"), 0))
	player.active_pokemon = attacker

	var bulky_target_cd := _make_basic_pokemon_data("Bulky Target", "G", 330)
	var bulky_target := PokemonSlot.new()
	bulky_target.pokemon_stack.append(CardInstance.create(bulky_target_cd, 1))
	opponent.active_pokemon = bulky_target

	opponent.prizes.clear()
	for i: int in 3:
		opponent.prizes.append(CardInstance.create(_make_basic_pokemon_data("Prize %d" % i, "C"), 1))
	var insufficient_reason: String = gsm.get_attack_unusable_reason(0, 0)

	opponent.prizes.pop_back()
	var usable_reason: String = gsm.get_attack_unusable_reason(0, 0)
	var first_attack: bool = gsm.use_attack(0, 0)
	var energy_after_attack: int = attacker.attached_energy.size()
	var target_damage_after_attack: int = opponent.active_pokemon.damage_counters

	gsm.end_turn(1)
	var locked_reason: String = gsm.get_attack_unusable_reason(0, 0)

	gsm.end_turn(0)
	gsm.end_turn(1)
	var unlocked_reason: String = gsm.get_attack_unusable_reason(0, 0)

	return run_checks([
		assert_not_null(radiant_charizard_cd, "CS5.5C_007 should exist in the card database"),
		assert_str_contains(insufficient_reason, "能量不足", "CS5.5C_007 should still require more than 1 Fire Energy before the opponent has taken 4 prizes"),
		assert_eq(usable_reason, "", "CS5.5C_007 should become usable with only 1 Fire Energy after the opponent has taken 4 prizes"),
		assert_true(first_attack, "CS5.5C_007 should use Combustion Blast successfully once Excited Heart reduces the cost"),
		assert_eq(energy_after_attack, 1, "CS5.5C_007 Combustion Blast should not discard the remaining Fire Energy"),
		assert_eq(target_damage_after_attack, 250, "CS5.5C_007 Combustion Blast should still deal its printed 250 damage"),
		assert_str_contains(locked_reason, "下回合", "CS5.5C_007 should lock Combustion Blast during the next turn"),
		assert_eq(unlocked_reason, "", "CS5.5C_007 should be able to use Combustion Blast again after waiting out the lock"),
	])


func test_cs5ac_006_moltres_fiery_wrath_scales_if_damaged_and_ignores_weakness() -> String:
	var moltres_cd: CardData = CardDatabase.get_card("CS5aC", "006")

	var baseline_gsm := GameStateMachine.new()
	baseline_gsm.game_state = _make_state()
	var baseline_state: GameState = baseline_gsm.game_state
	var baseline_player: PlayerState = baseline_state.players[0]
	var baseline_opponent: PlayerState = baseline_state.players[1]
	var weak_target_cd := _make_basic_pokemon_data("Weak Target", "G", 130)
	weak_target_cd.weakness_energy = "R"
	weak_target_cd.weakness_value = "2"
	var baseline_attacker := _make_slot(moltres_cd, 0)
	baseline_attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire Energy", "R"), 0))
	baseline_player.active_pokemon = baseline_attacker
	baseline_opponent.active_pokemon = _make_slot(weak_target_cd, 1)
	baseline_gsm.effect_processor.register_pokemon_card(moltres_cd)
	var baseline_attack := baseline_gsm.use_attack(0, 0)

	var boosted_gsm := GameStateMachine.new()
	boosted_gsm.game_state = _make_state()
	var boosted_state: GameState = boosted_gsm.game_state
	var boosted_player: PlayerState = boosted_state.players[0]
	var boosted_opponent: PlayerState = boosted_state.players[1]
	var boosted_target_cd := _make_basic_pokemon_data("Boosted Weak Target", "G", 130)
	boosted_target_cd.weakness_energy = "R"
	boosted_target_cd.weakness_value = "2"
	var boosted_attacker := _make_slot(moltres_cd, 0)
	boosted_attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire Energy", "R"), 0))
	boosted_attacker.damage_counters = 10
	boosted_player.active_pokemon = boosted_attacker
	boosted_opponent.active_pokemon = _make_slot(boosted_target_cd, 1)
	boosted_gsm.effect_processor.register_pokemon_card(moltres_cd)
	var boosted_attack := boosted_gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(moltres_cd, "CS5aC_006 should exist in the card database"),
		assert_true(baseline_gsm.effect_processor.has_attack_effect(moltres_cd.effect_id), "CS5aC_006 should register its scripted attack"),
		assert_true(baseline_attack, "CS5aC_006 should use Fiery Wrath successfully without self damage"),
		assert_eq(baseline_opponent.active_pokemon.damage_counters, 20, "CS5aC_006 should deal its printed 20 damage without applying Weakness"),
		assert_true(boosted_attack, "CS5aC_006 should use Fiery Wrath successfully with self damage"),
		assert_eq(boosted_opponent.active_pokemon.damage_counters, 90, "CS5aC_006 should add 70 damage when it already has damage counters and still ignore Weakness"),
	])


func test_csv2c_028_froakie_hop_step_maps_to_fail_on_tails() -> String:
	var processor := EffectProcessor.new()
	var froakie_cd: CardData = CardDatabase.get_card("CSV2C", "028")
	processor.register_pokemon_card(froakie_cd)
	var froakie_slot := _make_slot(froakie_cd, 0)
	var froakie_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(froakie_slot, 0)
	var froakie_effect: BaseEffect = froakie_effects[0] if not froakie_effects.is_empty() else null

	return run_checks([
		assert_not_null(froakie_cd, "CSV2C_028 should exist in the card database"),
		assert_true(froakie_effects.size() >= 1, "CSV2C_028 should register an attack effect for Hop Step"),
		assert_true(froakie_effect is AttackCoinFlipOrFail, "CSV2C_028 should fail on tails instead of always dealing damage"),
		assert_eq((froakie_effect as AttackCoinFlipOrFail).base_damage if froakie_effect is AttackCoinFlipOrFail else -1, 30, "CSV2C_028 should only cancel its printed 30 damage on tails"),
	])


func test_csv7c_123_greninja_ex_shinobi_blade_searches_selected_card_to_hand() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var greninja_cd: CardData = CardDatabase.get_card("CSV7C", "123")
	var attacker := _make_slot(greninja_cd, 0)
	player.active_pokemon = attacker
	var chosen := CardInstance.create(_make_trainer_data("Chosen Card", "Item"), 0)
	var other := CardInstance.create(_make_energy_data("Water Energy", "W"), 0)
	player.deck.append(other)
	player.deck.append(chosen)

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(greninja_cd)
	var attack_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in attack_effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), greninja_cd.attacks[0], state))
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{
		"greninja_ex_search_card": [chosen],
	}])

	return run_checks([
		assert_not_null(greninja_cd, "CSV7C_123 should exist in the card database"),
		assert_true(attack_effects.size() >= 1, "CSV7C_123 attack 0 should register an effect"),
		assert_eq(steps.size(), 1, "CSV7C_123 Shinobi Blade should present one optional search step"),
		assert_eq(int(steps[0].get("min_select", -1)), 0, "CSV7C_123 Shinobi Blade should allow skipping the deck search"),
		assert_eq(int(steps[0].get("max_select", -1)), 1, "CSV7C_123 Shinobi Blade should only allow choosing 1 card"),
		assert_contains(player.hand, chosen, "CSV7C_123 Shinobi Blade should put the chosen card into hand"),
		assert_contains(player.deck, other, "CSV7C_123 Shinobi Blade should leave unchosen cards in the deck"),
		assert_false(chosen in player.deck, "CSV7C_123 Shinobi Blade should remove the chosen card from the deck"),
	])


func test_csv7c_123_greninja_ex_mirage_barrage_discards_two_energy_and_hits_two_selected_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.discard_pile.clear()

	var greninja_cd: CardData = CardDatabase.get_card("CSV7C", "123")
	var attacker := _make_slot(greninja_cd, 0)
	player.active_pokemon = attacker
	var energy_a := CardInstance.create(_make_energy_data("Water A", "W"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Water B", "W"), 0)
	var energy_c := CardInstance.create(_make_energy_data("Psychic C", "P"), 0)
	attacker.attached_energy.append_array([energy_a, energy_b, energy_c])
	var chosen_active := opponent.active_pokemon
	var chosen_bench := opponent.bench[1]
	var untouched_bench := opponent.bench[0]

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(greninja_cd)
	var attack_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 1)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in attack_effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), greninja_cd.attacks[1], state))
	var discard_step: Dictionary = steps[0] if not steps.is_empty() else {}
	var target_step: Dictionary = steps[1] if steps.size() > 1 else {}
	processor.execute_attack_effect(attacker, 1, chosen_active, state, [{
		"greninja_ex_discard_energy": [energy_a, energy_b],
		"greninja_ex_targets": [chosen_active, chosen_bench],
	}])

	return run_checks([
		assert_not_null(greninja_cd, "CSV7C_123 should exist in the card database"),
		assert_true(attack_effects.size() >= 1, "CSV7C_123 attack 1 should register an effect"),
		assert_eq(steps.size(), 2, "CSV7C_123 Mirage Barrage should ask for discarded Energy and damaged targets"),
		assert_eq(int(discard_step.get("min_select", -1)), 2, "CSV7C_123 Mirage Barrage should require discarding exactly 2 Energy"),
		assert_eq(int(target_step.get("min_select", -1)), 2, "CSV7C_123 Mirage Barrage should require choosing exactly 2 targets"),
		assert_contains(player.discard_pile, energy_a, "CSV7C_123 Mirage Barrage should discard the first chosen Energy"),
		assert_contains(player.discard_pile, energy_b, "CSV7C_123 Mirage Barrage should discard the second chosen Energy"),
		assert_contains(attacker.attached_energy, energy_c, "CSV7C_123 Mirage Barrage should leave unchosen attached Energy in place"),
		assert_eq(chosen_active.damage_counters, 120, "CSV7C_123 Mirage Barrage should deal 120 to the selected Active target"),
		assert_eq(chosen_bench.damage_counters, 120, "CSV7C_123 Mirage Barrage should deal 120 to the selected Benched target"),
		assert_eq(untouched_bench.damage_counters, 0, "CSV7C_123 Mirage Barrage should not damage unselected Pokemon"),
	])
