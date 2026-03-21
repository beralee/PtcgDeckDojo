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
