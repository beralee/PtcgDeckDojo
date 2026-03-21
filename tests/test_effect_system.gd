## 效果系统单元测试 - 覆盖所有通用效果脚本
class_name TestEffectSystem
extends TestBase


## ==================== 辅助方法 ====================

## 创建测试用 GameState，双方各有1只战斗宝可梦+2只备战+手牌+牌库
func _make_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 1
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi

		# 战斗宝可梦（HP=100，火属性）
		var active_cd := CardData.new()
		active_cd.name = "火恐龙P%d" % pi
		active_cd.card_type = "Pokemon"
		active_cd.stage = "Basic"
		active_cd.hp = 100
		active_cd.energy_type = "R"
		active_cd.effect_id = "active_%d" % pi
		active_cd.attacks = [{"name": "火焰冲击", "cost": "RR", "damage": "60", "text": "", "is_vstar_power": false}]
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(active_cd, pi))
		player.active_pokemon = active_slot

		# 附着2个火能量
		for _i: int in 2:
			var energy_cd := CardData.new()
			energy_cd.name = "火能量"
			energy_cd.card_type = "Basic Energy"
			energy_cd.energy_provides = "R"
			active_slot.attached_energy.append(CardInstance.create(energy_cd, pi))

		# 备战宝可梦 x2
		for bi: int in 2:
			var bench_cd := CardData.new()
			bench_cd.name = "备战P%d_%d" % [pi, bi]
			bench_cd.card_type = "Pokemon"
			bench_cd.stage = "Basic"
			bench_cd.hp = 60
			bench_cd.energy_type = "W"
			bench_cd.effect_id = "bench_%d_%d" % [pi, bi]
			var bench_slot := PokemonSlot.new()
			bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, pi))
			player.bench.append(bench_slot)

		# 手牌 x5
		for hi: int in 5:
			var hand_cd := CardData.new()
			hand_cd.name = "手牌P%d_%d" % [pi, hi]
			hand_cd.card_type = "Pokemon"
			hand_cd.stage = "Basic"
			hand_cd.hp = 50
			hand_cd.energy_type = "G"
			player.hand.append(CardInstance.create(hand_cd, pi))

		# 牌库 x20（混合卡牌类型，方便检索测试）
		for di: int in 20:
			var deck_cd := CardData.new()
			if di < 10:
				deck_cd.name = "牌库宝可梦P%d_%d" % [pi, di]
				deck_cd.card_type = "Pokemon"
				deck_cd.stage = "Basic"
				deck_cd.hp = 40
			else:
				deck_cd.name = "牌库训练家P%d_%d" % [pi, di]
				deck_cd.card_type = "Item"
			player.deck.append(CardInstance.create(deck_cd, pi))

		# 奖赏卡 x3
		for pri: int in 3:
			var prize_cd := CardData.new()
			prize_cd.name = "奖赏P%d_%d" % [pi, pri]
			prize_cd.card_type = "Pokemon"
			prize_cd.stage = "Basic"
			prize_cd.hp = 30
			player.prizes.append(CardInstance.create(prize_cd, pi))

		state.players.append(player)
	return state


## 创建训练家卡实例
func _make_trainer(owner: int, eid: String) -> CardInstance:
	var cd := CardData.new()
	cd.name = "测试训练家"
	cd.card_type = "Item"
	cd.effect_id = eid
	return CardInstance.create(cd, owner)


## ==================== 训练家效果测试 ====================

## 测试 EffectDrawCards：抽3张牌
func test_draw_cards_basic() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var init_hand: int = player.hand.size()
	var init_deck: int = player.deck.size()
	var effect := EffectDrawCards.new(3)
	var card := _make_trainer(0, "draw_3")
	effect.execute(card, [], state)
	return run_checks([
		assert_eq(player.hand.size(), init_hand + 3, "手牌应增加3张"),
		assert_eq(player.deck.size(), init_deck - 3, "牌库应减少3张"),
	])


## 测试 EffectDrawCards：弃手牌后抽7张（博士的研究）
func test_draw_cards_discard_hand_first() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var init_hand: int = player.hand.size()
	var init_discard: int = player.discard_pile.size()
	var effect := EffectDrawCards.new(7, true)
	var card := _make_trainer(0, "professor")
	effect.execute(card, [], state)
	return run_checks([
		assert_eq(player.discard_pile.size(), init_discard + init_hand, "弃牌区应增加原手牌数量"),
		assert_eq(player.hand.size(), 7, "手牌应为7张"),
	])


