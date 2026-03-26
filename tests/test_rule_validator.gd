## 规则验证器测试
class_name TestRuleValidator
extends TestBase


## 创建一个用于测试的最小化游戏状态
func _make_state(turn: int = 2, first: int = 0, current: int = 0) -> GameState:
	var state := GameState.new()
	state.turn_number = turn
	state.first_player_index = first
	state.current_player_index = current
	state.phase = GameState.GamePhase.MAIN

	for _i: int in 2:
		var p := PlayerState.new()
		p.player_index = _i
		state.players.append(p)

	# 各放一只基础宝可梦
	for pi: int in 2:
		var cd := CardData.new()
		cd.card_type = "Pokemon"
		cd.stage = "Basic"
		cd.hp = 100
		cd.energy_type = "R"
		cd.retreat_cost = 1
		CardInstance.reset_id_counter()
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(CardInstance.create(cd, pi))
		state.players[pi].active_pokemon = slot

	return state


func test_can_attach_energy_fresh_turn() -> String:
	var state := _make_state()
	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_attach_energy(state, 0), true, "新回合可附着能量"),
	])


func test_cannot_attach_energy_twice() -> String:
	var state := _make_state()
	state.energy_attached_this_turn = true
	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_attach_energy(state, 0), false, "每回合只能附着一次"),
	])


func test_cannot_attach_energy_wrong_player() -> String:
	var state := _make_state()
	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_attach_energy(state, 1), false, "非当前玩家不可操作"),
	])


func test_can_play_supporter_normal() -> String:
	var state := _make_state(2, 0, 0)
	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_play_supporter(state, 0), true, "第2回合可使用支援者"),
	])


func test_cannot_play_supporter_first_turn_first_player() -> String:
	var state := _make_state(1, 0, 0)
	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_play_supporter(state, 0), false, "先攻首回合不可使用支援者"),
	])


func test_second_player_can_use_supporter_turn1() -> String:
	# 后攻玩家第一回合（game turn_number=2时后攻玩家行动）
	var state := _make_state(2, 0, 1)
	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_play_supporter(state, 1), true, "后攻玩家第一回合可使用支援者"),
	])


func test_cannot_play_supporter_already_used() -> String:
	var state := _make_state()
	state.supporter_used_this_turn = true
	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_play_supporter(state, 0), false, "每回合只能使用一次支援者"),
	])


func test_cannot_play_item_when_item_locked_for_turn() -> String:
	var state := _make_state(3, 0, 1)
	state.shared_turn_flags["item_lock_1"] = 3
	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_play_item(state, 1), false, "Locked player cannot play Items this turn"),
		assert_eq(v.can_play_item(state, 0), false, "Non-current player still cannot play Items"),
	])


func test_can_play_item_after_item_lock_turn_expires() -> String:
	var state := _make_state(4, 0, 1)
	state.shared_turn_flags["item_lock_1"] = 3
	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_play_item(state, 1), true, "Expired item lock should no longer block play"),
	])


func test_can_evolve_normal() -> String:
	var state := _make_state(2, 0, 0)
	var v := RuleValidator.new()

	# 基础宝可梦在上回合放置
	var slot: PokemonSlot = state.players[0].active_pokemon
	slot.turn_played = 1  # 上回合放置

	var evo_data := CardData.new()
	evo_data.card_type = "Pokemon"
	evo_data.stage = "Stage 1"
	evo_data.evolves_from = slot.get_pokemon_name()
	CardInstance.reset_id_counter()
	var evo := CardInstance.create(evo_data, 0)

	return run_checks([
		assert_eq(v.can_evolve(state, 0, slot, evo), true, "正常进化条件"),
	])


func test_cannot_evolve_turn_played_same_turn() -> String:
	var state := _make_state(2, 0, 0)
	var v := RuleValidator.new()

	var slot: PokemonSlot = state.players[0].active_pokemon
	slot.turn_played = 2  # 本回合刚放置

	var evo_data := CardData.new()
	evo_data.card_type = "Pokemon"
	evo_data.stage = "Stage 1"
	evo_data.evolves_from = slot.get_pokemon_name()
	CardInstance.reset_id_counter()
	var evo := CardInstance.create(evo_data, 0)

	return run_checks([
		assert_eq(v.can_evolve(state, 0, slot, evo), false, "本回合放置不可进化"),
	])


