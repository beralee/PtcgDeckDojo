## 具体卡牌效果测试 - 覆盖专用效果类与烟雾测试
class_name TestSpecializedEffects
extends TestBase

const EffectRecoverBasicEnergyEffect = preload("res://scripts/effects/trainer_effects/EffectRecoverBasicEnergy.gd")
const EffectSearchBasicEnergyEffect = preload("res://scripts/effects/trainer_effects/EffectSearchBasicEnergy.gd")
const EffectLanceEffect = preload("res://scripts/effects/trainer_effects/EffectLance.gd")
const EffectHisuianHeavyBallEffect = preload("res://scripts/effects/trainer_effects/EffectHisuianHeavyBall.gd")
const AbilityStarPortalEffect = preload("res://scripts/effects/pokemon_effects/AbilityStarPortal.gd")
const AbilityAttachFromDeckEffect = preload("res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd")
const AttackSearchDeckToHandEffect = preload("res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd")
const AttackCoinFlipMultiplierEffect = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipMultiplier.gd")
const AttackDiscardBasicEnergyFromHandDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackDiscardBasicEnergyFromHandDamage.gd")
const AttackSearchEnergyFromDeckToSelfEffect = preload("res://scripts/effects/pokemon_effects/AttackSearchEnergyFromDeckToSelf.gd")


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		var result: bool = _results.pop_front() if not _results.is_empty() else false
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
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	cd.effect_id = effect_id
	return cd


func _make_trainer_data(name: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _make_stage_one_reference(name: String, evolves_from: String, owner_index: int, energy_type: String = "R") -> CardInstance:
	var cd := _make_basic_pokemon_data(name, energy_type, 90, "Stage 1")
	cd.evolves_from = evolves_from
	return CardInstance.create(cd, owner_index)


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi

		var active_cd := _make_basic_pokemon_data("战斗P%d" % pi, "R", 120)
		active_cd.retreat_cost = 2
		active_cd.attacks = [{"name": "测试招式", "cost": "RC", "damage": "30", "text": "", "is_vstar_power": false}]
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(active_cd, pi))
		active.turn_played = 0
		player.active_pokemon = active

		for bi: int in 2:
			var bench_cd := _make_basic_pokemon_data("备战P%d_%d" % [pi, bi], "W", 80)
			var bench := PokemonSlot.new()
			bench.pokemon_stack.append(CardInstance.create(bench_cd, pi))
			bench.turn_played = 0
			player.bench.append(bench)

		for hi: int in 3:
			player.hand.append(CardInstance.create(_make_basic_pokemon_data("手牌P%d_%d" % [pi, hi], "G", 60), pi))

		for di: int in 6:
			player.deck.append(CardInstance.create(_make_basic_pokemon_data("牌库宝可梦P%d_%d" % [pi, di], "C", 60), pi))

		for pri: int in 3:
			player.prizes.append(CardInstance.create(_make_basic_pokemon_data("奖赏P%d_%d" % [pi, pri], "C", 50), pi))

		state.players.append(player)

	return state


func test_counter_catcher_switches_opponent_when_prize_behind() -> String:
	var state := _make_state()
	state.players[0].prizes.append(CardInstance.create(_make_basic_pokemon_data("额外奖赏", "C"), 0))
	var effect := EffectCounterCatcher.new()
	var card := CardInstance.create(_make_trainer_data("反击捕捉器", "Item"), 0)
	var old_active: String = state.players[1].active_pokemon.get_pokemon_name()
	var chosen_target: PokemonSlot = state.players[1].bench[1]
	var new_active: String = chosen_target.get_pokemon_name()

	effect.execute(card, [{"opponent_bench_target": [chosen_target]}], state)

	return run_checks([
		assert_true(effect.can_execute(card, state), "己方奖赏卡更多时应可发动"),
		assert_eq(state.players[1].active_pokemon.get_pokemon_name(), new_active, "应将对手第一只备战拉上前台"),
		assert_true(state.players[1].bench.any(func(slot: PokemonSlot) -> bool: return slot.get_pokemon_name() == old_active), "原战斗宝可梦应回到备战区"),
	])


func test_ultra_ball_uses_selected_discard_and_selected_pokemon() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	var discard_a := CardInstance.create(_make_basic_pokemon_data("弃牌甲", "C"), 0)
	var discard_b := CardInstance.create(_make_basic_pokemon_data("弃牌乙", "C"), 0)
	var keep_card := CardInstance.create(_make_basic_pokemon_data("保留牌", "C"), 0)
	player.hand.append(discard_a)
	player.hand.append(discard_b)
	player.hand.append(keep_card)
	player.deck.clear()
	var pokemon_a := CardInstance.create(_make_basic_pokemon_data("检索甲", "C"), 0)
	var pokemon_b := CardInstance.create(_make_basic_pokemon_data("检索乙", "C"), 0)
	player.deck.append(pokemon_a)
	player.deck.append(pokemon_b)
	var effect := EffectUltraBall.new()

	effect.execute(CardInstance.create(_make_trainer_data("高级球"), 0), [{
		"discard_cards": [discard_a, discard_b],
		"search_pokemon": [pokemon_b],
	}], state)

	return run_checks([
		assert_true(discard_a in player.discard_pile, "应按选择弃置第一张手牌"),
		assert_true(discard_b in player.discard_pile, "应按选择弃置第二张手牌"),
		assert_true(pokemon_b in player.hand, "应按选择加入指定宝可梦"),
		assert_true(keep_card in player.hand, "未选中的手牌应保留"),
	])


func test_ciphermaniac_places_selected_cards_on_top_in_order() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()

	var card_a := CardInstance.create(_make_trainer_data("A"), 0)
	var card_b := CardInstance.create(_make_trainer_data("B"), 0)
	var card_c := CardInstance.create(_make_trainer_data("C"), 0)
	var card_d := CardInstance.create(_make_trainer_data("D"), 0)
	player.deck.append(card_a)
	player.deck.append(card_b)
	player.deck.append(card_c)
	player.deck.append(card_d)

	var effect := EffectCiphermaniac.new()
	var supporter := CardInstance.create(_make_trainer_data("暗码迷的解读", "Supporter"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(supporter, state)
	effect.execute(supporter, [{
		"top_cards": [card_c, card_a],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "暗码迷应生成一条选牌交互步骤"),
		assert_eq(int(steps[0].get("min_select", 0)), 2, "牌库足够时应要求选择2张"),
		assert_eq(player.deck[0], card_c, "先选择的牌应成为最上面的牌"),
		assert_eq(player.deck[1], card_a, "第二张选择的牌应位于第二位"),
		assert_eq(player.deck.size(), 4, "结算后牌库数量不应变化"),
	])


func test_nest_ball_uses_selected_basic_pokemon() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	var basic_a := CardInstance.create(_make_basic_pokemon_data("基础甲", "C", 60), 0)
	var basic_b := CardInstance.create(_make_basic_pokemon_data("基础乙", "C", 70), 0)
	player.deck.append(basic_a)
	player.deck.append(basic_b)
	var effect := EffectNestBall.new()

	effect.execute(CardInstance.create(_make_trainer_data("巢穴球"), 0), [{
		"basic_pokemon": [basic_b],
	}], state)

	return run_checks([
		assert_eq(player.bench.back().get_pokemon_name(), "基础乙", "应按选择将指定基础宝可梦放入备战区"),
	])


func test_search_deck_uses_selected_target() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	var selected := CardInstance.create(_make_basic_pokemon_data("目标宝可梦", "C"), 0)
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("其他宝可梦", "C"), 0))
	player.deck.append(selected)
	var effect := EffectSearchDeck.new(1, 0, "Pokemon")

	effect.execute(CardInstance.create(_make_trainer_data("大师球"), 0), [{
		"search_cards": [selected],
	}], state)

	return run_checks([
		assert_true(selected in player.hand, "应按选择加入指定检索目标"),
	])


func test_capturing_aroma_heads_uses_shared_flipper_and_requires_evolution_pick() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.hand.clear()
	var basic := CardInstance.create(_make_basic_pokemon_data("基础宝可梦", "C", 70, "Basic"), 0)
	var evolution := _make_stage_one_reference("进化宝可梦", "基础宝可梦", 0)
	player.deck.append(basic)
	player.deck.append(evolution)

	var flipper := RiggedCoinFlipper.new([true])
	var emitted: Array[bool] = []
	flipper.coin_flipped.connect(func(result: bool) -> void: emitted.append(result))
	var processor := EffectProcessor.new(flipper)
	var effect := processor.get_effect("7cd68d9e286b78a7f9c799fce24a7d6c")
	var card := CardInstance.create(_make_trainer_data("捕获香氛", "Item", "7cd68d9e286b78a7f9c799fce24a7d6c"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{
		"searched_pokemon": [evolution],
	}], state)

	var items: Array = steps[0].get("items", [])
	return run_checks([
		assert_eq(emitted.size(), 1, "捕获香氛应通过共享 CoinFlipper 发出一次投币信号"),
		assert_eq(emitted[0], true, "正面结果应被共享投币器消费"),
		assert_eq(steps.size(), 1, "捕获香氛应生成一条交互步骤"),
		assert_eq(str(steps[0].get("id", "")), "searched_pokemon", "正面时应进入检索步骤"),
		assert_eq(bool(steps[0].get("allow_cancel", true)), false, "投币后不应允许取消来保留手牌"),
		assert_eq(items.size(), 1, "正面时只应展示进化宝可梦"),
		assert_true(items[0] == evolution, "正面时应只允许选择进化宝可梦"),
		assert_true(evolution in player.hand, "选择的进化宝可梦应加入手牌"),
		assert_true(basic in player.deck, "基础宝可梦不应被错误检索"),
	])