## 测试 EffectShuffleDrawCards：洗手抽同等数量
func test_shuffle_draw_same_count() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var init_hand: int = player.hand.size()
	var effect := EffectShuffleDrawCards.new(-1, false, false)
	var card := _make_trainer(0, "shuffle_draw")
	effect.execute(card, [], state)
	return run_checks([
		assert_eq(player.hand.size(), init_hand, "手牌数量应不变"),
	])


## 测试 EffectShuffleDrawCards：按奖赏卡数量抽牌（Iono）
func test_shuffle_draw_by_prizes() -> String:
	var state := _make_state()
	var player0: PlayerState = state.players[0]
	var player1: PlayerState = state.players[1]
	var p0_prizes: int = player0.prizes.size()
	var p1_prizes: int = player1.prizes.size()
	var effect := EffectShuffleDrawCards.new(-1, true, true)
	var card := _make_trainer(0, "iono")
	effect.execute(card, [], state)
	return run_checks([
		assert_eq(player0.hand.size(), p0_prizes, "玩家0手牌应等于奖赏卡数"),
		assert_eq(player1.hand.size(), p1_prizes, "玩家1手牌应等于奖赏卡数"),
	])


## 测试 EffectSearchDeck：无过滤检索1张
func test_search_deck_no_filter() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var init_hand: int = player.hand.size()
	var init_deck: int = player.deck.size()
	var effect := EffectSearchDeck.new(1, 0, "")
	var card := _make_trainer(0, "search_1")
	effect.execute(card, [], state)
	return run_checks([
		assert_eq(player.hand.size(), init_hand + 1, "手牌应增加1张"),
		assert_eq(player.deck.size(), init_deck - 1, "牌库应减少1张"),
	])


## 测试 EffectSearchDeck：只检索基础宝可梦
func test_search_deck_basic_filter() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var init_hand: int = player.hand.size()
	var effect := EffectSearchDeck.new(1, 0, "Basic")
	var card := _make_trainer(0, "nest_ball")
	effect.execute(card, [], state)
	# 牌库前10张是宝可梦，第1张应被找到
	var last_card: CardInstance = player.hand.back()
	return run_checks([
		assert_eq(player.hand.size(), init_hand + 1, "手牌应增加1张"),
		assert_true(last_card.card_data.is_basic_pokemon(), "检索到的应是基础宝可梦"),
	])


## 测试 EffectSearchDeck：弃牌代价
func test_search_deck_with_discard_cost() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var init_hand: int = player.hand.size()
	var init_discard: int = player.discard_pile.size()
	var effect := EffectSearchDeck.new(1, 2, "")
	var card := _make_trainer(0, "ultra_ball")
	effect.execute(card, [], state)
	return run_checks([
		# 弃2张 + 检索1张 = 手牌净减少1张
		assert_eq(player.hand.size(), init_hand - 2 + 1, "手牌=原手牌-弃2+检索1"),
		assert_eq(player.discard_pile.size(), init_discard + 2, "弃牌区应增加2张"),
	])


## 测试 EffectSearchDeck：can_execute 检查手牌不足
func test_search_deck_cannot_execute_insufficient_hand() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	# 清空手牌，只留1张
	while player.hand.size() > 1:
		player.hand.pop_back()
	var effect := EffectSearchDeck.new(1, 2, "")
	var card := _make_trainer(0, "ultra_ball")
	return run_checks([
		assert_false(effect.can_execute(card, state), "手牌不足时不应可执行"),
	])


## 测试 EffectSwitchPokemon：替换己方
func test_switch_self() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var old_active_name: String = player.active_pokemon.get_pokemon_name()
	var chosen_bench: PokemonSlot = player.bench[1]
	var bench_name: String = chosen_bench.get_pokemon_name()
	var effect := EffectSwitchPokemon.new("self")
	var card := _make_trainer(0, "switch")
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{"self_switch_target": [chosen_bench]}], state)
	return run_checks([
		assert_eq(steps.size(), 1, "宝可梦交替应生成1步己方选择"),
		assert_eq(player.active_pokemon.get_pokemon_name(), bench_name, "新战斗宝可梦应为玩家选择的备战宝可梦"),
		assert_true(player.bench.any(func(s: PokemonSlot) -> bool: return s.get_pokemon_name() == old_active_name), "原战斗宝可梦应在备战区"),
	])


