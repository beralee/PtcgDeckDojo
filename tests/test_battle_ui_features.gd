## Phase 3 UI 功能测试 - 投币信号、弃牌区数据、卡牌详情文本
class_name TestBattleUIFeatures
extends TestBase

const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


## 构建测试用 CardData（宝可梦）
func _make_pokemon_cd(pname: String, hp: int, energy: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = hp
	cd.energy_type = energy
	cd.retreat_cost = 1
	cd.weakness_energy = "W"
	cd.weakness_value = "×2"
	cd.resistance_energy = ""
	cd.resistance_value = ""
	cd.attacks = [
		{"name": "撞击", "cost": "RC", "damage": "30", "text": "", "is_vstar_power": false},
		{"name": "火焰喷射", "cost": "RRC", "damage": "90", "text": "弃置1个火能量。", "is_vstar_power": false},
	]
	cd.abilities = [{"name": "闪焰", "text": "每回合可抽1张牌"}]
	cd.evolves_from = ""
	return cd


## 构建测试用 CardData（训练家卡）
func _make_trainer_cd(tname: String, card_type: String, desc: String) -> CardData:
	var cd := CardData.new()
	cd.name = tname
	cd.card_type = card_type
	cd.description = desc
	return cd


## 构建测试用 CardData（能量卡）
func _make_energy_cd(ename: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = ename
	cd.card_type = "Basic Energy"
	cd.energy_provides = provides
	return cd


func _make_battle_scene_stub() -> Control:
	var battle_scene = BattleSceneScript.new()
	battle_scene.set("_dialog_title", Label.new())
	battle_scene.set("_dialog_list", ItemList.new())
	battle_scene.set("_dialog_card_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_card_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_panel", VBoxContainer.new())
	battle_scene.set("_dialog_assignment_source_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_source_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_target_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_target_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_summary_lbl", Label.new())
	battle_scene.set("_dialog_utility_row", HBoxContainer.new())
	battle_scene.set("_dialog_confirm", Button.new())
	battle_scene.set("_dialog_cancel", Button.new())
	battle_scene.set("_dialog_status_lbl", Label.new())
	battle_scene.set("_dialog_overlay", Panel.new())
	battle_scene.set("_handover_panel", Panel.new())
	battle_scene.set("_coin_overlay", Panel.new())
	battle_scene.set("_detail_overlay", Panel.new())
	battle_scene.set("_discard_overlay", Panel.new())
	return battle_scene


func _make_regidrago_vstar_cd() -> CardData:
	var cd := CardData.new()
	cd.name = "Regidrago VSTAR"
	cd.card_type = "Pokemon"
	cd.stage = "VSTAR"
	cd.hp = 280
	cd.energy_type = "N"
	cd.mechanic = "V"
	cd.effect_id = "749d2f12d33057c8cc20e52c1b11bcbf"
	cd.attacks = [{
		"name": "Apex Dragon",
		"cost": "GGR",
		"damage": "",
		"text": "Choose an attack from a Dragon Pokemon in your discard pile and use it as this attack.",
		"is_vstar_power": false,
	}]
	return cd


func _make_dragapult_ex_cd() -> CardData:
	var cd := CardData.new()
	cd.name = "Dragapult ex"
	cd.card_type = "Pokemon"
	cd.stage = "Stage 2"
	cd.hp = 320
	cd.energy_type = "N"
	cd.mechanic = "ex"
	cd.effect_id = "52a205820de799a53a689f23cbeb8622"
	cd.attacks = [
		{"name": "Jet Headbutt", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
	]
	return cd


# ===================== 投币测试 =====================

## 测试：CoinFlipper 的 coin_flipped 信号是否正确发出
func test_coin_flipper_emits_signal() -> String:
	var flipper := CoinFlipper.new()
	var received_results: Array[bool] = []
	flipper.coin_flipped.connect(func(r: bool) -> void: received_results.append(r))

	var result: bool = flipper.flip()
	return run_checks([
		assert_eq(received_results.size(), 1, "应收到1次信号"),
		assert_eq(received_results[0], result, "信号结果与返回值一致"),
	])


## 测试：CoinFlipper 多次投币信号全部发出
func test_coin_flipper_multiple_emits() -> String:
	var flipper := CoinFlipper.new()
	var emitted: Array[bool] = []
	flipper.coin_flipped.connect(func(_r: bool) -> void: emitted.append(true))

	var results: Array[bool] = flipper.flip_multiple(5)
	return run_checks([
		assert_eq(results.size(), 5, "投5次返回5个结果"),
		assert_eq(emitted.size(), 5, "信号发出5次"),
	])


## 测试：投币直到反面，信号计数正确
func test_coin_flipper_until_tails_emits() -> String:
	var flipper := CoinFlipper.new()
	var emitted: Array[bool] = []
	flipper.coin_flipped.connect(func(_r: bool) -> void: emitted.append(true))

	var heads: int = flipper.flip_until_tails()
	# 正面次数 + 最后一次反面 = 总投币次数
	return run_checks([
		assert_eq(emitted.size(), heads + 1, "信号次数 = 正面次数 + 1（反面）"),
	])


# ===================== 弃牌区数据测试 =====================

## 测试：弃牌区初始为空
func test_discard_pile_initially_empty() -> String:
	var player := PlayerState.new()
	player.player_index = 0
	return run_checks([
		assert_eq(player.discard_pile.size(), 0, "初始弃牌区为空"),
	])


## 测试：弃牌区正确累积卡牌
func test_discard_pile_accumulates() -> String:
	var player := PlayerState.new()
	player.player_index = 0

	CardInstance.reset_id_counter()
	for i: int in 3:
		var cd := _make_trainer_cd("物品%d" % i, "Item", "效果%d" % i)
		var inst := CardInstance.create(cd, 0)
		player.discard_pile.append(inst)

	return run_checks([
		assert_eq(player.discard_pile.size(), 3, "弃牌区有3张"),
		assert_eq(player.discard_pile[0].card_data.name, "物品0", "第1张正确"),
		assert_eq(player.discard_pile[2].card_data.name, "物品2", "第3张正确"),
	])


## 测试：昏厥宝可梦及附着卡牌全部进入弃牌区
func test_knockout_all_cards_to_discard() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.player_index = 0

	# 构建一个带能量和道具的宝可梦
	var cd := _make_pokemon_cd("小火龙", 70, "R")
	var pokemon_inst := CardInstance.create(cd, 0)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(pokemon_inst)

	var energy_cd := _make_energy_cd("火能量", "R")
	var energy_inst := CardInstance.create(energy_cd, 0)
	slot.attached_energy.append(energy_inst)

	var tool_cd := _make_trainer_cd("力量头巾", "Tool", "+20伤害")
	var tool_inst := CardInstance.create(tool_cd, 0)
	slot.attached_tool = tool_inst

	# collect_all_cards 应返回所有卡牌
	var all_cards: Array[CardInstance] = slot.collect_all_cards()
	for card: CardInstance in all_cards:
		player.discard_pile.append(card)

	return run_checks([
		assert_gte(player.discard_pile.size(), 3, "弃牌区至少3张（宝可梦+能量+道具）"),
	])


# ===================== 卡牌详情文本测试 =====================

## 测试：宝可梦卡 CardData 包含完整信息
func test_pokemon_card_data_completeness() -> String:
	var cd := _make_pokemon_cd("小火龙", 70, "R")
	return run_checks([
		assert_eq(cd.name, "小火龙", "名称正确"),
		assert_eq(cd.hp, 70, "HP正确"),
		assert_eq(cd.energy_type, "R", "属性正确"),
		assert_eq(cd.weakness_energy, "W", "弱点属性正确"),
		assert_eq(cd.weakness_value, "×2", "弱点倍率正确"),
		assert_eq(cd.retreat_cost, 1, "撤退费用正确"),
		assert_eq(cd.attacks.size(), 2, "有2个招式"),
		assert_eq(cd.abilities.size(), 1, "有1个特性"),
		assert_eq(cd.attacks[0].get("name", ""), "撞击", "招式1名称正确"),
		assert_eq(cd.attacks[0].get("cost", ""), "RC", "招式1费用正确"),
	])


## 测试：训练家卡 CardData 包含描述
func test_trainer_card_data_description() -> String:
	var cd := _make_trainer_cd("博士的研究", "Supporter", "弃掉手牌抽7张")
	return run_checks([
		assert_eq(cd.name, "博士的研究", "名称正确"),
		assert_eq(cd.card_type, "Supporter", "类型正确"),
		assert_str_contains(cd.description, "抽7张", "描述包含关键信息"),
	])


## 测试：能量卡 energy_provides 正确
func test_energy_card_provides() -> String:
	var cd := _make_energy_cd("火能量", "R")
	return run_checks([
		assert_eq(cd.card_type, "Basic Energy", "类型正确"),
		assert_eq(cd.energy_provides, "R", "提供火能量"),
	])


func test_battle_scene_uses_effective_hp_for_bravery_charm() -> String:
	var battle_scene = BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var scream_tail := _make_pokemon_cd("吼叫尾", 90, "P")
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(scream_tail, 0))
	slot.damage_counters = 20
	var bravery_charm := CardData.new()
	bravery_charm.name = "勇气护符"
	bravery_charm.card_type = "Tool"
	bravery_charm.effect_id = "d1c2f018a644e662f2b6895fdfc29281"
	slot.attached_tool = CardInstance.create(bravery_charm, 0)
	gsm.game_state.players[0].active_pokemon = slot
	battle_scene._gsm = gsm

	var status: Dictionary = battle_scene._build_battle_status(slot)
	var overlay_text: String = battle_scene._slot_overlay_text(slot)
	var subtitle: String = battle_scene._dialog_choice_subtitle(slot, "")

	return run_checks([
		assert_eq(int(status.get("hp_current", 0)), 120, "战斗状态当前HP应显示勇气护符加成后的有效剩余HP"),
		assert_eq(int(status.get("hp_max", 0)), 140, "战斗状态最大HP应显示勇气护符加成后的有效最大HP"),
		assert_str_contains(overlay_text, "120/140", "战斗页覆盖文本应显示有效HP"),
		assert_str_contains(subtitle, "120/140", "选择弹窗副标题也应显示有效HP"),
	])


## 测试：宝可梦判定方法正确
func test_battle_scene_regidrago_copy_dragapult_injects_followup_assignment_step() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var regidrago_cd := _make_regidrago_vstar_cd()
	var dragapult_cd := _make_dragapult_ex_cd()
	gsm.effect_processor.register_pokemon_card(regidrago_cd)
	gsm.effect_processor.register_pokemon_card(dragapult_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	attacker.turn_played = 0
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 1", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 2", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(dragapult_cd, 0))

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender", 220, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "P"), 1))
	bench_a.turn_played = 0
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "P"), 1))
	bench_b.turn_played = 0
	gsm.game_state.players[1].bench.append(bench_a)
	gsm.game_state.players[1].bench.append(bench_b)

	battle_scene.set("_gsm", gsm)
	battle_scene.call("_try_use_attack_with_interaction", 0, attacker, 0)

	var initial_steps: Array = battle_scene.get("_pending_effect_steps")
	var copied_step: Dictionary = initial_steps[0] if not initial_steps.is_empty() else {}
	var copied_items: Array = copied_step.get("items", [])
	var phantom_option: Dictionary = {}
	for item: Variant in copied_items:
		if not (item is Dictionary):
			continue
		var attack: Dictionary = item.get("attack", {})
		if str(attack.get("name", "")) == "Phantom Dive":
			phantom_option = item
			break

	battle_scene.set("_pending_effect_context", {"copied_attack": [phantom_option]})
	battle_scene.set("_pending_effect_step_index", 1)
	battle_scene.call("_inject_followup_steps")

	var pending_attack_effects: Array = battle_scene.get("_pending_effect_attack_effects")
	var pending_steps: Array = battle_scene.get("_pending_effect_steps")
	var has_followup := pending_steps.size() > 1 and str(pending_steps[1].get("id", "")) == "bench_damage_counters"
	var injected_step_count: int = pending_steps.size()

	battle_scene.set("_pending_effect_context", {
		"copied_attack": [phantom_option],
		"bench_damage_counters": [
			{"target": bench_a, "amount": 30},
			{"target": bench_b, "amount": 30},
		],
	})
	battle_scene.set("_pending_effect_step_index", 2)
	battle_scene.call("_inject_followup_steps")
	var final_steps: Array = battle_scene.get("_pending_effect_steps")

	return run_checks([
		assert_false(initial_steps.is_empty(), "巨龙无双应先进入复制招式交互"),
		assert_eq(pending_attack_effects.size(), 1, "攻击交互状态应保留原始攻击效果，供后续步骤注入使用"),
		assert_false(phantom_option.is_empty(), "复制招式列表中应包含 Phantom Dive"),
		assert_true(has_followup, "选中 Phantom Dive 后应注入 bench_damage_counters 分配步骤"),
	])


