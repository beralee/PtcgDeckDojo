class_name TestCardSemanticMatrix
extends TestBase

const AbilityAttachFromDeckEffect = preload("res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd")
const AttackSearchDeckToTopEffect = preload("res://scripts/effects/pokemon_effects/AttackSearchDeckToTop.gd")
const AttackUseDiscardDragonAttackEffect = preload("res://scripts/effects/pokemon_effects/AttackUseDiscardDragonAttack.gd")
const AttackReduceDamageNextTurnEffect = preload("res://scripts/effects/pokemon_effects/AttackReduceDamageNextTurn.gd")
const AttackMillSelfDeckEffect = preload("res://scripts/effects/pokemon_effects/AttackMillSelfDeck.gd")
const AttackKODefenderIfHasSpecialEnergyEffect = preload("res://scripts/effects/pokemon_effects/AttackKODefenderIfHasSpecialEnergy.gd")
const AttackDistributedBenchCountersEffect = preload("res://scripts/effects/pokemon_effects/AttackDistributedBenchCounters.gd")
const AttackLostZoneEnergyEffect = preload("res://scripts/effects/pokemon_effects/AttackLostZoneEnergy.gd")

const DRAW_TO_N_UIDS := ["151C_151", "CS5aC_105"]
const THUNDEROUS_BENCH_COUNT_UIDS := ["CS4DaC_137", "CS5bC_051"]
const RADIANT_CHARIZARD_UIDS := ["CS5.5C_007"]
const DISCARD_MULTI_UIDS := ["CS5aC_019"]
const DEFENSE_FAMILY_UIDS := ["CS5aC_046", "CS6.5C_049"]
const SEARCH_ANY_UIDS := ["CS5aC_107", "CSV4C_101"]
const BENCH_ENTER_UIDS := ["CS5bC_049", "CSV7C_033"]
const VSTAR_POWER_UIDS := ["CS5bC_096", "CS6aC_103"]
const DRAW_UTILITY_UIDS := ["CS5bC_111", "CS6.5C_020", "CS6.5C_023", "CSV1C_099"]
const ATTACK_UTILITY_UIDS := ["CSV4C_044", "CSV7C_171", "CS6bC_117", "CS6bC_107", "CS6bC_108"]
const METAL_AND_DISABLE_UIDS := ["CSV7C_109", "CSV7C_147", "CSV7C_202"]
const ATTACH_FROM_DECK_UIDS := ["CS6aC_113"]
const READ_WIND_UIDS := ["CS6aC_102"]
const SNORLAX_UIDS := ["CS6bC_113"]
const COIN_FLIP_UIDS := ["CSV4C_063", "SVP_105"]
const BELDUM_UIDS := ["CS6aC_083"]


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

	func flip_until_tails() -> int:
		var heads := 0
		while flip():
			heads += 1
		return heads


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
	cd.attacks = [{"name": "Audit Attack", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
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


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	CardInstance.reset_id_counter()

	for pi in range(2):
		var player := PlayerState.new()
		player.player_index = pi

		var active_cd := _make_basic_pokemon_data("Active%d" % pi, "R", 120)
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(active_cd, pi))
		active.turn_played = 0
		player.active_pokemon = active

		for bi in range(2):
			var bench_cd := _make_basic_pokemon_data("Bench%d_%d" % [pi, bi], "W", 90)
			var bench := PokemonSlot.new()
			bench.pokemon_stack.append(CardInstance.create(bench_cd, pi))
			bench.turn_played = 0
			player.bench.append(bench)

		for hi in range(3):
			player.hand.append(CardInstance.create(_make_basic_pokemon_data("Hand%d_%d" % [pi, hi], "C", 60), pi))

		for di in range(6):
			player.deck.append(CardInstance.create(_make_basic_pokemon_data("Deck%d_%d" % [pi, di], "C", 60), pi))

		for pri in range(3):
			player.prizes.append(CardInstance.create(_make_basic_pokemon_data("Prize%d_%d" % [pi, pri], "C", 50), pi))

		state.players.append(player)

	return state


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func test_draw_to_n_family_behaviour() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	for i in range(5):
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("DrawTo3_%d" % i, "C"), 0))

	var effect_three := AbilityDrawToN.new(3, true)
	var slot := player.active_pokemon
	state.current_player_index = 1
	var can_use_on_opponent_turn: bool = effect_three.can_use_ability(slot, state)
	state.current_player_index = 0
	effect_three.execute_ability(slot, 0, [], state)

	var state_five := _make_state()
	var player_five: PlayerState = state_five.players[0]
	player_five.hand.clear()
	player_five.deck.clear()
	for i in range(6):
		player_five.deck.append(CardInstance.create(_make_basic_pokemon_data("DrawTo5_%d" % i, "C"), 0))

	var effect_five := AbilityDrawToN.new(5, true)
	effect_five.execute_ability(player_five.active_pokemon, 0, [], state_five)

	return run_checks([
		assert_false(can_use_on_opponent_turn, "AbilityDrawToN should only be usable during its controller's turn"),
		assert_eq(player.hand.size(), 3, "AbilityDrawToN should draw up to three cards"),
		assert_false(effect_three.can_use_ability(slot, state), "AbilityDrawToN should mark once-per-turn usage"),
		assert_eq(player_five.hand.size(), 5, "AbilityDrawToN should also support draw-to-five variants"),
	])


