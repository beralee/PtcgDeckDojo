## Phase 3 UI 功能测试 - 投币信号、弃牌区数据、卡牌详情文本
class_name TestBattleUIFeatures
extends TestBase

const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")
const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")
const BattleSetupScript = preload("res://scenes/battle_setup/BattleSetup.gd")
const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")
const EffectBossOrdersScript = preload("res://scripts/effects/trainer_effects/EffectBossOrders.gd")
const EffectCounterCatcherScript = preload("res://scripts/effects/trainer_effects/EffectCounterCatcher.gd")
const EffectElectricGeneratorScript = preload("res://scripts/effects/trainer_effects/EffectElectricGenerator.gd")
const EffectPrimeCatcherScript = preload("res://scripts/effects/trainer_effects/EffectPrimeCatcher.gd")
const EffectEnergySwitchScript = preload("res://scripts/effects/trainer_effects/EffectEnergySwitch.gd")
const EffectPokemonCatcherScript = preload("res://scripts/effects/trainer_effects/EffectPokemonCatcher.gd")
const EffectMirageGateScript = preload("res://scripts/effects/trainer_effects/EffectMirageGate.gd")
const EffectSwitchCartScript = preload("res://scripts/effects/trainer_effects/EffectSwitchCart.gd")
const EffectSwitchPokemonScript = preload("res://scripts/effects/trainer_effects/EffectSwitchPokemon.gd")
const EffectRareCandyScript = preload("res://scripts/effects/trainer_effects/EffectRareCandy.gd")
const EffectCarmineScript = preload("res://scripts/effects/trainer_effects/EffectCarmine.gd")
const EffectMelaScript = preload("res://scripts/effects/trainer_effects/EffectMela.gd")
const EffectCollapsedStadiumScript = preload("res://scripts/effects/stadium_effects/EffectCollapsedStadium.gd")
const AbilitySelfKnockoutDamageCountersScript = preload("res://scripts/effects/pokemon_effects/AbilitySelfKnockoutDamageCounters.gd")
const AbilityPsychicEmbraceScript = preload("res://scripts/effects/pokemon_effects/AbilityPsychicEmbrace.gd")
const AbilityStarPortalScript = preload("res://scripts/effects/pokemon_effects/AbilityStarPortal.gd")
const AbilityGustFromBenchScript = preload("res://scripts/effects/pokemon_effects/AbilityGustFromBench.gd")
const AbilityBenchDamageOnPlayScript = preload("res://scripts/effects/pokemon_effects/AbilityBenchDamageOnPlay.gd")
const AbilityRunAwayDrawScript = preload("res://scripts/effects/pokemon_effects/AbilityRunAwayDraw.gd")
const EffectSadasVitalityScript = preload("res://scripts/effects/trainer_effects/EffectSadasVitality.gd")
const AbilityAttachFromDeckScript = preload("res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd")
const AttackAttachBasicEnergyFromDiscardScript = preload("res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromDiscard.gd")
const AttackSearchAndAttachScript = preload("res://scripts/effects/pokemon_effects/AttackSearchAndAttach.gd")
const AttackSearchAttachToVScript = preload("res://scripts/effects/pokemon_effects/AttackSearchAttachToV.gd")
const AttackReturnEnergyThenBenchDamageScript = preload("res://scripts/effects/pokemon_effects/AttackReturnEnergyThenBenchDamage.gd")
const AttackSwitchSelfToBenchScript = preload("res://scripts/effects/pokemon_effects/AttackSwitchSelfToBench.gd")
const AttackAnyTargetDamageScript = preload("res://scripts/effects/pokemon_effects/AttackAnyTargetDamage.gd")
const AttackSelfDamageCounterTargetDamageScript = preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterTargetDamage.gd")
const AttackTMEvolutionScript = preload("res://scripts/effects/pokemon_effects/AttackTMEvolution.gd")
const AbilityMoveDamageCountersToOpponentScript = preload("res://scripts/effects/pokemon_effects/AbilityMoveDamageCountersToOpponent.gd")
const AbilityMoveOpponentDamageCountersScript = preload("res://scripts/effects/pokemon_effects/AbilityMoveOpponentDamageCounters.gd")


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		var result: bool = _results.pop_front() if not _results.is_empty() else false
		coin_flipped.emit(result)
		return result


class FakeBattleReviewService extends RefCounted:
	var generate_calls: Array[Dictionary] = []

	func generate_review(host: Node, match_dir: String, api_config: Dictionary) -> Dictionary:
		generate_calls.append({
			"host": host,
			"match_dir": match_dir,
			"api_config": api_config.duplicate(true),
		})
		return {"status": "started"}



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
	battle_scene.set("_handover_lbl", Label.new())
	battle_scene.set("_handover_btn", Button.new())
	battle_scene.set("_coin_overlay", Panel.new())
	battle_scene.set("_detail_overlay", Panel.new())
	battle_scene.set("_discard_overlay", Panel.new())
	battle_scene.set("_log_list", ItemList.new())
	battle_scene.set("_lbl_phase", Label.new())
	battle_scene.set("_lbl_turn", Label.new())
	battle_scene.set("_opp_prizes", Label.new())
	battle_scene.set("_opp_deck", Label.new())
	battle_scene.set("_opp_discard", Label.new())
	battle_scene.set("_opp_hand_lbl", Label.new())
	battle_scene.set("_opp_hand_bar", PanelContainer.new())
	battle_scene.set("_opp_prize_hud_count", Label.new())
	battle_scene.set("_opp_deck_hud_value", Label.new())
	battle_scene.set("_opp_discard_hud_value", Label.new())
	battle_scene.set("_my_prizes", Label.new())
	battle_scene.set("_my_deck", Label.new())
	battle_scene.set("_my_discard", Label.new())
	battle_scene.set("_my_prize_hud_count", Label.new())
	battle_scene.set("_my_deck_hud_value", Label.new())
	battle_scene.set("_my_discard_hud_value", Label.new())
	battle_scene.set("_btn_end_turn", Button.new())
	battle_scene.set("_btn_opponent_hand", Button.new())
	battle_scene.set("_hud_end_turn_btn", Button.new())
	battle_scene.set("_stadium_lbl", Label.new())
	battle_scene.set("_btn_stadium_action", Button.new())
	battle_scene.set("_enemy_vstar_value", Label.new())
	battle_scene.set("_my_vstar_value", Label.new())
	battle_scene.set("_enemy_lost_value", Label.new())
	battle_scene.set("_my_lost_value", Label.new())
	battle_scene.set("_hand_container", HBoxContainer.new())
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


func test_battle_setup_scene_includes_first_player_option() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	var first_player_label := scene.find_child("FirstPlayerLabel", true, false)
	var first_player_option := scene.find_child("FirstPlayerOption", true, false)

	return run_checks([
		assert_true(first_player_label is Label, "对战设置页应包含先后攻标签"),
		assert_true(first_player_option is OptionButton, "对战设置页应包含先后攻选项"),
	])


func test_battle_setup_first_player_choice_mapping() -> String:
	var setup := BattleSetupScript.new()

	return run_checks([
		assert_eq(setup._first_player_choice_from_option_index(0), -1, "第 0 项应映射为随机先后攻"),
		assert_eq(setup._first_player_choice_from_option_index(1), 0, "第 1 项应映射为玩家1卡组先攻"),
		assert_eq(setup._first_player_option_index_from_choice(-1), 0, "随机先后攻应回填到第 0 项"),
		assert_eq(setup._first_player_option_index_from_choice(0), 1, "玩家1卡组先攻应回填到第 1 项"),
		assert_eq(setup._first_player_option_index_from_choice(1), 0, "未在 UI 暴露的玩家2先攻应回退到随机项"),
	])


func test_battle_setup_scene_includes_background_gallery() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	var background_label := scene.find_child("BackgroundLabel", true, false)
	var background_gallery := scene.find_child("BackgroundGallery", true, false)
	var background_gallery_row := scene.find_child("BackgroundGalleryRow", true, false)

	return run_checks([
		assert_true(background_label is Label, "对战设置页应包含场地选择标签"),
		assert_true(background_gallery is ScrollContainer, "对战设置页应包含横向场地滚动区"),
		assert_true(background_gallery_row is HBoxContainer, "对战设置页应包含场地缩略图行"),
	])


func test_battle_setup_lists_background_assets() -> String:
	var setup := BattleSetupScript.new()
	var backgrounds: Array[String] = setup._list_available_background_paths()

	return run_checks([
		assert_contains(backgrounds, "res://assets/ui/background.png", "应包含默认背景图"),
		assert_contains(backgrounds, "res://assets/ui/background1.png", "应包含新导入的 background1"),
		assert_eq(backgrounds[0], "res://assets/ui/background.png", "未主动选择时默认背景应为 background.png"),
	])