func test_capturing_aroma_tails_only_offers_basic_pokemon() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.hand.clear()
	var basic := CardInstance.create(_make_basic_pokemon_data("基础宝可梦", "C", 70, "Basic"), 0)
	var evolution := _make_stage_one_reference("进化宝可梦", "基础宝可梦", 0)
	player.deck.append(evolution)
	player.deck.append(basic)

	var effect := EffectCapturingAroma.new(RiggedCoinFlipper.new([false]))
	var card := CardInstance.create(_make_trainer_data("捕获香氛", "Item", "7cd68d9e286b78a7f9c799fce24a7d6c"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{
		"searched_pokemon": [basic],
	}], state)

	var items: Array = steps[0].get("items", [])
	return run_checks([
		assert_eq(steps.size(), 1, "反面时应生成一条检索步骤"),
		assert_eq(str(steps[0].get("id", "")), "searched_pokemon", "反面时仍应进入检索步骤"),
		assert_eq(bool(steps[0].get("allow_cancel", true)), false, "反面检索也不应允许取消"),
		assert_eq(items.size(), 1, "反面时只应展示基础宝可梦"),
		assert_true(items[0] == basic, "反面时应只允许选择基础宝可梦"),
		assert_true(basic in player.hand, "选择的基础宝可梦应加入手牌"),
		assert_true(evolution in player.deck, "进化宝可梦不应被错误检索"),
	])


func test_capturing_aroma_without_matching_target_returns_acknowledge_step() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.deck.append(_make_stage_one_reference("进化宝可梦", "基础宝可梦", 0))
	var effect := EffectCapturingAroma.new(RiggedCoinFlipper.new([false]))
	var card := CardInstance.create(_make_trainer_data("捕获香氛", "Item", "7cd68d9e286b78a7f9c799fce24a7d6c"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	return run_checks([
		assert_eq(steps.size(), 1, "没有匹配目标时仍应提供一条确认步骤"),
		assert_eq(str(steps[0].get("id", "")), "flip_result", "无匹配目标时应显示投币结果确认"),
		assert_eq(bool(steps[0].get("allow_cancel", true)), false, "无匹配目标时也不应允许取消"),
		assert_eq(Array(steps[0].get("items", [])).size(), 1, "确认步骤应只提供继续按钮"),
	])


func test_capturing_aroma_heads_includes_vstar_as_evolution() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.hand.clear()
	var basic := CardInstance.create(_make_basic_pokemon_data("基础宝可梦", "C", 70, "Basic"), 0)
	var vstar := CardInstance.create(_make_basic_pokemon_data("洛奇亚VSTAR", "C", 280, "VSTAR", "VSTAR"), 0)
	player.deck.append(basic)
	player.deck.append(vstar)

	var effect := EffectCapturingAroma.new(RiggedCoinFlipper.new([true]))
	var card := CardInstance.create(_make_trainer_data("捕获香氛", "Item", "7cd68d9e286b78a7f9c799fce24a7d6c"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{
		"searched_pokemon": [vstar],
	}], state)

	var items: Array = steps[0].get("items", [])
	return run_checks([
		assert_eq(items.size(), 1, "正面时应包含 VSTAR 作为进化宝可梦"),
		assert_true(items[0] == vstar, "正面时 VSTAR 应在可选列表中"),
		assert_true(vstar in player.hand, "选择的 VSTAR 应加入手牌"),
		assert_true(basic not in player.hand, "基础宝可梦不应被检索"),
	])


func test_pokemon_catcher_uses_shared_flipper_and_requires_target_on_heads() -> String:
	var state := _make_state()
	var opponent: PlayerState = state.players[1]
	var chosen: PokemonSlot = opponent.bench[1]

	var flipper := RiggedCoinFlipper.new([true])
	var emitted: Array[bool] = []
	flipper.coin_flipped.connect(func(result: bool) -> void: emitted.append(result))
	var processor := EffectProcessor.new(flipper)
	var effect := processor.get_effect("3a6d419769778b40091e69fbd76737ec")
	var card := CardInstance.create(_make_trainer_data("宝可梦捕捉器", "Item", "3a6d419769778b40091e69fbd76737ec"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{
		"opponent_bench_target": [chosen],
	}], state)

	var items: Array = steps[0].get("items", [])
	return run_checks([
		assert_eq(emitted.size(), 1, "宝可梦捕捉器应通过共享 CoinFlipper 发出一次投币信号"),
		assert_eq(emitted[0], true, "正面结果应被共享投币器消费"),
		assert_eq(steps.size(), 1, "正面时应生成一条目标选择步骤"),
		assert_eq(str(steps[0].get("id", "")), "opponent_bench_target", "正面时应选择对手备战宝可梦"),
		assert_eq(bool(steps[0].get("allow_cancel", true)), false, "正面后必须完成选择，不能取消"),
		assert_eq(items.size(), opponent.bench.size(), "正面时应列出全部对手备战宝可梦"),
		assert_true(opponent.active_pokemon == chosen, "选择的对手备战宝可梦应被换到战斗场"),
	])


func test_look_top_cards_uses_selected_target() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	var other := CardInstance.create(_make_basic_pokemon_data("顶部甲", "C"), 0)
	var chosen := CardInstance.create(_make_basic_pokemon_data("顶部乙", "C"), 0)
	player.deck.append(other)
	player.deck.append(chosen)
	var effect := EffectLookTopCards.new(2, "Pokemon", 1)

	effect.execute(CardInstance.create(_make_trainer_data("超级球"), 0), [{
		"look_top_cards": [chosen],
	}], state)

	return run_checks([
		assert_true(chosen in player.hand, "应按选择加入查看到的目标卡"),
		assert_true(other in player.deck, "未被选中的卡应留在牌库中"),
	])


func test_look_top_cards_can_whiff_without_becoming_unplayable() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	for i: int in 7:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("顶部%d" % i, "C"), 0))

	var effect := EffectLookTopCards.new(7, "Supporter", 1)
	var card := CardInstance.create(_make_trainer_data("宝可装置3.0"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [], state)

	return run_checks([
		assert_true(effect.can_execute(card, state), "只要牌库不为空，看牌顶类物品就应可使用"),
		assert_eq(steps.size(), 1, "应生成一条看牌和选择步骤"),
		assert_eq(int(steps[0].get("min_select", -1)), 0, "没有合法目标时应允许0选"),
		assert_eq(int(steps[0].get("max_select", -1)), 0, "没有合法目标时最多选择数应为0"),
		assert_eq(player.hand.size(), 0, "没有命中时不应凭空加入手牌"),
		assert_eq(player.deck.size(), 7, "空结算后牌库数量应保持不变"),
	])


func test_electric_generator_attaches_selected_energy_to_selected_target() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var lightning_bench := player.bench[0]
	lightning_bench.get_card_data().energy_type = "L"
	player.deck.clear()
	var energy_a := CardInstance.create(_make_energy_data("雷能量A", "L"), 0)
	var energy_b := CardInstance.create(_make_energy_data("雷能量B", "L"), 0)
	player.deck.append(energy_a)
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("杂项", "C"), 0))
	player.deck.append(energy_b)
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("杂项2", "C"), 0))
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("杂项3", "C"), 0))
	player.deck.append(CardInstance.create(_make_energy_data("火能量", "R"), 0))

	var effect := EffectElectricGenerator.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(
		CardInstance.create(_make_trainer_data("电气发生器"), 0),
		state
	)
	effect.execute(CardInstance.create(_make_trainer_data("电气发生器"), 0), [{
		"energy_assignments": [
			{"source": energy_a, "target": lightning_bench},
			{"source": energy_b, "target": lightning_bench},
		],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "电气发生器应生成一条分配交互步骤"),
		assert_eq(lightning_bench.attached_energy.size(), 2, "应从牌库顶5张附着2张基本雷能量"),
		assert_eq(player.deck.size(), 4, "牌库应减少2张能量"),
	])


func test_electric_generator_can_split_energy_between_two_benched_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var first_bench := player.bench[0]
	var second_bench := player.bench[1]
	first_bench.get_card_data().energy_type = "L"
	second_bench.get_card_data().energy_type = "L"
	player.deck.clear()
	var energy_a := CardInstance.create(_make_energy_data("雷能量A", "L"), 0)
	var energy_b := CardInstance.create(_make_energy_data("雷能量B", "L"), 0)
	player.deck.append_array([
		energy_a,
		CardInstance.create(_make_basic_pokemon_data("杂项", "C"), 0),
		energy_b,
		CardInstance.create(_make_basic_pokemon_data("杂项2", "C"), 0),
		CardInstance.create(_make_basic_pokemon_data("杂项3", "C"), 0),
	])

	var effect := EffectElectricGenerator.new()
	effect.execute(CardInstance.create(_make_trainer_data("电气发生器"), 0), [{
		"energy_assignments": [
			{"source": energy_a, "target": first_bench},
			{"source": energy_b, "target": second_bench},
		],
	}], state)

	return run_checks([
		assert_eq(first_bench.attached_energy.size(), 1, "第一张雷能量应可附着到第一只目标"),
		assert_eq(second_bench.attached_energy.size(), 1, "第二张雷能量应可附着到另一只目标"),
	])


func test_switch_cart_uses_selected_bench_target() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var chosen_bench: PokemonSlot = player.bench[1]
	var old_active: PokemonSlot = player.active_pokemon
	old_active.damage_counters = 50
	var effect := EffectSwitchCart.new()

	effect.execute(CardInstance.create(_make_trainer_data("交替推车"), 0), [{
		"switch_target": [chosen_bench],
	}], state)

	return run_checks([
		assert_eq(player.active_pokemon, chosen_bench, "应按选择换上指定备战宝可梦"),
		assert_true(old_active in player.bench, "原战斗宝可梦应回到备战区"),
		assert_eq(old_active.damage_counters, 20, "原战斗宝可梦应回复30点伤害"),
	])