func test_thunderous_charge_and_bench_count_family_behaviour() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("TopDraw", "L"), 0))

	var active_cd := _make_basic_pokemon_data("FleetFooted", "L", 200, "Basic", "V")
	active_cd.abilities = [{"name": "ThunderousCharge"}]
	var active_slot := _make_slot(active_cd, 0)
	state.players[0].active_pokemon = active_slot

	var draw_effect := AbilityThunderousCharge.new()
	draw_effect.execute_ability(active_slot, 0, [], state)
	var bench_slot := player.bench[0]
	bench_slot.pokemon_stack.clear()
	bench_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var can_use_from_bench: bool = draw_effect.can_use_ability(bench_slot, state)
	state.current_player_index = 1
	var can_use_on_opponent_turn: bool = draw_effect.can_use_ability(active_slot, state)
	state.current_player_index = 0

	var damage_effect := AttackBenchCountDamage.new(20, "both")
	var bonus_damage: int = damage_effect.get_damage_bonus(active_slot, state)

	return run_checks([
		assert_eq(player.hand.size(), 1, "AbilityThunderousCharge should draw one card"),
		assert_true(active_slot.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == AbilityThunderousCharge.USED_FLAG_TYPE), "AbilityThunderousCharge should leave a once-per-turn flag"),
		assert_false(can_use_from_bench, "AbilityThunderousCharge should require the Pokemon to be Active"),
		assert_false(can_use_on_opponent_turn, "AbilityThunderousCharge should only be usable during its controller's turn"),
		assert_eq(bonus_damage, 80, "AttackBenchCountDamage should count both benches"),
	])


func test_radiant_charizard_family_behaviour() -> String:
	var player := PlayerState.new()
	player.player_index = 0
	var charizard_cd := _make_basic_pokemon_data("RadiantCharizard", "R", 160)
	charizard_cd.abilities = [{"name": AbilityReduceAttackCost.ABILITY_NAME}]
	player.active_pokemon = _make_slot(charizard_cd, 0)
	player.bench.append(_make_slot(charizard_cd, 0))

	var reduction: int = AbilityReduceAttackCost.get_fire_cost_reduction(player)
	var lock_effect := AttackSelfLockNextTurn.new()
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	lock_effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_eq(reduction, 2, "AbilityReduceAttackCost should stack across multiple copies in play"),
		assert_true(attacker.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == "attack_lock"), "AttackSelfLockNextTurn should mark the attack as locked"),
	])


func test_discard_multi_and_rule_box_defense_families() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var attacker := player.active_pokemon
	attacker.attached_energy.clear()
	var energy_a := CardInstance.create(_make_energy_data("L1", "L"), 0)
	var energy_b := CardInstance.create(_make_energy_data("L2", "L"), 0)
	attacker.attached_energy.append(energy_a)
	player.bench[0].attached_energy.append(energy_b)
	var defender := state.players[1].active_pokemon

	var discard_multi := AttackDiscardEnergyMultiDamage.new("L", 60)
	discard_multi.set_attack_interaction_context([{
		"discard_energy": [energy_a, energy_b],
	}])
	var damage_bonus := discard_multi.get_damage_bonus(attacker, state)
	discard_multi.execute_attack(attacker, defender, 0, state)
	discard_multi.clear_attack_interaction_context()

	var defending_player := PlayerState.new()
	var gardevoir_cd := _make_basic_pokemon_data("RadiantGardevoir", "P", 130)
	gardevoir_cd.abilities = [{"name": AbilityVReduceDamage.ABILITY_NAME}]
	defending_player.active_pokemon = _make_slot(gardevoir_cd, 1)
	var normal_defender_cd := _make_basic_pokemon_data("NonRule", "C", 80)
	var normal_defender := _make_slot(normal_defender_cd, 1)
	var v_attacker_cd := _make_basic_pokemon_data("RuleBox", "C", 200, "Basic", "V")
	var v_attacker := _make_slot(v_attacker_cd, 0)

	var zamazenta_cd := _make_basic_pokemon_data("Zamazenta", "M", 130)
	zamazenta_cd.abilities = [{"name": AbilityConditionalDefense.ABILITY_NAME}]
	var zamazenta := _make_slot(zamazenta_cd, 1)
	zamazenta.attached_energy.append(CardInstance.create(_make_energy_data("Metal", "M"), 1))

	return run_checks([
		assert_eq(damage_bonus, 60, "AttackDiscardEnergyMultiDamage should offset the printed 60x text to the selected count"),
		assert_eq(defender.damage_counters, 0, "AttackDiscardEnergyMultiDamage should only discard energy; damage bonus comes from DamageCalculator"),
		assert_eq(attacker.attached_energy.size(), 0, "AttackDiscardEnergyMultiDamage should discard selected energy from the attacker"),
		assert_eq(player.bench[0].attached_energy.size(), 0, "AttackDiscardEnergyMultiDamage should also discard selected energy from the bench"),
		assert_eq(player.discard_pile.size(), 2, "AttackDiscardEnergyMultiDamage should move discarded energy to discard"),
		assert_eq(AbilityVReduceDamage.get_v_damage_reduction(defending_player, normal_defender, v_attacker), -20, "AbilityVReduceDamage should reduce damage from rule-box attackers"),
		assert_eq(AbilityConditionalDefense.get_conditional_defense(zamazenta), -30, "AbilityConditionalDefense should require basic metal energy"),
	])


func test_mew_copy_attack_uses_selected_opponent_attack() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()

	var mew_cd := _make_basic_pokemon_data("梦幻ex", "P", 180, "Basic", "ex", "49669fcf461deacebeb5755c11ec51f1")
	mew_cd.attacks = [{
		"name": "基因侵入",
		"cost": "CCC",
		"damage": "",
		"text": "",
		"is_vstar_power": false,
	}]
	var mew_attacker := _make_slot(mew_cd, 0)
	state.players[0].active_pokemon = mew_attacker

	var haxorus_cd := _make_dragon_pokemon_data(
		"双斧战龙",
		170,
		"e45788bd7d9ffec5b3da3730d2dc806f",
		[
			{"name": "巨斧劈落", "cost": "N", "damage": "", "text": "", "is_vstar_power": false},
			{"name": "龙之波动", "cost": "NNC", "damage": "230", "text": "", "is_vstar_power": false},
		]
	)
	processor.register_pokemon_card(haxorus_cd)
	state.players[1].active_pokemon = _make_slot(haxorus_cd, 1)

	var mew_effect := AttackCopyAttack.new(processor)
	var steps: Array[Dictionary] = mew_effect.get_attack_interaction_steps(mew_attacker.get_top_card(), mew_cd.attacks[0], state)
	var ctx := {
		"copied_attack": [{
			"source_effect_id": haxorus_cd.effect_id,
			"attack_index": 1,
			"attack": haxorus_cd.attacks[1],
		}],
	}
	mew_effect.set_attack_interaction_context([ctx])
	var damage_bonus := mew_effect.get_damage_bonus(mew_attacker, state)
	mew_effect.execute_attack(mew_attacker, state.players[1].active_pokemon, 0, state)
	mew_effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "基因侵入应先要求选择对手战斗宝可梦的招式"),
		assert_eq(damage_bonus, 230, "基因侵入应按选择的对手招式返回对应伤害"),
		assert_eq(state.players[0].deck.size(), 3, "复制龙之波动时应执行其附加效果并磨掉己方牌库3张"),
	])


