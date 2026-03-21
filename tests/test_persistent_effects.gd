## 持续效果系统测试 - 覆盖竞技场/道具/特殊能量的持续效果
class_name TestPersistentEffects
extends TestBase


## ==================== 辅助方法 ====================

## 创建基础 GameState
func _make_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 2
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi

		# 战斗宝可梦（HP=100，基础）
		var active_cd := CardData.new()
		active_cd.name = "测试宝可梦P%d" % pi
		active_cd.card_type = "Pokemon"
		active_cd.stage = "Basic"
		active_cd.hp = 100
		active_cd.energy_type = "R"
		active_cd.retreat_cost = 2
		active_cd.effect_id = ""
		active_cd.attacks = [{"name": "撞击", "cost": "RC", "damage": "30", "text": "", "is_vstar_power": false}]
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(active_cd, pi))
		player.active_pokemon = active_slot

		# 备战宝可梦 x1
		var bench_cd := CardData.new()
		bench_cd.name = "备战P%d" % pi
		bench_cd.card_type = "Pokemon"
		bench_cd.stage = "Basic"
		bench_cd.hp = 60
		bench_cd.energy_type = "W"
		bench_cd.retreat_cost = 1
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, pi))
		player.bench.append(bench_slot)

		# 手牌 x3
		for hi: int in 3:
			var hand_cd := CardData.new()
			hand_cd.name = "手牌P%d_%d" % [pi, hi]
			hand_cd.card_type = "Item"
			player.hand.append(CardInstance.create(hand_cd, pi))

		# 牌库 x10
		for di: int in 10:
			var deck_cd := CardData.new()
			deck_cd.name = "牌库P%d_%d" % [pi, di]
			deck_cd.card_type = "Pokemon"
			deck_cd.stage = "Basic"
			deck_cd.hp = 40
			player.deck.append(CardInstance.create(deck_cd, pi))

		# 奖赏卡 x3
		for pri: int in 3:
			var prize_cd := CardData.new()
			prize_cd.name = "奖赏P%d_%d" % [pi, pri]
			prize_cd.card_type = "Pokemon"
			prize_cd.stage = "Basic"
			player.prizes.append(CardInstance.create(prize_cd, pi))

		state.players.append(player)
	return state


## 创建特殊能量并附着
func _attach_special_energy(slot: PokemonSlot, pi: int, eid: String, provides: String = "C") -> CardInstance:
	var cd := CardData.new()
	cd.name = "特殊能量"
	cd.card_type = "Special Energy"
	cd.energy_provides = provides
	cd.effect_id = eid
	var inst := CardInstance.create(cd, pi)
	slot.attached_energy.append(inst)
	return inst


## 创建道具并附着
func _attach_tool(slot: PokemonSlot, pi: int, eid: String) -> CardInstance:
	var cd := CardData.new()
	cd.name = "测试道具"
	cd.card_type = "Tool"
	cd.effect_id = eid
	var inst := CardInstance.create(cd, pi)
	slot.attached_tool = inst
	return inst


## 放置竞技场卡
func _place_stadium(state: GameState, pi: int, eid: String) -> CardInstance:
	var cd := CardData.new()
	cd.name = "测试竞技场"
	cd.card_type = "Stadium"
	cd.effect_id = eid
	var inst := CardInstance.create(cd, pi)
	state.stadium_card = inst
	state.stadium_owner_index = pi
	return inst


## ==================== 道具效果测试 ====================

## 测试道具攻击伤害修正
func test_tool_attack_damage_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("power_band", EffectToolDamageModifier.new(30, "attack", ""))
	_attach_tool(state.players[0].active_pokemon, 0, "power_band")
	var atk_mod: int = proc.get_attacker_modifier(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(atk_mod, 30, "攻击伤害应+30"),
	])


## 测试道具防御伤害修正
func test_tool_defense_damage_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("protect_pad", EffectToolDamageModifier.new(-20, "defense", ""))
	_attach_tool(state.players[1].active_pokemon, 1, "protect_pad")
	var def_mod: int = proc.get_defender_modifier(state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(def_mod, -20, "受到伤害应-20"),
	])


## 测试道具撤退费用修正
func test_tool_retreat_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("balloon", EffectToolRetreatModifier.new(-2))
	_attach_tool(state.players[0].active_pokemon, 0, "balloon")
	var cost: int = proc.get_effective_retreat_cost(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(cost, 0, "原撤退费用2-2=0"),
	])


## 测试道具撤退费用不低于0
func test_tool_retreat_modifier_min_zero() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("balloon", EffectToolRetreatModifier.new(-3))
	_attach_tool(state.players[0].active_pokemon, 0, "balloon")
	var cost: int = proc.get_effective_retreat_cost(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(cost, 0, "撤退费用不应低于0"),
	])