func test_search_pokemon_to_bench_uses_selected_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	player.deck.clear()
	var selected_a := CardInstance.create(_make_basic_pokemon_data("雷基础甲", "L"), 0)
	var selected_b := CardInstance.create(_make_basic_pokemon_data("雷基础乙", "L"), 0)
	player.deck.append(selected_a)
	player.deck.append(selected_b)
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("其他宝可梦", "C"), 0))
	var ability := AbilitySearchPokemonToBench.new("L", 2)

	ability.execute_ability(player.active_pokemon, 0, [{
		"bench_pokemon": [selected_a, selected_b],
	}], state)

	return run_checks([
		assert_eq(player.bench.size(), 2, "应按选择将最多2只雷属性基础宝可梦放入备战区"),
		assert_eq(player.bench[0].get_pokemon_name(), "雷基础甲", "第一只应为选中的目标"),
		assert_eq(player.bench[1].get_pokemon_name(), "雷基础乙", "第二只应为选中的目标"),
	])


func test_quick_charge_searches_lightning_energy_from_deck_to_self() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var attacker := player.active_pokemon
	player.deck.clear()
	var lightning_energy := CardInstance.create(_make_energy_data("雷能量", "L"), 0)
	var other_energy := CardInstance.create(_make_energy_data("火能量", "R"), 0)
	player.deck.append(other_energy)
	player.deck.append(lightning_energy)

	var effect := AttackSearchEnergyFromDeckToSelfEffect.new("L", 1)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker.get_top_card(), {}, state)
	effect.set_attack_interaction_context([{
		"deck_energy": [lightning_energy],
	}])
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "快速充能应生成从牌库选能量的交互"),
		assert_eq(attacker.attached_energy.size(), 1, "快速充能应把选中的雷能量附着给自己"),
		assert_eq(player.deck.size(), 1, "被附着的能量应从牌库移除"),
	])


func test_squawkabilly_attack_attaches_selected_basic_energy_to_selected_bench() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var attacker := player.active_pokemon
	var chosen_bench := player.bench[1]
	player.discard_pile.clear()
	var energy_a := CardInstance.create(_make_energy_data("Discard L", "L"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Discard R", "R"), 0)
	player.discard_pile.append_array([energy_a, energy_b])

	var effect := AttackAttachBasicEnergyFromDiscard.new("", 2, "own_bench")
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker.get_top_card(), {}, state)
	effect.set_attack_interaction_context([{
		"discard_energy": [energy_a, energy_b],
		"attach_target": [chosen_bench],
	}])
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 2, "怒鹦哥ex的鼓足干劲应包含选能量和选目标两步交互"),
		assert_eq(chosen_bench.attached_energy.size(), 2, "选中的备战宝可梦应获得弃牌区的两张基本能量"),
		assert_eq(player.discard_pile.size(), 0, "被附着的能量应从弃牌区移除"),
	])


func test_moonlight_shuriken_discards_two_attached_energy() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var attacker_cd := _make_basic_pokemon_data("光辉甲贺忍蛙", "W", 130, "Basic", "", "09445b8c32fd4abef4230ebcdc964096")
	attacker_cd.attacks = [{
		"name": "月光手里剑",
		"cost": "WWC",
		"damage": "",
		"text": "",
		"is_vstar_power": false,
	}]
	processor.register_pokemon_card(attacker_cd)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("水1", "W"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("水2", "W"), 0))
	state.players[0].active_pokemon = attacker

	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [])

	return run_checks([
		assert_eq(attacker.attached_energy.size(), 0, "月光手里剑结算后应弃掉攻击者身上的2个能量"),
		assert_eq(state.players[0].discard_pile.size(), 2, "被弃置的能量应进入弃牌区"),
	])


func test_gust_ability_uses_selected_target() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	# 铁包袱必须在备战区才能发动特性
	var gust_pokemon := PokemonSlot.new()
	var gust_cd := _make_basic_pokemon_data("铁包袱", "W", 120)
	gust_cd.abilities = [{"name": "强力吹风机", "text": ""}]
	gust_pokemon.pokemon_stack.append(CardInstance.create(gust_cd, 0))
	gust_pokemon.turn_played = 0
	player.bench.append(gust_pokemon)
	var bench_count_before: int = player.bench.size()
	var chosen_target: PokemonSlot = opponent.bench[1]
	var old_active: PokemonSlot = opponent.active_pokemon
	var player_old_active: PokemonSlot = player.active_pokemon
	var ability := AbilityGustFromBench.new()

	# 验证在战斗位不能发动
	var gust_on_active := PokemonSlot.new()
	gust_on_active.pokemon_stack.append(CardInstance.create(gust_cd, 0))
	player.active_pokemon = gust_on_active
	var cannot_use_from_active: bool = not ability.can_use_ability(gust_on_active, state)
	player.active_pokemon = player_old_active

	# 验证在备战区可以发动
	var can_use_from_bench: bool = ability.can_use_ability(gust_pokemon, state)

	ability.execute_ability(gust_pokemon, 0, [{
		"opponent_bench_target": [chosen_target],
	}], state)

	return run_checks([
		assert_true(cannot_use_from_active, "在战斗位不应能发动强力吹风机"),
		assert_true(can_use_from_bench, "在备战区应能发动强力吹风机"),
		assert_eq(opponent.active_pokemon, chosen_target, "应将对手所选备战宝可梦换上战斗场"),
		assert_true(old_active in opponent.bench, "对手原战斗宝可梦应回到备战区"),
		assert_false(gust_pokemon in player.bench, "铁包袱发动后应从备战区移除"),
		assert_true(player.discard_pile.any(func(c: CardInstance) -> bool: return c.card_data.name == "铁包袱"), "铁包袱发动后应进入弃牌区"),
	])


func test_attack_bench_count_damage_bonus_counts_both_benches() -> String:
	var state := _make_state()
	state.players[0].bench.resize(3)
	state.players[1].bench.resize(2)
	var attack_effect := AttackBenchCountDamage.new(20, "both")
	var damage_calc := DamageCalculator.new()
	var attacker: PokemonSlot = state.players[0].active_pokemon
	var defender: PokemonSlot = state.players[1].active_pokemon
	var attack := {"name": "雷电回旋曲", "damage": "20"}

	var bonus: int = attack_effect.get_damage_bonus(attacker, state)
	var total_damage: int = damage_calc.calculate_damage(attacker, defender, attack, state, bonus, 0, 0)

	return run_checks([
		assert_eq(bonus, 100, "双方备战区合计5只宝可梦时应追加100伤害"),
		assert_eq(total_damage, 120, "基础20加追加100后总伤害应为120"),
	])


func test_rare_candy_evolves_basic_into_stage_two() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.append(_make_stage_one_reference("火恐龙", "小火龙", 0))
	for _i: int in 3:
		player.deck.append(CardInstance.create(_make_energy_data("基本火能量", "R"), 0))
	var stage2_cd := _make_basic_pokemon_data("喷火龙ex", "R", 330, "Stage 2")
	stage2_cd.evolves_from = "火恐龙"
	stage2_cd.effect_id = "rare_candy_charizard_test"
	stage2_cd.abilities = [{"name": "烈炎支配", "text": ""}]
	var stage2 := CardInstance.create(stage2_cd, 0)
	player.hand.append(stage2)
	player.active_pokemon.pokemon_stack.clear()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("小火龙", "R", 70), 0))
	player.active_pokemon.turn_played = 0

	var effect := EffectRareCandy.new()
	var card := CardInstance.create(_make_trainer_data("神奇糖果"), 0)
	var can_execute: bool = effect.can_execute(card, state)
	effect.execute(card, [], state)
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	gsm.effect_processor.register_effect(stage2_cd.effect_id, AbilityAttachFromDeckEffect.new("R", 3, "own", true, false))
	var evolve_steps: Array[Dictionary] = gsm.get_evolve_ability_interaction_steps(player.active_pokemon)

	return run_checks([
		assert_true(can_execute, "满足条件时应可使用神奇糖果"),
		assert_eq(player.active_pokemon.pokemon_stack.size(), 2, "应直接完成跳阶进化"),
		assert_eq(player.active_pokemon.get_pokemon_name(), "喷火龙ex", "顶层应变为2阶进化宝可梦"),
		assert_eq(evolve_steps.size(), 1, "神奇糖果进化到喷火龙ex后应立即能生成烈炎支配交互步骤"),
		assert_eq(str(evolve_steps[0].get("ui_mode", "")), "card_assignment", "进化后的烈炎支配应走统一的分配交互"),
	])


func test_rare_candy_rejects_unrelated_evolution_target() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var effect := EffectRareCandy.new()
	var card := CardInstance.create(_make_trainer_data("Rare Candy"), 0)
	player.deck.append(_make_stage_one_reference("Charmeleon", "Charmander", 0))

	var stage2_cd := _make_basic_pokemon_data("Charizard ex", "R", 330, "Stage 2")
	stage2_cd.evolves_from = "Charmeleon"
	var stage2 := CardInstance.create(stage2_cd, 0)
	player.hand.append(stage2)

	player.active_pokemon.pokemon_stack.clear()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Pidgey", "C", 60), 0))
	player.active_pokemon.turn_played = 0

	var valid_basic := player.bench[0]
	valid_basic.pokemon_stack.clear()
	valid_basic.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Charmander", "R", 70), 0))
	valid_basic.turn_played = 0

	var invalid_basic := player.bench[1]
	invalid_basic.pokemon_stack.clear()
	invalid_basic.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Pidgey", "C", 60), 0))
	invalid_basic.turn_played = 0

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var target_step: Dictionary = steps[1] if steps.size() > 1 else {}
	var target_items: Array = target_step.get("items", [])

	effect.execute(card, [{
		"stage2_card": [stage2],
		"target_pokemon": [invalid_basic],
	}], state)

	return run_checks([
		assert_true(effect.can_execute(card, state), "Rare Candy should be playable when a valid pair exists"),
		assert_true(valid_basic in target_items, "Matching basics should appear in the target list"),
		assert_false(invalid_basic in target_items, "Unrelated basics should not appear in the target list"),
		assert_eq(invalid_basic.get_pokemon_name(), "Pidgey", "Invalid target should not evolve"),
		assert_eq(valid_basic.get_pokemon_name(), "Charmander", "Invalid explicit selection should not evolve a different Pokemon"),
	])