func test_search_any_and_bench_enter_families() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	for i in range(4):
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("SearchAny_%d" % i, "C"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("SupporterCard", "Supporter"), 0))

	var search_one := AbilitySearchAny.new(1, false, false)
	search_one.execute_ability(player.active_pokemon, 0, [], state)
	var hand_after_search_one := player.hand.size()

	var search_two := AbilitySearchAny.new(2, true, false)
	search_two.execute_ability(player.active_pokemon, 0, [], state)
	var hand_after_search_two := player.hand.size()

	var lumineon_effect := AbilityOnBenchEnter.new("search_supporter")
	var lumineon := player.bench[0]
	var hand_before_lumineon := player.hand.size()
	lumineon_effect.execute_ability(lumineon, 0, [], state)
	var hand_after_lumineon := player.hand.size()

	var rush_effect := AbilityOnBenchEnter.new("rush_in")
	var rush_target := player.bench[1]
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_data("Carry", "G"), 0))
	rush_effect.execute_ability(rush_target, 0, [rush_target], state)

	return run_checks([
		assert_eq(hand_after_search_one, 1, "AbilitySearchAny(1) should add 1 card to hand"),
		assert_eq(hand_after_search_two, 3, "AbilitySearchAny(2) should add 2 more cards to hand"),
		assert_true(hand_after_lumineon == hand_before_lumineon or hand_after_lumineon == hand_before_lumineon + 1, "AbilityOnBenchEnter search_supporter should only add a Supporter when牌库中仍有目标"),
		assert_true(player.hand.any(func(card: CardInstance) -> bool: return card.card_data.card_type == "Supporter"), "AbilityOnBenchEnter search_supporter should find a Supporter"),
		assert_eq(player.active_pokemon, rush_target, "AbilityOnBenchEnter rush_in should switch the chosen bench Pokemon active"),
		assert_eq(rush_target.attached_energy.size(), 1, "AbilityOnBenchEnter rush_in should move attached energy to the entering Pokemon"),
	])


func test_vstar_power_families() -> String:
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	var extra_turn := AttackVSTARExtraTurn.new()
	extra_turn.execute_attack(attacker, state.players[1].active_pokemon, 0, state)

	var summon_state := _make_state()
	var summon_player: PlayerState = summon_state.players[0]
	summon_player.bench.clear()
	summon_player.discard_pile.clear()
	var target_a := CardInstance.create(_make_basic_pokemon_data("ColorlessA", "C", 120), 0)
	var target_b := CardInstance.create(_make_basic_pokemon_data("ColorlessB", "C", 110), 0)
	summon_player.discard_pile.append(target_a)
	summon_player.discard_pile.append(target_b)
	var summon_effect := AbilityVSTARSummon.new(2)
	summon_effect.execute_ability(summon_player.active_pokemon, 0, [{
		"summon_targets": [target_a, target_b],
	}], summon_state)

	var search_state := _make_state()
	var search_player: PlayerState = search_state.players[0]
	search_player.deck.clear()
	var searched_card := CardInstance.create(_make_trainer_data("AnyCard", "Item"), 0)
	search_player.deck.append(searched_card)
	var forest_slot := search_player.active_pokemon
	forest_slot.get_card_data().mechanic = "V"
	var forest_tool_cd := _make_trainer_data("Forest Seal Stone", "Tool", AbilityVSTARSearch.FOREST_SEAL_EFFECT_ID)
	forest_slot.attached_tool = CardInstance.create(forest_tool_cd, 0)
	var search_effect := AbilityVSTARSearch.new()
	search_effect.execute_ability(forest_slot, 0, [{
		"search_cards": [searched_card],
	}], search_state)

	return run_checks([
		assert_true(state.vstar_power_used[0], "AttackVSTARExtraTurn should consume the player's VSTAR power"),
		assert_true(attacker.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == "extra_turn"), "AttackVSTARExtraTurn should mark an extra turn"),
		assert_eq(summon_player.bench.size(), 2, "AbilityVSTARSummon should bench selected colorless Pokemon"),
		assert_true(summon_state.vstar_power_used[0], "AbilityVSTARSummon should also consume the VSTAR power"),
		assert_true(searched_card in search_player.hand, "AbilityVSTARSearch should add the selected card to hand"),
		assert_true(search_state.vstar_power_used[0], "AbilityVSTARSearch should consume the VSTAR power"),
	])