## 测试 EffectSwitchPokemon：替换对方
func test_switch_opponent() -> String:
	var state := _make_state()
	var opp: PlayerState = state.players[1]
	var old_active_name: String = opp.active_pokemon.get_pokemon_name()
	var chosen_bench: PokemonSlot = opp.bench[1]
	var bench_name: String = chosen_bench.get_pokemon_name()
	var effect := EffectSwitchPokemon.new("opponent")
	var card := _make_trainer(0, "boss")
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	effect.execute(card, [{"opponent_switch_target": [chosen_bench]}], state)
	return run_checks([
		assert_eq(steps.size(), 1, "替换对手时应生成1步目标选择"),
		assert_eq(opp.active_pokemon.get_pokemon_name(), bench_name, "对方战斗宝可梦应被替换为玩家选择的目标"),
		assert_true(opp.bench.any(func(s: PokemonSlot) -> bool: return s.get_pokemon_name() == old_active_name), "原战斗宝可梦应在备战区"),
	])


## 测试 EffectSwitchPokemon：can_execute 无备战宝可梦
func test_switch_cannot_execute_no_bench() -> String:
	var state := _make_state()
	state.players[0].bench.clear()
	var effect := EffectSwitchPokemon.new("self")
	var card := _make_trainer(0, "switch")
	return run_checks([
		assert_false(effect.can_execute(card, state), "无备战宝可梦时不应可执行"),
	])


## 测试 EffectHeal：治疗30点伤害
func test_heal_partial() -> String:
	var state := _make_state()
	var slot: PokemonSlot = state.players[0].active_pokemon
	slot.damage_counters = 50
	var effect := EffectHeal.new(30, false, 0)
	var card := _make_trainer(0, "potion")
	effect.execute(card, [], state)
	return run_checks([
		assert_eq(slot.damage_counters, 20, "伤害应从50减到20"),
	])


## 测试 EffectHeal：治疗不会低于0
func test_heal_no_negative() -> String:
	var state := _make_state()
	var slot: PokemonSlot = state.players[0].active_pokemon
	slot.damage_counters = 10
	var effect := EffectHeal.new(30, false, 0)
	var card := _make_trainer(0, "potion")
	effect.execute(card, [], state)
	return run_checks([
		assert_eq(slot.damage_counters, 0, "伤害不应低于0"),
	])


## 测试 EffectHeal：全部治疗并弃能量
func test_heal_all_with_energy_cost() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var slot: PokemonSlot = player.active_pokemon
	slot.damage_counters = 80
	var init_energy: int = slot.attached_energy.size()
	var init_discard: int = player.discard_pile.size()
	var effect := EffectHeal.new(0, true, 1)
	var card := _make_trainer(0, "super_potion")
	effect.execute(card, [], state)
	return run_checks([
		assert_eq(slot.damage_counters, 0, "伤害应完全治愈"),
		assert_eq(slot.attached_energy.size(), init_energy - 1, "应弃置1个能量"),
		assert_eq(player.discard_pile.size(), init_discard + 1, "弃牌区应增加1张能量"),
	])


## ==================== 招式附加效果测试 ====================

## 测试 EffectDiscardEnergy：弃置1个指定类型能量
func test_discard_energy_specific_type() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var slot: PokemonSlot = player.active_pokemon
	var init_energy: int = slot.attached_energy.size()
	var init_discard: int = player.discard_pile.size()
	var effect := EffectDiscardEnergy.new(1, "R")
	effect.execute_attack(slot, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_eq(slot.attached_energy.size(), init_energy - 1, "应弃置1个能量"),
		assert_eq(player.discard_pile.size(), init_discard + 1, "弃牌区应增加1"),
	])


## 测试 EffectDiscardEnergy：弃置全部能量
func test_discard_energy_all() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var slot: PokemonSlot = player.active_pokemon
	var init_discard: int = player.discard_pile.size()
	var effect := EffectDiscardEnergy.new(-1)
	effect.execute_attack(slot, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_eq(slot.attached_energy.size(), 0, "能量应全部弃置"),
		assert_eq(player.discard_pile.size(), init_discard + 2, "弃牌区应增加2"),
	])


## 测试 EffectApplyStatus：施加中毒
func test_apply_status_poison() -> String:
	var state := _make_state()
	var attacker: PokemonSlot = state.players[0].active_pokemon
	var defender: PokemonSlot = state.players[1].active_pokemon
	assert_false(defender.status_conditions.get("poisoned", false))
	var effect := EffectApplyStatus.new("poisoned", false)
	effect.execute_attack(attacker, defender, 0, state)
	return run_checks([
		assert_true(defender.status_conditions.get("poisoned", false), "对方应被中毒"),
	])