func test_rare_candy_accepts_pidgeot_without_pidgeotto_in_deck_or_cache() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var effect := EffectRareCandy.new()
	var card := CardInstance.create(_make_trainer_data("Rare Candy"), 0)

	var stage2_cd := _make_basic_pokemon_data("Pidgeot ex", "C", 280, "Stage 2")
	stage2_cd.evolves_from = "比比鸟"
	var stage2 := CardInstance.create(stage2_cd, 0)
	player.hand.append(stage2)

	player.active_pokemon.pokemon_stack.clear()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("波波", "C", 60), 0))
	player.active_pokemon.turn_played = 0

	return run_checks([
		assert_true(effect.can_execute(card, state), "Rare Candy should support valid 0-stage1 Pidgeot lines"),
	])


func test_rare_candy_accepts_greninja_ex_without_frogadier_in_cache() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var effect := EffectRareCandy.new()
	var card := CardInstance.create(_make_trainer_data("Rare Candy"), 0)
	var greninja_cd: CardData = CardDatabase.get_card("CSV7C", "123")
	var froakie_cd: CardData = CardDatabase.get_card("CSV2C", "028")
	var greninja := CardInstance.create(greninja_cd, 0)
	player.hand.append(greninja)

	player.active_pokemon.pokemon_stack.clear()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(froakie_cd, 0))
	player.active_pokemon.turn_played = 0

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var stage2_items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var target_items: Array = steps[1].get("items", []) if steps.size() > 1 else []
	var can_execute: bool = effect.can_execute(card, state)
	effect.execute(card, [], state)

	return run_checks([
		assert_not_null(greninja_cd, "CSV7C_123 should exist in the card database"),
		assert_not_null(froakie_cd, "CSV2C_028 should exist in the card database"),
		assert_true(can_execute, "Rare Candy should support Greninja ex even when Frogadier is missing from the local cache"),
		assert_true(greninja in stage2_items, "Greninja ex should appear in the Rare Candy Stage 2 selection list"),
		assert_true(player.active_pokemon in target_items, "Froakie should appear in the Rare Candy target list for Greninja ex"),
		assert_eq(player.active_pokemon.get_pokemon_name(), greninja_cd.name, "Rare Candy should evolve Froakie directly into Greninja ex"),
	])


func test_tool_conditional_damage_checks_conditions() -> String:
	var state := _make_state()
	state.players[1].active_pokemon.get_card_data().mechanic = "ex"
	var ex_tool := EffectToolConditionalDamage.new(50, "ex")
	var v_tool := EffectToolConditionalDamage.new(30, "V")
	var prize_tool := EffectToolConditionalDamage.new(30, "prize_behind")
	state.players[0].prizes.append(CardInstance.create(_make_basic_pokemon_data("额外奖赏", "C"), 0))

	return run_checks([
		assert_true(ex_tool.is_active(state.players[0].active_pokemon, state), "对方为 ex 时应生效"),
		assert_false(v_tool.is_active(state.players[0].active_pokemon, state), "对方不是 V 时不应生效"),
		assert_true(prize_tool.is_active(state.players[0].active_pokemon, state), "己方奖赏卡落后时应生效"),
	])


func test_tool_conditional_damage_integrates_with_effect_processor() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	state.players[1].active_pokemon.get_card_data().mechanic = "ex"
	proc.register_effect("max_belt", EffectToolConditionalDamage.new(50, "ex"))
	state.players[0].active_pokemon.attached_tool = CardInstance.create(_make_trainer_data("极限腰带", "Tool", "max_belt"), 0)

	return run_checks([
		assert_eq(proc.get_attacker_modifier(state.players[0].active_pokemon, state), 50, "EffectProcessor 应能读到条件伤害加成"),
	])


func test_tool_future_boost_and_rescue_board_integrate_with_effect_processor() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var slot := state.players[0].active_pokemon
	slot.get_card_data().is_tags = PackedStringArray(["Future"])

	proc.register_effect("future_tool", EffectToolFutureBoost.new())
	slot.attached_tool = CardInstance.create(_make_trainer_data("驱劲能量 未来", "Tool", "future_tool"), 0)
	var attack_bonus: int = proc.get_attacker_modifier(slot, state)
	var retreat_cost: int = proc.get_effective_retreat_cost(slot, state)

	proc.register_effect("rescue_board", EffectToolRescueBoard.new())
	slot.attached_tool = CardInstance.create(_make_trainer_data("紧急滑板", "Tool", "rescue_board"), 0)
	slot.damage_counters = 90
	var rescue_retreat_cost: int = proc.get_effective_retreat_cost(slot, state)

	return run_checks([
		assert_eq(attack_bonus, 20, "未来宝可梦应获得+20攻击"),
		assert_eq(retreat_cost, 0, "未来宝可梦撤退费用应归零"),
		assert_eq(rescue_retreat_cost, 0, "紧急滑板在低血量时应将撤退费用归零"),
	])


func test_lightning_boost_applies_to_basic_lightning_attackers() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]

	var attacker_cd := _make_basic_pokemon_data("雷攻击者", "L", 110)
	player.active_pokemon.pokemon_stack.clear()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(attacker_cd, 0))

	var zapdos_cd := _make_basic_pokemon_data("闪电鸟", "L", 110)
	zapdos_cd.abilities = [{"name": "电气象征", "text": ""}]
	var zapdos_slot := PokemonSlot.new()
	zapdos_slot.pokemon_stack.append(CardInstance.create(zapdos_cd, 0))
	player.bench.append(zapdos_slot)

	var attack_bonus: int = proc.get_attacker_modifier(player.active_pokemon, state)

	return run_checks([
		assert_eq(attack_bonus, 10, "闪电鸟应让己方基础雷宝可梦的攻击伤害+10"),
	])


func test_techno_radar_uses_one_discard_and_only_future_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var radar_card := CardInstance.create(_make_trainer_data("高科技雷达"), 0)
	var discard_a := CardInstance.create(_make_basic_pokemon_data("弃牌甲", "C"), 0)
	var discard_b := CardInstance.create(_make_basic_pokemon_data("弃牌乙", "C"), 0)
	var keep_card := CardInstance.create(_make_basic_pokemon_data("保留牌", "C"), 0)
	player.hand.append_array([radar_card, discard_a, keep_card])

	var future_a := CardInstance.create(_make_basic_pokemon_data("未来甲", "L"), 0)
	future_a.card_data.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	var future_b := CardInstance.create(_make_basic_pokemon_data("未来乙", "P"), 0)
	future_b.card_data.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	var normal := CardInstance.create(_make_basic_pokemon_data("普通宝可梦", "W"), 0)
	player.deck.append_array([future_a, future_b, normal])

	var effect := EffectTechnoRadar.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(radar_card, state)
	var can_execute := effect.can_execute(radar_card, state)
	effect.execute(radar_card, [{
		"discard_cards": [discard_a],
		"search_future_pokemon": [future_b, future_a],
	}], state)

	return run_checks([
		assert_true(can_execute, "手牌有其他2张且牌库里有未来宝可梦时应可使用高科技雷达"),
		assert_eq(steps.size(), 2, "高科技雷达应生成弃牌和检索两步交互"),
		assert_true(discard_a in player.discard_pile, "应弃掉第一张选中的手牌"),
		assert_eq(int(steps[0].get("min_select", -1)), 1, "Techno Radar should require discarding 1 card"),
		assert_eq(int(steps[0].get("max_select", -1)), 1, "Techno Radar should allow discarding only 1 card"),
		assert_false(discard_b in player.discard_pile, "Techno Radar should not discard an extra second hand card"),
		assert_true(future_a in player.hand and future_b in player.hand, "应加入选中的未来宝可梦"),
		assert_false(normal in player.hand, "不应加入非未来宝可梦"),
		assert_true(keep_card in player.hand, "未选中的手牌应保留"),
	])


func test_techno_radar_can_use_with_one_other_hand_card() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var radar_card := CardInstance.create(_make_trainer_data("高科技雷达"), 0)
	var discard_card := CardInstance.create(_make_basic_pokemon_data("弃牌候选", "C"), 0)
	player.hand.append_array([radar_card, discard_card])

	var future_card := CardInstance.create(_make_basic_pokemon_data("未来宝可梦", "L"), 0)
	future_card.card_data.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	player.deck.append(future_card)

	var effect := EffectTechnoRadar.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(radar_card, state)
	var can_execute := effect.can_execute(radar_card, state)

	return run_checks([
		assert_true(can_execute, "高科技雷达在手牌只有1张其他卡时也应可使用"),
		assert_eq(int(steps[0].get("min_select", -1)), 1, "高科技雷达应只要求弃1张手牌"),
		assert_eq(int(steps[0].get("max_select", -1)), 1, "高科技雷达应只允许弃1张手牌"),
	])