func test_battle_scene_includes_zeus_help_button() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var zeus_button := scene.find_child("BtnZeusHelp", true, false)
	var back_button := scene.find_child("BtnBack", true, false)

	return run_checks([
		assert_true(zeus_button is Button, "BattleScene 顶栏应包含宙斯帮我按钮"),
		assert_true(back_button is Button, "BattleScene 顶栏应保留退出游戏按钮"),
	])


func test_battle_scene_opponent_hand_button_only_visible_in_vs_ai() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0
	var opponent_hand_button := scene.get("_btn_opponent_hand") as Button

	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene.call("_refresh_ui")
	var hidden_in_two_player := not opponent_hand_button.visible

	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_refresh_ui")
	var visible_in_vs_ai := opponent_hand_button.visible

	return run_checks([
		assert_true(hidden_in_two_player, "对手手牌按钮在双人模式下应隐藏"),
		assert_true(visible_in_vs_ai, "对手手牌按钮在 VS_AI 模式下应显示"),
	])


func test_battle_scene_opponent_hand_viewer_shows_card_previews() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0
	var discard_title := Label.new()
	var discard_overlay := Panel.new()
	var discard_list := ItemList.new()
	var discard_card_row := HBoxContainer.new()
	scene.set("_discard_title", discard_title)
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_discard_list", discard_list)
	scene.set("_discard_card_row", discard_card_row)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opp_hand_a := CardInstance.create(_make_pokemon_cd("AI 手牌A", 70, "L"), 1)
	var opp_hand_b := CardInstance.create(_make_trainer_cd("AI 手牌B", "Item", "debug"), 1)
	gsm.game_state.players[1].hand = [opp_hand_a, opp_hand_b]

	scene.call("_show_opponent_hand_cards")

	return run_checks([
		assert_true(discard_overlay.visible, "点击对手手牌后应打开只读预览层"),
		assert_eq(discard_title.text, "对手手牌（2 张）", "预览层标题应显示对手手牌数量"),
		assert_eq(discard_card_row.get_child_count(), 2, "预览层应按缩略卡图显示对手当前手牌"),
	])


func test_battle_scene_zeus_help_moves_selected_cards_without_consuming_vstar() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.vstar_power_used = [false, false]
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)

	CardInstance.reset_id_counter()
	var deck_a := CardInstance.create(_make_trainer_cd("DeckA", "Item", ""), 0)
	var deck_b := CardInstance.create(_make_trainer_cd("DeckB", "Supporter", ""), 0)
	var deck_c := CardInstance.create(_make_pokemon_cd("DeckC", 70, "C"), 0)
	gsm.game_state.players[0].deck = [deck_a, deck_b, deck_c]
	var dialog_cards: Array = gsm.game_state.players[0].deck.duplicate()

	var chosen: Array[CardInstance] = scene._resolve_zeus_help_selected_cards(0, dialog_cards, PackedInt32Array([1, 2]))
	scene._apply_zeus_help(0, chosen)

	return run_checks([
		assert_eq(chosen.size(), 2, "宙斯帮我应解析出两张被选中的牌"),
		assert_true(deck_b in gsm.game_state.players[0].hand and deck_c in gsm.game_state.players[0].hand, "宙斯帮我应将选中的牌加入手牌"),
		assert_true(deck_a in gsm.game_state.players[0].deck, "未选中的牌应留在牌库"),
		assert_false(gsm.game_state.vstar_power_used[0], "宙斯帮我不应消耗 VSTAR 次数"),
	])


func test_battle_scene_send_out_uses_field_slot_choice() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_send_out_dialog", 0)

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "send_out", "替换上场应保留 send_out pending choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "slot_select", "替换上场应进入场上 slot 选择模式"),
	])


func test_battle_scene_retreat_uses_field_slot_choice() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di_amp: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Amp Deck %d-%d" % [pi, di_amp], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat 1", "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_retreat_dialog", 0)

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "retreat_bench", "Retreat should keep retreat_bench pending choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "slot_select", "Retreat should use field slot selection"),
	])


func test_battle_scene_dreepy_rescue_board_retreats_through_manual_click_flow() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var dreepy_cd: CardData = CardDatabase.get_card("CSV8C", "157")
	var rescue_board_cd: CardData = CardDatabase.get_card("CSV7C", "185")
	var player_state: PlayerState = gsm.game_state.players[0]

	var active := PokemonSlot.new()
	if dreepy_cd != null:
		active.pokemon_stack.append(CardInstance.create(dreepy_cd, 0))
	player_state.active_pokemon = active

	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "C"), 0))
	player_state.bench = [bench]

	var rescue_board: CardInstance = null
	if rescue_board_cd != null:
		rescue_board = CardInstance.create(rescue_board_cd, 0)
		player_state.hand.append(rescue_board)

	if rescue_board != null:
		scene.call("_on_hand_card_clicked", rescue_board, PanelContainer.new())
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		scene.call("_on_slot_input", click, "my_active")

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var actions: Array = (scene.get("_dialog_data") as Dictionary).get("actions", [])
	var retreat_index: int = -1
	for i: int in actions.size():
		var action: Dictionary = actions[i]
		if str(action.get("type", "")) == "retreat":
			retreat_index = i
			break

	scene.call("_handle_dialog_choice", PackedInt32Array([retreat_index]))
	var retreat_dialog_data: Dictionary = scene.get("_dialog_data")
	var preselect_discard: Array = retreat_dialog_data.get("energy_discard", [])
	scene.call("_handle_field_slot_select_index", 0)

	return run_checks([
		assert_not_null(dreepy_cd, "CSV8C_157 Dreepy should exist in the card database"),
		assert_not_null(rescue_board_cd, "CSV7C_185 Rescue Board should exist in the card database"),
		assert_eq(active.attached_tool, rescue_board, "The manual click flow should actually attach Rescue Board to Dreepy"),
		assert_gte(retreat_index, 0, "The active Pokemon action dialog should include a retreat action"),
		assert_eq(preselect_discard.size(), 0, "A zero-cost Rescue Board retreat should not preselect any Energy to discard"),
		assert_eq(player_state.active_pokemon, bench, "Selecting the Benched Pokemon should complete the retreat in the manual UI flow"),
		assert_true(active in player_state.bench, "The former Active Dreepy should return to the Bench after the retreat"),
		assert_eq(active.attached_tool, rescue_board, "Rescue Board should stay attached after the manual retreat resolves"),
	])


func test_battle_scene_heavy_baton_uses_field_slot_choice() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "C"), 0))
	var bench_targets: Array[PokemonSlot] = [bench_a, bench_b]

	scene.call("_show_heavy_baton_dialog", 0, bench_targets, 2, "Heavy Baton")

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "heavy_baton_target", "Heavy Baton should keep heavy_baton_target pending choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "slot_select", "Heavy Baton should use field slot selection"),
	])


func test_battle_scene_effect_step_routes_pokemon_slot_choice_to_field_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var target_a := PokemonSlot.new()
	target_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target A", 90, "C"), 0))
	var target_b := PokemonSlot.new()
	target_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target B", 80, "C"), 0))
	gsm.game_state.players[0].bench = [target_a, target_b]

	var dummy_card := CardInstance.create(_make_trainer_cd("Switch Cart", "Item", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "switch_target",
		"title": "Choose a Benched Pokemon",
		"items": [target_a, target_b],
		"labels": ["A", "B"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, dummy_card)

	return run_checks([
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "PokemonSlot effect steps should stay in effect_interaction flow"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "PokemonSlot effect steps should route to field slot UI"),
	])


func test_battle_scene_field_assignment_builds_entries_without_dialog_targets() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "L"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	var energy_a := CardInstance.create(_make_energy_cd("Lightning A", "L"), 0)
	var energy_b := CardInstance.create(_make_energy_cd("Lightning B", "L"), 0)
	var dummy_card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "energy_assignments",
		"title": "Assign Energy",
		"ui_mode": "card_assignment",
		"source_items": [energy_a, energy_b],
		"source_labels": ["Lightning A", "Lightning B"],
		"target_items": [bench_a, bench_b],
		"target_labels": ["Bench A", "Bench B"],
		"min_select": 1,
		"max_select": 2,
		"allow_cancel": true,
	}]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, dummy_card)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 1)

	var assignments: Array = battle_scene.get("_field_interaction_assignment_entries")
	var first_assignment: Dictionary = assignments[0] if not assignments.is_empty() else {}

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "PokemonSlot assignment targets should route to field assignment UI"),
		assert_eq(assignments.size(), 1, "Choosing a source card and field target should create one assignment entry"),
		assert_eq(first_assignment.get("source"), energy_a, "Assignment should preserve the chosen source card"),
		assert_eq(first_assignment.get("target"), bench_b, "Assignment should preserve the clicked field target"),
	])