## 测试 EffectApplyStatus：施加麻痹（互斥测试）
func test_apply_status_paralyze_replaces_sleep() -> String:
	var state := _make_state()
	var defender: PokemonSlot = state.players[1].active_pokemon
	defender.set_status("asleep", true)
	var effect := EffectApplyStatus.new("paralyzed", false)
	effect.execute_attack(state.players[0].active_pokemon, defender, 0, state)
	return run_checks([
		assert_true(defender.status_conditions.get("paralyzed", false), "对方应被麻痹"),
		assert_false(defender.status_conditions.get("asleep", false), "睡眠应被清除（互斥）"),
	])


## 测试 EffectSelfDamage：自伤30
func test_self_damage() -> String:
	var state := _make_state()
	var attacker: PokemonSlot = state.players[0].active_pokemon
	var init_damage: int = attacker.damage_counters
	var effect := EffectSelfDamage.new(30)
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_eq(attacker.damage_counters, init_damage + 30, "攻击者应受到30自伤"),
	])


## 测试 EffectBenchDamage：对方全部备战宝可梦各受10
func test_bench_damage_all_opponent() -> String:
	var state := _make_state()
	var attacker: PokemonSlot = state.players[0].active_pokemon
	var opp: PlayerState = state.players[1]
	var effect := EffectBenchDamage.new(10, true, "opponent")
	effect.execute_attack(attacker, opp.active_pokemon, 0, state)
	var all_damaged: bool = true
	for slot: PokemonSlot in opp.bench:
		if slot.damage_counters != 10:
			all_damaged = false
	return run_checks([
		assert_true(all_damaged, "对方全部备战宝可梦应各受10伤害"),
	])


## 测试 EffectBenchDamage：对方第1只备战受20
func test_bench_damage_single_opponent() -> String:
	var state := _make_state()
	var attacker: PokemonSlot = state.players[0].active_pokemon
	var opp: PlayerState = state.players[1]
	var effect := EffectBenchDamage.new(20, false, "opponent")
	effect.execute_attack(attacker, opp.active_pokemon, 0, state)
	return run_checks([
		assert_eq(opp.bench[0].damage_counters, 20, "第1只备战宝可梦应受20伤害"),
		assert_eq(opp.bench[1].damage_counters, 0, "第2只备战宝可梦应无伤害"),
	])


## ==================== 特性效果测试 ====================

## 测试 AbilityDrawCard：特性抽2张
func test_ability_draw_card() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var slot: PokemonSlot = player.active_pokemon
	var init_hand: int = player.hand.size()
	var init_deck: int = player.deck.size()
	var effect := AbilityDrawCard.new(2)
	effect.execute_ability(slot, 0, [], state)
	return run_checks([
		assert_eq(player.hand.size(), init_hand + 2, "手牌应增加2张"),
		assert_eq(player.deck.size(), init_deck - 2, "牌库应减少2张"),
	])


## 测试 AbilityDamageModifier：攻击修正
func test_ability_damage_modifier_attack() -> String:
	var mod := AbilityDamageModifier.new(20, "attack", true)
	return run_checks([
		assert_true(mod.is_attack_modifier(), "应为攻击修正"),
		assert_false(mod.is_defense_modifier(), "不应为防守修正"),
		assert_eq(mod.get_modifier(), 20, "修正量应为20"),
	])


## 测试 AbilityDamageModifier：防守修正
func test_ability_damage_modifier_defense() -> String:
	var mod := AbilityDamageModifier.new(-30, "defense", true)
	return run_checks([
		assert_false(mod.is_attack_modifier(), "不应为攻击修正"),
		assert_true(mod.is_defense_modifier(), "应为防守修正"),
		assert_eq(mod.get_modifier(), -30, "修正量应为-30"),
	])


## ==================== EffectProcessor 测试 ====================

## 测试注册和执行训练家效果
func test_processor_register_and_execute() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var init_hand: int = player.hand.size()
	proc.register_effect("draw_2", EffectDrawCards.new(2))
	var card := _make_trainer(0, "draw_2")
	var result: bool = proc.execute_card_effect(card, [], state)
	return run_checks([
		assert_true(result, "执行应成功"),
		assert_eq(player.hand.size(), init_hand + 2, "手牌应增加2"),
	])