func test_draw_utility_families() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	player.hand.append(CardInstance.create(_make_energy_data("DiscardMe", "W"), 0))
	for i in range(4):
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("DrawUtil_%d" % i, "C"), 0))

	var discard_draw := AbilityDiscardDraw.new(2)
	state.current_player_index = 1
	var discard_draw_on_opponent_turn: bool = discard_draw.can_use_ability(player.active_pokemon, state)
	state.current_player_index = 0
	discard_draw.execute_ability(player.active_pokemon, 0, [{
		"discard_energy": [player.hand[0]],
	}], state)

	var end_turn_draw := AbilityEndTurnDraw.new(2)
	end_turn_draw.execute_ability(player.active_pokemon, 0, [], state)

	var bonus_state := _make_state()
	var bonus_player: PlayerState = bonus_state.players[0]
	bonus_player.hand.clear()
	bonus_player.deck.clear()
	bonus_player.deck.append(CardInstance.create(_make_basic_pokemon_data("BonusDrawActiveA", "C"), 0))
	bonus_player.deck.append(CardInstance.create(_make_basic_pokemon_data("BonusDrawActiveB", "C"), 0))
	bonus_player.deck.append(CardInstance.create(_make_basic_pokemon_data("BonusDrawBench", "C"), 0))
	var bonus_effect := AbilityBonusDrawIfActive.new()
	bonus_state.current_player_index = 1
	var bonus_on_opponent_turn: bool = bonus_effect.can_use_ability(bonus_player.active_pokemon, bonus_state)
	bonus_state.current_player_index = 0
	bonus_effect.execute_ability(bonus_player.active_pokemon, 0, [], bonus_state)
	var active_bonus_hand_size: int = bonus_player.hand.size()
	var bench_slot := bonus_player.bench[0]
	bench_slot.effects.clear()
	bonus_effect.execute_ability(bench_slot, 0, [], bonus_state)

	var shuffle_state := _make_state()
	var shuffle_player: PlayerState = shuffle_state.players[0]
	shuffle_player.hand.clear()
	shuffle_player.deck.clear()
	shuffle_player.hand.append(CardInstance.create(_make_basic_pokemon_data("HandA", "C"), 0))
	shuffle_player.hand.append(CardInstance.create(_make_basic_pokemon_data("HandB", "C"), 0))
	shuffle_player.deck.append(CardInstance.create(_make_basic_pokemon_data("DeckA", "C"), 0))
	var shuffle_draw := AbilityShuffleHandDraw.new(1)
	shuffle_draw.execute_ability(shuffle_player.active_pokemon, 0, [], shuffle_state)

	var blocks_bench := AbilityBenchProtect.new()

	return run_checks([
		assert_false(discard_draw_on_opponent_turn, "AbilityDiscardDraw should only be usable during its controller's turn"),
		assert_eq(player.discard_pile.size(), 1, "AbilityDiscardDraw should discard one energy"),
		assert_eq(player.hand.size(), 4, "AbilityDiscardDraw and AbilityEndTurnDraw should both increase hand size"),
		assert_false(bonus_on_opponent_turn, "AbilityBonusDrawIfActive should only be usable during its controller's turn"),
		assert_eq(active_bonus_hand_size, 2, "AbilityBonusDrawIfActive should draw 2 cards while Active"),
		assert_eq(bonus_player.hand.size(), 3, "AbilityBonusDrawIfActive should draw 1 card while Benched"),
		assert_true(end_turn_draw.has_end_turn_triggered(player.active_pokemon, state), "AbilityEndTurnDraw should leave an end-turn marker"),
		assert_eq(shuffle_player.hand.size(), 1, "AbilityShuffleHandDraw should redraw to its configured count"),
		assert_true(blocks_bench.blocks_bench_damage(), "AbilityBenchProtect should advertise bench protection"),
	])


func test_attack_utility_families() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var defender := state.players[1].active_pokemon

	player.hand.clear()
	player.deck.clear()
	for i in range(7):
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("TopPick_%d" % i, "C"), 0))

	var draw_to_seven := AttackDrawTo7.new()
	draw_to_seven.execute_attack(player.active_pokemon, defender, 0, state)

	var cinccino := player.active_pokemon
	cinccino.attached_energy.clear()
	cinccino.attached_energy.append(CardInstance.create(_make_energy_data("SpecialA", "C", "Special Energy"), 0))
	cinccino.attached_energy.append(CardInstance.create(_make_energy_data("SpecialB", "C", "Special Energy"), 0))
	var special_multi := AttackSpecialEnergyMultiDamage.new(70)
	special_multi.execute_attack(cinccino, defender, 0, state)

	var call_state := _make_state()
	var call_player: PlayerState = call_state.players[0]
	call_player.bench.clear()
	call_player.deck.clear()
	call_player.deck.append(CardInstance.create(_make_basic_pokemon_data("BasicA", "C"), 0))
	call_player.deck.append(CardInstance.create(_make_basic_pokemon_data("BasicB", "C"), 0))
	var call_family := AttackCallForFamily.new(1)
	call_family.execute_attack(call_player.active_pokemon, call_state.players[1].active_pokemon, 0, call_state)

	var lost_state := _make_state()
	var lost_player: PlayerState = lost_state.players[0]
	var lost_attacker := lost_player.active_pokemon
	lost_attacker.attached_energy.clear()
	for i in range(3):
		lost_attacker.attached_energy.append(CardInstance.create(_make_energy_data("Lost_%d" % i, "P"), 0))
	var lost_effect := AttackLostZoneEnergy.new(3, true)
	lost_effect.execute_attack(lost_attacker, lost_state.players[1].active_pokemon, 0, lost_state)

	var ko_effect := AttackLostZoneKO.new(10)
	var ko_defender := lost_state.players[1].active_pokemon
	for i in range(7):
		lost_player.lost_zone.append(CardInstance.create(_make_basic_pokemon_data("LostCard_%d" % i, "P"), 0))
	ko_effect.execute_attack(lost_attacker, ko_defender, 1, lost_state)

	return run_checks([
		assert_eq(player.hand.size(), 7, "AttackDrawTo7 should refill hand to seven"),
		assert_eq(defender.damage_counters, 140, "AttackSpecialEnergyMultiDamage should add damage per special energy"),
		assert_eq(call_player.bench.size(), 1, "AttackCallForFamily should bench a basic Pokemon"),
		assert_eq(lost_player.lost_zone.size(), 10, "Lost Zone attacks should populate lost-zone tracking"),
		assert_eq(ko_defender.damage_counters, ko_defender.get_max_hp(), "AttackLostZoneKO should knock out the defender"),
	])


