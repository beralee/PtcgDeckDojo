class_name TestStateEncoder
extends TestBase

const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")


func _make_game_state() -> GameState:
	var gs := GameState.new()
	gs.turn_number = 3
	gs.first_player_index = 0
	gs.current_player_index = 0
	gs.energy_attached_this_turn = false
	gs.supporter_used_this_turn = false

	for i in 2:
		var ps := PlayerState.new()
		ps.player_index = i

		var active_cd := CardData.new()
		active_cd.name = "Pikachu ex" if i == 0 else "Gardevoir ex"
		active_cd.card_type = "Pokemon"
		active_cd.stage = "Basic" if i == 0 else "Stage 2"
		active_cd.hp = 200 if i == 0 else 310
		active_cd.mechanic = "ex"
		active_cd.energy_type = "L" if i == 0 else "P"
		active_cd.attacks = [{"name": "攻击", "cost": "LC", "damage": "90", "text": ""}]
		var active_card := CardInstance.create(active_cd, i)
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack = [active_card]
		active_slot.damage_counters = 30 if i == 0 else 0
		for _e in 2:
			var energy_cd := CardData.new()
			energy_cd.card_type = "Basic Energy"
			energy_cd.energy_type = "L" if i == 0 else "P"
			active_slot.attached_energy.append(CardInstance.create(energy_cd, i))
		ps.active_pokemon = active_slot

		var bench_cd := CardData.new()
		bench_cd.name = "后备宝可梦"
		bench_cd.card_type = "Pokemon"
		bench_cd.stage = "Basic"
		bench_cd.hp = 60
		bench_cd.energy_type = "C"
		bench_cd.attacks = []
		var bench_card := CardInstance.create(bench_cd, i)
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack = [bench_card]
		ps.bench = [bench_slot]

		for _h in 5:
			ps.hand.append(CardInstance.create(CardData.new(), i))
		for _d in 30:
			ps.deck.append(CardInstance.create(CardData.new(), i))
		for _p in 5:
			ps.prizes.append(CardInstance.create(CardData.new(), i))

		gs.players.append(ps)

	return gs


func test_encode_returns_correct_dimension() -> String:
	var gs := _make_game_state()
	var features: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_eq(features.size(), 44, "特征向量维度应为 44"),
	])


func test_encode_values_in_expected_range() -> String:
	var gs := _make_game_state()
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(absf(f[0] - 0.85) < 0.01, "active_hp_ratio 应为 0.85，实际 %.4f" % f[0]),
		assert_true(absf(f[1] - 0.15) < 0.01, "active_damage_ratio 应为 0.15，实际 %.4f" % f[1]),
		assert_true(absf(f[2] - 0.4) < 0.01, "active_energy_count 应为 0.4，实际 %.4f" % f[2]),
		assert_true(f[4] == 1.0, "active_is_ex 应为 1.0"),
		assert_true(f[5] == 0.0, "active_stage 应为 0.0 (Basic)"),
		assert_true(absf(f[6] - 0.2) < 0.01, "bench_count 应为 0.2"),
		assert_true(absf(f[9] - 0.25) < 0.01, "hand_size 应为 0.25"),
		assert_true(absf(f[10] - 0.75) < 0.01, "deck_size 应为 0.75"),
		assert_true(f[12] == 1.0, "supporter_available 应为 1.0"),
		assert_true(f[13] == 1.0, "energy_available 应为 1.0"),
	])


func test_encode_symmetry() -> String:
	var gs := _make_game_state()
	var f0: Array[float] = StateEncoderScript.encode(gs, 0)
	var f1: Array[float] = StateEncoderScript.encode(gs, 1)
	var symmetric: bool = true
	for i in 20:
		if absf(f0[i] - f1[20 + i]) > 0.001:
			symmetric = false
			break
	return run_checks([
		assert_true(symmetric, "交换视角后自己的特征应等于对手的特征"),
	])


func test_encode_turn_and_first_player() -> String:
	var gs := _make_game_state()
	gs.turn_number = 15
	gs.first_player_index = 0
	var f0: Array[float] = StateEncoderScript.encode(gs, 0)
	var f1: Array[float] = StateEncoderScript.encode(gs, 1)
	return run_checks([
		assert_true(absf(f0[40] - 0.5) < 0.01, "回合数归一化应为 0.5"),
		assert_true(f0[41] == 1.0, "玩家 0 是先手"),
		assert_true(f1[41] == 0.0, "玩家 1 不是先手"),
	])


func test_encode_empty_bench() -> String:
	var gs := _make_game_state()
	gs.players[0].bench.clear()
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(f[6] == 0.0, "空后备 bench_count 应为 0"),
		assert_true(f[7] == 0.0, "空后备 bench_total_hp 应为 0"),
		assert_true(f[8] == 0.0, "空后备 bench_total_energy 应为 0"),
	])


func test_encode_no_active_pokemon() -> String:
	var gs := _make_game_state()
	gs.players[0].active_pokemon = null
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(f[0] == 0.0, "无前场 active_hp_ratio 应为 0"),
		assert_true(f[1] == 0.0, "无前场 active_damage_ratio 应为 0"),
		assert_true(f[2] == 0.0, "无前场 active_energy_count 应为 0"),
	])


func test_encode_new_features() -> String:
	var gs := _make_game_state()
	## 给 player 0 的前场加状态异常
	gs.players[0].active_pokemon.status_conditions["poisoned"] = true
	## 给 player 0 添加弃牌区
	for _i in 10:
		gs.players[0].discard_pile.append(CardInstance.create(CardData.new(), 0))
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(f[14] == 1.0, "中毒时 poisoned_or_burned 应为 1.0"),
		assert_true(f[15] == 0.0, "无特殊状态时 status_locked 应为 0.0"),
		assert_true(absf(f[19] - 0.25) < 0.01, "10 张弃牌 / 40 = 0.25"),
		assert_true(f[42] == 0.0, "无竞技场卡时 stadium_in_play 应为 0.0"),
	])
