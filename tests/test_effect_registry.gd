## EffectRegistry 测试 - 验证固定 effect_id 注册和宝可梦动态注册
class_name TestEffectRegistry
extends TestBase


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi

		var active_cd := CardData.new()
		active_cd.name = "战斗宝可梦P%d" % pi
		active_cd.card_type = "Pokemon"
		active_cd.stage = "Basic"
		active_cd.hp = 120
		active_cd.energy_type = "R"
		active_cd.effect_id = ""
		active_cd.attacks = [
			{"name": "炎爆", "cost": "RR", "damage": "100", "text": "", "is_vstar_power": false}
		]
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(active_cd, pi))
		player.active_pokemon = active

		for _i: int in 2:
			var energy_cd := CardData.new()
			energy_cd.name = "火能量"
			energy_cd.card_type = "Basic Energy"
			energy_cd.energy_provides = "R"
			active.attached_energy.append(CardInstance.create(energy_cd, pi))

		var bench_cd := CardData.new()
		bench_cd.name = "备战宝可梦P%d" % pi
		bench_cd.card_type = "Pokemon"
		bench_cd.stage = "Basic"
		bench_cd.hp = 80
		bench_cd.energy_type = "W"
		var bench := PokemonSlot.new()
		bench.pokemon_stack.append(CardInstance.create(bench_cd, pi))
		player.bench.append(bench)

		state.players.append(player)

	return state


func test_register_all_fixed_effect_ids() -> String:
	var proc := EffectProcessor.new()

	var fixed_effect_ids := [
		"06bc00d5dcec33898dc6db2e4c4d10ec",
		"1af63a7e2cb7a79215474ad8db8fd8fd",
		"66b2f1d77328b6578b1bf0d58d98f66b",
		"8f655fea1f90164bfbccb7a95c223e17",
		"a337ed34a45e63c6d21d98c3d8e0cb6e",
		"a47d5a8ed00e14a2146fc511745d23b5",
		"c9c948169525fbb3dce70c477ec7a90a",
		"d3891abcfe3277c8811cde06741d3236",
		"f866dfee26cd6b0dbbb52b74438d0a59",
		"768b545a38fccd5e265093b5adce10af",
		"1838e8afe529b519a57dd8bbd307905a",
		"7cd68d9e286b78a7f9c799fce24a7d6c",
		"7c0b20e121c9d0e0d2d8a43524f7494e",
		"4ec261453212280d0eb03ed8254ca97f",
		"30e7c440d69817592656f5b44e444111",
		"2234845fbc2e11ab95587e1b393bb318",
		"8b0d4f541f256d67f0757efe4fc8b407",
		"8342fe3eeec6f897f3271be1aa26a412",
		"5bdbc985f9aa2e6f248b53f6f35d1d37",
		"73d5f46ecf3a6d71b23ce7bc1a28d4f4",
		"8e1fa2c9018db938084c94c7c970d419",
		"af514f82d182aeae5327b2c360df703d",
		"aecd80ca2722885c3d062a2255346f3e",
		"0a9bdf265647461dd5c6c827ffc19e61",
		"1b5fc2ed2bce98ef93457881c05354e2",
		"05b9dc8ee5c16c46da20f47a04907856",
		"d83b170c43c0ade1f81c817c4488d5db",
		"a8a2b27c2641d8d7212fc887ca032e4c",
		"4f53ab6bf158fd1a8869ae037f4a0d6d",
		"2e07a9870350b611a3d21ab2053dfa2a",
		"9fa9943ccda36f417ac3cb675177c216",
		"e242d711feffd98f3fbb5c511d00d667",
		"36939b241f51e497487feb52e0ea8994",
		"d1c2f018a644e662f2b6895fdfc29281",
		"54920a273edba38ce45f3bc8f6e8ff25",
		"770c741043025f241dbd81422cb8987d",
		"0b4cc131a19862f92acf71494f29a0ed",
		"fb3628071280487676f79281696ffbd9",
		"7f4e493ec0d852a5bb31c02bdbdb2c4e",
		"13b3caaa408a85dfd1e2a5ad797e8b8a",
		"9c04dd0addf56a7b2c88476bc8e45c0e",
		"1323733f19cc04e54090b39bc1a393b8",
		"2c65697c2aceac4e6a1f85f810fa386f",
		"88bf9902f1d769a667bbd3939fc757de",
		"dbb3f3d2ef2f3372bc8b21336e6c9bc6",
		"fb0948c721db1f31767aa6cf0c2ea692",
	]

	for eid: String in fixed_effect_ids:
		if not proc.has_effect(eid):
			return "固定 effect_id 未注册: %s" % eid

	return run_checks([
		assert_gte(proc.get_registered_count(), fixed_effect_ids.size(), "注册表条目数应不少于固定映射数"),
	])


func test_effect_processor_auto_registers_fixed_effects() -> String:
	var proc := EffectProcessor.new()
	return run_checks([
		assert_true(proc.has_effect("a337ed34a45e63c6d21d98c3d8e0cb6e"), "EffectProcessor 初始化后应自动注册高级球"),
		assert_true(proc.has_effect("8e1fa2c9018db938084c94c7c970d419"), "EffectProcessor 初始化后应自动注册老大的指令"),
		assert_true(proc.has_effect("fb3628071280487676f79281696ffbd9"), "EffectProcessor 初始化后应自动注册崩塌的竞技场"),
	])


func test_register_pokemon_card_by_ability_and_attack_name() -> String:
	var proc := EffectProcessor.new()
	var card := CardData.new()
	card.name = "测试宝可梦"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 130
	card.energy_type = "W"
	card.effect_id = "pokemon_dynamic"
	card.abilities = [{"name": "浪花水帘", "text": ""}]
	card.attacks = [{"name": "三重蓄能", "cost": "CCC", "damage": "0", "text": "", "is_vstar_power": false}]

	EffectRegistry.register_pokemon_card(proc, card)

	return run_checks([
		assert_true(proc.has_effect("pokemon_dynamic"), "应注册特性效果"),
		assert_true(proc.has_attack_effect("pokemon_dynamic"), "应注册招式附加效果"),
		assert_true(proc.get_effect("pokemon_dynamic") is AbilityBenchProtect, "特性应映射到 AbilityBenchProtect"),
	])


func test_register_pokemon_card_executes_multiple_attack_effects() -> String:
	var proc := EffectProcessor.new()
	var state := _make_state()
	var attacker: PokemonSlot = state.players[0].active_pokemon
	var defender: PokemonSlot = state.players[1].active_pokemon
	var attacker_cd: CardData = attacker.get_card_data()
	attacker_cd.effect_id = "pokemon_attack_multi"
	attacker_cd.attacks = [{"name": "炎爆", "cost": "RR", "damage": "100", "text": "", "is_vstar_power": false}]

	EffectRegistry.register_pokemon_card(proc, attacker_cd)

	var init_energy: int = attacker.attached_energy.size()
	proc.execute_attack_effect(attacker, 0, defender, state)

	return run_checks([
		assert_true(proc.has_attack_effect("pokemon_attack_multi"), "应注册炎爆的招式附加效果"),
		assert_eq(attacker.attached_energy.size(), init_energy - 1, "炎爆应弃置1个火能量"),
		assert_true(attacker.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == "attack_lock"), "应记录下回合招式锁定"),
	])