func test_battle_scene_does_not_reinject_resolved_followup_steps() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var regidrago_cd := _make_regidrago_vstar_cd()
	var dragapult_cd := _make_dragapult_ex_cd()
	gsm.effect_processor.register_pokemon_card(regidrago_cd)
	gsm.effect_processor.register_pokemon_card(dragapult_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	attacker.turn_played = 0
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 1", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 2", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(dragapult_cd, 0))

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender", 220, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "P"), 1))
	bench_a.turn_played = 0
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "P"), 1))
	bench_b.turn_played = 0
	gsm.game_state.players[1].bench.append(bench_a)
	gsm.game_state.players[1].bench.append(bench_b)

	battle_scene.set("_gsm", gsm)
	battle_scene.call("_try_use_attack_with_interaction", 0, attacker, 0)

	var initial_steps: Array = battle_scene.get("_pending_effect_steps")
	var copied_items: Array = (initial_steps[0] as Dictionary).get("items", []) if not initial_steps.is_empty() else []
	var phantom_option: Dictionary = {}
	for item: Variant in copied_items:
		if not (item is Dictionary):
			continue
		var attack: Dictionary = item.get("attack", {})
		if str(attack.get("name", "")) == "Phantom Dive":
			phantom_option = item
			break

	battle_scene.set("_pending_effect_context", {"copied_attack": [phantom_option]})
	battle_scene.set("_pending_effect_step_index", 1)
	battle_scene.call("_inject_followup_steps")
	var injected_count: int = (battle_scene.get("_pending_effect_steps") as Array).size()

	battle_scene.set("_pending_effect_context", {
		"copied_attack": [phantom_option],
		"bench_damage_counters": [
			{"target": bench_a, "amount": 30},
			{"target": bench_b, "amount": 30},
		],
	})
	battle_scene.set("_pending_effect_step_index", 2)
	battle_scene.call("_inject_followup_steps")
	var final_count: int = (battle_scene.get("_pending_effect_steps") as Array).size()

	return run_checks([
		assert_false(phantom_option.is_empty(), "Phantom Dive should still be available as a copied attack"),
		assert_eq(final_count, injected_count, "Resolved follow-up steps should not be injected a second time"),
	])