func test_disable_metal_and_stadium_families() -> String:
	var state := _make_state()

	var flutter_cd := _make_basic_pokemon_data("Flutter", "P", 90)
	flutter_cd.abilities = [{"name": AbilityDisableOpponentAbility.ABILITY_NAME}]
	state.players[1].active_pokemon = _make_slot(flutter_cd, 1)

	var metal_state := _make_state()
	var metal_player: PlayerState = metal_state.players[0]
	metal_player.deck.clear()
	metal_player.deck.append(CardInstance.create(_make_energy_data("MetalA", "M"), 0))
	metal_player.deck.append(CardInstance.create(_make_energy_data("MetalB", "M"), 0))
	metal_player.deck.append(CardInstance.create(_make_trainer_data("Other", "Item"), 0))
	var metal_effect := AbilityMetalMaker.new(4, "M")
	metal_effect.execute_ability(metal_player.active_pokemon, 0, [metal_player.active_pokemon], metal_state)

	var stadium := EffectStadiumDamageModifier.new(-30, "defense", "M")
	var defender_cd := _make_basic_pokemon_data("MetalDefender", "M", 120)
	var defender := _make_slot(defender_cd, 1)

	return run_checks([
		assert_true(AbilityDisableOpponentAbility.is_opponent_abilities_disabled(state, 0), "AbilityDisableOpponentAbility should disable the opponent when active"),
		assert_eq(metal_player.active_pokemon.attached_energy.size(), 2, "AbilityMetalMaker should attach matching basic metal energy"),
		assert_true(stadium.is_defense_modifier(), "EffectStadiumDamageModifier should register as a defense modifier"),
		assert_true(stadium.matches_pokemon(defender), "EffectStadiumDamageModifier should match metal Pokemon"),
	])


func test_attach_from_deck_family_behaviour() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.active_pokemon.attached_energy.clear()
	player.deck.append(CardInstance.create(_make_energy_data("Gift", "C", "Special Energy"), 0))
	player.deck.append(CardInstance.create(_make_energy_data("Jet", "C", "Special Energy"), 0))
	player.deck.append(CardInstance.create(_make_energy_data("Basic", "R"), 0))

	var attach_effect := AbilityAttachFromDeckEffect.new("Special Energy", 2, "own_one", false, true)
	attach_effect.execute_ability(player.active_pokemon, 0, [player.active_pokemon], state)

	return run_checks([
		assert_eq(player.active_pokemon.attached_energy.size(), 2, "AbilityAttachFromDeck should attach the requested number of matching energy cards"),
		assert_true(player.active_pokemon.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == AbilityAttachFromDeckEffect.USED_KEY), "AbilityAttachFromDeck should mark once-per-turn usage"),
	])


func test_read_wind_snorlax_and_coin_flip_families() -> String:
	var read_state := _make_state()
	var read_player: PlayerState = read_state.players[0]
	read_player.hand.clear()
	read_player.discard_pile.clear()
	read_player.hand.append(CardInstance.create(_make_basic_pokemon_data("DiscardTarget", "C"), 0))
	for i in range(4):
		read_player.deck.append(CardInstance.create(_make_basic_pokemon_data("ReadWind_%d" % i, "C"), 0))
	AttackReadWindDraw.new().execute_attack(read_player.active_pokemon, read_state.players[1].active_pokemon, 0, read_state)

	var snorlax_cd := _make_basic_pokemon_data("Snorlax", "C", 150)
	snorlax_cd.abilities = [{"name": "无畏脂肪"}]
	var snorlax := _make_slot(snorlax_cd, 0)
	AttackSelfSleep.new().execute_attack(snorlax, read_state.players[1].active_pokemon, 0, read_state)

	var coin_state := _make_state()
	var coin_defender := coin_state.players[1].active_pokemon
	coin_defender.damage_counters = 20
	var coin_effect := AttackCoinFlipMultiplier.new(20, RiggedCoinFlipper.new([true, true, false]))
	coin_effect.execute_attack(coin_state.players[0].active_pokemon, coin_defender, 0, coin_state)

	return run_checks([
		assert_eq(read_player.discard_pile.size(), 1, "AttackReadWindDraw should discard one card"),
		assert_eq(read_player.hand.size(), 3, "AttackReadWindDraw should draw three cards after the discard"),
		assert_true(AbilityIgnoreEffects.has_ignore_effects(snorlax), "AbilityIgnoreEffects should detect Snorlax-style protection"),
		assert_true(snorlax.status_conditions.get("asleep", false), "AttackSelfSleep should put the attacker to sleep"),
		assert_eq(coin_defender.damage_counters, 40, "AttackCoinFlipMultiplier should use the injected coin-flip sequence"),
	])


func test_beldum_search_to_top_family() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("OtherA", "C"), 0))
	var chosen_top := CardInstance.create(_make_basic_pokemon_data("ChosenTop", "C"), 0)
	player.deck.append(chosen_top)
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("OtherB", "C"), 0))

	var effect := AttackSearchDeckToTopEffect.new(1)
	effect.set_attack_interaction_context([{
		"search_cards": [chosen_top],
	}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(player.deck[0].card_data.name, "ChosenTop", "AttackSearchDeckToTop should leave the selected card on top of the deck"),
		assert_eq(player.hand.size(), 3, "AttackSearchDeckToTop should not add cards to hand"),
	])


## ==================== 巨龙无双（雷吉铎拉戈VSTAR）语义测试 ====================

## 辅助：创建雷吉铎拉戈VSTAR 的 CardData
func _make_regidrago_vstar_data() -> CardData:
	var cd := _make_basic_pokemon_data(
		"Regidrago VSTAR", "N", 280, "VSTAR", "V",
		"749d2f12d33057c8cc20e52c1b11bcbf"
	)
	var atks: Array[Dictionary] = [{
		"name": "巨龙无双",
		"cost": "GGR",
		"damage": "",
		"text": "选择自己弃牌区中的龙宝可梦所拥有的1个招式，作为这个招式使用。",
		"is_vstar_power": false,
	}]
	cd.attacks = atks
	return cd


## 辅助：创建一个通用龙系宝可梦 CardData
func _make_dragon_pokemon_data(
	pname: String,
	hp: int,
	effect_id: String,
	attacks_raw: Array
) -> CardData:
	var cd := _make_basic_pokemon_data(pname, "N", hp, "Basic", "", effect_id)
	var typed_attacks: Array[Dictionary] = []
	for a: Variant in attacks_raw:
		if a is Dictionary:
			typed_attacks.append(a)
	cd.attacks = typed_attacks
	return cd


