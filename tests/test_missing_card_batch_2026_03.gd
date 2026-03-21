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
const AbilitySelfHealVSTAR = preload("res://scripts/effects/pokemon_effects/AbilitySelfHealVSTAR.gd")
const AbilityMillDeckRecoverToHand = preload("res://scripts/effects/pokemon_effects/AbilityMillDeckRecoverToHand.gd")
const AttackAttachBasicEnergyFromDiscard = preload("res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromDiscard.gd")
const AbilityAttachBasicEnergyFromHandDraw = preload("res://scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandDraw.gd")
const AbilityLookTopToHand = preload("res://scripts/effects/pokemon_effects/AbilityLookTopToHand.gd")
const AbilityDrawIfKnockoutLastTurn = preload("res://scripts/effects/pokemon_effects/AbilityDrawIfKnockoutLastTurn.gd")
const AttackLostZoneEnergy = preload("res://scripts/effects/pokemon_effects/AttackLostZoneEnergy.gd")
const AttackLookTopPickHandRestLostZone = preload("res://scripts/effects/pokemon_effects/AttackLookTopPickHandRestLostZone.gd")
const AttackAnyTargetDamage = preload("res://scripts/effects/pokemon_effects/AttackAnyTargetDamage.gd")
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

	ability.execute_ability(hawlucha_slot, 0, [{
		"opponent_bench_targets": [opponent.bench[0], opponent.bench[1]],
	}], state)

	return run_checks([
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
	var deck_a := CardInstance.create(_make_basic_pokemon_data("Recover A", "C"), 0)
	var deck_b := CardInstance.create(_make_basic_pokemon_data("Recover B", "C"), 0)
	player.deck.append(deck_a)
	player.deck.append(deck_b)
	var ability := AbilityMillDeckRecoverToHand.new(2, 2, true)
	var slot := player.active_pokemon

	ability.execute_ability(slot, 0, [{"recover_cards": [deck_a, deck_b]}], state)

	return run_checks([
		assert_true(deck_a in player.hand and deck_b in player.hand, "CS6.5C_055 should recover chosen milled cards"),
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

	ability.execute_ability(slot, 0, [{"basic_energy_from_hand": [grass]}], state)

	return run_checks([
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

	ability.execute_ability(player.active_pokemon, 0, [], state)

	return run_checks([
		assert_eq(player.hand.size(), 3, "CSV8C_135 should draw 3 when your Pokemon was KO'd during the opponent's last turn"),
	])


func test_csv8c_135_fezandipiti_ability_unlocks_after_real_knockout_flow() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
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
	var send_out_ok := gsm.send_out_pokemon(0, replacement_slot)
	var hand_before_ability := player.hand.size()
	var ability_ok := gsm.use_ability(0, fez_slot, 0)

	return run_checks([
		assert_eq(state.last_knockout_turn_against[0], 3, "CSV8C_135 should record the turn when your Pokemon was KO'd"),
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
	var state := gsm.game_state
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
	var state := gsm.game_state
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
	var state := gsm.game_state
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
	var state := gsm.game_state

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
	var send_out_ok := gsm.send_out_pokemon(0, replacement)

	return run_checks([
		assert_true(success, "CS6bC_123 should resolve successfully when another hand card is available"),
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

	return run_checks([
		assert_true(success, "CSV8C_203 should be playable"),
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

	return run_checks([
		assert_true(success, "黑夜魔灵应成功使用咒怨炸弹"),
		assert_eq(target.damage_counters, target_hp_before + 130, "应对目标放置13个伤害指示物（130伤害）"),
		assert_true(dusknoir_slot not in state.players[0].bench, "黑夜魔灵应从备战区移除"),
		assert_eq(state.phase, GameState.GamePhase.MAIN, "自爆后应回到MAIN阶段继续操作"),
		assert_eq(state.current_player_index, 0, "仍应是玩家0的回合"),
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
	## 验证馈赠能量在附着宝可梦昏厥时抽卡到7张
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state

	var defender_cd := _make_basic_pokemon_data("带馈赠能量", "C", 10, "Basic", "", "gift_test_def")
	var defender := _make_slot(defender_cd, 1)
	var gift_cd := _make_energy_data("馈赠能量", "C", "Special Energy", "dbb3f3d2ef2f3372bc8b21336e6c9bc6")
	defender.attached_energy.append(CardInstance.create(gift_cd, 1))
	state.players[1].active_pokemon = defender

	# 确保玩家1手牌少于7张且牌库有足够卡牌
	state.players[1].hand.clear()
	state.players[1].hand.append(CardInstance.create(_make_basic_pokemon_data("H1", "C"), 1))
	state.players[1].hand.append(CardInstance.create(_make_basic_pokemon_data("H2", "C"), 1))
	for i: int in 10:
		state.players[1].deck.append(CardInstance.create(_make_basic_pokemon_data("D%d" % i, "C"), 1))

	# 通过直接检查静态方法
	var has_gift: bool = EffectGiftEnergy.check_gift_energy_on_knockout(defender)
	var hand_before: int = state.players[1].hand.size()
	EffectGiftEnergy.trigger_on_knockout(state.players[1])
	var hand_after: int = state.players[1].hand.size()

	return run_checks([
		assert_true(has_gift, "附有馈赠能量的宝可梦应检测到馈赠能量"),
		assert_eq(hand_before, 2, "触发前手牌2张"),
		assert_eq(hand_after, 7, "触发后手牌应为7张"),
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

	var prizes_after: int = state.players[0].prizes.size()
	var prizes_taken: int = prizes_before - prizes_after

	return run_checks([
		assert_eq(prizes_taken, 1, "遗赠能量应使ex宝可梦昏厥时对手只拿1张奖赏卡（正常2张减1张）"),
	])