func test_battle_scene_boss_orders_routes_real_effect_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active

	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 80, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := EffectBossOrdersScript.new()
	var card := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Boss's Orders should route to field slot selection"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "Boss's Orders should expose opponent bench targets on the field"),
	])


func test_battle_scene_electric_generator_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_lightning_a := PokemonSlot.new()
	bench_lightning_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L A", 90, "L"), 0))
	var bench_lightning_b := PokemonSlot.new()
	bench_lightning_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_lightning_a, bench_lightning_b]

	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_pokemon_cd("Reveal Pokemon", 70, "C"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
		CardInstance.create(_make_trainer_cd("Reveal Item", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Grass", "G"), 0),
	]

	var effect := EffectElectricGeneratorScript.new()
	var card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Electric Generator should route to field assignment UI"),
		assert_eq(int(data.get("source_items", []).size()), 2, "Electric Generator should expose the revealed Lightning Energy cards as source items"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Electric Generator should expose valid Lightning bench targets on the field"),
	])


func test_battle_scene_send_out_positions_panel_upward() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_send_out_dialog", 0)

	return run_checks([
		assert_eq(str(scene.get("_field_interaction_position")), "top", "Own bench selection should move the field panel upward"),
	])


func test_battle_scene_boss_orders_positions_panel_downward() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active

	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 80, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := EffectBossOrdersScript.new()
	var card := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Opponent-only targets should move the field panel downward"),
	])


func test_battle_scene_electric_generator_positions_panel_upward() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_lightning_a := PokemonSlot.new()
	bench_lightning_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L A", 90, "L"), 0))
	var bench_lightning_b := PokemonSlot.new()
	bench_lightning_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_lightning_a, bench_lightning_b]

	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_pokemon_cd("Reveal Pokemon", 70, "C"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
		CardInstance.create(_make_trainer_cd("Reveal Item", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Grass", "G"), 0),
	]

	var effect := EffectElectricGeneratorScript.new()
	var card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Own bench energy targets should move the field panel upward"),
	])


func test_battle_scene_field_interaction_panel_metrics_follow_play_card_size() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.call("_ensure_field_interaction_panel")
	battle_scene.set("_play_card_size", Vector2(112, 156))
	battle_scene.call("_update_field_interaction_panel_metrics", Vector2(1366, 768))

	var panel: PanelContainer = battle_scene.get("_field_interaction_panel")
	var scroll: ScrollContainer = battle_scene.get("_field_interaction_scroll")

	return run_checks([
		assert_eq(scroll.custom_minimum_size.y, 164.0, "Field interaction card strip height should track battlefield card height"),
		assert_eq(panel.custom_minimum_size.y, 250.0, "Field interaction panel height should be derived from the card strip instead of drifting"),
		assert_gte(panel.custom_minimum_size.x, 680.0, "Field interaction panel width should remain wide enough for multi-card assignment UI"),
		assert_true(bool(scroll.size_flags_vertical & Control.SIZE_SHRINK_CENTER), "Field interaction scroll should shrink vertically"),
		assert_true(bool(panel.size_flags_vertical & Control.SIZE_SHRINK_CENTER), "Field interaction panel should shrink vertically"),
	])


func test_battle_scene_field_interaction_metrics_preserve_top_position() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	battle_scene.set("_play_card_size", Vector2(112, 156))

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_lightning_a := PokemonSlot.new()
	bench_lightning_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L A", 90, "L"), 0))
	var bench_lightning_b := PokemonSlot.new()
	bench_lightning_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_lightning_a, bench_lightning_b]
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_pokemon_cd("Reveal Pokemon", 70, "C"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
		CardInstance.create(_make_trainer_cd("Reveal Item", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Grass", "G"), 0),
	]

	var effect := EffectElectricGeneratorScript.new()
	var card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	battle_scene.call("_update_field_interaction_panel_metrics", Vector2(1366, 768))

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Field interaction metric refresh should preserve upward docking for own targets"),
	])