func test_basic_energy_recovery_and_search_effects() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var hand_a := CardInstance.create(_make_basic_pokemon_data("手牌甲", "C"), 0)
	var hand_b := CardInstance.create(_make_basic_pokemon_data("手牌乙", "C"), 0)
	player.hand.append_array([hand_a, hand_b])

	var discard_w := CardInstance.create(_make_energy_data("基础水能量", "W"), 0)
	var discard_l := CardInstance.create(_make_energy_data("基础雷能量", "L"), 0)
	var discard_special := CardInstance.create(_make_energy_data("双重涡轮能量", "C", "Special Energy"), 0)
	player.discard_pile.append_array([discard_w, discard_l, discard_special])

	var deck_r := CardInstance.create(_make_energy_data("基础火能量", "R"), 0)
	var deck_g := CardInstance.create(_make_energy_data("基础草能量", "G"), 0)
	player.deck.append_array([deck_r, deck_g])

	var energy_retrieval := EffectRecoverBasicEnergyEffect.new(2, 0)
	energy_retrieval.execute(CardInstance.create(_make_trainer_data("能量回收"), 0), [{
		"recover_energy": [discard_w, discard_l],
	}], state)

	var superior := EffectRecoverBasicEnergyEffect.new(4, 2)
	# Put the basic energies back for the second part of the test.
	player.discard_pile.append_array([discard_w, discard_l])
	player.hand.erase(discard_w)
	player.hand.erase(discard_l)
	superior.execute(CardInstance.create(_make_trainer_data("超级能量回收"), 0), [{
		"discard_cards": [hand_a, hand_b],
		"recover_energy": [discard_w, discard_l],
	}], state)

	var earthen := EffectSearchBasicEnergyEffect.new(2, 1)
	var discard_tool := CardInstance.create(_make_trainer_data("代价牌"), 0)
	player.hand.append(discard_tool)
	earthen.execute(CardInstance.create(_make_trainer_data("大地容器"), 0), [{
		"discard_cards": [discard_tool],
		"search_energy": [deck_r, deck_g],
	}], state)

	return run_checks([
		assert_true(discard_w in player.hand and discard_l in player.hand, "能量回收类效果应将基础能量加入手牌"),
		assert_true(hand_a in player.discard_pile and hand_b in player.discard_pile, "超级能量回收应先弃掉2张手牌"),
		assert_true(deck_r in player.hand and deck_g in player.hand, "大地容器应从牌库检索基础能量"),
		assert_false(discard_special in player.hand, "特殊能量不应被基础能量回收效果检索"),
	])