## 辅助：设置巨龙无双测试的通用状态
## 返回 [processor, state, attacker_slot, defender_slot]
func _setup_dragon_copy_test(
	source_cd: CardData,
	source_attack_index: int
) -> Array:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]

	# 注册雷吉铎拉戈VSTAR
	var regidrago_cd := _make_regidrago_vstar_data()
	processor.register_pokemon_card(regidrago_cd)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	attacker.turn_played = 0
	player.active_pokemon = attacker

	# 注册源龙系宝可梦并放入弃牌区
	processor.register_pokemon_card(source_cd)
	var source_card := CardInstance.create(source_cd, 0)
	player.discard_pile.append(source_card)

	var defender: PokemonSlot = state.players[1].active_pokemon

	# 构建交互上下文（模拟玩家已选择了被复制的招式）
	var copied_attack: Dictionary = source_cd.attacks[source_attack_index]
	var ctx := {
		"copied_attack": [{
			"source_card": source_card,
			"attack_index": source_attack_index,
			"attack": copied_attack,
		}],
	}

	return [processor, state, attacker, defender, ctx]


## 测试1：复制简单伤害招式（多龙巴鲁托ex 喷射头击 70伤害）
func test_dragon_copy_simple_damage_attack() -> String:
	var source_cd := _make_dragon_pokemon_data(
		"Dragapult ex", 320, "52a205820de799a53a689f23cbeb8622",
		[
			{"name": "喷射头击", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
			{"name": "幻影潜袭", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
		]
	)
	var setup: Array = _setup_dragon_copy_test(source_cd, 0)
	var processor: EffectProcessor = setup[0]
	var state: GameState = setup[1]
	var attacker: PokemonSlot = setup[2]
	var defender: PokemonSlot = setup[3]
	var ctx: Dictionary = setup[4]

	# 获取巨龙无双效果并计算伤害加值
	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	dragon_effect.set_attack_interaction_context([ctx])
	var bonus: int = dragon_effect.get_damage_bonus(attacker, state)
	dragon_effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(bonus, 70, "复制喷射头击应返回70伤害加值"),
	])


## 测试2：复制带减伤效果的招式（洗翠黏美龙VSTAR 钢铁滚动 200伤害 + 下回合减伤80）
func test_dragon_copy_reduce_damage_attack() -> String:
	var source_cd := _make_dragon_pokemon_data(
		"Hisuian Goodra VSTAR", 270, "c3ada06b5a60fb63228d9f704109718b",
		[{"name": "钢铁滚动", "cost": "WMC", "damage": "200", "text": "", "is_vstar_power": false}]
	)
	var setup: Array = _setup_dragon_copy_test(source_cd, 0)
	var processor: EffectProcessor = setup[0]
	var state: GameState = setup[1]
	var attacker: PokemonSlot = setup[2]
	var defender: PokemonSlot = setup[3]
	var ctx: Dictionary = setup[4]

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	# 计算伤害
	dragon_effect.set_attack_interaction_context([ctx])
	var bonus: int = dragon_effect.get_damage_bonus(attacker, state)

	# 执行附加效果（应该给 attacker 添加减伤标记）
	dragon_effect.execute_attack(attacker, defender, 0, state)
	dragon_effect.clear_attack_interaction_context()

	var has_reduce_marker := false
	for effect_data: Dictionary in attacker.effects:
		if effect_data.get("type", "") == "reduce_damage_next_turn":
			has_reduce_marker = true

	return run_checks([
		assert_eq(bonus, 200, "复制钢铁滚动应返回200伤害加值"),
		assert_true(has_reduce_marker, "复制钢铁滚动应给攻击者添加减伤80标记"),
	])


## 测试3：复制双斧战龙的龙之波动（230伤害 + 磨牌3张）
func test_dragon_copy_mill_self_attack() -> String:
	var source_cd := _make_dragon_pokemon_data(
		"Haxorus", 170, "e45788bd7d9ffec5b3da3730d2dc806f",
		[
			{"name": "巨斧劈落", "cost": "F", "damage": "", "text": "", "is_vstar_power": false},
			{"name": "龙之波动", "cost": "FM", "damage": "230", "text": "", "is_vstar_power": false},
		]
	)
	var setup: Array = _setup_dragon_copy_test(source_cd, 1)
	var processor: EffectProcessor = setup[0]
	var state: GameState = setup[1]
	var attacker: PokemonSlot = setup[2]
	var _defender: PokemonSlot = setup[3]
	var ctx: Dictionary = setup[4]
	var player: PlayerState = state.players[0]
	var initial_deck_size: int = player.deck.size()

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	dragon_effect.set_attack_interaction_context([ctx])
	var bonus: int = dragon_effect.get_damage_bonus(attacker, state)

	# 执行附加效果（应该磨牌）
	dragon_effect.execute_attack(attacker, _defender, 0, state)
	dragon_effect.clear_attack_interaction_context()

	# 双斧战龙的龙之波动注册了 AttackMillSelfDeck(3, 1)，attack_index=1
	# 被复制的 attack_index=1，所以应该匹配
	var milled: int = initial_deck_size - player.deck.size()

	return run_checks([
		assert_eq(bonus, 230, "复制龙之波动应返回230伤害加值"),
		assert_eq(milled, 3, "复制龙之波动应磨牌3张（与双斧战龙的磨牌效果一致）"),
	])