## 测试道具HP修正
func test_tool_hp_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("vest", EffectToolHPModifier.new(50, false))
	_attach_tool(state.players[0].active_pokemon, 0, "vest")
	var max_hp: int = proc.get_effective_max_hp(state.players[0].active_pokemon)
	var remaining: int = proc.get_effective_remaining_hp(state.players[0].active_pokemon)
	return run_checks([
		assert_eq(max_hp, 150, "有效最大HP应为100+50=150"),
		assert_eq(remaining, 150, "有效剩余HP应为150"),
	])


## 测试道具HP修正下的昏厥判定
func test_tool_hp_knockout_check() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("vest", EffectToolHPModifier.new(50, false))
	var slot: PokemonSlot = state.players[0].active_pokemon
	_attach_tool(slot, 0, "vest")
	slot.damage_counters = 120
	return run_checks([
		assert_true(slot.is_knocked_out(), "原始判定应昏厥（120>=100）"),
		assert_false(proc.is_effectively_knocked_out(slot), "有效判定不应昏厥（120<150）"),
	])


## 测试道具禁用特性
func test_tool_disable_ability() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("vest_disable", EffectToolHPModifier.new(50, true))
	var slot: PokemonSlot = state.players[0].active_pokemon
	_attach_tool(slot, 0, "vest_disable")
	return run_checks([
		assert_true(proc.is_ability_disabled(slot), "特性应被禁用"),
	])


## 测试无道具时特性不被禁用
func test_no_tool_ability_not_disabled() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var slot: PokemonSlot = state.players[0].active_pokemon
	return run_checks([
		assert_false(proc.is_ability_disabled(slot), "无道具时特性不应被禁用"),
	])


## ==================== 竞技场效果测试 ====================

## 测试竞技场攻击伤害修正
func test_stadium_attack_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("atk_stadium", EffectStadiumDamageModifier.new(10, "attack", "", false))
	_place_stadium(state, 0, "atk_stadium")
	var atk_mod: int = proc.get_attacker_modifier(state.players[0].active_pokemon, state)
	var opp_mod: int = proc.get_attacker_modifier(state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(atk_mod, 10, "己方攻击应+10"),
		assert_eq(opp_mod, 10, "对方攻击也应+10（非仅持有者）"),
	])


## 测试竞技场仅持有者生效
func test_stadium_owner_only() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("owner_stadium", EffectStadiumDamageModifier.new(20, "attack", "", true))
	_place_stadium(state, 0, "owner_stadium")
	var atk_mod: int = proc.get_attacker_modifier(state.players[0].active_pokemon, state)
	var opp_mod: int = proc.get_attacker_modifier(state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(atk_mod, 20, "持有者攻击应+20"),
		assert_eq(opp_mod, 0, "非持有者攻击不应受影响"),
	])


## 测试竞技场宝可梦过滤
func test_stadium_pokemon_filter() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("basic_stadium", EffectStadiumDamageModifier.new(-10, "defense", "Basic", false))
	_place_stadium(state, 0, "basic_stadium")
	# 战斗宝可梦是 Basic
	var def_mod: int = proc.get_defender_modifier(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(def_mod, -10, "基础宝可梦受到伤害应-10"),
	])


## 测试竞技场撤退费用修正
func test_stadium_retreat_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("retreat_stadium", EffectStadiumRetreatModifier.new(-1, ""))
	_place_stadium(state, 0, "retreat_stadium")
	var cost: int = proc.get_effective_retreat_cost(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(cost, 1, "原撤退费用2-1=1"),
	])


## 测试无竞技场时无修正
func test_no_stadium_no_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var atk_mod: int = proc.get_attacker_modifier(state.players[0].active_pokemon, state)
	var retreat: int = proc.get_effective_retreat_cost(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(atk_mod, 0, "无竞技场时攻击修正应为0"),
		assert_eq(retreat, 2, "无竞技场时撤退费用应为原值2"),
	])


## ==================== 特殊能量效果测试 ====================

## 测试双倍无色能量提供量
func test_double_colorless_energy_count() -> String:
	var proc := EffectProcessor.new()
	proc.register_effect("dce", EffectDoubleColorless.new(2))
	var cd := CardData.new()
	cd.name = "双倍无色能量"
	cd.card_type = "Special Energy"
	cd.energy_provides = "C"
	cd.effect_id = "dce"
	var inst := CardInstance.create(cd, 0)
	var count: int = proc.get_energy_colorless_count(inst)
	return run_checks([
		assert_eq(count, 2, "应提供2个无色能量"),
	])


## 测试特殊能量攻击伤害修正
func test_special_energy_damage_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("jet_energy", EffectSpecialEnergyModifier.new(10, 0, "C", 1))
	_attach_special_energy(state.players[0].active_pokemon, 0, "jet_energy")
	var atk_mod: int = proc.get_attacker_modifier(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(atk_mod, 10, "特殊能量应提供+10攻击修正"),
	])


## 测试特殊能量撤退修正
func test_special_energy_retreat_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("float_energy", EffectSpecialEnergyModifier.new(0, -1, "C", 1))
	_attach_special_energy(state.players[0].active_pokemon, 0, "float_energy")
	var cost: int = proc.get_effective_retreat_cost(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(cost, 1, "原撤退费用2-1=1"),
	])