func test_lance_searches_only_selected_dragon_pokemon() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var dragon_a := CardInstance.create(_make_basic_pokemon_data("Dragon A", "N"), 0)
	var dragon_b := CardInstance.create(_make_basic_pokemon_data("Dragon B", "N"), 0)
	var dragon_c := CardInstance.create(_make_basic_pokemon_data("Dragon C", "N"), 0)
	var non_dragon := CardInstance.create(_make_basic_pokemon_data("Non Dragon", "R"), 0)
	player.deck.append_array([dragon_a, non_dragon, dragon_b, dragon_c])

	var effect := EffectLanceEffect.new()
	var supporter := CardInstance.create(_make_trainer_data("Lance", "Supporter"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(supporter, state)
	effect.execute(supporter, [{
		"dragon_pokemon": [dragon_c, dragon_a],
	}], state)

	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var items: Array = step.get("items", [])
	return run_checks([
		assert_true(effect.can_execute(supporter, state), "Lance should be playable when the deck contains Dragon Pokemon"),
		assert_eq(steps.size(), 1, "Lance should generate one search step"),
		assert_eq(int(step.get("min_select", -1)), 0, "Lance should allow choosing up to 3 Dragon Pokemon"),
		assert_eq(int(step.get("max_select", -1)), 3, "Lance should allow selecting as many as 3 Dragon Pokemon"),
		assert_true(dragon_a in items and dragon_b in items and dragon_c in items, "Lance should only offer Dragon Pokemon from the deck"),
		assert_false(non_dragon in items, "Lance should not offer non-Dragon Pokemon"),
		assert_true(dragon_a in player.hand and dragon_c in player.hand, "Lance should move the selected Dragon Pokemon to hand"),
		assert_true(dragon_b in player.deck, "Lance should leave unselected Dragon Pokemon in the deck"),
		assert_true(non_dragon in player.deck, "Lance should leave non-Dragon Pokemon in the deck"),
	])


func test_up_to_effects_allow_zero_selection_without_fallback() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var superior_cost_a := CardInstance.create(_make_trainer_data("Superior Cost A"), 0)
	var superior_cost_b := CardInstance.create(_make_trainer_data("Superior Cost B"), 0)
	var discard_energy := CardInstance.create(_make_energy_data("Discard Grass", "G"), 0)
	player.hand.append_array([superior_cost_a, superior_cost_b])
	player.discard_pile.append(discard_energy)

	var superior := EffectRecoverBasicEnergyEffect.new(4, 2)
	var superior_steps: Array[Dictionary] = superior.get_interaction_steps(CardInstance.create(_make_trainer_data("超级能量回收"), 0), state)
	superior.execute(CardInstance.create(_make_trainer_data("超级能量回收"), 0), [{
		"discard_cards": [superior_cost_a, superior_cost_b],
		"recover_energy": [],
	}], state)

	var earthen_cost := CardInstance.create(_make_trainer_data("Earthen Cost"), 0)
	var deck_energy_a := CardInstance.create(_make_energy_data("Deck Fire", "R"), 0)
	var deck_energy_b := CardInstance.create(_make_energy_data("Deck Grass", "G"), 0)
	player.hand.append(earthen_cost)
	player.deck.append_array([deck_energy_a, deck_energy_b])

	var earthen := EffectSearchBasicEnergyEffect.new(2, 1)
	var earthen_steps: Array[Dictionary] = earthen.get_interaction_steps(CardInstance.create(_make_trainer_data("大地容器"), 0), state)
	earthen.execute(CardInstance.create(_make_trainer_data("大地容器"), 0), [{
		"discard_cards": [earthen_cost],
		"search_energy": [],
	}], state)

	var rod_pokemon := CardInstance.create(_make_basic_pokemon_data("Rod Pokemon", "C"), 0)
	var rod_energy := CardInstance.create(_make_energy_data("Rod Energy", "W"), 0)
	player.discard_pile.append_array([rod_pokemon, rod_energy])
	var deck_size_before_rod: int = player.deck.size()
	var super_rod := EffectSuperRod.new()
	var rod_steps: Array[Dictionary] = super_rod.get_interaction_steps(CardInstance.create(_make_trainer_data("厉害钓竿"), 0), state)
	super_rod.execute(CardInstance.create(_make_trainer_data("厉害钓竿"), 0), [{
		"cards_to_return": [],
	}], state)

	return run_checks([
		assert_eq(int(superior_steps[1].get("min_select", -1)), 0, "超级能量回收应允许选择0张基本能量"),
		assert_eq(int(earthen_steps[1].get("min_select", -1)), 0, "大地容器应允许选择0张基本能量"),
		assert_eq(int(rod_steps[0].get("min_select", -1)), 0, "厉害钓竿应允许选择0张卡牌"),
		assert_true(superior_cost_a in player.discard_pile and superior_cost_b in player.discard_pile, "超级能量回收仍应支付2张手牌的代价"),
		assert_false(discard_energy in player.hand, "显式选择0张时，超级能量回收不应自动回收能量"),
		assert_false(deck_energy_a in player.hand or deck_energy_b in player.hand, "显式选择0张时，大地容器不应自动检索能量"),
		assert_true(rod_pokemon in player.discard_pile and rod_energy in player.discard_pile, "显式选择0张时，厉害钓竿不应自动回收卡牌"),
		assert_eq(player.deck.size(), deck_size_before_rod, "显式选择0张时，厉害钓竿不应改变牌库数量"),
	])


func test_superior_energy_retrieval_cannot_recover_cost_energy() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var cost_energy_a := CardInstance.create(_make_energy_data("Cost Lightning A", "L"), 0)
	var cost_energy_b := CardInstance.create(_make_energy_data("Cost Lightning B", "L"), 0)
	var existing_energy := CardInstance.create(_make_energy_data("Existing Grass", "G"), 0)
	player.hand.append_array([cost_energy_a, cost_energy_b])
	player.discard_pile.append(existing_energy)

	var superior := EffectRecoverBasicEnergyEffect.new(4, 2)
	superior.execute(CardInstance.create(_make_trainer_data("超级能量回收"), 0), [{
		"discard_cards": [cost_energy_a, cost_energy_b],
		"recover_energy": [existing_energy, cost_energy_a, cost_energy_b],
	}], state)

	return run_checks([
		assert_true(existing_energy in player.hand, "超级能量回收应能回收原本就在弃牌区中的基本能量"),
		assert_true(cost_energy_a in player.discard_pile and cost_energy_b in player.discard_pile, "超级能量回收不应回收作为代价刚弃掉的基本能量"),
	])


func _legacy_hisuian_heavy_ball_wrong_swap_test() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.prizes.clear()
	var basic_prize := CardInstance.create(_make_basic_pokemon_data("奖赏基础", "W"), 0)
	var other_prize := CardInstance.create(_make_trainer_data("奖赏物品"), 0)
	var replacement_hand := CardInstance.create(_make_trainer_data("手牌替换"), 0)
	player.prizes.append_array([basic_prize, other_prize])
	player.hand.clear()
	player.hand.append(replacement_hand)

	var effect := EffectHisuianHeavyBallEffect.new()
	effect.execute(CardInstance.create(_make_trainer_data("洗翠的沉重球"), 0), [{
		"chosen_prize_basic": [basic_prize],
		"replacement_prize_card": [replacement_hand],
	}], state)

	return run_checks([
		assert_true(basic_prize in player.hand, "洗翠的沉重球应将奖赏区的基础宝可梦加入手牌"),
		assert_eq(player.prizes.size(), 2, "奖赏卡数量应保持不变"),
		assert_true(replacement_hand in player.prizes, "应将选中的手牌放回奖赏卡"),
		assert_false(replacement_hand in player.hand, "放回奖赏卡的手牌不应继续留在手牌"),
	])


func test_hisuian_heavy_ball_takes_basic_from_prizes_and_replaces_with_self() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.prizes.clear()
	var basic_prize := CardInstance.create(_make_basic_pokemon_data("Prize Basic", "W"), 0)
	var other_prize := CardInstance.create(_make_trainer_data("Prize Item"), 0)
	var hand_card := CardInstance.create(_make_trainer_data("Hand Card"), 0)
	player.prizes.append_array([basic_prize, other_prize])
	player.hand.clear()
	player.hand.append(hand_card)

	var effect := EffectHisuianHeavyBallEffect.new()
	var card := CardInstance.create(_make_trainer_data("Hisuian Heavy Ball"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{
		"chosen_prize_basic": [basic_prize],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Hisuian Heavy Ball should only ask for the prize Basic selection"),
		assert_eq(str(steps[0].get("id", "")), "chosen_prize_basic", "The only interaction should be choosing the Basic Pokemon from prizes"),
		assert_true(basic_prize in player.hand, "Hisuian Heavy Ball should move the chosen Basic Pokemon to hand"),
		assert_eq(player.prizes.size(), 2, "Prize count should stay unchanged after the swap"),
		assert_true(card in player.prizes, "The Heavy Ball itself should become the replacement prize card"),
		assert_false(hand_card in player.prizes, "An unrelated hand card should not be moved into prizes"),
		assert_true(hand_card in player.hand, "Other hand cards should remain in hand"),
	])


func test_hisuian_heavy_ball_play_trainer_keeps_source_card_out_of_discard() -> String:
	var state := _make_state()
	state.phase = GameState.GamePhase.MAIN
	var player: PlayerState = state.players[0]
	player.prizes.clear()
	player.hand.clear()

	var basic_prize := CardInstance.create(_make_basic_pokemon_data("Prize Basic", "W"), 0)
	var other_prize := CardInstance.create(_make_trainer_data("Prize Item"), 0)
	var heavy_ball := CardInstance.create(
		_make_trainer_data("Hisuian Heavy Ball", "Item", "2f68195255c863293be4fad262bf23d2"),
		0
	)
	var hand_card := CardInstance.create(_make_trainer_data("Hand Card"), 0)
	player.prizes.append_array([basic_prize, other_prize])
	player.hand.append_array([heavy_ball, hand_card])

	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var used: bool = gsm.play_trainer(0, heavy_ball, [{
		"chosen_prize_basic": [basic_prize],
	}])

	return run_checks([
		assert_true(used, "GameStateMachine should allow Hisuian Heavy Ball to be played"),
		assert_true(basic_prize in player.hand, "Playing Hisuian Heavy Ball should still take the chosen Basic Pokemon"),
		assert_true(heavy_ball in player.prizes, "The played Heavy Ball should be placed into prizes"),
		assert_false(heavy_ball in player.discard_pile, "The played Heavy Ball must not also be discarded"),
		assert_true(hand_card in player.hand, "Other hand cards should remain in hand after the effect resolves"),
	])

func test_hisuian_heavy_ball_can_execute_without_basic_prize() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.prizes.clear()
	player.prizes.append(CardInstance.create(_make_trainer_data("奖赏物品A"), 0))
	player.prizes.append(CardInstance.create(_make_trainer_data("奖赏物品B"), 0))

	var effect := EffectHisuianHeavyBallEffect.new()
	var card := CardInstance.create(_make_trainer_data("洗翠的沉重球"), 0)
	effect.execute(card, [], state)

	return run_checks([
		assert_true(effect.can_execute(card, state), "即使奖赏卡里没有基础宝可梦也应允许使用洗翠的沉重球"),
		assert_true(effect.get_interaction_steps(card, state).is_empty(), "没有基础宝可梦时不应强制选择目标"),
		assert_eq(player.prizes.size(), 2, "空结算时奖赏卡数量应保持不变"),
	])


func test_future_tag_overrides_apply_to_cached_cards() -> String:
	var future_card := CardDatabase.get_card("CSV7C", "153")
	var non_future_card := CardDatabase.get_card("CSV1C", "050")

	if future_card == null:
		return "未找到缓存卡 CSV7C/153"
	if non_future_card == null:
		return "未找到缓存卡 CSV1C/050"

	var proc := EffectProcessor.new()
	var state := _make_state()
	var slot := state.players[0].active_pokemon
	slot.pokemon_stack.clear()
	slot.pokemon_stack.append(CardInstance.create(future_card, 0))
	proc.register_effect("future_tool", EffectToolFutureBoost.new())
	slot.attached_tool = CardInstance.create(_make_trainer_data("驱劲能量 未来", "Tool", "future_tool"), 0)

	var future_attack_bonus: int = proc.get_attacker_modifier(slot, state)
	var future_retreat_cost: int = proc.get_effective_retreat_cost(slot, state)
	var radar_matches_future := EffectTechnoRadar.new()._is_future(future_card)
	var radar_matches_old_miraidon := EffectTechnoRadar.new()._is_future(non_future_card)

	return run_checks([
		assert_true(future_card.is_future_pokemon(), "CSV7C/153 应通过补丁标签识别为未来宝可梦"),
		assert_false(non_future_card.is_future_pokemon(), "CSV1C/050 不应被误判为未来宝可梦"),
		assert_eq(future_attack_bonus, 20, "驱劲能量 未来应对 CSV7C/153 生效"),
		assert_eq(future_retreat_cost, 0, "CSV7C/153 的撤退费用应被驱劲能量 未来降为0"),
		assert_true(radar_matches_future, "高科技雷达应能识别补丁后的未来宝可梦"),
		assert_false(radar_matches_old_miraidon, "高科技雷达不应误抓旧版密勒顿ex"),
	])


func test_star_portal_attaches_water_energy_from_discard() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var palkia := PokemonSlot.new()
	var palkia_cd := _make_basic_pokemon_data("帕路奇亚VSTAR", "W", 280, "Basic", "V")
	palkia_cd.effect_id = "palkia_vstar"
	palkia.pokemon_stack.append(CardInstance.create(palkia_cd, 0))
	player.active_pokemon = palkia
	player.bench[0].get_card_data().energy_type = "W"
	player.discard_pile.clear()
	var water_a := CardInstance.create(_make_energy_data("水能量甲", "W"), 0)
	var water_b := CardInstance.create(_make_energy_data("水能量乙", "W"), 0)
	var water_c := CardInstance.create(_make_energy_data("水能量丙", "W"), 0)
	player.discard_pile.append_array([water_a, water_b, water_c])

	var ability := AbilityStarPortalEffect.new()
	state.current_player_index = 1
	var can_use_on_opponent_turn: bool = ability.can_use_ability(palkia, state)
	state.current_player_index = 0
	ability.execute_ability(palkia, 0, [{
		"star_portal_assignments": [
			{"source": water_a, "target": player.active_pokemon},
			{"source": water_b, "target": player.bench[0]},
			{"source": water_c, "target": player.bench[0]},
		],
	}], state)

	return run_checks([
		assert_false(can_use_on_opponent_turn, "星耀传送门应只能在自己的回合使用"),
		assert_eq(player.active_pokemon.attached_energy.size(), 1, "星耀传送门应能附着到战斗宝可梦"),
		assert_eq(player.bench[0].attached_energy.size(), 2, "星耀传送门应允许同一目标获得多张能量"),
		assert_true(state.vstar_power_used[0], "VSTAR 力量使用后应被标记"),
	])


func test_iron_crown_boosts_other_future_pokemon_only() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()

	var crown_cd := _make_basic_pokemon_data("铁头壳ex", "P", 220, "Basic", "ex", "iron_crown_boost")
	crown_cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	crown_cd.abilities = [{"name": "蔚蓝指令", "text": ""}]
	var crown_slot := PokemonSlot.new()
	crown_slot.pokemon_stack.append(CardInstance.create(crown_cd, 0))
	player.bench.append(crown_slot)
	proc.register_effect("iron_crown_boost", AbilityFutureDamageBoost.new())

	var future_attacker_cd := _make_basic_pokemon_data("未来攻击手", "L", 120)
	future_attacker_cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	player.active_pokemon.pokemon_stack.clear()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(future_attacker_cd, 0))

	var boosted_damage: int = proc.get_attacker_modifier(player.active_pokemon, state)
	var crown_self_damage: int = proc.get_attacker_modifier(crown_slot, state)

	return run_checks([
		assert_eq(boosted_damage, 20, "铁头壳ex应让其他未来宝可梦伤害+20"),
		assert_eq(crown_self_damage, 0, "铁头壳ex自己不应获得蔚蓝指令加成"),
	])


func test_specialized_new_pokemon_attack_effects() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var defender: PokemonSlot = state.players[1].active_pokemon

	var stadium_search := AttackSearchDeckToHandEffect.new(1, "Stadium")
	var stadium_card := CardInstance.create(_make_trainer_data("竞技场", "Stadium"), 0)
	player.deck.clear()
	player.deck.append(stadium_card)
	stadium_search.execute_attack(player.active_pokemon, defender, 0, state)
	var searched_stadium_in_hand := stadium_card in player.hand

	var coin_attack := AttackCoinFlipMultiplierEffect.new(20)
	defender.damage_counters = 20
	coin_attack.execute_attack(player.active_pokemon, defender, 0, state)

	var gold_attack := AttackDiscardBasicEnergyFromHandDamageEffect.new(50)
	player.hand.clear()
	var metal_a := CardInstance.create(_make_energy_data("基础钢能量甲", "M"), 0)
	var metal_b := CardInstance.create(_make_energy_data("基础钢能量乙", "M"), 0)
	player.hand.append_array([metal_a, metal_b])
	defender.damage_counters = 50
	gold_attack.execute_attack(player.active_pokemon, defender, 0, state)

	return run_checks([
		assert_true(searched_stadium_in_hand, "起源帕路奇亚V的检索招式应能将竞技场加入手牌"),
		assert_gte(defender.damage_counters, 0, "直到反面为止的投币招式不应造成负伤害"),
		assert_true(metal_a in player.discard_pile and metal_b in player.discard_pile, "赛富豪ex的招式应弃掉手牌中的基础能量"),
		assert_eq(defender.damage_counters, 100, "弃2张基础能量时应总计造成100伤害"),
	])


func test_attack_search_and_attach_can_filter_future_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()

	var active_cd := _make_basic_pokemon_data("未来前台", "L", 110)
	active_cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	player.active_pokemon.pokemon_stack.clear()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(active_cd, 0))

	var future_bench_cd := _make_basic_pokemon_data("未来备战", "P", 100)
	future_bench_cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	player.bench[0].pokemon_stack.clear()
	player.bench[0].pokemon_stack.append(CardInstance.create(future_bench_cd, 0))
	player.bench[1].pokemon_stack.clear()
	player.bench[1].pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("普通备战", "W", 100), 0))

	player.deck.append(CardInstance.create(_make_energy_data("基本雷能量", "L"), 0))
	player.deck.append(CardInstance.create(_make_energy_data("基本超能量", "P"), 0))

	var effect := AttackSearchAndAttach.new("", 2, "deck_search", 0, "any", CardData.FUTURE_TAG)
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_eq(player.bench[0].attached_energy.size(), 1, "未来备战宝可梦应获得1张能量"),
		assert_eq(player.active_pokemon.attached_energy.size(), 1, "未来前台宝可梦应获得1张能量"),
		assert_eq(player.bench[1].attached_energy.size(), 0, "非未来备战宝可梦不应被附着能量"),
	])