func test_battle_scene_electric_generator_allows_two_field_assignments() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_lightning_a := PokemonSlot.new()
	bench_lightning_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L A", 90, "L"), 0))
	var bench_lightning_b := PokemonSlot.new()
	bench_lightning_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_lightning_a, bench_lightning_b]

	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_pokemon_cd("Reveal Pokemon", 70, "C"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
		CardInstance.create(_make_trainer_cd("Reveal Item", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Grass", "G"), 0),
	]

	var effect := EffectElectricGeneratorScript.new()
	var card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_on_field_assignment_source_chosen", 1)
	battle_scene.call("_handle_field_assignment_target_index", 1)

	var assignments: Array = battle_scene.get("_field_interaction_assignment_entries")

	return run_checks([
		assert_eq(assignments.size(), 2, "Electric Generator should keep accepting a second assignment when two Lightning Energy cards are revealed"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Electric Generator should stay in assignment mode until the player confirms"),
	])


func test_battle_scene_prime_catcher_repositions_between_opponent_and_own_steps() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var my_active := PokemonSlot.new()
	my_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("My Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = my_active
	var my_bench := PokemonSlot.new()
	my_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("My Bench", 90, "C"), 0))
	gsm.game_state.players[0].bench = [my_bench]

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := EffectPrimeCatcherScript.new()
	var card := CardInstance.create(_make_trainer_cd("Prime Catcher", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var first_position: String = str(battle_scene.get("_field_interaction_position"))

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var second_position: String = str(battle_scene.get("_field_interaction_position"))

	return run_checks([
		assert_eq(first_position, "bottom", "Prime Catcher opponent-target step should place the panel downward"),
		assert_eq(second_position, "top", "Prime Catcher own-switch step should move the panel upward"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Prime Catcher second step should still use field slot selection"),
	])


func test_battle_scene_psychic_embrace_switches_from_dialog_to_field_target() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var gardevoir := PokemonSlot.new()
	var gardevoir_card := CardInstance.create(_make_pokemon_cd("Gardevoir ex", 310, "P"), 0)
	gardevoir_card.card_data.effect_id = "abca39bc2f5c5e8da3e8fd3db4b19886"
	gardevoir.pokemon_stack.append(gardevoir_card)
	gsm.game_state.players[0].active_pokemon = gardevoir

	var drifloon := PokemonSlot.new()
	drifloon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Drifloon", 70, "P"), 0))
	gsm.game_state.players[0].bench = [drifloon]
	gsm.game_state.players[0].discard_pile = [CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)]

	var effect := AbilityPsychicEmbraceScript.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(gardevoir_card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "ability", 0, steps, gardevoir_card, gardevoir, 0)
	var first_pending: String = str(battle_scene.get("_pending_choice"))
	var first_field_mode: String = str(battle_scene.get("_field_interaction_mode"))

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var second_pending: String = str(battle_scene.get("_pending_choice"))
	var second_field_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var second_position: String = str(battle_scene.get("_field_interaction_position"))

	return run_checks([
		assert_eq(first_pending, "effect_interaction", "Psychic Embrace should start inside the effect interaction flow"),
		assert_eq(first_field_mode, "", "Discard energy selection should still use the dialog UI"),
		assert_eq(second_pending, "effect_interaction", "After selecting an energy, Psychic Embrace should continue to the target step"),
		assert_eq(second_field_mode, "slot_select", "Pokemon target selection should switch to field slot UI"),
		assert_eq(second_position, "top", "Own Psychic target selection should move the field panel upward"),
	])


func test_battle_scene_energy_switch_rejects_same_slot_target_in_field_assignment() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning A", "L"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench]

	var effect := EffectEnergySwitchScript.new()
	var card := CardInstance.create(_make_trainer_cd("Energy Switch", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	var step: Dictionary = steps[0].duplicate(true) if not steps.is_empty() else {}
	step["max_select"] = 2
	steps = [step]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var initial_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var initial_position: String = str(battle_scene.get("_field_interaction_position"))
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	var rejected_count: int = (battle_scene.get("_field_interaction_assignment_entries") as Array).size()

	battle_scene.call("_handle_field_assignment_target_index", 1)
	var accepted_entries: Array = battle_scene.get("_field_interaction_assignment_entries")
	var accepted_target: Variant = (accepted_entries[0] as Dictionary).get("target") if not accepted_entries.is_empty() else null

	return run_checks([
		assert_eq(initial_mode, "assignment", "Energy Switch should use field assignment UI"),
		assert_eq(initial_position, "top", "Own Energy Switch targets should move the field panel upward"),
		assert_eq(rejected_count, 0, "Energy Switch should reject assigning an energy back onto the same source Pokemon"),
		assert_eq(accepted_entries.size(), 1, "Energy Switch should accept a different target Pokemon"),
		assert_eq(accepted_target, bench, "Accepted assignment should point to the other Pokemon"),
	])


func test_battle_scene_counter_catcher_routes_real_effect_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	gsm.game_state.players[0].prizes = [CardInstance.create(_make_pokemon_cd("My Prize 1", 60, "C"), 0), CardInstance.create(_make_pokemon_cd("My Prize 2", 60, "C"), 0), CardInstance.create(_make_pokemon_cd("My Prize 3", 60, "C"), 0)]
	gsm.game_state.players[1].prizes = [CardInstance.create(_make_pokemon_cd("Opp Prize", 60, "C"), 1)]
	gsm.game_state.players[1].active_pokemon = PokemonSlot.new()
	gsm.game_state.players[1].active_pokemon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := EffectCounterCatcherScript.new()
	var card := CardInstance.create(_make_trainer_cd("Counter Catcher", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Counter Catcher should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Counter Catcher should move the field panel downward for opponent targets"),
	])


func test_battle_scene_pokemon_catcher_heads_route_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 80, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := EffectPokemonCatcherScript.new(RiggedCoinFlipper.new([true]))
	var card := CardInstance.create(_make_trainer_cd("Pokemon Catcher", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Pokemon Catcher on heads should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Pokemon Catcher should move the field panel downward for opponent targets"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "Pokemon Catcher should expose opponent bench targets on the field"),
	])


func test_battle_scene_switch_cart_routes_real_effect_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Basic Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench]

	var effect := EffectSwitchCartScript.new()
	var card := CardInstance.create(_make_trainer_cd("Switch Cart", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Switch Cart should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Switch Cart should move the field panel upward for own bench targets"),
	])


func test_battle_scene_mirage_gate_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench]
	for i: int in 7:
		gsm.game_state.players[0].lost_zone.append(CardInstance.create(_make_trainer_cd("Lost %d" % i, "Item", ""), 0))
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Fire", "R"), 0),
		CardInstance.create(_make_energy_cd("Water", "W"), 0),
		CardInstance.create(_make_energy_cd("Fire Extra", "R"), 0),
	]

	var effect := EffectMirageGateScript.new()
	var card := CardInstance.create(_make_trainer_cd("Mirage Gate", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Mirage Gate should route to field assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Mirage Gate should move the field panel upward for own Pokemon targets"),
		assert_eq(int(data.get("source_items", []).size()), 2, "Mirage Gate should expose up to two different basic energy source cards"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Mirage Gate should expose own field Pokemon targets"),
	])


func test_battle_scene_mirage_gate_logs_when_the_deck_has_no_basic_energy() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	for i: int in 7:
		gsm.game_state.players[0].lost_zone.append(CardInstance.create(_make_trainer_cd("Lost %d" % i, "Item", ""), 0))
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_trainer_cd("Deck Item", "Item", ""), 0),
	]

	var mirage_gate_cd := _make_trainer_cd("Mirage Gate", "Item", "")
	mirage_gate_cd.effect_id = "15b5bf0cc2edae9b9cd0bc24389ad355"
	var card := CardInstance.create(mirage_gate_cd, 0)
	gsm.game_state.players[0].hand.append(card)
	battle_scene.call("_try_play_trainer_with_interaction", 0, card)
	var log_list: ItemList = battle_scene.get("_log_list")
	var last_log: String = log_list.get_item_text(log_list.item_count - 1) if log_list.item_count > 0 else ""

	return run_checks([
		assert_eq(log_list.item_count > 0, true, "Mirage Gate should leave a UI log entry when it whiffs"),
		assert_eq(last_log, "牌库里没有可附着的基本能量，幻象之门没有附着任何能量。", "Mirage Gate should explain the whiff to the player"),
		assert_contains(gsm.game_state.players[0].discard_pile, card, "Mirage Gate should still be discarded after the whiff"),
	])


func test_battle_scene_carmine_click_allows_first_turn_supporter_exception() -> String:
	var scene = _make_battle_scene_stub()

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 1
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.supporter_used_this_turn = false
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var own_active := PokemonSlot.new()
	own_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Own Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = own_active

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active

	scene._gsm = gsm
	scene._view_player = 0

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	for i: int in 4:
		player.hand.append(CardInstance.create(_make_pokemon_cd("Discard %d" % i, 60, "C"), 0))
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_pokemon_cd("Draw %d" % i, 60, "C"), 0))

	var card_data := _make_trainer_cd("CSV8C_199 Carmine", "Supporter", "")
	card_data.effect_id = "8150af4062192998497e376ad931bea4"
	var card := CardInstance.create(card_data, 0)
	player.hand.append(card)
	gsm.effect_processor.register_effect(card_data.effect_id, EffectCarmineScript.new())

	scene.call("_on_hand_card_clicked", card, PanelContainer.new())

	return run_checks([
		assert_eq(player.hand.size(), 5, "BattleScene should let Carmine discard the hand and draw 5 on the first turn going first"),
		assert_eq(player.discard_pile.size(), 5, "BattleScene should discard Carmine plus the previous hand cards"),
		assert_true(gsm.game_state.supporter_used_this_turn, "BattleScene should still mark the supporter as used after Carmine resolves"),
	])


func test_battle_scene_rare_candy_switches_from_dialog_to_field_target() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var basic := PokemonSlot.new()
	var basic_cd := _make_pokemon_cd("Charmander", 70, "R")
	basic.pokemon_stack.append(CardInstance.create(basic_cd, 0))
	basic.turn_played = 1
	gsm.game_state.players[0].active_pokemon = basic

	var stage2_cd := CardData.new()
	stage2_cd.name = "Charizard ex"
	stage2_cd.card_type = "Pokemon"
	stage2_cd.stage = "Stage 2"
	stage2_cd.evolves_from = "Charmeleon"
	stage2_cd.hp = 330
	stage2_cd.energy_type = "R"
	var stage2_card := CardInstance.create(stage2_cd, 0)
	gsm.game_state.players[0].hand = [stage2_card]

	var stage1_cd := CardData.new()
	stage1_cd.name = "Charmeleon"
	stage1_cd.card_type = "Pokemon"
	stage1_cd.stage = "Stage 1"
	stage1_cd.evolves_from = "Charmander"
	stage1_cd.hp = 100
	stage1_cd.energy_type = "R"
	gsm.game_state.players[0].deck = [CardInstance.create(stage1_cd, 0)]

	var effect := EffectRareCandyScript.new()
	var card := CardInstance.create(_make_trainer_cd("Rare Candy", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var first_field_mode: String = str(battle_scene.get("_field_interaction_mode"))

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))

	return run_checks([
		assert_eq(first_field_mode, "", "Rare Candy stage-2 card selection should still use the dialog UI"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Rare Candy target Pokemon selection should switch to field slot UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Rare Candy should move the field panel upward for own Pokemon targets"),
	])


func test_battle_scene_bench_damage_on_play_routes_real_effect_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_user := PokemonSlot.new()
	var user_card := CardInstance.create(_make_pokemon_cd("Bench User", 80, "P"), 0)
	bench_user.pokemon_stack.append(user_card)
	bench_user.turn_played = 3
	gsm.game_state.players[0].bench = [bench_user]

	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 80, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := AbilityBenchDamageOnPlayScript.new(10, 2)
	var steps: Array[Dictionary] = effect.get_interaction_steps(user_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, user_card, bench_user, 0)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Bench damage on play should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Opponent bench multi-select should move the field panel downward"),
		assert_eq(int(data.get("min_select", 0)), 2, "Bench damage on play should require selecting the full number of targets"),
		assert_eq(int(data.get("max_select", 0)), 2, "Bench damage on play should cap selections at the printed number of targets"),
	])


func test_battle_scene_star_portal_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.vstar_power_used = [false, false]
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var palkia_slot := PokemonSlot.new()
	var palkia_card := CardInstance.create(_make_pokemon_cd("Palkia VSTAR", 280, "W"), 0)
	palkia_slot.pokemon_stack.append(palkia_card)
	gsm.game_state.players[0].active_pokemon = palkia_slot
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench Water", 90, "W"), 0))
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[0].discard_pile = [
		CardInstance.create(_make_energy_cd("Water A", "W"), 0),
		CardInstance.create(_make_energy_cd("Water B", "W"), 0),
		CardInstance.create(_make_energy_cd("Water C", "W"), 0),
	]

	var effect := AbilityStarPortalScript.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(palkia_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, palkia_card, palkia_slot, 0)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Star Portal should route to field assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Star Portal should move the field panel upward for own Pokemon targets"),
		assert_eq(int(data.get("source_items", []).size()), 3, "Star Portal should expose up to three Water Energy cards"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Star Portal should expose Water Pokemon targets on the field"),
	])