func test_has_enough_energy_exact() -> String:
	var v := RuleValidator.new()

	var slot := PokemonSlot.new()
	# 添加1个火能量
	var e_data := CardData.new()
	e_data.card_type = "Basic Energy"
	e_data.energy_provides = "R"
	CardInstance.reset_id_counter()
	slot.attached_energy.append(CardInstance.create(e_data, 0))

	return run_checks([
		assert_eq(v.has_enough_energy(slot, "R"), true, "1火能量支付R费用"),
		assert_eq(v.has_enough_energy(slot, "RR"), false, "1火能量不够支付RR"),
		assert_eq(v.has_enough_energy(slot, "C"), true, "火能量可当无色用"),
		assert_eq(v.has_enough_energy(slot, ""), true, "无费用招式总是可用"),
	])


func test_has_enough_energy_colorless() -> String:
	var v := RuleValidator.new()

	var slot := PokemonSlot.new()
	# 添加2个水能量
	var e_data := CardData.new()
	e_data.card_type = "Basic Energy"
	e_data.energy_provides = "W"
	CardInstance.reset_id_counter()
	slot.attached_energy.append(CardInstance.create(e_data, 0))
	slot.attached_energy.append(CardInstance.create(e_data, 0))

	return run_checks([
		assert_eq(v.has_enough_energy(slot, "WC"), true, "2水能量支付WC"),
		assert_eq(v.has_enough_energy(slot, "WCC"), false, "2水能量不够支付WCC"),
		assert_eq(v.has_enough_energy(slot, "RC"), false, "无火能量不能支付RC"),
	])


## 回归测试：多属性消耗中缺少某属性时应返回 false
func test_has_enough_energy_missing_required_type() -> String:
	var v := RuleValidator.new()

	# 仅有1火能量，尝试支付GGR（需要2草+1火）
	var slot := PokemonSlot.new()
	var e_fire := CardData.new()
	e_fire.card_type = "Basic Energy"
	e_fire.energy_provides = "R"
	CardInstance.reset_id_counter()
	slot.attached_energy.append(CardInstance.create(e_fire, 0))

	# 有1草1火，尝试支付GGR（需要2草+1火，草不够）
	var slot2 := PokemonSlot.new()
	var e_grass := CardData.new()
	e_grass.card_type = "Basic Energy"
	e_grass.energy_provides = "G"
	slot2.attached_energy.append(CardInstance.create(e_grass, 0))
	slot2.attached_energy.append(CardInstance.create(e_fire, 0))

	# 有2草1火，正好支付GGR
	var slot3 := PokemonSlot.new()
	slot3.attached_energy.append(CardInstance.create(e_grass, 0))
	slot3.attached_energy.append(CardInstance.create(e_grass, 0))
	slot3.attached_energy.append(CardInstance.create(e_fire, 0))

	return run_checks([
		assert_eq(v.has_enough_energy(slot, "GGR"), false, "仅1火能量不够支付GGR"),
		assert_eq(v.has_enough_energy(slot2, "GGR"), false, "1草1火不够支付GGR"),
		assert_eq(v.has_enough_energy(slot3, "GGR"), true, "2草1火正好支付GGR"),
		assert_eq(v.has_enough_energy(slot, "R"), true, "1火能量可支付R"),
		assert_eq(v.has_enough_energy(slot, "G"), false, "1火能量不能支付G"),
	])


func test_can_retreat_normal() -> String:
	var state := _make_state()
	# 在备战区放一只宝可梦
	var cd := CardData.new()
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	CardInstance.reset_id_counter()
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(cd, 0))
	state.players[0].bench.append(bench_slot)

	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_retreat(state, 0), true, "有备战宝可梦可撤退"),
	])


func test_cannot_retreat_asleep() -> String:
	var state := _make_state()
	state.players[0].active_pokemon.status_conditions["asleep"] = true

	var cd := CardData.new()
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	CardInstance.reset_id_counter()
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(cd, 0))
	state.players[0].bench.append(bench_slot)

	var v := RuleValidator.new()
	return run_checks([
		assert_eq(v.can_retreat(state, 0), false, "睡眠状态不可撤退"),
	])