func test_collapsed_stadium_discards_excess_bench() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	for i: int in 4:
		var extra := PokemonSlot.new()
		extra.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("额外备战%d" % i, "C"), 0))
		player.bench.append(extra)

	var effect := EffectCollapsedStadium.new()
	effect.execute(CardInstance.create(_make_trainer_data("崩塌的竞技场", "Stadium"), 0), [], state)

	return run_checks([
		assert_eq(effect.get_bench_limit(), 4, "崩塌的竞技场上限应为4"),
		assert_eq(player.bench.size(), 4, "超出上限的备战宝可梦应被弃掉"),
		assert_eq(player.discard_pile.size(), 2, "应弃掉2张多余备战宝可梦"),
	])


func test_town_store_searches_tool() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("普通宝可梦", "C"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("沉重接力棒", "Tool"), 0))

	var effect := EffectTownStore.new()
	var card := CardInstance.create(_make_trainer_data("城镇百货", "Stadium"), 0)
	var can_execute: bool = effect.can_execute(card, state)
	effect.execute(card, [], state)

	return run_checks([
		assert_true(can_execute, "牌库中有道具时应可执行"),
		assert_eq(player.hand.back().card_data.card_type, "Tool", "应检索到宝可梦道具"),
		assert_eq(player.deck.size(), 1, "牌库应减少1张"),
	])


func test_therapeutic_energy_clears_status_on_attach() -> String:
	var state := _make_state()
	var slot := state.players[0].active_pokemon
	var energy := CardInstance.create(_make_energy_data("治疗能量", "C", "Special Energy", "2c65697c2aceac4e6a1f85f810fa386f"), 0)
	slot.attached_energy.append(energy)
	slot.status_conditions["asleep"] = true
	slot.status_conditions["paralyzed"] = true
	slot.status_conditions["confused"] = true

	var effect := EffectTherapeuticEnergy.new()
	effect.execute(energy, [], state)

	return run_checks([
		assert_false(slot.status_conditions["asleep"], "睡眠应被清除"),
		assert_false(slot.status_conditions["paralyzed"], "麻痹应被清除"),
		assert_false(slot.status_conditions["confused"], "混乱应被清除"),
		assert_true(EffectTherapeuticEnergy.has_therapeutic_energy(slot), "应识别到治疗能量"),
	])


func test_v_guard_energy_reduces_damage_from_v_attacker() -> String:
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("V攻击者", "L", 200, "Basic", "V"), 0))
	var effect := EffectVGuardEnergy.new()
	return run_checks([
		assert_eq(effect.get_defense_modifier(attacker), -30, "面对 V 攻击者应减伤30"),
	])


func test_gift_energy_trigger_draws_to_seven() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	while player.hand.size() > 4:
		player.hand.pop_back()
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("补抽牌%d" % i, "C"), 0))

	EffectGiftEnergy.trigger_on_knockout(player)

	return run_checks([
		assert_eq(player.hand.size(), 7, "馈赠能量应将手牌补到7张"),
	])


func test_ability_search_any_marks_once_per_turn_usage() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("检索牌%d" % i, "C"), 0))

	var effect := AbilitySearchAny.new(2, true, false)
	var slot := player.active_pokemon
	effect.execute_ability(slot, 0, [], state)

	return run_checks([
		assert_eq(player.hand.size(), 2, "应检索2张牌到手牌"),
		assert_false(effect.can_use_ability(slot, state), "同回合不应再次使用"),
		assert_true(slot.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == AbilitySearchAny.USED_KEY), "应记录本回合已使用标记"),
	])


func test_ability_search_any_requires_controller_turn() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("检索目标", "C"), 0))

	var effect := AbilitySearchAny.new(1, true, false)
	var slot := player.active_pokemon
	state.current_player_index = 1
	var can_use_on_opponent_turn := effect.can_use_ability(slot, state)
	var hand_before := player.hand.size()
	effect.execute_ability(slot, 0, [], state)

	return run_checks([
		assert_false(can_use_on_opponent_turn, "AbilitySearchAny should only be usable during its controller's turn"),
		assert_eq(player.hand.size(), hand_before, "AbilitySearchAny should not move cards when called on the opponent's turn"),
		assert_eq(player.deck.size(), 1, "AbilitySearchAny should leave the deck untouched on the opponent's turn"),
	])


func test_pidgeot_quick_search_is_shared_once_per_turn() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.bench.clear()
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("音速搜索目标%d" % i, "C"), 0))

	var pidgeot_cd := _make_basic_pokemon_data("Pidgeot ex", "C", 280, "Stage 2", "ex", "8105afde9792c2596166f318a480d041")
	pidgeot_cd.abilities = [{"name": "音速搜索"}]
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(pidgeot_cd, 0))
	active_slot.turn_played = 0
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(pidgeot_cd, 0))
	bench_slot.turn_played = 0
	player.active_pokemon = active_slot
	player.bench.append(bench_slot)

	var processor := EffectProcessor.new()
	EffectRegistry.register_pokemon_card(processor, pidgeot_cd)

	var can_use_first := processor.can_use_ability(active_slot, state, 0)
	var used_first := processor.execute_ability_effect(active_slot, 0, [], state)
	var can_reuse_same_turn := processor.can_use_ability(active_slot, state, 0)
	var other_copy_can_use_same_turn := processor.can_use_ability(bench_slot, state, 0)
	state.turn_number += 1
	var other_copy_can_use_next_turn := processor.can_use_ability(bench_slot, state, 0)

	return run_checks([
		assert_true(can_use_first, "CSV4C_101 Quick Search should be usable before any copy has been used this turn"),
		assert_true(used_first, "CSV4C_101 Quick Search should resolve through EffectProcessor"),
		assert_eq(player.hand.size(), 1, "CSV4C_101 Quick Search should add exactly 1 card to hand"),
		assert_false(can_reuse_same_turn, "CSV4C_101 Quick Search should not be reusable by the same Pidgeot ex this turn"),
		assert_false(other_copy_can_use_same_turn, "CSV4C_101 should block other Quick Search copies for the rest of the turn"),
		assert_true(active_slot.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == AbilitySearchAny.USED_KEY), "CSV4C_101 should still mark the used Pokemon for UI consumers"),
		assert_true(other_copy_can_use_next_turn, "CSV4C_101 Quick Search should become usable again on a later turn"),
	])


func test_attack_search_and_attach_to_bench() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_energy_data("雷能量A", "L"), 0))
	player.deck.append(CardInstance.create(_make_energy_data("雷能量B", "L"), 0))
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("杂项", "C"), 0))

	var effect := AttackSearchAndAttach.new("L", 2, "deck_search", 5, "bench")
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_eq(player.bench[0].attached_energy.size(), 1, "第一只备战宝可梦应附着1个能量"),
		assert_eq(player.bench[1].attached_energy.size(), 1, "第二只备战宝可梦应附着1个能量"),
		assert_eq(player.deck.size(), 1, "牌库应移除2张能量"),
	])


func test_attack_search_attach_to_v_targets_v_pokemon() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_energy_data("火能量A", "R"), 0))
	player.deck.append(CardInstance.create(_make_energy_data("火能量B", "R"), 0))
	player.bench[0].pokemon_stack.clear()
	player.bench[0].pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("阿尔宙斯V", "C", 220, "Basic", "V"), 0))

	var effect := AttackSearchAttachToV.new(2)
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_eq(player.bench[0].attached_energy.size(), 2, "应将2个基本能量附着到V宝可梦"),
	])


func test_attack_bench_snipe_and_self_damage() -> String:
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	var effect := AttackBenchSnipe.new(60, 2, 30)
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_eq(state.players[1].bench[0].damage_counters, 60, "第一只备战应受60伤害"),
		assert_eq(state.players[1].bench[1].damage_counters, 60, "第二只备战应受60伤害"),
		assert_eq(attacker.damage_counters, 30, "攻击者应自伤30"),
	])


