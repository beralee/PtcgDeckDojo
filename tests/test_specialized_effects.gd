## 具体卡牌效果测试 - 覆盖专用效果类与烟雾测试
class_name TestSpecializedEffects
extends TestBase

const EffectRecoverBasicEnergyEffect = preload("res://scripts/effects/trainer_effects/EffectRecoverBasicEnergy.gd")
const EffectSearchBasicEnergyEffect = preload("res://scripts/effects/trainer_effects/EffectSearchBasicEnergy.gd")
const EffectHisuianHeavyBallEffect = preload("res://scripts/effects/trainer_effects/EffectHisuianHeavyBall.gd")
const AbilityStarPortalEffect = preload("res://scripts/effects/pokemon_effects/AbilityStarPortal.gd")
const AbilityAttachFromDeckEffect = preload("res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd")
const AttackSearchDeckToHandEffect = preload("res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd")
const AttackCoinFlipMultiplierEffect = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipMultiplier.gd")
const AttackDiscardBasicEnergyFromHandDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackDiscardBasicEnergyFromHandDamage.gd")


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
		"selected_energy": [energy_a, energy_b],
		"attach_target": [lightning_bench],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 2, "电气发生器应生成揭示能量和附着目标两步交互"),
		assert_eq(lightning_bench.attached_energy.size(), 2, "应从牌库顶5张附着2张基本雷能量"),
		assert_eq(player.deck.size(), 4, "牌库应减少2张能量"),
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
	var ability := AbilityGustFromBench.new()

	# 验证在战斗位不能发动
	var gust_on_active := PokemonSlot.new()
	gust_on_active.pokemon_stack.append(CardInstance.create(gust_cd, 0))
	player.active_pokemon = gust_on_active
	var cannot_use_from_active: bool = not ability.can_use_ability(gust_on_active, state)

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


func test_techno_radar_uses_two_discards_and_only_future_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var radar_card := CardInstance.create(_make_trainer_data("高科技雷达"), 0)
	var discard_a := CardInstance.create(_make_basic_pokemon_data("弃牌甲", "C"), 0)
	var discard_b := CardInstance.create(_make_basic_pokemon_data("弃牌乙", "C"), 0)
	var keep_card := CardInstance.create(_make_basic_pokemon_data("保留牌", "C"), 0)
	player.hand.append_array([radar_card, discard_a, discard_b, keep_card])

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
		"discard_cards": [discard_a, discard_b],
		"search_future_pokemon": [future_b, future_a],
	}], state)

	return run_checks([
		assert_true(can_execute, "手牌有其他2张且牌库里有未来宝可梦时应可使用高科技雷达"),
		assert_eq(steps.size(), 2, "高科技雷达应生成弃牌和检索两步交互"),
		assert_true(discard_a in player.discard_pile, "应弃掉第一张选中的手牌"),
		assert_true(discard_b in player.discard_pile, "应弃掉第二张选中的手牌"),
		assert_true(future_a in player.hand and future_b in player.hand, "应加入选中的未来宝可梦"),
		assert_false(normal in player.hand, "不应加入非未来宝可梦"),
		assert_true(keep_card in player.hand, "未选中的手牌应保留"),
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


func test_hisuian_heavy_ball_takes_basic_from_prizes() -> String:
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
	ability.execute_ability(palkia, 0, [{
		"star_portal_assignments": [
			{"source": water_a, "target": player.active_pokemon},
			{"source": water_b, "target": player.bench[0]},
			{"source": water_c, "target": player.bench[0]},
		],
	}], state)

	return run_checks([
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
		AbilityReduceAttackCost.new(),
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