func test_can_use_attack_with_energy() -> String:
	var state := _make_state(2, 0, 0)
	var v := RuleValidator.new()

	var active: PokemonSlot = state.players[0].active_pokemon
	active.get_card_data().attacks = [{"name": "吐火", "cost": "R", "damage": "30", "is_vstar_power": false}]

	var e_data := CardData.new()
	e_data.card_type = "Basic Energy"
	e_data.energy_provides = "R"
	CardInstance.reset_id_counter()
	active.attached_energy.append(CardInstance.create(e_data, 0))

	return run_checks([
		assert_eq(v.can_use_attack(state, 0, 0), true, "有足够能量可使用招式"),
	])


func test_can_use_attack_with_zero_string_cost() -> String:
	var state := _make_state(2, 0, 0)
	var v := RuleValidator.new()

	var active: PokemonSlot = state.players[0].active_pokemon
	active.get_card_data().attacks = [{"name": "Eeeek", "cost": "0", "damage": "", "is_vstar_power": false}]

	return run_checks([
		assert_eq(v.can_use_attack(state, 0, 0), true, "字符串0应视为零费招式"),
		assert_eq(v.get_attack_unusable_reason(state, 0, 0), "", "零费招式不应返回不可用原因"),
	])


func test_cannot_attack_first_turn_first_player() -> String:
	var state := _make_state(1, 0, 0)
	var v := RuleValidator.new()

	var active: PokemonSlot = state.players[0].active_pokemon
	active.get_card_data().attacks = [{"name": "招式", "cost": "", "damage": "10", "is_vstar_power": false}]

	return run_checks([
		assert_eq(v.can_use_attack(state, 0, 0), false, "先攻首回合不可攻击"),
	])


func test_can_attack_first_turn_when_attack_text_allows_it() -> String:
	var state := _make_state(1, 0, 0)
	var v := RuleValidator.new()

	var active: PokemonSlot = state.players[0].active_pokemon
	active.get_card_data().attacks = [{
		"name": "快速充能",
		"cost": "L",
		"damage": "",
		"text": "这个招式，即使是先攻玩家的最初回合也可以使用。",
		"is_vstar_power": false,
	}]
	var energy := CardData.new()
	energy.card_type = "Basic Energy"
	energy.energy_provides = "L"
	active.attached_energy.append(CardInstance.create(energy, 0))

	return run_checks([
		assert_eq(v.can_use_attack(state, 0, 0), true, "明确写明可在先攻首回合使用的招式不应被通用限制挡住"),
		assert_eq(v.get_attack_unusable_reason(state, 0, 0), "", "快速充能这类例外招式不应返回不可用原因"),
	])


func test_bloodmoon_cost_reduction_matches_localized_attack_name() -> String:
	var state := _make_state(2, 0, 0)
	var v := RuleValidator.new()
	var processor := EffectProcessor.new()
	state.players[1].prizes.clear()
	for i: int in 3:
		state.players[1].prizes.append(CardInstance.create(state.players[1].active_pokemon.get_top_card().card_data, 1))

	var bloodmoon_cd := CardData.new()
	bloodmoon_cd.name = "月月熊 赫月ex"
	bloodmoon_cd.card_type = "Pokemon"
	bloodmoon_cd.stage = "Basic"
	bloodmoon_cd.hp = 240
	bloodmoon_cd.energy_type = "C"
	bloodmoon_cd.effect_id = "f2afef80b13b8f6a071facbcade0251c"
	bloodmoon_cd.attacks = [{
		"name": "血月",
		"cost": "CCCCC",
		"damage": "240",
		"text": "",
		"is_vstar_power": false,
	}]
	processor.register_pokemon_card(bloodmoon_cd)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(bloodmoon_cd, 0))
	for i: int in 2:
		var energy := CardData.new()
		energy.card_type = "Basic Energy"
		energy.energy_provides = "C"
		attacker.attached_energy.append(CardInstance.create(energy, 0))
	state.players[0].active_pokemon = attacker

	return run_checks([
		assert_eq(v.can_use_attack(state, 0, 0, processor), true, "血月应按对手已拿奖赏数减少无色费用"),
		assert_eq(v.get_attack_unusable_reason(state, 0, 0, processor), "", "本地化招式名不应导致血月减费失效"),
	])