func test_battle_scene_sadas_vitality_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var ancient_active := PokemonSlot.new()
	var ancient_cd := _make_pokemon_cd("Ancient Active", 120, "F")
	ancient_cd.is_tags = PackedStringArray(["Ancient"])
	ancient_active.pokemon_stack.append(CardInstance.create(ancient_cd, 0))
	gsm.game_state.players[0].active_pokemon = ancient_active

	var ancient_bench := PokemonSlot.new()
	var ancient_bench_cd := _make_pokemon_cd("Ancient Bench", 90, "F")
	ancient_bench_cd.is_tags = PackedStringArray(["Ancient"])
	ancient_bench.pokemon_stack.append(CardInstance.create(ancient_bench_cd, 0))
	gsm.game_state.players[0].bench = [ancient_bench]
	gsm.game_state.players[0].discard_pile = [
		CardInstance.create(_make_energy_cd("Basic A", "F"), 0),
		CardInstance.create(_make_energy_cd("Basic B", "F"), 0),
	]

	var effect := EffectSadasVitalityScript.new()
	var card := CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Sada's Vitality should route to field assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Sada's Vitality should move the field panel upward for own Ancient targets"),
		assert_eq(int(data.get("source_items", []).size()), 2, "Sada's Vitality should expose discard energy cards as sources"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Sada's Vitality should expose Ancient Pokemon targets on the field"),
	])


func test_battle_scene_attach_from_deck_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	var source_card := CardInstance.create(_make_pokemon_cd("Attach Source", 130, "L"), 0)
	active.pokemon_stack.append(source_card)
	gsm.game_state.players[0].active_pokemon = active
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench Target", 90, "L"), 0))
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
	]

	var effect := AbilityAttachFromDeckScript.new("L", 2, "own", false, false)
	var steps: Array[Dictionary] = effect.get_interaction_steps(source_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, source_card, active, 0)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Attach-from-deck abilities should route to field assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Attach-from-deck abilities should move the field panel upward for own targets"),
		assert_eq(int(data.get("source_items", []).size()), 2, "Attach-from-deck abilities should expose matching deck energy cards"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Attach-from-deck abilities should expose own field Pokemon targets"),
	])


func test_battle_scene_attack_switch_self_to_bench_routes_real_attack_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker := PokemonSlot.new()
	var attacker_card := CardInstance.create(_make_pokemon_cd("Attacker", 120, "P"), 0)
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "P"), 0))
	gsm.game_state.players[0].bench = [bench]

	var effect := AttackSwitchSelfToBenchScript.new()
	var attack_data := {"name": "Switch Strike"}
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, attack_data, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Self-switch attacks should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Self-switch attacks should move the field panel upward for own bench targets"),
	])


func test_battle_scene_attack_any_target_damage_routes_real_attack_to_opponent_field() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker := PokemonSlot.new()
	var attacker_card := CardInstance.create(_make_pokemon_cd("Attacker", 120, "P"), 0)
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := AttackAnyTargetDamageScript.new(100)
	var attack_data := {"name": "Any Target Hit"}
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, attack_data, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Chosen-target attacks should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Chosen-target attacks should move the field panel downward for opponent targets"),
		assert_eq(int(data.get("items", []).size()), 2, "Chosen-target attacks should expose both opponent active and bench Pokemon"),
	])


func test_battle_scene_self_damage_counter_attack_routes_real_attack_to_opponent_field() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker := PokemonSlot.new()
	var attacker_card := CardInstance.create(_make_pokemon_cd("Scream Tail", 90, "P"), 0)
	attacker.pokemon_stack.append(attacker_card)
	attacker.damage_counters = 30
	gsm.game_state.players[0].active_pokemon = attacker

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := AttackSelfDamageCounterTargetDamageScript.new(20)
	var attack_data := {"name": "Roaring Scream"}
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, attack_data, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Self-damage-counter attacks should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Self-damage-counter attacks should move the field panel downward for opponent targets"),
	])


func test_battle_scene_tm_evolution_routes_granted_attack_targets_to_field_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Attacker", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = attacker

	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench Basic", 70, "R"), 0))
	gsm.game_state.players[0].bench = [bench]

	var evo_cd := CardData.new()
	evo_cd.name = "Bench Evolution"
	evo_cd.card_type = "Pokemon"
	evo_cd.stage = "Stage 1"
	evo_cd.evolves_from = "Bench Basic"
	evo_cd.hp = 110
	evo_cd.energy_type = "R"
	gsm.game_state.players[0].deck = [CardInstance.create(evo_cd, 0)]

	var effect := AttackTMEvolutionScript.new(2)
	var granted_attack: Dictionary = effect.get_granted_attacks(attacker, gsm.game_state)[0]
	var steps: Array[Dictionary] = effect.get_granted_attack_interaction_steps(attacker, granted_attack, gsm.game_state)
	var tool_card := CardInstance.create(_make_trainer_cd("TM Evolution", "Tool", ""), 0)
	battle_scene.call("_start_effect_interaction", "granted_attack", 0, steps, tool_card, attacker, 0, granted_attack)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "TM Evolution should route bench target selection to field slot UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "TM Evolution should move the field panel upward for own bench targets"),
	])


func test_battle_scene_move_damage_counters_to_opponent_repositions_between_steps() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var user_slot := PokemonSlot.new()
	user_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Munkidori", 90, "D"), 0))
	user_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Dark Energy", "D"), 0))
	gsm.game_state.players[0].active_pokemon = user_slot

	var own_damaged := PokemonSlot.new()
	own_damaged.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Own Damaged", 120, "P"), 0))
	own_damaged.damage_counters = 30
	gsm.game_state.players[0].bench = [own_damaged]

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := AbilityMoveDamageCountersToOpponentScript.new(3)
	var user_card := user_slot.get_top_card()
	var steps: Array[Dictionary] = effect.get_interaction_steps(user_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, user_card, user_slot, 0)
	var first_position: String = str(battle_scene.get("_field_interaction_position"))

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var second_position: String = str(battle_scene.get("_field_interaction_position"))

	return run_checks([
		assert_eq(first_position, "top", "Selecting the damaged own Pokemon should move the panel upward"),
		assert_eq(second_position, "bottom", "Selecting the opponent target should move the panel downward"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "The second step should still use field slot UI"),
	])


func test_battle_scene_move_opponent_damage_counters_keeps_panel_downward() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var user_slot := PokemonSlot.new()
	user_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Radiant Alakazam", 90, "P"), 0))
	gsm.game_state.players[0].active_pokemon = user_slot

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	opp_active.damage_counters = 20
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := AbilityMoveOpponentDamageCountersScript.new()
	var user_card := user_slot.get_top_card()
	var steps: Array[Dictionary] = effect.get_interaction_steps(user_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, user_card, user_slot, 0)
	var first_position: String = str(battle_scene.get("_field_interaction_position"))

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var second_position: String = str(battle_scene.get("_field_interaction_position"))

	return run_checks([
		assert_eq(first_position, "bottom", "Opponent source selection should move the panel downward"),
		assert_eq(second_position, "bottom", "Opponent target selection should keep the panel downward"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "The second step should still use field slot UI"),
	])


func test_battle_scene_loads_selected_background_texture() -> String:
	var previous_background := GameManager.selected_battle_background
	GameManager.selected_battle_background = "res://assets/ui/background1.png"
	var scene := BattleSceneScript.new()
	var resolved_path := scene._resolve_battle_backdrop_path()
	var loaded_texture := scene._load_battle_backdrop_texture()
	GameManager.selected_battle_background = previous_background

	return run_checks([
		assert_eq(resolved_path, "res://assets/ui/background1.png", "BattleScene 应解析到选中的背景路径"),
		assert_not_null(loaded_texture, "应能加载已选择的对战背景"),
	])


# ===================== 弃牌区数据测试 =====================

## 测试：弃牌区初始为空
func test_battle_scene_prize_slots_keep_fixed_grid_positions() -> String:
	var scene := BattleSceneScript.new()
	var slots: Array[BattleCardView] = []
	for _i: int in 6:
		var slot := BattleCardView.new()
		slot.set_compact_preview(true)
		slot.setup_from_instance(null, BattleCardView.MODE_PREVIEW)
		slots.append(slot)

	var player := PlayerState.new()
	var prize_cards: Array[CardInstance] = []
	CardInstance.reset_id_counter()
	for i: int in 6:
		var card := CardInstance.create(_make_pokemon_cd("Prize%d" % i, 60, "C"), 0)
		card.face_up = false
		prize_cards.append(card)
	player.set_prizes(prize_cards)
	player.take_prize_from_slot(1)

	scene.call("_update_prize_slots", slots, player.get_prize_layout(), true)

	return run_checks([
		assert_true(slots[0].visible, "Filled prize slots should stay visible"),
		assert_true(slots[1].visible, "Empty fixed slot should still keep its grid position"),
		assert_true(slots[1].self_modulate.a < 0.1, "Taken prize slots should fade out instead of collapsing"),
		assert_true(slots[2].self_modulate.a > 0.9, "Neighbour prize slots should stay in place and visible"),
	])