## 测试特殊能量类型查询
func test_special_energy_type_query() -> String:
	var proc := EffectProcessor.new()
	proc.register_effect("fire_special", EffectSpecialEnergyModifier.new(0, 0, "R", 1))
	var cd := CardData.new()
	cd.name = "特殊火能量"
	cd.card_type = "Special Energy"
	cd.energy_provides = ""
	cd.effect_id = "fire_special"
	var inst := CardInstance.create(cd, 0)
	var energy_type: String = proc.get_energy_type(inst)
	return run_checks([
		assert_eq(energy_type, "R", "应返回火能量类型"),
	])


## 测试特殊能量附着时效果
func test_special_energy_on_attach() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	proc.register_effect("heal_energy", EffectSpecialEnergyOnAttach.new(30, 0))
	var slot: PokemonSlot = state.players[0].active_pokemon
	slot.damage_counters = 50
	var card := CardInstance.create(CardData.new(), 0)
	card.card_data.effect_id = "heal_energy"
	card.owner_index = 0
	proc.execute_card_effect(card, [], state)
	return run_checks([
		assert_eq(slot.damage_counters, 20, "伤害应从50减到20"),
	])


## ==================== 综合修正叠加测试 ====================

## 测试道具+竞技场+特殊能量攻击修正叠加
func test_combined_attack_modifiers() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	# 道具 +30
	proc.register_effect("tool_atk", EffectToolDamageModifier.new(30, "attack", ""))
	_attach_tool(state.players[0].active_pokemon, 0, "tool_atk")
	# 竞技场 +10
	proc.register_effect("stadium_atk", EffectStadiumDamageModifier.new(10, "attack", "", false))
	_place_stadium(state, 0, "stadium_atk")
	# 特殊能量 +10
	proc.register_effect("energy_atk", EffectSpecialEnergyModifier.new(10, 0, "C", 1))
	_attach_special_energy(state.players[0].active_pokemon, 0, "energy_atk")
	var total: int = proc.get_attacker_modifier(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(total, 50, "总攻击修正应为30+10+10=50"),
	])


## 测试道具+竞技场撤退修正叠加
func test_combined_retreat_modifiers() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	# 道具 -1
	proc.register_effect("tool_retreat", EffectToolRetreatModifier.new(-1))
	_attach_tool(state.players[0].active_pokemon, 0, "tool_retreat")
	# 竞技场 -1
	proc.register_effect("stadium_retreat", EffectStadiumRetreatModifier.new(-1, ""))
	_place_stadium(state, 0, "stadium_retreat")
	var cost: int = proc.get_effective_retreat_cost(state.players[0].active_pokemon, state)
	return run_checks([
		assert_eq(cost, 0, "原撤退费用2-1-1=0"),
	])


## 测试特性被道具禁用后不计入修正
func test_ability_disabled_by_tool_no_modifier() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	# 宝可梦有攻击+20特性
	var slot: PokemonSlot = state.players[0].active_pokemon
	slot.get_top_card().card_data.effect_id = "atk_ability"
	proc.register_effect("atk_ability", AbilityDamageModifier.new(20, "attack", true))
	# 未被禁用时
	var mod_before: int = proc.get_attacker_modifier(slot, state)
	# 附着禁用特性的道具
	proc.register_effect("vest_disable", EffectToolHPModifier.new(50, true))
	_attach_tool(slot, 0, "vest_disable")
	var mod_after: int = proc.get_attacker_modifier(slot, state)
	return run_checks([
		assert_eq(mod_before, 20, "禁用前攻击修正应为20"),
		assert_eq(mod_after, 0, "禁用后攻击修正应为0"),
	])


## ==================== 描述文本测试 ====================

## 测试所有新效果的 get_description 不为空
func test_all_new_descriptions() -> String:
	var effects: Array[BaseEffect] = [
		EffectDoubleColorless.new(2),
		EffectSpecialEnergyOnAttach.new(30, 0),
		EffectSpecialEnergyOnAttach.new(0, 1),
		EffectSpecialEnergyModifier.new(10, 0, "R", 1),
		EffectSpecialEnergyModifier.new(0, -1, "C", 1),
		EffectStadiumDraw.new(1),
		EffectStadiumDamageModifier.new(10, "attack", "Basic"),
		EffectStadiumDamageModifier.new(-20, "defense", ""),
		EffectStadiumRetreatModifier.new(-1),
		EffectToolDamageModifier.new(30, "attack", "ex"),
		EffectToolDamageModifier.new(-20, "defense"),
		EffectToolRetreatModifier.new(-2),
		EffectToolHPModifier.new(50),
		EffectToolHPModifier.new(50, true),
	]
	for effect: BaseEffect in effects:
		var desc: String = effect.get_description()
		if desc == "":
			return "效果描述不应为空"
	return ""