## 测试未注册效果返回 true（静默成功）
func test_processor_unregistered_effect_returns_true() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var card := _make_trainer(0, "nonexistent")
	var result: bool = proc.execute_card_effect(card, [], state)
	return run_checks([
		assert_true(result, "未注册效果应返回true"),
	])


## 测试 can_execute 返回 false 时不执行
func test_processor_can_execute_check() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	# 清空手牌，让 SearchDeck(discard_cost=3) 无法执行
	player.hand.clear()
	proc.register_effect("need_3", EffectSearchDeck.new(1, 3, ""))
	var card := _make_trainer(0, "need_3")
	var result: bool = proc.execute_card_effect(card, [], state)
	return run_checks([
		assert_false(result, "手牌不足时应返回false"),
	])


## 测试批量注册
func test_processor_batch_register() -> String:
	var proc := EffectProcessor.new()
	var base_count: int = proc.get_registered_count()
	proc.register_effects({
		"draw_1": EffectDrawCards.new(1),
		"draw_5": EffectDrawCards.new(5),
		"switch": EffectSwitchPokemon.new("self"),
	})
	return run_checks([
		assert_true(proc.has_effect("draw_1"), "应已注册 draw_1"),
		assert_true(proc.has_effect("draw_5"), "应已注册 draw_5"),
		assert_true(proc.has_effect("switch"), "应已注册 switch"),
		assert_eq(proc.get_registered_count(), base_count + 3, "注册数应在原有基础上增加3"),
	])


## 测试招式附加效果注册和执行
func test_processor_attack_effect() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var attacker: PokemonSlot = state.players[0].active_pokemon
	var defender: PokemonSlot = state.players[1].active_pokemon
	# 修改 attacker 的 effect_id 以匹配注册
	attacker.get_top_card().card_data.effect_id = "fire_attack"
	proc.register_attack_effect("fire_attack", EffectDiscardEnergy.new(1, "R"))
	proc.register_attack_effect("fire_attack", EffectApplyStatus.new("burned", false))
	var init_energy: int = attacker.attached_energy.size()
	proc.execute_attack_effect(attacker, 0, defender, state)
	return run_checks([
		assert_eq(attacker.attached_energy.size(), init_energy - 1, "应弃置1个能量"),
		assert_true(defender.status_conditions.get("burned", false), "对方应被灼伤"),
	])


## 测试伤害修正查询
func test_processor_damage_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var attacker: PokemonSlot = state.players[0].active_pokemon
	var defender: PokemonSlot = state.players[1].active_pokemon
	# 给攻击者注册 +20 攻击修正
	attacker.get_top_card().card_data.effect_id = "atk_boost"
	proc.register_effect("atk_boost", AbilityDamageModifier.new(20, "attack", true))
	var atk_mod: int = proc.get_attacker_modifier(attacker, state)
	var def_mod: int = proc.get_defender_modifier(defender, state)
	return run_checks([
		assert_eq(atk_mod, 20, "攻击修正应为20"),
		assert_eq(def_mod, 0, "防守修正应为0（无防守特性）"),
	])


## ==================== 描述文本测试 ====================

## 测试所有效果的 get_description 不为空
func test_all_descriptions_non_empty() -> String:
	var effects: Array[BaseEffect] = [
		EffectDrawCards.new(3),
		EffectDrawCards.new(7, true),
		EffectShuffleDrawCards.new(-1, false, false),
		EffectShuffleDrawCards.new(-1, true, true),
		EffectSearchDeck.new(1, 2, "Basic"),
		EffectSwitchPokemon.new("self"),
		EffectSwitchPokemon.new("opponent"),
		EffectSwitchPokemon.new("both"),
		EffectHeal.new(30),
		EffectHeal.new(0, true),
		EffectDiscardEnergy.new(1, "R"),
		EffectDiscardEnergy.new(-1),
		EffectApplyStatus.new("poisoned"),
		EffectApplyStatus.new("paralyzed", true),
		EffectCoinFlipDamage.new(30, 1),
		EffectCoinFlipDamage.new(30, 3),
		EffectCoinFlipDamage.new(30, 0, true),
		EffectSelfDamage.new(30),
		EffectBenchDamage.new(20, true),
		EffectBenchDamage.new(10, false),
		AbilityDrawCard.new(1),
		AbilityDamageModifier.new(20, "attack"),
		AbilityDamageModifier.new(-30, "defense"),
	]
	for effect: BaseEffect in effects:
		var desc: String = effect.get_description()
		if desc == "":
			return "效果 %s 的 description 不应为空" % effect.get_class()
	return ""