func test_battle_scene_prize_selection_titles_highlight_and_reset() -> String:
	var scene = _make_battle_scene_stub()
	var my_title := Label.new()
	var opp_title := Label.new()
	var my_hud_title := Label.new()
	var opp_hud_title := Label.new()
	scene.set("_my_prizes_title", my_title)
	scene.set("_opp_prizes_title", opp_title)
	scene.set("_my_prize_hud_title", my_hud_title)
	scene.set("_opp_prize_hud_title", opp_hud_title)
	scene.set("_view_player", 0)
	scene.set("_pending_choice", "take_prize")
	scene.set("_pending_prize_player_index", 0)
	scene.set("_pending_prize_remaining", 2)
	scene.call("_refresh_prize_titles")

	var pending_my_text: String = my_title.text
	var pending_opp_text: String = opp_title.text
	var pending_my_hud_text: String = my_hud_title.text
	var pending_my_color: Color = my_title.get_theme_color("font_color")
	var pending_my_hud_color: Color = my_hud_title.get_theme_color("font_color")
	var my_title_size: int = my_title.get_theme_font_size("font_size")
	var opp_title_size: int = opp_title.get_theme_font_size("font_size")

	scene.set("_pending_choice", "")
	scene.set("_pending_prize_player_index", -1)
	scene.set("_pending_prize_remaining", 0)
	scene.call("_refresh_prize_titles")

	return run_checks([
		assert_eq(pending_my_text, "选择2张奖赏卡", "Prize selection should replace the player title with the highlighted count prompt"),
		assert_eq(pending_my_hud_text, "选择2张奖赏卡", "Prize selection should also update the field HUD title"),
		assert_eq(pending_opp_text, "对方奖赏", "The non-selecting side should keep its default title"),
		assert_eq(pending_my_color, Color(1.0, 0.87, 0.34, 1.0), "Prize selection title should switch to the highlight color"),
		assert_eq(pending_my_hud_color, Color(1.0, 0.87, 0.34, 1.0), "Prize selection HUD title should switch to the highlight color"),
		assert_eq(my_title_size, 11, "Prize titles should be one size larger in the side panel"),
		assert_eq(opp_title_size, 11, "Opponent prize title should also be one size larger in the side panel"),
		assert_eq(my_title.text, "己方奖赏", "After prize selection, the player title should reset to its default text"),
		assert_eq(opp_title.text, "对方奖赏", "After prize selection, the opponent title should remain at its default text"),
		assert_eq(my_hud_title.text, "己方奖赏", "After prize selection, the HUD title should reset to its default text"),
		assert_eq(my_title.get_theme_color("font_color"), Color(0.93, 0.97, 1.0, 0.9), "After prize selection, the side-panel title should return to its normal color"),
		assert_eq(my_hud_title.get_theme_color("font_color"), Color(0.54, 0.9, 0.94, 0.9), "After prize selection, the HUD title should return to its normal color"),
	])


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
	var field_interaction_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var steps_after_choice: Array = battle_scene.get("_pending_effect_steps")
	var has_assignment_step := steps_after_choice.size() > 1 and str(steps_after_choice[1].get("id", "")) == "bench_damage_counters"

	return run_checks([
		assert_gte(phantom_index, 0, "Phantom Dive should appear in the copied attack options"),
		assert_eq(pending_choice, "effect_interaction", "Selecting Phantom Dive should continue into the follow-up interaction flow"),
		assert_eq(field_interaction_mode, "assignment", "Selecting Phantom Dive should switch into the field assignment interaction mode"),
		assert_true(has_assignment_step, "The queued follow-up step should be bench_damage_counters"),
	])


func test_battle_scene_mela_routes_real_effect_from_field_slot_to_dialog() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Fire Active", 110, "R"), 0))
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Fire Bench", 90, "R"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[0].discard_pile = [
		CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0),
	]

	var mela_card := CardInstance.create(_make_trainer_cd("Mela", "Supporter", ""), 0)
	var steps: Array[Dictionary] = EffectMelaScript.new().get_interaction_steps(mela_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, mela_card)
	battle_scene.call("_handle_field_slot_select_index", 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "", "Mela 选完我方宝可梦后应退出场上点选"),
		assert_true(bool(battle_scene.get("_dialog_overlay").visible), "Mela 第二步应回到弃牌区能量选择弹框"),
		assert_eq(int(battle_scene.get("_pending_effect_step_index")), 1, "Mela 选完目标后应推进到第二个交互步骤"),
	])


func test_battle_scene_attach_basic_energy_from_discard_routes_second_step_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_card := CardInstance.create(_make_pokemon_cd("Discard Attacker", 140, "L"), 0)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 100, "L"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 100, "L"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]
	gsm.game_state.players[0].discard_pile = [
		CardInstance.create(_make_energy_cd("Lightning 1", "L"), 0),
		CardInstance.create(_make_energy_cd("Lightning 2", "L"), 0),
	]

	var effect := AttackAttachBasicEnergyFromDiscardScript.new("L", 2, "own_bench")
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, {}, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1]))

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "弃牌贴能攻击第二步应切到场上选目标"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "给我方宝可梦贴能的场上交互应上移"),
		assert_eq(int(battle_scene.get("_pending_effect_step_index")), 1, "完成能量选择后应推进到目标选择步骤"),
	])


func test_battle_scene_search_and_attach_routes_real_attack_to_field_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_card := CardInstance.create(_make_pokemon_cd("Search Attacker", 140, "L"), 0)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 100, "L"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 100, "L"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning 1", "L"), 0),
		CardInstance.create(_make_trainer_cd("Decoy", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Lightning 2", "L"), 0),
	]

	var effect := AttackSearchAndAttachScript.new("L", 2, "top_n", 5, "bench")
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, {}, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "搜牌库贴能攻击应直接进入场上分配 UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "给我方宝可梦贴能的 assignment UI 应上移"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("source_items", []).size()), 2, "应展示两张可分配的基础能量"),
	])


func test_battle_scene_return_energy_then_bench_damage_routes_second_step_to_opponent_field() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_card := CardInstance.create(_make_pokemon_cd("Bench Sniper", 180, "W"), 0)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(attacker_card)
	attacker.attached_energy = [
		CardInstance.create(_make_energy_cd("Water 1", "W"), 0),
		CardInstance.create(_make_energy_cd("Water 2", "W"), 0),
		CardInstance.create(_make_energy_cd("Water 3", "W"), 0),
	]
	gsm.game_state.players[0].active_pokemon = attacker
	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := AttackReturnEnergyThenBenchDamageScript.new(120, -1, 3)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, {}, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1, 2]))

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "退能打备战攻击第二步应切到场上选对手目标"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "攻击对方场上的目标时 UI 应下移"),
		assert_eq(int(battle_scene.get("_pending_effect_step_index")), 1, "完成退能选择后应推进到备战目标步骤"),
	])


func test_battle_scene_opponent_chooses_step_requests_handover_in_two_player() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opponent_active := PokemonSlot.new()
	opponent_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opponent_active
	var opponent_bench := PokemonSlot.new()
	opponent_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opponent_bench]

	var gust_card := CardInstance.create(_make_pokemon_cd("Iron Bundle", 100, "W"), 0)
	var steps: Array[Dictionary] = AbilityGustFromBenchScript.new().get_interaction_steps(gust_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, gust_card)

	var handover_visible: bool = bool(battle_scene.get("_handover_panel").visible)
	battle_scene.call("_set_handover_panel_visible", false, "test_resume")
	battle_scene.set("_view_player", 1)
	battle_scene.call("_show_next_effect_interaction_step")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(handover_visible, "opponent_chooses 的步骤在双人模式下应先交机给对手"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "交机后应继续进入场上选槽模式"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "交机给对手后应按对手视角上移面板"),
	])