func test_attack_top_deck_search_filters_tool() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("牌库底部", "C"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("沉重接力棒", "Tool"), 0))

	var effect := AttackTopDeckSearch.new(2, 1, "Tool")
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_eq(player.hand.size(), 1, "应从顶部检索1张道具到手牌"),
		assert_eq(player.hand[0].card_data.card_type, "Tool", "加入手牌的应为道具"),
		assert_eq(player.deck.size(), 1, "未选中的卡应放回牌库"),
	])


func test_attack_read_wind_draw_discards_then_draws() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()
	player.hand.append(CardInstance.create(_make_basic_pokemon_data("手牌甲", "C"), 0))
	player.hand.append(CardInstance.create(_make_basic_pokemon_data("手牌乙", "C"), 0))
	player.deck.clear()
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("抽牌%d" % i, "C"), 0))

	var effect := AttackReadWindDraw.new()
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_eq(player.hand.size(), 4, "弃1抽3后手牌应净增2"),
		assert_eq(player.discard_pile.size(), 1, "应弃置1张手牌"),
	])


func test_attack_read_wind_draw_generates_hand_selection_step() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	var hand_a := CardInstance.create(_make_basic_pokemon_data("Discard A", "C"), 0)
	var hand_b := CardInstance.create(_make_basic_pokemon_data("Discard B", "C"), 0)
	player.hand.append_array([hand_a, hand_b])

	var lugia_cd := _make_basic_pokemon_data("Lugia V", "C", 220, "Basic", "V", "d8e735158b27693de9d70f883d84f5a2")
	lugia_cd.attacks = [{"name": "读风", "cost": "C", "damage": "", "text": "", "is_vstar_power": false}]
	var effect := AttackReadWindDraw.new()
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), lugia_cd.attacks[0], state)
	var first_step: Dictionary = steps[0] if not steps.is_empty() else {}
	var items: Array = first_step.get("items", [])

	return run_checks([
		assert_eq(steps.size(), 1, "AttackReadWindDraw should expose one interaction step"),
		assert_eq(str(first_step.get("id", "")), "discard_card", "AttackReadWindDraw should ask the player to choose a hand card"),
		assert_eq(int(first_step.get("min_select", 0)), 1, "AttackReadWindDraw should require one discard selection"),
		assert_eq(int(first_step.get("max_select", 0)), 1, "AttackReadWindDraw should allow selecting exactly one hand card"),
		assert_true(hand_a in items and hand_b in items, "AttackReadWindDraw should offer the current hand as discard candidates"),
	])


func test_interaction_steps_generated_for_common_trainers() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	var hand_a := CardInstance.create(_make_basic_pokemon_data("手牌甲", "C"), 0)
	var hand_b := CardInstance.create(_make_basic_pokemon_data("手牌乙", "C"), 0)
	player.hand.append(hand_a)
	player.hand.append(hand_b)
	player.deck.clear()
	var basic := CardInstance.create(_make_basic_pokemon_data("基础宝可梦", "C", 60), 0)
	var pokemon := CardInstance.create(_make_basic_pokemon_data("任意宝可梦", "C", 90), 0)
	player.deck.append(basic)
	player.deck.append(pokemon)

	var ultra_steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(CardInstance.create(_make_trainer_data("高级球"), 0), state)
	var nest_steps: Array[Dictionary] = EffectNestBall.new().get_interaction_steps(CardInstance.create(_make_trainer_data("巢穴球"), 0), state)

	return run_checks([
		assert_eq(ultra_steps.size(), 2, "高级球应生成两步交互"),
		assert_eq(int(ultra_steps[0].get("max_select", 0)), 2, "高级球第一步应选择2张手牌"),
		assert_eq(nest_steps.size(), 1, "巢穴球应生成一步交互"),
		assert_eq(str(nest_steps[0].get("id", "")), "basic_pokemon", "巢穴球步骤 id 应正确"),
	])


func test_specialized_effect_descriptions_and_smoke() -> String:
	var effects: Array[BaseEffect] = [
		EffectCounterCatcher.new(),
		EffectNestBall.new(),
		EffectCancelCologne.new(),
		EffectLostVacuum.new(),
		EffectUltraBall.new(),
		EffectPalPad.new(),
		EffectSuperRod.new(),
		EffectRareCandy.new(),
		EffectBuddyPoffin.new(),
		EffectLookTopCards.new(),
		EffectCapturingAroma.new(),
		EffectPrimeCatcher.new(),
		EffectElectricGenerator.new(),
		EffectTechnoRadar.new(),
		EffectSwitchCart.new(),
		EffectArven.new(),
		EffectBossOrders.new(),
		EffectIono.new(),
		EffectCiphermaniac.new(),
		EffectProfTuro.new(),
		EffectSerena.new(),
		EffectIrida.new(),
		EffectJacq.new(),
		EffectToolConditionalDamage.new(),
		EffectToolFutureBoost.new(),
		EffectToolHeavyBaton.new(),
		EffectToolRescueBoard.new(),
		EffectCollapsedStadium.new(),
		EffectLostCity.new(),
		EffectTownStore.new(),
		EffectGiftEnergy.new(),
		EffectJetEnergy.new(),
		EffectMistEnergy.new(),
		EffectTherapeuticEnergy.new(),
		EffectVGuardEnergy.new(),
		AbilityAttachFromDeckEffect.new(),
		AbilityBenchImmune.new(),
		AbilityBenchProtect.new(),
		AbilityConditionalDefense.new(),
		AbilityDisableOpponentAbility.new(),
		AbilityDiscardDraw.new(),
		AbilityDrawToN.new(),
		AbilityEndTurnDraw.new(),
		AbilityFirstTurnDraw.new(),
		AbilityFutureDamageBoost.new(),
		AbilityGustFromBench.new(),
		AbilityIgnoreEffects.new(),
		AbilityLightningBoost.new(),
		AbilityMetalMaker.new(),
		AbilityOnBenchEnter.new(),
		AbilityPrizeCountColorlessReduction.new(),
		AbilitySearchAny.new(),
		AbilitySearchPokemonToBench.new(),
		AbilityShuffleHandDraw.new(),
		AbilityThunderousCharge.new(),
		AbilityVReduceDamage.new(),
		AbilityVSTARSearch.new(),
		AbilityVSTARSummon.new(),
		AttackBenchCountDamage.new(),
		AttackBenchDamageCounters.new(),
		AttackBenchSnipe.new(),
		AttackCallForFamily.new(),
		AttackCoinFlipOrFail.new(),
		AttackCopyAttack.new(),
		AttackDiscardEnergyFromSelf.new(),
		AttackDiscardEnergyMultiDamage.new(),
		AttackDiscardStadium.new(),
		AttackDrawTo7.new(),
		AttackEnergyCountDamage.new(),
		AttackExtraPrize.new(),
		AttackIgnoreDefenderEffects.new(),
		AttackLostZoneEnergy.new(),
		AttackLostZoneKO.new(),
		AttackOptionalDiscardStadium.new(),
		AttackPrizeDamageBonus.new(),
		AttackReadWindDraw.new(),
		AttackRetreatAfterAttack.new(),
		AttackReturnToDeck.new(),
		AttackRevengeBonus.new(),
		AttackScrapShort.new(),
		AttackSearchAndAttach.new(),
		AttackSearchAttachToV.new(),
		AttackSelfLockNextTurn.new(),
		AttackSelfSleep.new(),
		AttackSpecialEnergyMultiDamage.new(),
		AttackTopDeckSearch.new(),
		AttackVSTARExtraTurn.new(),
	]

	for effect: BaseEffect in effects:
		if effect == null:
			return "专用效果类实例化失败"
		if effect.get_description() == "":
			return "效果描述不应为空: %s" % effect.get_class()

	return ""


func test_prime_catcher_requires_own_bench_target() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var effect := EffectPrimeCatcher.new()
	var card := CardInstance.create(_make_trainer_data("顶尖捕捉器"), 0)

	player.bench.clear()
	var cannot_use_without_own_bench: bool = not effect.can_execute(card, state)

	var bench_cd := _make_basic_pokemon_data("Own Bench", "C", 100)
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
	player.bench.append(bench_slot)

	var can_use_with_both_benches: bool = effect.can_execute(card, state)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	return run_checks([
		assert_true(cannot_use_without_own_bench, "顶尖捕捉器在己方没有备战宝可梦时不应可用"),
		assert_true(can_use_with_both_benches, "顶尖捕捉器在双方都有备战宝可梦时应可用"),
		assert_eq(steps.size(), 2, "顶尖捕捉器应提供对手和己方两步选择"),
		assert_eq(int(steps[1].get("items", []).size()), player.bench.size(), "顶尖捕捉器第二步应只列出己方备战宝可梦"),
	])


func test_buddy_poffin_allows_zero_selection_without_fallback() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	player.deck.clear()

	var poffin_a := CardInstance.create(_make_basic_pokemon_data("Poffin A", "C", 60), 0)
	var poffin_b := CardInstance.create(_make_basic_pokemon_data("Poffin B", "W", 70), 0)
	player.deck.append_array([poffin_a, poffin_b])

	var effect := EffectBuddyPoffin.new()
	var card := CardInstance.create(_make_trainer_data("友好宝芬"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{
		"buddy_poffin_pokemon": [],
	}], state)

	return run_checks([
		assert_eq(int(steps[0].get("min_select", -1)), 0, "友好宝芬应允许选择0张基础宝可梦"),
		assert_true(player.bench.is_empty(), "显式选择0张时，友好宝芬不应自动放置宝可梦"),
		assert_true(poffin_a in player.deck and poffin_b in player.deck, "显式选择0张时，友好宝芬不应从牌库移除宝可梦"),
	])