func test_battle_scene_regidrago_copy_dragapult_real_choice_enters_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var regidrago_cd := _make_regidrago_vstar_cd()
	var dragapult_cd := _make_dragapult_ex_cd()
	gsm.effect_processor.register_pokemon_card(regidrago_cd)
	gsm.effect_processor.register_pokemon_card(dragapult_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	attacker.turn_played = 0
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 1", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 2", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(dragapult_cd, 0))

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender", 220, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "P"), 1))
	bench_a.turn_played = 0
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "P"), 1))
	bench_b.turn_played = 0
	gsm.game_state.players[1].bench.append(bench_a)
	gsm.game_state.players[1].bench.append(bench_b)

	battle_scene.set("_gsm", gsm)
	battle_scene.call("_try_use_attack_with_interaction", 0, attacker, 0)

	var initial_steps: Array = battle_scene.get("_pending_effect_steps")
	var copied_items: Array = (initial_steps[0] as Dictionary).get("items", []) if not initial_steps.is_empty() else []
	var phantom_index: int = -1
	for i: int in copied_items.size():
		var item: Variant = copied_items[i]
		if not (item is Dictionary):
			continue
		var attack: Dictionary = item.get("attack", {})
		if str(attack.get("name", "")) == "Phantom Dive":
			phantom_index = i
			break

	if phantom_index >= 0:
		battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([phantom_index]))

	var pending_choice: String = battle_scene.get("_pending_choice")
	var assignment_mode: bool = bool(battle_scene.get("_dialog_assignment_mode"))
	var steps_after_choice: Array = battle_scene.get("_pending_effect_steps")
	var has_assignment_step := steps_after_choice.size() > 1 and str(steps_after_choice[1].get("id", "")) == "bench_damage_counters"

	return run_checks([
		assert_gte(phantom_index, 0, "Phantom Dive should appear in the copied attack options"),
		assert_eq(pending_choice, "effect_interaction", "Selecting Phantom Dive should continue into the follow-up interaction flow"),
		assert_true(assignment_mode, "Selecting Phantom Dive should switch the dialog into assignment mode"),
		assert_true(has_assignment_step, "The queued follow-up step should be bench_damage_counters"),
	])


func test_card_type_checks() -> String:
	var pokemon := _make_pokemon_cd("小火龙", 70, "R")
	var trainer := _make_trainer_cd("超级球", "Item", "搜索牌库")
	var energy := _make_energy_cd("火能量", "R")
	return run_checks([
		assert_true(pokemon.is_pokemon(), "宝可梦is_pokemon"),
		assert_true(pokemon.is_basic_pokemon(), "基础宝可梦is_basic_pokemon"),
		assert_false(pokemon.is_trainer(), "宝可梦非训练家"),
		assert_true(trainer.is_trainer(), "训练家is_trainer"),
		assert_false(trainer.is_pokemon(), "训练家非宝可梦"),
		assert_true(energy.is_energy(), "能量is_energy"),
	])