## 测试4：复制双斧战龙的巨斧劈落（对方有特殊能量则KO）
func test_dragon_copy_ko_if_special_energy_attack() -> String:
	var source_cd := _make_dragon_pokemon_data(
		"Haxorus", 170, "e45788bd7d9ffec5b3da3730d2dc806f",
		[
			{"name": "巨斧劈落", "cost": "F", "damage": "", "text": "", "is_vstar_power": false},
			{"name": "龙之波动", "cost": "FM", "damage": "230", "text": "", "is_vstar_power": false},
		]
	)
	var setup: Array = _setup_dragon_copy_test(source_cd, 0)
	var processor: EffectProcessor = setup[0]
	var state: GameState = setup[1]
	var attacker: PokemonSlot = setup[2]
	var defender: PokemonSlot = setup[3]
	var ctx: Dictionary = setup[4]

	# 给防守方附着一个特殊能量
	var special_energy_cd := _make_energy_data("Double Turbo", "", "Special Energy", "9c04dd0addf56a7b2c88476bc8e45c0e")
	defender.attached_energy.append(CardInstance.create(special_energy_cd, 1))

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	dragon_effect.set_attack_interaction_context([ctx])
	# 巨斧劈落的 damage 为空，所以伤害加值应为0
	var bonus: int = dragon_effect.get_damage_bonus(attacker, state)

	# 执行附加效果（应该KO防守方）
	dragon_effect.execute_attack(attacker, defender, 0, state)
	dragon_effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(bonus, 0, "复制巨斧劈落（无数字伤害）应返回0伤害加值"),
		assert_eq(defender.damage_counters, defender.get_max_hp(), "复制巨斧劈落应在对方有特殊能量时KO防守方"),
	])


## 测试5：复制骑拉帝纳VSTAR 放逐冲击（280伤害 + 弃3能量到放逐区）
func test_dragon_copy_lost_zone_energy_attack() -> String:
	var source_cd := _make_dragon_pokemon_data(
		"Giratina VSTAR", 280, "90c254f809637aea730f5ff97b143f44",
		[
			{"name": "放逐冲击", "cost": "GPC", "damage": "280", "text": "", "is_vstar_power": false},
			{"name": "星耀安魂曲", "cost": "GP", "damage": "", "text": "", "is_vstar_power": true},
		]
	)
	var setup: Array = _setup_dragon_copy_test(source_cd, 0)
	var processor: EffectProcessor = setup[0]
	var state: GameState = setup[1]
	var attacker: PokemonSlot = setup[2]
	var defender: PokemonSlot = setup[3]
	var ctx: Dictionary = setup[4]
	var player: PlayerState = state.players[0]

	# 给攻击者附着能量（放逐冲击弃2个能量到放逐区）
	for _i: int in 3:
		attacker.attached_energy.append(
			CardInstance.create(_make_energy_data("Grass", "G"), 0)
		)

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	dragon_effect.set_attack_interaction_context([ctx])
	var bonus: int = dragon_effect.get_damage_bonus(attacker, state)

	# 执行附加效果（应该弃2能量到放逐区）
	dragon_effect.execute_attack(attacker, defender, 0, state)
	dragon_effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(bonus, 280, "复制放逐冲击应返回280伤害加值"),
		assert_eq(attacker.attached_energy.size(), 1, "复制放逐冲击应弃置2张能量（剩余1张）"),
		assert_eq(player.lost_zone.size(), 2, "复制放逐冲击应将2张能量放入放逐区"),
	])


## 测试6：VSTAR力量招式（星耀安魂曲）不应出现在可选列表中
func test_dragon_copy_filters_vstar_power_attacks() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]

	# 注册雷吉铎拉戈VSTAR
	var regidrago_cd := _make_regidrago_vstar_data()
	processor.register_pokemon_card(regidrago_cd)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	player.active_pokemon = attacker

	# 注册骑拉帝纳VSTAR（有一个VSTAR力量招式和一个普通招式）
	var giratina_cd := _make_dragon_pokemon_data(
		"Giratina VSTAR", 280, "90c254f809637aea730f5ff97b143f44",
		[
			{"name": "放逐冲击", "cost": "GPC", "damage": "280", "text": "", "is_vstar_power": false},
			{"name": "星耀安魂曲", "cost": "GP", "damage": "", "text": "", "is_vstar_power": true},
		]
	)
	processor.register_pokemon_card(giratina_cd)
	var giratina_card := CardInstance.create(giratina_cd, 0)
	player.discard_pile.append(giratina_card)

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	var card: CardInstance = attacker.get_top_card()
	var attack: Dictionary = regidrago_cd.attacks[0]
	var steps: Array[Dictionary] = dragon_effect.get_attack_interaction_steps(card, attack, state)

	var attack_names: Array[String] = []
	if not steps.is_empty():
		var items: Array = steps[0].get("items", [])
		for item: Variant in items:
			if item is Dictionary:
				var atk: Dictionary = item.get("attack", {})
				attack_names.append(str(atk.get("name", "")))

	return run_checks([
		assert_true("放逐冲击" in attack_names, "放逐冲击应出现在可选列表中"),
		assert_false("星耀安魂曲" in attack_names, "VSTAR力量招式不应出现在可选列表中"),
	])


## 测试7：弃牌区无龙系宝可梦时交互步骤应为空
func test_dragon_copy_empty_discard_returns_no_steps() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.discard_pile.clear()

	var regidrago_cd := _make_regidrago_vstar_data()
	processor.register_pokemon_card(regidrago_cd)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	player.active_pokemon = attacker

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	var card: CardInstance = attacker.get_top_card()
	var attack: Dictionary = regidrago_cd.attacks[0]
	var steps: Array[Dictionary] = dragon_effect.get_attack_interaction_steps(card, attack, state)

	return run_checks([
		assert_true(steps.is_empty(), "弃牌区无龙系宝可梦时交互步骤应为空"),
	])


## 测试8：不应复制自身（另一只雷吉铎拉戈VSTAR在弃牌区）
func test_dragon_copy_does_not_copy_self() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.discard_pile.clear()

	var regidrago_cd := _make_regidrago_vstar_data()
	processor.register_pokemon_card(regidrago_cd)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	player.active_pokemon = attacker

	# 将另一只雷吉铎拉戈VSTAR放入弃牌区
	var another_regidrago := CardInstance.create(regidrago_cd, 0)
	player.discard_pile.append(another_regidrago)

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	var card: CardInstance = attacker.get_top_card()
	var attack: Dictionary = regidrago_cd.attacks[0]
	var steps: Array[Dictionary] = dragon_effect.get_attack_interaction_steps(card, attack, state)

	return run_checks([
		assert_true(steps.is_empty(), "弃牌区只有另一只雷吉铎拉戈VSTAR时交互步骤应为空"),
	])