func test_battle_scene_collapsed_stadium_handover_uses_step_chooser_player() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active %d" % pi, 120, "C"), pi))
		player.active_pokemon = active
		for bench_index: int in 5:
			var bench := PokemonSlot.new()
			bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench %d-%d" % [pi, bench_index], 80, "C"), pi))
			player.bench.append(bench)

	var stadium_card := CardInstance.create(_make_trainer_cd("Collapsed Stadium", "Stadium", ""), 0)
	var steps: Array[Dictionary] = EffectCollapsedStadiumScript.new().get_on_play_interaction_steps(stadium_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "play_stadium", 0, steps, stadium_card)
	battle_scene.call("_handle_field_slot_select_index", 0)
	var handover_visible: bool = bool(battle_scene.get("_handover_panel").visible)
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "", "第一位玩家选完后应先等待下一步交机"),
		assert_true(handover_visible, "Collapsed Stadium 轮到对手弃备战时应触发交机提示"),
	])


func test_battle_scene_iron_hands_ui_prize_and_turn_flow() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.state_changed.connect(battle_scene._on_state_changed)
	gsm.player_choice_required.connect(battle_scene._on_player_choice_required)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		my_prize_slots.append(BattleCardView.new())
		opp_prize_slots.append(BattleCardView.new())
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di_amp_ui: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Amp UI Deck %d-%d" % [pi, di_amp_ui], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var iron_hands_cd: CardData = CardDatabase.get_card("CSV6C", "051")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(iron_hands_cd, 0))
	for energy_type: String in ["L", "L", "C", "C"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type, energy_type), 0))
	gsm.effect_processor.register_pokemon_card(iron_hands_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := _make_pokemon_cd("Prize Target", 120, "W")
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	var replacement_slot := PokemonSlot.new()
	replacement_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 120, "W"), 1))
	gsm.game_state.players[1].bench = [replacement_slot]
	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i, 60, "C"), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 1)
	var first_pending_choice: String = str(battle_scene.get("_pending_choice"))
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	var second_pending_choice: String = str(battle_scene.get("_pending_choice"))
	battle_scene.call("_try_take_prize_from_slot", 0, 1)
	var handover_after_second_prize: bool = bool(battle_scene.get("_handover_panel").visible)
	battle_scene.call("_on_handover_confirmed")
	var send_out_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var opp_deck_before_send_out: int = gsm.game_state.players[1].deck.size()
	battle_scene.call("_handle_field_slot_select_index", 0)
	var current_after_send_out: int = gsm.game_state.current_player_index
	var phase_after_send_out: int = gsm.game_state.phase
	var opp_deck_after_send_out: int = gsm.game_state.players[1].deck.size()
	var win_reason_after_send_out: String = gsm.game_state.win_reason
	var view_after_send_out: int = int(battle_scene.get("_view_player"))

	gsm.end_turn(1)
	var handover_back_to_player: bool = bool(battle_scene.get("_handover_panel").visible)
	var current_after_opponent_end: int = gsm.game_state.current_player_index
	var phase_after_opponent_end: int = gsm.game_state.phase
	var view_after_opponent_end: int = int(battle_scene.get("_view_player"))
	var pending_handover_valid: bool = (battle_scene.get("_pending_handover_action") as Callable).is_valid()
	battle_scene.call("_on_handover_confirmed")
	battle_scene.call("_show_attack_dialog", 0, attacker_slot)
	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var amp_action: Dictionary = actions[1] if actions.size() > 1 and actions[1] is Dictionary else {}

	var checks := run_checks([
		assert_eq(first_pending_choice, "take_prize", "Iron Hands ex Amp You Very Much should first enter prize selection"),
		assert_eq(second_pending_choice, "take_prize", "After the first prize, Iron Hands ex should still wait for the second prize"),
		assert_true(handover_after_second_prize, "Two-player mode should hand over to the opponent after the second prize"),
		assert_eq(send_out_mode, "slot_select", "After handover confirmation, Iron Hands ex should open the send-out field selector"),
		assert_eq(opp_deck_before_send_out, 3, "The opponent fixture should still have cards in deck before sending out"),
		assert_eq(current_after_send_out, 1, "After the defending player sends out a replacement, the turn should pass to the opponent"),
		assert_eq(opp_deck_after_send_out, 2, "After the defending player sends out a replacement, they should draw 1 card for turn"),
		assert_eq(phase_after_send_out, GameState.GamePhase.MAIN, "After replacement, the opponent should begin their turn in MAIN"),
		assert_eq(win_reason_after_send_out, "", "After replacement, the game should not immediately end"),
		assert_eq(view_after_send_out, 1, "After replacement, the view should follow the opponent turn"),
		assert_eq(current_after_opponent_end, 0, "After the opponent ends the turn, the current player should switch back to the player"),
		assert_eq(phase_after_opponent_end, GameState.GamePhase.MAIN, "After the opponent ends the turn, the next player should also be in MAIN"),
		assert_eq(view_after_opponent_end, 1, "Before the handover is confirmed, the view should still stay on the opponent side"),
		assert_false(pending_handover_valid, "The handover system should not be stuck with a stale deferred action after the opponent turn ends"),
		assert_true(handover_back_to_player, "After the opponent ends the turn, the UI should prompt to hand over back to the player"),
		assert_true(bool(amp_action.get("enabled", false)), "On the next turn, Amp You Very Much should still be enabled"),
		assert_eq(str(amp_action.get("reason", "")), "", "Amp You Very Much should not keep a stale disable reason"),
	])
	if checks != "":
		GameManager.current_mode = previous_mode
		return checks

	var arm_press_scene = _make_battle_scene_stub()
	var arm_press_gsm := GameStateMachine.new()
	arm_press_gsm.game_state = GameState.new()
	arm_press_gsm.game_state.current_player_index = 0
	arm_press_gsm.game_state.first_player_index = 0
	arm_press_gsm.game_state.turn_number = 2
	arm_press_gsm.game_state.phase = GameState.GamePhase.MAIN
	arm_press_scene.set("_gsm", arm_press_gsm)
	arm_press_scene.set("_view_player", 0)
	arm_press_gsm.state_changed.connect(arm_press_scene._on_state_changed)
	arm_press_gsm.player_choice_required.connect(arm_press_scene._on_player_choice_required)
	arm_press_gsm.action_logged.connect(arm_press_scene._on_action_logged)
	var arm_my_prize_slots: Array[BattleCardView] = []
	var arm_opp_prize_slots: Array[BattleCardView] = []
	for _j: int in 6:
		arm_my_prize_slots.append(BattleCardView.new())
		arm_opp_prize_slots.append(BattleCardView.new())
	arm_press_scene.set("_my_prize_slots", arm_my_prize_slots)
	arm_press_scene.set("_opp_prize_slots", arm_opp_prize_slots)

	for pi2: int in 2:
		var player2 := PlayerState.new()
		player2.player_index = pi2
		for dj: int in 3:
			player2.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi2, dj], 60, "C"), pi2))
		arm_press_gsm.game_state.players.append(player2)

	var arm_attacker := PokemonSlot.new()
	arm_attacker.pokemon_stack.append(CardInstance.create(iron_hands_cd, 0))
	for energy_type2: String in ["L", "L", "C"]:
		arm_attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type2, energy_type2), 0))
	arm_press_gsm.effect_processor.register_pokemon_card(iron_hands_cd)
	arm_press_gsm.game_state.players[0].active_pokemon = arm_attacker
	var arm_defender := PokemonSlot.new()
	arm_defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Arm Press Target", 160, "W"), 1))
	arm_press_gsm.game_state.players[1].active_pokemon = arm_defender
	var arm_replacement := PokemonSlot.new()
	arm_replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 100, "W"), 1))
	arm_press_gsm.game_state.players[1].bench = [arm_replacement]
	for i2: int in 6:
		arm_press_gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i2, 60, "C"), 0))
		arm_press_gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i2, 60, "C"), 1))

	arm_press_scene.call("_try_use_attack_with_interaction", 0, arm_attacker, 0)
	arm_press_scene.call("_try_take_prize_from_slot", 0, 0)
	var handover_visible: bool = bool(arm_press_scene.get("_handover_panel").visible)
	arm_press_scene.call("_on_handover_confirmed")
	arm_press_scene.call("_handle_field_slot_select_index", 0)
	var arm_current_after_send_out: int = arm_press_gsm.game_state.current_player_index
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(handover_visible, "Arm Press knockout should prompt a handover to the opponent"),
		assert_eq(arm_current_after_send_out, 1, "After Arm Press knockout and replacement, the turn should pass to the opponent"),
	])


func test_battle_scene_match_end_review_action_starts_review_instead_of_leaving_battle() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var fake_review_service := FakeBattleReviewService.new()
	battle_scene.set("_battle_review_service", fake_review_service)
	battle_scene.set("_battle_review_match_dir", "user://test_match_end_review")
	battle_scene.set("_battle_review_winner_index", 0)
	battle_scene.set("_battle_review_reason", "knockout")

	battle_scene.call("_show_match_end_dialog", 0, "knockout")
	var dialog_items: Array = battle_scene.get("_dialog_items_data")
	battle_scene.call("_handle_dialog_choice", PackedInt32Array([1]))

	var generate_calls: Array = fake_review_service.generate_calls
	var called_match_dir: String = str((generate_calls[0] as Dictionary).get("match_dir", "")) if not generate_calls.is_empty() and generate_calls[0] is Dictionary else ""
	var review_busy: bool = bool(battle_scene.get("_battle_review_busy"))
	var progress_text: String = str(battle_scene.get("_battle_review_progress_text"))
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(dialog_items.size(), 3, "Match end dialog should include summary, review action, and return action when review is available"),
		assert_eq(str(dialog_items[1]), "生成AI复盘", "The first actionable match end option should be the AI review action"),
		assert_eq(generate_calls.size(), 1, "Choosing the AI review action should start battle review generation"),
		assert_eq(called_match_dir, "user://test_match_end_review", "Battle review generation should use the current match dir"),
		assert_true(review_busy, "Choosing the AI review action should mark review generation as running"),
		assert_eq(progress_text, "正在筛选关键回合...", "Choosing the AI review action should update match end progress text"),
	])


func test_battle_scene_switch_pokemon_routes_real_effect_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	var switch_card := CardInstance.create(_make_trainer_cd("Pokemon Switch", "Item", ""), 0)
	var steps: Array[Dictionary] = EffectSwitchPokemonScript.new("self").get_interaction_steps(switch_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, switch_card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "宝可梦交替应直接进入场上换位选择"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "我方换位交互面板应上移"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "应展示全部可选备战宝可梦"),
	])


func test_battle_scene_search_attach_to_v_routes_real_attack_to_field_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_card := CardInstance.create(_make_pokemon_cd("Arceus VSTAR", 280, "C"), 0)
	attacker_card.card_data.mechanic = "VSTAR"
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker
	var bench_v := PokemonSlot.new()
	var bench_v_card := CardInstance.create(_make_pokemon_cd("Bench V", 220, "L"), 0)
	bench_v_card.card_data.mechanic = "V"
	bench_v.pokemon_stack.append(bench_v_card)
	var bench_non_v := PokemonSlot.new()
	bench_non_v.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench NonV", 100, "L"), 0))
	gsm.game_state.players[0].bench = [bench_v, bench_non_v]
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning 1", "L"), 0),
		CardInstance.create(_make_energy_cd("Water 1", "W"), 0),
		CardInstance.create(_make_energy_cd("Psychic 1", "P"), 0),
	]

	var effect := AttackSearchAttachToVScript.new(3)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, {}, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)
	var targets: Array = (battle_scene.get("_field_interaction_data") as Dictionary).get("target_items", [])

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "三重星应直接进入场上 assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "给我方 V 宝可梦贴能的面板应上移"),
		assert_eq(targets.size(), 2, "应只提供己方 V 宝可梦作为可贴能目标"),
		assert_true(bench_non_v not in targets, "非 V 宝可梦不应出现在三重星的可选目标中"),
	])


func test_battle_scene_run_away_draw_routes_real_ability_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_card := CardInstance.create(_make_pokemon_cd("Run Away", 70, "C"), 0)
	var active := PokemonSlot.new()
	active.pokemon_stack.append(active_card)
	gsm.game_state.players[0].active_pokemon = active
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	var steps: Array[Dictionary] = AbilityRunAwayDrawScript.new(3).get_interaction_steps(active_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, active_card, active, 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "跑路抽牌应在场上选择新的战斗宝可梦"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "我方替换战斗宝可梦的面板应上移"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "应展示全部可选备战宝可梦"),
	])


func test_battle_scene_self_knockout_damage_counters_routes_real_ability_to_opponent_field() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var self_ko_card := CardInstance.create(_make_pokemon_cd("Self KO", 90, "P"), 0)
	var self_ko_slot := PokemonSlot.new()
	self_ko_slot.pokemon_stack.append(self_ko_card)
	gsm.game_state.players[0].active_pokemon = self_ko_slot
	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var steps: Array[Dictionary] = AbilitySelfKnockoutDamageCountersScript.new(5).get_interaction_steps(self_ko_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, self_ko_card, self_ko_slot, 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "自爆放伤害指示物应在场上选择对手目标"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "攻击对方场上的特性目标面板应下移"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "应展示对手全部可选宝可梦"),
	])


func test_battle_scene_used_ability_slots_tilt_right_this_turn() -> String:
	var battle_scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 3
	battle_scene._gsm = gsm

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_panel := PanelContainer.new()
	var active_view := BattleCardViewScript.new()
	active_panel.add_child(active_view)
	battle_scene.set("_slot_card_views", {"my_active": active_view})

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Ability User", 120, "P"), 0))
	active_slot.effects.append({
		"type": "ability_demo_used",
		"turn": gsm.game_state.turn_number,
	})

	battle_scene.call("_refresh_slot_card_view", "my_active", active_slot, true)
	var used_panel := active_view.get("_status_used_panel") as Control
	var used_label := active_view.get("_status_used_label") as Label
	return run_checks([
		assert_true(used_panel != null, "BattleCardView should expose a USED status panel"),
		assert_true(used_panel.visible, "Used-ability active Pokemon should show the USED badge"),
		assert_true(used_label != null, "BattleCardView should expose a USED status label"),
		assert_eq(used_label.text, "USED", "USED badge should use the expected text"),
		assert_true(bool(battle_scene.call("_slot_used_ability_this_turn", active_slot)), "BattleScene should still detect used abilities this turn"),
	])

	return run_checks([
		assert_eq(int(active_view.rotation_degrees), 15, "本回合已用过特性的战斗宝可梦应向右倾斜 15 度"),
		assert_true(bool(battle_scene.call("_slot_used_ability_this_turn", active_slot)), "当回合 ability 标记应被 BattleScene 识别为已用特性"),
	])


func test_battle_scene_used_ability_tilt_resets_next_turn() -> String:
	var battle_scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 3
	battle_scene._gsm = gsm

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_panel := PanelContainer.new()
	var bench_view := BattleCardViewScript.new()
	bench_panel.add_child(bench_view)
	battle_scene.set("_slot_card_views", {"my_bench_0": bench_view})

	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench Ability User", 90, "P"), 0))
	bench_slot.effects.append({
		"type": "ability_demo_used",
		"turn": 3,
	})

	battle_scene.call("_refresh_slot_card_view", "my_bench_0", bench_slot, false)
	var used_panel_now := bench_view.get("_status_used_panel") as Control
	var used_visible_now: bool = used_panel_now != null and used_panel_now.visible
	var tilted_now: float = 15.0
	gsm.game_state.turn_number = 4
	battle_scene.call("_refresh_slot_card_view", "my_bench_0", bench_slot, false)
	var used_panel_next_turn := bench_view.get("_status_used_panel") as Control
	return run_checks([
		assert_true(used_panel_now != null, "BattleCardView should expose a USED status panel"),
		assert_true(used_visible_now, "USED badge should be visible during the turn it was used"),
		assert_true(used_panel_next_turn != null, "BattleCardView should keep the USED status panel after refresh"),
		assert_false(used_panel_next_turn.visible, "USED badge should clear on the next turn"),
		assert_false(bool(battle_scene.call("_slot_used_ability_this_turn", bench_slot)), "Old ability markers should not count next turn"),
	])

	return run_checks([
		assert_eq(int(tilted_now), 15, "备战区宝可梦本回合用过特性时也应倾斜"),
		assert_eq(int(bench_view.rotation_degrees), 0, "到下个回合刷新后应自动回正"),
		assert_false(bool(battle_scene.call("_slot_used_ability_this_turn", bench_slot)), "非当回合的 ability 标记不应继续判定为已用特性"),
	])


func test_battle_scene_used_ability_tilt_adjusts_card_z_index() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(120, 168)
	card_view.size = Vector2(120, 168)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	card_view.set_battle_status({
		"hp_current": 120,
		"hp_max": 120,
		"hp_ratio": 1.0,
		"energy_icons": [],
		"tool_name": "",
		"ability_used_this_turn": true,
	})
	var used_panel := card_view.get("_status_used_panel") as Control
	var used_label := card_view.get("_status_used_label") as Label
	return run_checks([
		assert_true(used_panel != null, "BattleCardView should expose a USED status panel"),
		assert_true(used_panel.visible, "USED badge should be visible when battle status marks ability usage"),
		assert_true(used_label != null, "BattleCardView should expose a USED status label"),
		assert_eq(used_label.text, "USED", "USED badge should render the expected text"),
		assert_eq(int(card_view.rotation_degrees), 0, "Card root should remain upright"),
		assert_eq(int(card_view.z_index), 0, "USED badge should not change card layering"),
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