## 测试9：DamageCalculator 支持空 damage 字段 + 非零 attack_modifier
func test_damage_calculator_with_empty_damage_and_modifier() -> String:
	var calc := DamageCalculator.new()
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Test", "N", 100), 0))
	var defender := PokemonSlot.new()
	var defender_cd := _make_basic_pokemon_data("Defender", "C", 100)
	defender.pokemon_stack.append(CardInstance.create(defender_cd, 1))

	var attack := {"name": "巨龙无双", "cost": "GGR", "damage": "", "text": ""}
	var state := _make_state()

	# 有 attack_modifier（来自 get_damage_bonus）但 damage 为空
	var result: int = calc.calculate_damage(attacker, defender, attack, state, 200, 0, 0, false)
	# 无 modifier 时应返回0
	var result_zero: int = calc.calculate_damage(attacker, defender, attack, state, 0, 0, 0, false)

	return run_checks([
		assert_eq(result, 200, "空damage + 200 attack_modifier 应计算出200伤害"),
		assert_eq(result_zero, 0, "空damage + 0 modifier 应返回0"),
	])


## 测试10：复制幻影潜袭时应产生后续伤害指示物分配交互步骤
func test_dragon_copy_phantom_dive_produces_followup_bench_steps() -> String:
	var source_cd := _make_dragon_pokemon_data(
		"Dragapult ex", 320, "52a205820de799a53a689f23cbeb8622",
		[
			{"name": "喷射头击", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
			{"name": "幻影潜袭", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
		]
	)
	var setup: Array = _setup_dragon_copy_test(source_cd, 1)
	var processor: EffectProcessor = setup[0]
	var state: GameState = setup[1]
	var attacker: PokemonSlot = setup[2]
	var defender: PokemonSlot = setup[3]
	var ctx: Dictionary = setup[4]

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	# 模拟玩家已选择幻影潜袭
	var regidrago_cd := _make_regidrago_vstar_data()
	var card: CardInstance = attacker.get_top_card()
	var attack: Dictionary = regidrago_cd.attacks[0]

	# 获取后续交互步骤
	var followup: Array[Dictionary] = dragon_effect.get_followup_attack_interaction_steps(
		card, attack, state, ctx
	)

	# 后续步骤应包含伤害指示物分配（card_assignment 模式）
	var has_bench_counters := false
	for step: Dictionary in followup:
		if str(step.get("id", "")) == "bench_damage_counters":
			has_bench_counters = true

	return run_checks([
		assert_false(followup.is_empty(), "复制幻影潜袭时应产生后续交互步骤"),
		assert_true(has_bench_counters, "后续步骤应包含 bench_damage_counters 分配"),
	])


## 测试11：复制幻影潜袭时全流程（选择招式 + 分配伤害指示物 + 执行）
func test_dragon_copy_phantom_dive_full_flow_with_bench_counters() -> String:
	var source_cd := _make_dragon_pokemon_data(
		"Dragapult ex", 320, "52a205820de799a53a689f23cbeb8622",
		[
			{"name": "喷射头击", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
			{"name": "幻影潜袭", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
		]
	)
	var setup: Array = _setup_dragon_copy_test(source_cd, 1)
	var processor: EffectProcessor = setup[0]
	var state: GameState = setup[1]
	var attacker: PokemonSlot = setup[2]
	var defender: PokemonSlot = setup[3]
	var ctx: Dictionary = setup[4]

	# 模拟完整上下文：已选择幻影潜袭 + 已分配伤害指示物
	var bench_a: PokemonSlot = state.players[1].bench[0]
	var bench_b: PokemonSlot = state.players[1].bench[1]
	ctx["bench_damage_counters"] = [
		{"target": bench_a, "amount": 40},
		{"target": bench_b, "amount": 20},
	]

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	# 执行巨龙无双效果（应转发上下文给被复制招式的效果）
	dragon_effect.set_attack_interaction_context([ctx])
	dragon_effect.execute_attack(attacker, defender, 0, state)
	dragon_effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(bench_a.damage_counters, 40, "复制幻影潜袭应将40伤害分配给第一只备战宝可梦"),
		assert_eq(bench_b.damage_counters, 20, "复制幻影潜袭应将20伤害分配给第二只备战宝可梦"),
	])


## 测试12：对方无备战宝可梦时应跳过伤害指示物分配
func test_dragon_copy_phantom_dive_no_bench_skips_counters() -> String:
	var source_cd := _make_dragon_pokemon_data(
		"Dragapult ex", 320, "52a205820de799a53a689f23cbeb8622",
		[
			{"name": "喷射头击", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
			{"name": "幻影潜袭", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
		]
	)
	var setup: Array = _setup_dragon_copy_test(source_cd, 1)
	var processor: EffectProcessor = setup[0]
	var state: GameState = setup[1]
	var attacker: PokemonSlot = setup[2]
	var ctx: Dictionary = setup[4]

	# 清空对方备战区
	state.players[1].bench.clear()

	var regidrago_cd := _make_regidrago_vstar_data()
	var card: CardInstance = attacker.get_top_card()
	var attack: Dictionary = regidrago_cd.attacks[0]

	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var dragon_effect: AttackUseDiscardDragonAttackEffect = null
	for fx: BaseEffect in effects:
		if fx is AttackUseDiscardDragonAttackEffect:
			dragon_effect = fx
			break

	if dragon_effect == null:
		return "巨龙无双效果未注册到 EffectProcessor"

	var followup: Array[Dictionary] = dragon_effect.get_followup_attack_interaction_steps(
		card, attack, state, ctx
	)

	return run_checks([
		assert_true(followup.is_empty(), "对方无备战宝可梦时应无后续交互步骤"),
	])
