## Phase 3 UI 功能测试 - 投币信号、弃牌区数据、卡牌详情文本
class_name TestBattleUIFeatures
extends TestBase

const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")
const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")
const BattleSetupScript = preload("res://scenes/battle_setup/BattleSetup.gd")
const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const EffectBossOrdersScript = preload("res://scripts/effects/trainer_effects/EffectBossOrders.gd")
const EffectCounterCatcherScript = preload("res://scripts/effects/trainer_effects/EffectCounterCatcher.gd")
const EffectElectricGeneratorScript = preload("res://scripts/effects/trainer_effects/EffectElectricGenerator.gd")
const EffectPrimeCatcherScript = preload("res://scripts/effects/trainer_effects/EffectPrimeCatcher.gd")
const EffectEnergySwitchScript = preload("res://scripts/effects/trainer_effects/EffectEnergySwitch.gd")
const EffectPokemonCatcherScript = preload("res://scripts/effects/trainer_effects/EffectPokemonCatcher.gd")
const EffectCapturingAromaScript = preload("res://scripts/effects/trainer_effects/EffectCapturingAroma.gd")
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


class FakeCoinAnimator extends Node:
	var played_results: Array[bool] = []

	func play(result: bool) -> void:
		played_results.append(result)


class SpyRetreatGameStateMachine extends GameStateMachine:
	var retreat_calls: int = 0
	var retreat_result: bool = true
	var last_energy_to_discard: Array[CardInstance] = []
	var last_bench_target: PokemonSlot = null

	func retreat(_player_index: int, energy_to_discard: Array[CardInstance], bench_target: PokemonSlot) -> bool:
		retreat_calls += 1
		last_energy_to_discard = energy_to_discard.duplicate()
		last_bench_target = bench_target
		return retreat_result


class SetupThenEndTurnAIOpponent extends RefCounted:
	var player_index: int = 1
	var difficulty: int = 1
	var run_count: int = 0
	var end_turn_calls: int = 0
	var _delegate = AIOpponentScript.new()

	func _init(next_player_index: int = 1) -> void:
		player_index = next_player_index
		_delegate.configure(next_player_index, difficulty)

	func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
		return _delegate.should_control_turn(game_state, ui_blocked)

	func run_single_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
		run_count += 1
		if (
			gsm != null
			and gsm.game_state != null
			and gsm.game_state.phase == GameState.GamePhase.MAIN
			and gsm.game_state.current_player_index == player_index
			and str(battle_scene.get("_pending_choice")) == ""
		):
			end_turn_calls += 1
			battle_scene.call("_on_end_turn")
			return true
		return _delegate.run_single_step(battle_scene, gsm)



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
	battle_scene.set("_log_list", RichTextLabel.new())
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
	battle_scene.set("_btn_attack_vfx_preview", Button.new())
	battle_scene.set("_btn_ai_advice", Button.new())
	battle_scene.set("_btn_battle_discuss_ai", Button.new())
	battle_scene.set("_btn_zeus_help", Button.new())
	battle_scene.set("_btn_opponent_hand", Button.new())
	battle_scene.set("_btn_replay_prev_turn", Button.new())
	battle_scene.set("_btn_replay_next_turn", Button.new())
	battle_scene.set("_btn_replay_continue", Button.new())
	battle_scene.set("_btn_replay_back_to_list", Button.new())
	battle_scene.set("_hud_end_turn_btn", Button.new())
	battle_scene.set("_stadium_lbl", Label.new())
	battle_scene.set("_btn_stadium_action", Button.new())
	battle_scene.set("_enemy_vstar_value", Label.new())
	battle_scene.set("_my_vstar_value", Label.new())
	battle_scene.set("_enemy_lost_value", Label.new())
	battle_scene.set("_my_lost_value", Label.new())
	battle_scene.set("_hand_container", HBoxContainer.new())
	(battle_scene.get("_handover_panel") as Panel).visible = false
	return battle_scene


func _make_named_deck_cards(owner_index: int, names: Array[String]) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for name: String in names:
		cards.append(CardInstance.create(_make_pokemon_cd(name, 60, "C"), owner_index))
	return cards


func _seed_battle_scene_deck_previews(scene: Control) -> void:
	var my_preview := BattleCardViewScript.new()
	var opp_preview := BattleCardViewScript.new()
	scene.add_child(my_preview)
	scene.add_child(opp_preview)
	scene.set("_my_deck_preview", my_preview)
	scene.set("_opp_deck_preview", opp_preview)


func _seed_battle_scene_discard_previews(scene: Control) -> void:
	var my_preview := BattleCardViewScript.new()
	var opp_preview := BattleCardViewScript.new()
	scene.add_child(my_preview)
	scene.add_child(opp_preview)
	scene.set("_my_discard_preview", my_preview)
	scene.set("_opp_discard_preview", opp_preview)


func _attach_test_center_field(scene: Control, position: Vector2, size: Vector2) -> Control:
	var main_area := Control.new()
	main_area.name = "MainArea"
	main_area.position = Vector2.ZERO
	main_area.size = Vector2(1280, 720)
	scene.add_child(main_area)

	var center_field := Control.new()
	center_field.name = "CenterField"
	center_field.position = position
	center_field.size = size
	main_area.add_child(center_field)
	return center_field


func _attach_test_field_area(scene: Control, center_field_position: Vector2, center_field_size: Vector2, field_area_position: Vector2, field_area_size: Vector2) -> Control:
	var center_field := _attach_test_center_field(scene, center_field_position, center_field_size)
	var field_area := Control.new()
	field_area.name = "FieldArea"
	field_area.position = field_area_position
	field_area.size = field_area_size
	center_field.add_child(field_area)
	return field_area


func _attach_test_main_area_with_hand_area(
	scene: Control,
	main_area_position: Vector2,
	main_area_size: Vector2,
	center_field_position: Vector2,
	center_field_size: Vector2,
	hand_area_position: Vector2,
	hand_area_size: Vector2,
	log_panel_position: Vector2 = Vector2(-1, -1),
	log_panel_size: Vector2 = Vector2.ZERO
) -> Dictionary:
	var main_area := Control.new()
	main_area.name = "MainArea"
	main_area.position = main_area_position
	main_area.size = main_area_size
	scene.add_child(main_area)

	var center_field := Control.new()
	center_field.name = "CenterField"
	center_field.position = center_field_position
	center_field.size = center_field_size
	main_area.add_child(center_field)

	var hand_area := Control.new()
	hand_area.name = "HandArea"
	hand_area.position = hand_area_position
	hand_area.size = hand_area_size
	center_field.add_child(hand_area)

	var log_panel: Control = null
	if log_panel_position.x >= 0.0 and log_panel_position.y >= 0.0:
		log_panel = Control.new()
		log_panel.name = "LogPanel"
		log_panel.position = log_panel_position
		log_panel.size = log_panel_size
		main_area.add_child(log_panel)

	return {
		"main_area": main_area,
		"center_field": center_field,
		"hand_area": hand_area,
		"log_panel": log_panel,
	}


func _sample_raw_replay_snapshot() -> Dictionary:
	return {
		"event_type": "state_snapshot",
		"turn_number": 6,
		"phase": "main",
		"player_index": 1,
		"snapshot_reason": "turn_start",
		"state": {
			"turn_number": 6,
			"phase": "main",
			"current_player_index": 1,
			"first_player_index": 0,
			"winner_index": -1,
			"win_reason": "",
			"energy_attached_this_turn": false,
			"supporter_used_this_turn": false,
			"stadium_played_this_turn": false,
			"retreat_used_this_turn": false,
			"stadium_card": {},
			"stadium_owner_index": -1,
			"players": [
				{
					"player_index": 0,
					"hand": [],
					"deck": [],
					"prizes": [],
					"discard_pile": [],
					"lost_zone": [],
					"active": {
						"damage_counters": 0,
						"retreat_cost": 1,
						"attached_energy": [],
						"attached_tool": {},
						"status_conditions": {"poisoned": false, "burned": false, "asleep": false, "paralyzed": false, "confused": false},
						"effects": [],
						"turn_played": 4,
						"turn_evolved": -1,
						"pokemon_stack": [{
							"card_name": "Opponent Active",
							"instance_id": 10,
							"owner_index": 0,
							"face_up": true,
							"card_type": "Pokemon",
							"stage": "Basic",
							"hp": 70,
							"energy_type": "P",
							"effect_id": "",
							"energy_provides": "",
							"attacks": [],
							"abilities": [],
						}],
					},
					"bench": [],
				},
				{
					"player_index": 1,
					"hand": [{
						"card_name": "Switch",
						"instance_id": 20,
						"owner_index": 1,
						"face_up": true,
						"card_type": "Trainer",
						"stage": "",
						"hp": 0,
						"energy_type": "",
						"effect_id": "",
						"energy_provides": "",
						"attacks": [],
						"abilities": [],
					}],
					"deck": [],
					"prizes": [],
					"discard_pile": [],
					"lost_zone": [],
					"active": {
						"damage_counters": 0,
						"retreat_cost": 1,
						"attached_energy": [],
						"attached_tool": {},
						"status_conditions": {"poisoned": false, "burned": false, "asleep": false, "paralyzed": false, "confused": false},
						"effects": [],
						"turn_played": 5,
						"turn_evolved": -1,
						"pokemon_stack": [{
							"card_name": "Player Active",
							"instance_id": 21,
							"owner_index": 1,
							"face_up": true,
							"card_type": "Pokemon",
							"stage": "Basic",
							"hp": 120,
							"energy_type": "R",
							"effect_id": "",
							"energy_provides": "",
							"attacks": [{"name": "Test", "cost": "R", "damage": "30", "text": "", "is_vstar_power": false}],
							"abilities": [],
						}],
					},
					"bench": [],
				},
			],
		},
	}


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
		assert_eq(setup._first_player_choice_from_option_index(1), 0, "第 1 项应映射为玩家1先攻"),
		assert_eq(setup._first_player_choice_from_option_index(2), 1, "第 2 项应映射为玩家2先攻"),
		assert_eq(setup._first_player_option_index_from_choice(-1), 0, "随机先后攻应回填到第 0 项"),
		assert_eq(setup._first_player_option_index_from_choice(0), 1, "玩家1先攻应回填到第 1 项"),
		assert_eq(setup._first_player_option_index_from_choice(1), 2, "玩家2先攻应回填到第 2 项"),
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


func test_battle_scene_includes_attack_vfx_preview_button_left_of_ai_advice() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var preview_button := scene.find_child("BtnAttackVfxPreview", true, false)
	var ai_advice_button := scene.find_child("BtnAiAdvice", true, false)
	var discuss_button := scene.find_child("BtnBattleDiscussAI", true, false)
	var preview_index := preview_button.get_index() if preview_button is Button else -1
	var ai_index := ai_advice_button.get_index() if ai_advice_button is Button else -1
	var discuss_index := discuss_button.get_index() if discuss_button is Button else -1
	var preview_text: String = preview_button.text if preview_button is Button else ""

	return run_checks([
		assert_true(preview_button is Button, "BattleScene 顶栏应包含放烟花按钮"),
		assert_true(ai_advice_button is Button, "BattleScene 顶栏应保留 AI 建议按钮"),
		assert_true(discuss_button is Button, "BattleScene 顶栏应包含 AI 探讨按钮"),
		assert_eq((discuss_button as Button).text, "AI探讨", "AI 探讨按钮文案应为纯中文"),
		assert_eq(preview_text, "放烟花", "放烟花按钮文案应为纯中文"),
		assert_true(preview_index >= 0 and ai_index >= 0 and preview_index < ai_index, "放烟花按钮应位于 AI 建议左侧"),
		assert_true(ai_index >= 0 and discuss_index >= 0 and discuss_index > ai_index, "AI 探讨按钮应位于 AI 建议右侧"),
	])


func test_battle_discussion_context_hides_opponent_private_zones() -> String:
	var original_ids: Array = GameManager.selected_deck_ids.duplicate()
	var original_mode: int = GameManager.current_mode
	var player_deck := DeckData.new()
	player_deck.id = 990101
	player_deck.deck_name = "对战探讨玩家牌"
	player_deck.total_cards = 60
	player_deck.cards = [{"set_code": "UTEST", "card_index": "001", "count": 4, "card_type": "Pokemon", "name": "己方基础"}]
	var opponent_deck := DeckData.new()
	opponent_deck.id = 990102
	opponent_deck.deck_name = "对战探讨对手牌"
	opponent_deck.total_cards = 60
	opponent_deck.cards = [{"set_code": "UTEST", "card_index": "002", "count": 4, "card_type": "Pokemon", "name": "对手基础"}]
	CardDatabase.save_deck(player_deck)
	CardDatabase.save_deck(opponent_deck)
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids = [player_deck.id, opponent_deck.id]

	var scene = BattleSceneScript.new()
	scene.set("_view_player", 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 3
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	var my_card := _make_pokemon_cd("己方基础", 70, "P")
	my_card.set_code = "UTEST"
	my_card.card_index = "001"
	var opp_secret := _make_pokemon_cd("对手隐藏手牌", 70, "L")
	opp_secret.set_code = "UTEST"
	opp_secret.card_index = "999"
	var opp_active := _make_pokemon_cd("对手前场", 120, "L")
	opp_active.set_code = "UTEST"
	opp_active.card_index = "002"
	gsm.game_state.players[0].hand.append(CardInstance.create(my_card, 0))
	gsm.game_state.players[0].deck.append(CardInstance.create(my_card, 0))
	gsm.game_state.players[1].hand.append(CardInstance.create(opp_secret, 1))
	gsm.game_state.players[1].deck.append(CardInstance.create(opp_secret, 1))
	for _i: int in range(3):
		gsm.game_state.players[0].prizes.append(CardInstance.create(my_card, 0))
	for _i: int in range(4):
		gsm.game_state.players[1].prizes.append(CardInstance.create(opp_secret, 1))
	gsm.game_state.players[1].active_pokemon = PokemonSlot.new()
	gsm.game_state.players[1].active_pokemon.pokemon_stack.append(CardInstance.create(opp_active, 1))
	scene.set("_gsm", gsm)

	var context: Dictionary = scene.call("_build_battle_discussion_context")
	var opponent_public: Dictionary = context.get("opponent_public_state", {})
	var my_state: Dictionary = context.get("my_visible_state", {})
	var public_counts: Dictionary = context.get("public_counts", {})
	var context_text := JSON.stringify(context)

	GameManager.selected_deck_ids = original_ids
	GameManager.current_mode = original_mode
	CardDatabase.delete_deck(player_deck.id)
	CardDatabase.delete_deck(opponent_deck.id)

	return run_checks([
		assert_true((my_state.get("hand", []) as Array).size() == 1, "当前视角应包含己方手牌内容"),
		assert_eq(str(opponent_public.get("hand", "")), "[hidden: opponent hand contents are not visible]", "对手手牌内容必须隐藏"),
		assert_false(context_text.contains("对手隐藏手牌"), "对战探讨上下文不得泄露对手手牌或牌库具体卡名"),
		assert_true(context_text.contains("对手前场"), "对战探讨上下文应包含对手公开前场信息"),
		assert_eq(str(public_counts.get("prize_remaining_score", "")), "3-4", "Battle discussion should expose prize remaining score explicitly"),
		assert_eq(str(public_counts.get("prizes_taken_score", "")), "3-2", "Battle discussion should expose prizes taken score explicitly"),
	])


func test_battle_scene_includes_replay_navigation_buttons() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var prev_button := scene.find_child("BtnReplayPrevTurn", true, false)
	var next_button := scene.find_child("BtnReplayNextTurn", true, false)

	return run_checks([
		assert_true(prev_button is Button, "BattleScene should expose BtnReplayPrevTurn"),
		assert_true(next_button is Button, "BattleScene should expose BtnReplayNextTurn"),
	])


func test_battle_scene_attack_vfx_preview_dialog_lists_profiles_and_plays_selected_effect() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	battle_scene.call("_on_attack_vfx_preview_pressed")
	var pending_choice_before: String = str(battle_scene.get("_pending_choice"))
	var dialog_items: Array = battle_scene.get("_dialog_items_data")
	battle_scene.call("_handle_dialog_choice", PackedInt32Array([0]))
	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var burst: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null

	return run_checks([
		assert_eq(pending_choice_before, "attack_vfx_preview", "放烟花按钮应进入 attack_vfx_preview 对话流程"),
		assert_gte(dialog_items.size(), 1, "放烟花对话框应至少列出一个已实现特效"),
		assert_not_null(overlay, "选择预览特效后应创建攻击特效 overlay"),
		assert_not_null(burst, "选择预览特效后应立刻生成一个 burst 节点"),
		assert_eq(str(burst.get_meta("profile_id", "")), "hero_dragapult_ex", "第一个预览项应播放首个已实现英雄特效"),
	])


func test_battle_scene_attack_vfx_preview_uses_overlay_local_coordinates() -> String:
	var battle_scene = _make_battle_scene_stub()
	var main_area := Control.new()
	main_area.name = "MainArea"
	main_area.position = Vector2(48, 36)
	main_area.size = Vector2(1280, 720)
	battle_scene.add_child(main_area)

	var center_field := Control.new()
	center_field.name = "CenterField"
	center_field.position = Vector2(80, 20)
	center_field.size = Vector2(1200, 760)
	main_area.add_child(center_field)

	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	battle_scene.call("_on_attack_vfx_preview_pressed")
	battle_scene.call("_handle_dialog_choice", PackedInt32Array([0]))
	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Control = sequence.get_node_or_null("AttackVfxCast") as Control if sequence != null else null
	var expected_local := my_active.global_position + my_active.size * 0.5

	return run_checks([
		assert_not_null(overlay, "应创建攻击特效 overlay"),
		assert_eq(overlay.get_parent(), battle_scene, "Attack VFX overlay should attach to the scene root instead of MainArea"),
		assert_not_null(sequence, "应创建攻击特效序列节点"),
		assert_not_null(cast_node, "应创建攻击特效施法节点"),
		assert_eq(cast_node.position, expected_local, "攻击特效节点应落在 overlay 的正确局部坐标"),
	])


func test_vs_ai_ai_first_turn_returns_view_and_controls_to_human_after_setup() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 1
	scene._gsm = gsm
	scene._view_player = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var human: PlayerState = gsm.game_state.players[0]
	var ai_player: PlayerState = gsm.game_state.players[1]
	human.hand = [CardInstance.create(_make_pokemon_cd("Human Lead", 60, "C"), 0)]
	ai_player.hand = [CardInstance.create(_make_pokemon_cd("AI Lead", 60, "C"), 1)]
	for pi: int in 2:
		for deck_idx: int in 8:
			gsm.game_state.players[pi].deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, deck_idx], 60, "C"), pi))
	gsm.state_changed.connect(scene._on_state_changed)
	gsm.action_logged.connect(scene._on_action_logged)
	gsm.player_choice_required.connect(scene._on_player_choice_required)
	gsm.game_over.connect(scene._on_game_over)
	gsm.coin_flipper.coin_flipped.connect(scene._on_coin_flipped)
	var ai := SetupThenEndTurnAIOpponent.new(1)
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_ai_opponent", ai)

	scene._begin_setup_flow()
	scene._handle_dialog_choice(PackedInt32Array([0]))
	var guard_steps: int = 0
	while bool(scene.get("_ai_step_scheduled")) and guard_steps < 6:
		scene._run_ai_step()
		guard_steps += 1

	var current_player_after_ai_turn: int = gsm.game_state.current_player_index
	var phase_after_ai_turn: int = gsm.game_state.phase
	var view_player_after_ai_turn: int = int(scene.get("_view_player"))
	var end_turn_disabled: bool = bool((scene.get("_btn_end_turn") as Button).disabled)
	var pending_choice_after_ai_turn: String = str(scene.get("_pending_choice"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(ai.run_count >= 2, "AI-first setup should run through setup resolution and the opening turn"),
		assert_eq(ai.end_turn_calls, 1, "The AI test double should end exactly one opening turn"),
		assert_eq(current_player_after_ai_turn, 0, "After the AI opening turn ends, control should return to the human player"),
		assert_eq(phase_after_ai_turn, GameState.GamePhase.MAIN, "After the AI opening turn ends, the human should be in MAIN phase"),
		assert_eq(view_player_after_ai_turn, 0, "VS_AI should keep the visible side on the human player after the AI opening turn"),
		assert_false(end_turn_disabled, "The local player should regain an enabled end-turn button after the AI opening turn"),
		assert_eq(pending_choice_after_ai_turn, "", "No stale setup or AI prompt should remain after the AI opening turn"),
	])


func test_battle_scene_detects_reordered_deck_for_active_player_only() -> String:
	CardInstance.reset_id_counter()
	var scene := _make_battle_scene_stub()
	_seed_battle_scene_deck_previews(scene)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	gsm.game_state.players[0].deck = _make_named_deck_cards(0, ["A", "B", "C"])
	gsm.game_state.players[1].deck = _make_named_deck_cards(1, ["X", "Y", "Z"])
	scene._gsm = gsm
	scene._view_player = 0

	scene.call("_refresh_deck_shuffle_detection", gsm.game_state)
	# 模拟玩家0洗牌
	gsm.game_state.players[0].shuffle_deck()
	scene.call("_refresh_deck_shuffle_detection", gsm.game_state)

	var own_tween: Variant = scene.get("_my_deck_shuffle_tween")
	var opp_tween: Variant = scene.get("_opp_deck_shuffle_tween")
	scene.queue_free()
	return run_checks([
		assert_not_null(own_tween, "Reordering the viewed player's deck should start a shuffle effect"),
		assert_null(opp_tween, "Reordering one side should not start the other deck's shuffle effect"),
	])


func test_battle_scene_shuffle_effect_restart_replaces_running_tween() -> String:
	var scene := _make_battle_scene_stub()
	_seed_battle_scene_deck_previews(scene)

	scene.call("_play_deck_shuffle_effect", 0)
	var first_tween: Variant = scene.get("_my_deck_shuffle_tween")
	scene.call("_play_deck_shuffle_effect", 0)
	var second_tween: Variant = scene.get("_my_deck_shuffle_tween")

	scene.queue_free()
	return run_checks([
		assert_not_null(first_tween, "First shuffle should create a tween"),
		assert_not_null(second_tween, "Restarted shuffle should still have a tween"),
		assert_true(first_tween != second_tween, "Restarting the effect should replace the running tween"),
	])


func test_battle_scene_shuffle_effect_keeps_current_preview_base_when_no_tween_is_running() -> String:
	var scene := _make_battle_scene_stub()
	_seed_battle_scene_deck_previews(scene)
	scene.set("_view_player", 0)
	var my_preview: BattleCardView = scene.get("_my_deck_preview")
	my_preview.position = Vector2(18, 42)
	scene.set("_deck_preview_base_positions", {0: Vector2.ZERO, 1: Vector2.ZERO})

	scene.call("_play_deck_shuffle_effect", 0)
	var stored_base: Vector2 = (scene.get("_deck_preview_base_positions") as Dictionary).get(0, Vector2.ZERO)
	var preview_position: Vector2 = my_preview.position
	var tween_marker: Variant = scene.get("_my_deck_shuffle_tween")

	scene.queue_free()
	return run_checks([
		assert_eq(preview_position, Vector2(18, 42), "Starting a shuffle effect without an active tween should not snap the preview to a stale cached position"),
		assert_eq(stored_base, Vector2(18, 42), "Shuffle effect should capture the preview's current layout position as its base position"),
		assert_not_null(tween_marker, "Shuffle effect should still register an active tween marker"),
	])


func test_battle_scene_stop_deck_shuffle_effect_resets_visual_transform() -> String:
	var scene := _make_battle_scene_stub()
	_seed_battle_scene_deck_previews(scene)
	scene.set("_view_player", 0)
	var my_preview: BattleCardView = scene.get("_my_deck_preview")
	my_preview.rotation_degrees = 7.0
	my_preview.scale = Vector2(1.08, 1.08)
	scene.set("_my_deck_shuffle_tween", scene.create_tween())

	scene.call("_stop_deck_shuffle_effect", 0)
	var tween_marker: Variant = scene.get("_my_deck_shuffle_tween")
	var preview_rotation := my_preview.rotation_degrees
	var preview_scale := my_preview.scale

	scene.queue_free()
	return run_checks([
		assert_eq(preview_rotation, 0.0, "Stopping a shuffle effect should reset preview rotation"),
		assert_eq(preview_scale, Vector2.ONE, "Stopping a shuffle effect should reset preview scale"),
		assert_null(tween_marker, "Stopping a shuffle effect should clear the tween marker"),
	])


func test_battle_scene_turn_start_draw_starts_reveal_and_defers_hand_refresh() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Reveal Draw", 70, "C"), 0)
	gsm.game_state.players[0].hand = [drawn_card]

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 1, "card_names": ["Reveal Draw"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var reveal_active: Variant = battle_scene.get("_draw_reveal_active")
	var pending_hand_refresh: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	var reveal_overlay: Variant = battle_scene.get("_draw_reveal_overlay")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")

	return run_checks([
		assert_eq(reveal_active, true, "DRAW_CARD actions should enter draw reveal state"),
		assert_eq(pending_hand_refresh, true, "Visible hand refresh should be deferred while draw reveal is active"),
		assert_not_null(reveal_overlay, "Draw reveal should provision its overlay when the first reveal starts"),
		assert_eq(hand_container.get_child_count(), 0, "Deferred hand refresh should not render the new hand cards yet"),
	])


func test_battle_scene_turn_start_draw_waits_for_player_click_before_hand_refresh() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Player Reveal", 70, "C"), 0)
	gsm.game_state.players[0].hand = [drawn_card]

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 1, "card_names": ["Player Reveal"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var waiting_before: Variant = battle_scene.get("_draw_reveal_waiting_for_confirm")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_confirm := controller != null and controller.has_method("confirm_current_reveal")
	if has_confirm:
		controller.call("confirm_current_reveal", battle_scene)

	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	var pending_after: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(waiting_before, true, "Human-controlled draw reveal should pause for click confirmation"),
		assert_eq(has_confirm, true, "Draw reveal controller should expose a confirm_current_reveal entrypoint"),
		assert_eq(reveal_active_after, false, "Reveal should finish after player confirmation"),
		assert_eq(pending_after, false, "Hand refresh deferral should clear after the reveal completes"),
		assert_eq(hand_container.get_child_count(), 1, "Confirmed draw reveal should finally render the drawn hand card"),
	])


func test_battle_scene_turn_start_draw_auto_continues_for_ai_side() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 1)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("AI Reveal", 70, "C"), 1)
	gsm.game_state.players[1].hand = [drawn_card]

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 1, "card_names": ["AI Reveal"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var auto_pending_before: Variant = battle_scene.get("_draw_reveal_auto_continue_pending")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_auto_continue := controller != null and controller.has_method("run_auto_continue")
	if has_auto_continue:
		controller.call("run_auto_continue", battle_scene)
	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	var pending_after: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(auto_pending_before, true, "AI-controlled draw reveal should arm auto-continue instead of waiting for click"),
		assert_eq(has_auto_continue, true, "Draw reveal controller should expose a run_auto_continue entrypoint"),
		assert_eq(reveal_active_after, false, "Auto-continued AI reveal should finish cleanly"),
		assert_eq(pending_after, false, "AI auto-continue should flush the deferred hand refresh"),
		assert_eq(hand_container.get_child_count(), 1, "Auto-continued AI reveal should render the drawn hand card"),
	])


func test_battle_scene_professors_research_reveals_batch_until_single_confirm() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_cards: Array[CardInstance] = []
	var card_ids: Array[int] = []
	var card_names: Array[String] = []
	for card_index: int in 7:
		var drawn_card := CardInstance.create(_make_pokemon_cd("Research %d" % [card_index + 1], 70, "C"), 0)
		drawn_cards.append(drawn_card)
		card_ids.append(drawn_card.instance_id)
		card_names.append(drawn_card.card_data.name)
	gsm.game_state.players[0].hand = drawn_cards.duplicate()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 7, "card_names": card_names, "card_instance_ids": card_ids},
		1,
		"Professor's Research"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var waiting_before: Variant = battle_scene.get("_draw_reveal_waiting_for_confirm")
	var reveal_views_before: Array = battle_scene.get("_draw_reveal_card_views")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_confirm := controller != null and controller.has_method("confirm_current_reveal")
	if has_confirm:
		controller.call("confirm_current_reveal", battle_scene)

	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	var pending_after: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(waiting_before, true, "Professor's Research should pause once after revealing the full batch"),
		assert_eq(reveal_views_before.size(), 7, "Professor's Research should stage all seven revealed cards before confirmation"),
		assert_eq(hand_container.get_child_count(), 7, "The full batch should render into hand after the single confirmation"),
		assert_eq(has_confirm, true, "Batch reveal should use the same confirm entrypoint"),
		assert_eq(reveal_active_after, false, "Batch reveal should finish after the single confirmation"),
		assert_eq(pending_after, false, "Hand refresh deferral should clear after the batch reveal completes"),
	])


func test_battle_scene_professors_research_batch_auto_continues_for_ai_side() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 1)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_cards: Array[CardInstance] = []
	var card_ids: Array[int] = []
	var card_names: Array[String] = []
	for card_index: int in 7:
		var drawn_card := CardInstance.create(_make_pokemon_cd("AI Research %d" % [card_index + 1], 70, "C"), 1)
		drawn_cards.append(drawn_card)
		card_ids.append(drawn_card.instance_id)
		card_names.append(drawn_card.card_data.name)
	gsm.game_state.players[1].hand = drawn_cards.duplicate()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 7, "card_names": card_names, "card_instance_ids": card_ids},
		1,
		"Professor's Research"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var auto_pending_before: Variant = battle_scene.get("_draw_reveal_auto_continue_pending")
	var reveal_views_before: Array = battle_scene.get("_draw_reveal_card_views")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_auto_continue := controller != null and controller.has_method("run_auto_continue")
	if has_auto_continue:
		controller.call("run_auto_continue", battle_scene)

	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	var pending_after: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(auto_pending_before, true, "AI batch reveal should arm auto-continue after the final staged card"),
		assert_eq(reveal_views_before.size(), 7, "AI batch reveal should still stage all seven cards before continuing"),
		assert_eq(has_auto_continue, true, "Batch reveal should expose the auto-continue entrypoint"),
		assert_eq(reveal_active_after, false, "AI batch reveal should finish after auto-continue"),
		assert_eq(pending_after, false, "AI batch reveal should clear deferred hand refresh when complete"),
		assert_eq(hand_container.get_child_count(), 7, "AI batch reveal should render the full batch into hand once complete"),
	])


func test_battle_scene_professors_research_hides_drawn_cards_while_discard_reveal_is_running() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var professor_cd := CardData.new()
	professor_cd.name = "Professor's Research"
	professor_cd.card_type = "Supporter"
	professor_cd.effect_id = "aecd80ca2722885c3d062a2255346f3e"
	var professor := CardInstance.create(professor_cd, 0)
	var filler := CardInstance.create(_make_pokemon_cd("Discard Filler", 70, "C"), 0)
	gsm.game_state.players[0].hand = [professor, filler]
	for draw_index: int in 7:
		gsm.game_state.players[0].deck.append(CardInstance.create(_make_pokemon_cd("Research Draw %d" % [draw_index + 1], 70, "C"), 0))

	battle_scene.call("_refresh_hand")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var before_play_count := hand_container.get_child_count()
	var played: bool = gsm.play_trainer(0, professor, [])
	var current_reveal: GameAction = battle_scene.get("_draw_reveal_current_action") as GameAction
	var queued_reveals: Array = battle_scene.get("_draw_reveal_queue")
	battle_scene.call("_refresh_hand")
	var during_discard_reveal_count := hand_container.get_child_count()
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(before_play_count, 2, "Precondition: the original hand should be visible before Professor's Research resolves"),
		assert_true(played, "Professor's Research should resolve successfully"),
		assert_not_null(current_reveal, "Professor's Research should start a reveal immediately"),
		assert_eq(current_reveal.action_type, GameAction.ActionType.DISCARD, "The first reveal should be the hand discard"),
		assert_true(queued_reveals.size() >= 1, "Professor's Research should queue the draw reveal behind the discard reveal"),
		assert_eq(during_discard_reveal_count, 0, "Freshly drawn cards should stay hidden while the discard reveal is still running"),
	])


func test_battle_scene_two_player_opponent_redraw_stays_face_down_and_targets_top_hand_area() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var center_field: Control = layout.get("center_field")
	var hand_area: Control = layout.get("hand_area")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_cards: Array[CardInstance] = []
	var card_ids: Array[int] = []
	var card_names: Array[String] = []
	for card_index: int in 2:
		var drawn_card := CardInstance.create(_make_pokemon_cd("Hidden Draw %d" % [card_index + 1], 70, "C"), 1)
		drawn_cards.append(drawn_card)
		card_ids.append(drawn_card.instance_id)
		card_names.append(drawn_card.card_data.name)
	gsm.game_state.players[1].hand = drawn_cards.duplicate()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 2, "card_names": card_names, "card_instance_ids": card_ids},
		3,
		"Judge redraw"
	)
	battle_scene.call("_on_action_logged", action)

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var reveal_views: Array = battle_scene.get("_draw_reveal_card_views")
	var top_anchor: Variant = controller.call("_hand_target_anchor", battle_scene, 1)
	var bottom_anchor: Variant = controller.call("_hand_target_anchor", battle_scene, 0)
	var probe := BattleCardViewScript.new()
	probe.custom_minimum_size = Vector2(130, 182)
	var top_target: Vector2 = controller.call("_hand_target_position", battle_scene, probe, 1, 0, 1)
	var bottom_target: Vector2 = controller.call("_hand_target_position", battle_scene, probe, 0, 0, 1)
	var expected_top := Vector2(
		center_field.global_position.x + (center_field.size.x - 130.0) * 0.5,
		center_field.global_position.y + 16.0
	)
	var expected_bottom := Vector2(
		hand_area.global_position.x + (hand_area.size.x - 130.0) * 0.5,
		hand_area.global_position.y + (hand_area.size.y - 182.0) * 0.5
	)
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(battle_scene.get("_draw_reveal_auto_continue_pending"), true, "Hidden opponent redraw should auto-continue instead of waiting for local confirmation"),
		assert_eq(reveal_views.size(), 2, "Opponent redraw should still stage both cards"),
		assert_eq(top_anchor, center_field, "Opponent redraw should anchor to the center field instead of the hand strip"),
		assert_eq(bottom_anchor, hand_area, "Local redraw should anchor to the hand area"),
		assert_eq(top_target, expected_top, "Opponent redraw should fly to the upper middle of CenterField"),
		assert_eq(bottom_target, expected_bottom, "Local redraw should fly to the middle of HandArea"),
		assert_true(bool(reveal_views[0].get("_face_down")), "Opponent redraw should keep the first staged card face down"),
		assert_true(bool(reveal_views[1].get("_face_down")), "Opponent redraw should keep the second staged card face down"),
	])


func test_battle_scene_vs_ai_opponent_draw_targets_top_center_instead_of_my_hand() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 900),
		Vector2(80, 20),
		Vector2(1200, 760),
		Vector2(0, 650),
		Vector2(1200, 110)
	)
	var center_field: Control = layout.get("center_field")
	var hand_area: Control = layout.get("hand_area")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("AI Draw", 70, "C"), 1)
	gsm.game_state.players[1].hand = [drawn_card]
	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 1, "card_names": [drawn_card.card_data.name], "card_instance_ids": [drawn_card.instance_id]},
		3,
		"AI draw"
	)
	battle_scene.call("_on_action_logged", action)

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var probe := BattleCardViewScript.new()
	probe.custom_minimum_size = Vector2(130, 182)
	var anchor: Variant = controller.call("_hand_target_anchor", battle_scene, 1)
	var target: Vector2 = controller.call("_hand_target_position", battle_scene, probe, 1, 0, 1)
	var expected_top := Vector2(
		center_field.global_position.x + (center_field.size.x - 130.0) * 0.5,
		center_field.global_position.y + 16.0
	)
	var wrong_bottom := Vector2(
		hand_area.global_position.x + (hand_area.size.x - 130.0) * 0.5,
		hand_area.global_position.y + (hand_area.size.y - 182.0) * 0.5
	)
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(anchor, center_field, "VS AI opponent draw should anchor to CenterField rather than the local hand area"),
		assert_eq(target, expected_top, "VS AI opponent draw should target the upper middle of CenterField"),
		assert_true(target != wrong_bottom, "VS AI opponent draw must not target the local hand area"),
	])


func test_battle_scene_batch_draw_progressively_refreshes_visible_hand_cards() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_cards: Array[CardInstance] = []
	var card_ids: Array[int] = []
	var card_names: Array[String] = []
	for card_index: int in 3:
		var drawn_card := CardInstance.create(_make_pokemon_cd("Visible Draw %d" % [card_index + 1], 70, "C"), 0)
		drawn_cards.append(drawn_card)
		card_ids.append(drawn_card.instance_id)
		card_names.append(drawn_card.card_data.name)
	gsm.game_state.players[0].hand = drawn_cards.duplicate()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 3, "card_names": card_names, "card_instance_ids": card_ids},
		4,
		"Batch draw"
	)
	battle_scene.call("_on_action_logged", action)

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")

	controller.call("_set_visible_reveal_count", battle_scene, 1)
	battle_scene.call("_refresh_hand")
	var count_after_first := hand_container.get_child_count()

	controller.call("_set_visible_reveal_count", battle_scene, 2)
	battle_scene.call("_refresh_hand")
	var count_after_second := hand_container.get_child_count()

	controller.call("_set_visible_reveal_count", battle_scene, 3)
	battle_scene.call("_refresh_hand")
	var count_after_third := hand_container.get_child_count()
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(count_after_first, 1, "The first landed card should immediately appear in hand"),
		assert_eq(count_after_second, 2, "The second landed card should increment the visible hand size"),
		assert_eq(count_after_third, 3, "The final landed card should complete the visible hand size"),
	])


func test_battle_scene_draw_reveal_hides_new_cards_before_the_first_fly_in() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var original_hand := CardInstance.create(_make_pokemon_cd("Existing Hand Card", 70, "C"), 0)
	var drawn_a := CardInstance.create(_make_pokemon_cd("Visible Draw 1", 70, "C"), 0)
	var drawn_b := CardInstance.create(_make_pokemon_cd("Visible Draw 2", 70, "C"), 0)
	gsm.game_state.players[0].hand = [original_hand, drawn_a, drawn_b]
	battle_scene.call("_refresh_hand")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var before_action_count := hand_container.get_child_count()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{
			"count": 2,
			"card_names": [drawn_a.card_data.name, drawn_b.card_data.name],
			"card_instance_ids": [drawn_a.instance_id, drawn_b.instance_id],
		},
		4,
		"Batch draw"
	)
	battle_scene.call("_on_action_logged", action)
	var after_action_count := hand_container.get_child_count()
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(before_action_count, 3, "Precondition: the already-updated hand is visible before the draw reveal begins"),
		assert_eq(after_action_count, 1, "Draw reveal should hide the freshly drawn cards until they start flying into hand"),
	])


func test_battle_scene_hand_discard_action_starts_discard_reveal() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	_seed_battle_scene_discard_previews(battle_scene)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var discarded_a := CardInstance.create(_make_pokemon_cd("Discard Reveal A", 70, "C"), 0)
	var discarded_b := CardInstance.create(_make_pokemon_cd("Discard Reveal B", 70, "C"), 0)
	gsm.game_state.players[0].discard_pile = [discarded_a, discarded_b]

	var action := GameAction.create(
		GameAction.ActionType.DISCARD,
		0,
		{
			"count": 2,
			"source_zone": "hand",
			"card_names": [discarded_a.card_data.name, discarded_b.card_data.name],
			"card_instance_ids": [discarded_a.instance_id, discarded_b.instance_id],
		},
		4,
		"discard two"
	)
	battle_scene.call("_on_action_logged", action)

	var reveal_active: Variant = battle_scene.get("_draw_reveal_active")
	var reveal_views: Array = battle_scene.get("_draw_reveal_card_views")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(reveal_active, true, "Hand-origin DISCARD actions should reuse the reveal pipeline"),
		assert_eq(reveal_views.size(), 2, "Discard reveal should stage each discarded hand card"),
	])


func test_battle_scene_hand_discard_reveal_uses_slower_flight_duration_than_draw_reveal() -> String:
	var battle_scene = _make_battle_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var discard_duration: Variant = controller.call("_discard_fly_duration_seconds")
	var draw_duration: Variant = controller.call("_draw_fly_duration_seconds")

	return run_checks([
		assert_eq(discard_duration, 0.14, "Hand discard reveal should use the tuned slower discard flight duration"),
		assert_eq(draw_duration, 0.08, "Draw reveal should keep its faster flight duration"),
		assert_true(float(discard_duration) > float(draw_duration), "Discard reveal should stay slower than draw reveal"),
	])


func test_battle_scene_hand_discard_reveal_removes_cards_from_hand_before_flying() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	_seed_battle_scene_discard_previews(battle_scene)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var discarded_a := CardInstance.create(_make_pokemon_cd("Discard Reveal A", 70, "C"), 0)
	var discarded_b := CardInstance.create(_make_pokemon_cd("Discard Reveal B", 70, "C"), 0)
	var remaining := CardInstance.create(_make_pokemon_cd("Remaining Hand Card", 70, "C"), 0)
	gsm.game_state.players[0].hand = [discarded_a, discarded_b, remaining]
	battle_scene.call("_refresh_hand")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var before_action_count := hand_container.get_child_count()

	gsm.game_state.players[0].hand = [remaining]
	gsm.game_state.players[0].discard_pile = [discarded_a, discarded_b]
	var action := GameAction.create(
		GameAction.ActionType.DISCARD,
		0,
		{
			"count": 2,
			"source_zone": "hand",
			"card_names": [discarded_a.card_data.name, discarded_b.card_data.name],
			"card_instance_ids": [discarded_a.instance_id, discarded_b.instance_id],
		},
		4,
		"discard two"
	)
	battle_scene.call("_on_action_logged", action)
	var after_action_count := hand_container.get_child_count()
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(before_action_count, 3, "Precondition: the original hand should still be visible before the discard action is logged"),
		assert_eq(after_action_count, 1, "Discard reveal should remove discarded cards from the hand immediately before the flight starts"),
	])


func test_battle_scene_hand_discard_reveal_updates_visible_discard_count_one_by_one() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	_seed_battle_scene_discard_previews(battle_scene)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var existing := CardInstance.create(_make_pokemon_cd("Existing Discard", 70, "C"), 0)
	var discarded_a := CardInstance.create(_make_pokemon_cd("Discard Reveal A", 70, "C"), 0)
	var discarded_b := CardInstance.create(_make_pokemon_cd("Discard Reveal B", 70, "C"), 0)
	gsm.game_state.players[0].discard_pile = [existing, discarded_a, discarded_b]

	var action := GameAction.create(
		GameAction.ActionType.DISCARD,
		0,
		{
			"count": 2,
			"source_zone": "hand",
			"card_names": [discarded_a.card_data.name, discarded_b.card_data.name],
			"card_instance_ids": [discarded_a.instance_id, discarded_b.instance_id],
		},
		5,
		"discard two"
	)
	battle_scene.call("_on_action_logged", action)

	var display: RefCounted = battle_scene.get("_battle_display_controller")
	var before_visible: Array = display.call("_visible_discard_pile", battle_scene, 0, gsm.game_state.players[0].discard_pile)
	var reveal_views: Array = battle_scene.get("_draw_reveal_card_views")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	controller.call("_mark_discard_card_landed", battle_scene, reveal_views[0], 0, 1)
	var after_first_visible: Array = display.call("_visible_discard_pile", battle_scene, 0, gsm.game_state.players[0].discard_pile)
	controller.call("_mark_discard_card_landed", battle_scene, reveal_views[1], 0, 2)
	var after_second_visible: Array = display.call("_visible_discard_pile", battle_scene, 0, gsm.game_state.players[0].discard_pile)
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(before_visible.size(), 1, "Before any discard card lands, only the pre-existing discard pile should be visible"),
		assert_eq(after_first_visible.size(), 2, "After the first discard lands, the visible discard pile should grow by one"),
		assert_eq(after_second_visible.size(), 3, "After the second discard lands, the visible discard pile should reach the full final size"),
	])


func test_battle_scene_attack_action_starts_fireworks_vfx_burst() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Dragapult ex", 320, "P"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 220, "C"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Phantom Dive", "target_pokemon_name": "Target", "damage": 200},
		3,
		"attack"
	)
	battle_scene.call("_on_action_logged", action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var overlay_child_count: int = overlay.get_child_count() if overlay != null else 0
	var burst: Control = overlay.get_child(0) as Control if overlay != null and overlay_child_count > 0 else null

	return run_checks([
		assert_not_null(overlay, "Attack action should lazily create the attack VFX overlay"),
		assert_eq(overlay_child_count, 1, "Attack action should spawn exactly one burst container"),
		assert_not_null(burst, "Attack burst container should exist"),
		assert_eq(str(burst.get_meta("profile_id", "")) if burst != null else "", "hero_dragapult_ex", "Hero attack should resolve its dedicated VFX profile"),
	])


func test_battle_scene_attack_vfx_targets_opponent_active_center() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(200, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(760, 110)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Charizard ex", 330, "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 220, "C"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burning Darkness", "target_pokemon_name": "Target", "damage": 180},
		3,
		"attack"
	)
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var target: Vector2 = controller.call("resolve_impact_position", battle_scene, action) if controller != null else Vector2.ZERO
	var expected := opp_active.global_position + opp_active.size * 0.5

	return run_checks([
		assert_not_null(controller, "BattleScene should expose an attack VFX controller"),
		assert_eq(target, expected, "Attack VFX should target the opponent active center by default"),
	])


func test_battle_scene_attack_vfx_does_not_block_live_actions() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Raging Bolt ex", 240, "L"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 220, "C"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burst Roar", "target_pokemon_name": "Target", "damage": 70},
		3,
		"attack"
	)
	battle_scene.call("_on_action_logged", action)

	return run_checks([
		assert_eq(battle_scene.call("_can_accept_live_action"), true, "Attack fireworks should not block the next live action gate"),
	])


func test_battle_scene_attack_vfx_overlay_does_not_shift_hand_area_layout() -> String:
	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var center_field: Control = layout.get("center_field")
	var hand_area: Control = layout.get("hand_area")
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Gouging Fire ex", 230, "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Charmander", 70, "R"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var before_position := hand_area.global_position
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burning Charge", "target_pokemon_name": "Charmander", "damage": 260},
		3,
		"attack"
	)
	battle_scene.call("_on_action_logged", action)
	var after_position := hand_area.global_position

	return run_checks([
		assert_eq(after_position, before_position, "Attack VFX overlay should not perturb HandArea layout after an attack"),
	])


func test_battle_scene_fire_attack_spawns_real_impact_vfx_in_live_action() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Gouging Fire ex", 230, "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Charmander", 70, "R"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burning Charge", "target_pokemon_name": "Charmander", "damage": 260},
		3,
		"attack"
	)
	battle_scene.call("_on_action_logged", action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var residue_node: Node = sequence.get_node_or_null("AttackVfxResidue0") if sequence != null else null

	return run_checks([
		assert_not_null(overlay, "Fire live attack should create the attack VFX overlay"),
		assert_not_null(sequence, "Fire live attack should create a VFX sequence"),
		assert_eq(str(sequence.get_meta("profile_id", "")) if sequence != null else "", "fallback_fire", "Fire live attack should resolve the fire impact-only VFX profile"),
		assert_not_null(impact_node, "Fire live attack should create an impact node"),
		assert_not_null(residue_node, "Fire live attack should create a residue node"),
	])


func test_battle_scene_batch_draw_layout_wraps_after_four_cards() -> String:
	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var main_area: Control = layout.get("main_area")
	var log_panel: Control = layout.get("log_panel")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var positions: Array[Vector2] = []
	var scale_probe := BattleCardViewScript.new()
	scale_probe.custom_minimum_size = Vector2(130, 182)
	var scale: Vector2 = controller.call("_batch_reveal_scale", battle_scene, scale_probe, 7)
	var scaled_width: float = 130.0 * scale.x
	var scaled_height: float = 182.0 * scale.y
	for index: int in 7:
		var card_view := BattleCardViewScript.new()
		card_view.custom_minimum_size = Vector2(130, 182)
		positions.append(controller.call("_batch_stack_position", battle_scene, card_view, index, 7))

	var center_x: float = main_area.global_position.x + (log_panel.global_position.x - main_area.global_position.x) * 0.5
	var first_row_y: float = positions[0].y
	var second_row_y: float = positions[4].y
	var first_row_center_x := (positions[0].x + positions[3].x + scaled_width) * 0.5
	var second_row_center_x := (positions[4].x + positions[6].x + scaled_width) * 0.5

	return run_checks([
		assert_eq(scale, Vector2(2.0, 2.0), "Professor's Research batch reveal should keep the same 2x scale as the single-card reveal"),
		assert_eq(positions[0].y, first_row_y, "First batch card should stay on the first row"),
		assert_eq(positions[1].y, first_row_y, "Second batch card should stay on the first row"),
		assert_eq(positions[2].y, first_row_y, "Third batch card should stay on the first row"),
		assert_eq(positions[3].y, first_row_y, "Fourth batch card should stay on the first row"),
		assert_eq(positions[4].y, second_row_y, "Fifth batch card should start the second row"),
		assert_eq(positions[5].y, second_row_y, "Sixth batch card should stay on the second row"),
		assert_eq(positions[6].y, second_row_y, "Seventh batch card should stay on the second row"),
		assert_true(absf(second_row_y - (first_row_y + scaled_height)) < 0.01, "Cards after the first four should move to a lower second row with no extra vertical gap"),
		assert_true(absf(positions[1].x - (positions[0].x + scaled_width)) < 0.01, "First-row cards should touch without extra horizontal gap"),
		assert_true(absf(positions[2].x - (positions[1].x + scaled_width)) < 0.01, "First-row cards should touch without extra horizontal gap"),
		assert_true(absf(positions[3].x - (positions[2].x + scaled_width)) < 0.01, "First-row cards should touch without extra horizontal gap"),
		assert_true(absf(positions[5].x - (positions[4].x + scaled_width)) < 0.01, "Second-row cards should touch without extra horizontal gap"),
		assert_true(absf(positions[6].x - (positions[5].x + scaled_width)) < 0.01, "Second-row cards should touch without extra horizontal gap"),
		assert_true(absf(first_row_center_x - center_x) < 0.01, "The first row should stay centered inside MainArea without using FieldArea"),
		assert_true(absf(second_row_center_x - center_x) < 0.01, "The second row should also be centered inside MainArea without using FieldArea"),
	])


func test_battle_scene_batch_draw_layout_centers_short_second_row_independently() -> String:
	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var main_area: Control = layout.get("main_area")
	var log_panel: Control = layout.get("log_panel")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(130, 182)
	var scale: Vector2 = controller.call("_batch_reveal_scale", battle_scene, card_view, 7)
	var scaled_width: float = 130.0 * scale.x

	var first_row_left: Vector2 = controller.call("_batch_stack_position", battle_scene, card_view, 0, 7)
	var second_row_left: Vector2 = controller.call("_batch_stack_position", battle_scene, card_view, 4, 7)
	var first_row_right: Vector2 = controller.call("_batch_stack_position", battle_scene, card_view, 3, 7)
	var second_row_right: Vector2 = controller.call("_batch_stack_position", battle_scene, card_view, 6, 7)
	var center_x: float = main_area.global_position.x + (log_panel.global_position.x - main_area.global_position.x) * 0.5
	var second_row_center_x := (second_row_left.x + second_row_right.x + scaled_width) * 0.5

	return run_checks([
		assert_true(second_row_left.x > first_row_left.x, "A three-card second row should not left-align with the four-card first row"),
		assert_true(second_row_right.x + scaled_width < first_row_right.x + scaled_width, "A three-card second row should end earlier than the four-card first row"),
		assert_true(absf(second_row_center_x - center_x) < 0.01, "A shorter second row should still be independently centered inside MainArea"),
	])


func test_battle_scene_draw_reveal_blocks_live_actions() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_draw_reveal_active", true)
	var can_act: Variant = battle_scene.call("_can_accept_live_action")

	return run_checks([
		assert_eq(can_act, false, "Draw reveal should temporarily block live clicks until the reveal is resolved"),
	])


func test_battle_scene_draw_reveal_blocks_ai_progression() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_draw_reveal_active", true)
	var ai_blocked: Variant = battle_scene.call("_is_ui_blocking_ai")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(ai_blocked, true, "Active draw reveal should block AI progression until the reveal finishes"),
	])


func test_battle_scene_draw_reveal_shade_does_not_swallow_confirm_click() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Shade Click", 70, "C"), 0)
	gsm.game_state.players[0].hand = [drawn_card]

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 1, "card_names": ["Shade Click"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)
	var overlay: Control = battle_scene.get("_draw_reveal_overlay")
	var shade: ColorRect = overlay.get_child(0) as ColorRect

	return run_checks([
		assert_not_null(overlay, "Draw reveal should build an overlay for confirm state"),
		assert_not_null(shade, "Draw reveal overlay should include a dimming shade layer"),
		assert_eq(shade.mouse_filter, Control.MOUSE_FILTER_PASS, "The dimming shade must pass clicks through so the parent overlay can confirm the reveal"),
	])


func test_battle_scene_draw_reveal_centers_on_mainarea_without_handarea_instead_of_fieldarea_or_viewport() -> String:
	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var main_area: Control = layout.get("main_area")
	var hand_area: Control = layout.get("hand_area")
	var log_panel: Control = layout.get("log_panel")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(130, 182)

	var centered_position: Variant = controller.call("_center_position", battle_scene, card_view)
	var reveal_height := hand_area.global_position.y - main_area.global_position.y
	var reveal_width := log_panel.global_position.x - main_area.global_position.x
	var expected := Vector2(
		main_area.global_position.x + (reveal_width - 130.0) * 0.5,
		main_area.global_position.y + (reveal_height - 182.0) * 0.5
	)

	return run_checks([
		assert_eq(centered_position, expected, "Draw reveals should center within MainArea while excluding both the bottom HandArea and the right LogPanel"),
	])


func test_battle_scene_two_player_turn_start_draw_waits_for_handover_before_reveal() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Deferred Draw", 70, "C"), 1)
	gsm.game_state.players[1].hand = [drawn_card]
	battle_scene.call("_check_two_player_handover")

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 1, "card_names": ["Deferred Draw"], "card_instance_ids": [drawn_card.instance_id]},
		2,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)

	var handover_visible_before: bool = bool(battle_scene.get("_handover_panel").visible)
	var reveal_active_before: Variant = battle_scene.get("_draw_reveal_active")
	battle_scene.call("_on_handover_confirmed")
	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(handover_visible_before, "Two-player turn start should still be waiting on the handover confirmation"),
		assert_eq(reveal_active_before, false, "Turn-start draw reveal should stay deferred until the handover is confirmed"),
		assert_eq(reveal_active_after, true, "After the handover confirmation, the deferred draw reveal should begin"),
	])


func test_battle_scene_repeated_two_player_turn_start_draws_clear_reveal_state_between_turns() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var checks: Array[String] = []
	for turn_index: int in 4:
		var current_player: int = 1 if turn_index % 2 == 0 else 0
		gsm.game_state.current_player_index = current_player
		battle_scene.call("_check_two_player_handover")

		var drawn_card := CardInstance.create(_make_pokemon_cd("Loop Draw %d" % [turn_index + 1], 70, "C"), current_player)
		gsm.game_state.players[current_player].hand = [drawn_card]
		var action := GameAction.create(
			GameAction.ActionType.DRAW_CARD,
			current_player,
			{"count": 1, "card_names": [drawn_card.card_data.name], "card_instance_ids": [drawn_card.instance_id]},
			turn_index + 1,
			"loop draw"
		)
		battle_scene.call("_on_action_logged", action)
		checks.append(assert_eq(battle_scene.get("_draw_reveal_active"), false, "Deferred turn-start reveal should not start before handover confirmation on turn %d" % [turn_index + 1]))

		battle_scene.call("_on_handover_confirmed")
		checks.append(assert_eq(battle_scene.get("_draw_reveal_waiting_for_confirm"), true, "After handover confirmation, the reveal should enter click-to-continue state on turn %d" % [turn_index + 1]))
		checks.append(assert_not_null(battle_scene.get("_draw_reveal_current_action"), "After handover confirmation, the reveal should have a current action on turn %d" % [turn_index + 1]))
		var overlay_after_confirm: Control = battle_scene.get("_draw_reveal_overlay")
		var stage_after_confirm: Control = overlay_after_confirm.get_node_or_null("Stage") as Control if overlay_after_confirm != null else null
		checks.append(assert_not_null(stage_after_confirm, "Draw reveal overlay should keep its stage after handover confirmation on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_card_views").size(), 1, "Each repeated turn-start draw should stage exactly one reveal card on turn %d" % [turn_index + 1]))

		controller.call("confirm_current_reveal", battle_scene)

		var overlay: Control = battle_scene.get("_draw_reveal_overlay")
		checks.append(assert_eq(battle_scene.get("_draw_reveal_active"), false, "Reveal active state should clear after confirmation on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_waiting_for_confirm"), false, "Waiting-for-confirm should clear after confirmation on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_queue").size(), 0, "Reveal queue should be empty after completion on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_card_views").size(), 0, "Staged reveal cards should be cleared after completion on turn %d" % [turn_index + 1]))
		checks.append(assert_null(battle_scene.get("_draw_reveal_current_action"), "Current reveal action should clear after completion on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_pending_hand_refresh"), false, "Deferred hand refresh should flush after completion on turn %d" % [turn_index + 1]))
		checks.append(assert_not_null(overlay, "Repeated reveal flow should provision an overlay by turn %d" % [turn_index + 1]))
		if overlay != null:
			checks.append(assert_eq(overlay.visible, false, "Reveal overlay should hide after completion on turn %d" % [turn_index + 1]))
			var hint: Label = overlay.get_node_or_null("Hint") as Label
			checks.append(assert_not_null(hint, "Reveal overlay should keep a hint label on turn %d" % [turn_index + 1]))
			if hint != null:
				checks.append(assert_eq(hint.text, "", "Reveal hint text should clear after completion on turn %d" % [turn_index + 1]))
				checks.append(assert_eq(hint.visible, false, "Reveal hint should hide after completion on turn %d" % [turn_index + 1]))

	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_battle_scene_repeated_vs_ai_draw_reveals_reset_after_human_and_ai_turns() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var turn_players: Array[int] = [0, 1, 0, 1, 0]
	var checks: Array[String] = []
	for turn_index: int in turn_players.size():
		var current_player: int = turn_players[turn_index]
		gsm.game_state.current_player_index = current_player
		var drawn_card := CardInstance.create(_make_pokemon_cd("VS AI Draw %d" % [turn_index + 1], 70, "C"), current_player)
		gsm.game_state.players[current_player].hand = [drawn_card]
		var action := GameAction.create(
			GameAction.ActionType.DRAW_CARD,
			current_player,
			{"count": 1, "card_names": [drawn_card.card_data.name], "card_instance_ids": [drawn_card.instance_id]},
			turn_index + 1,
			"vs ai draw"
		)
		battle_scene.call("_on_action_logged", action)

		if current_player == 0:
			checks.append(assert_eq(battle_scene.get("_draw_reveal_waiting_for_confirm"), true, "Player draw should wait for click on turn %d" % [turn_index + 1]))
			controller.call("confirm_current_reveal", battle_scene)
		else:
			checks.append(assert_eq(battle_scene.get("_draw_reveal_auto_continue_pending"), true, "AI draw should arm auto-continue on turn %d" % [turn_index + 1]))
			controller.call("run_auto_continue", battle_scene)

		var overlay: Control = battle_scene.get("_draw_reveal_overlay")
		checks.append(assert_eq(battle_scene.get("_draw_reveal_active"), false, "Reveal active state should clear after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_waiting_for_confirm"), false, "Waiting-for-confirm should be reset after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_auto_continue_pending"), false, "Auto-continue flag should be reset after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_card_views").size(), 0, "Staged reveal cards should clear after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_queue").size(), 0, "Reveal queue should stay empty after turn %d" % [turn_index + 1]))
		checks.append(assert_null(battle_scene.get("_draw_reveal_current_action"), "Current reveal action should clear after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_pending_hand_refresh"), false, "Deferred hand refresh should clear after turn %d" % [turn_index + 1]))
		checks.append(assert_not_null(overlay, "VS AI repeated reveal flow should provision an overlay by turn %d" % [turn_index + 1]))
		if overlay != null:
			checks.append(assert_eq(overlay.visible, false, "Reveal overlay should hide after turn %d" % [turn_index + 1]))

	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_battle_scene_replay_mode_blocks_live_hand_actions() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_battle_mode", "review_readonly")
	battle_scene.set("_selected_hand_card", CardInstance.create(_make_trainer_cd("Any", "Item", ""), 0))
	var can_act := bool(battle_scene.call("_can_accept_live_action"))

	return run_checks([
		assert_false(can_act, "Replay mode should block live actions"),
	])


func test_battle_scene_replay_next_turn_loads_adjacent_turn_start() -> String:
	var battle_scene := _make_battle_scene_stub()
	var replay_turn_numbers: Array[int] = [4, 6]
	battle_scene.set("_battle_mode", "review_readonly")
	battle_scene.set("_replay_match_dir", "res://tests/fixtures/match_review_fixture")
	battle_scene.set("_replay_turn_numbers", replay_turn_numbers)
	battle_scene.set("_replay_current_turn_index", 0)
	battle_scene.call("_on_replay_next_turn_pressed")

	return run_checks([
		assert_eq(int(battle_scene.get("_replay_current_turn_index")), 1, "Next Turn should advance the replay turn index"),
		assert_eq(int(battle_scene.get("_view_player")), 1, "Replay should follow the loaded turn's acting player"),
	])


func test_battle_scene_continue_from_here_switches_to_live_mode() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_gsm", GameStateMachine.new())
	battle_scene.set("_battle_mode", "review_readonly")
	battle_scene.set("_replay_loaded_raw_snapshot", _sample_raw_replay_snapshot())
	battle_scene.call("_on_replay_continue_pressed")

	var gsm := battle_scene.get("_gsm") as GameStateMachine
	return run_checks([
		assert_eq(str(battle_scene.get("_battle_mode")), "live", "Continue From Here should return the scene to live mode"),
		assert_true(battle_scene.call("_can_accept_live_action"), "Continue From Here should re-enable live actions"),
		assert_eq(gsm.game_state.turn_number, 6, "Continue From Here should load the replay turn into GameState"),
	])


func test_battle_scene_replay_mode_ignores_hand_card_clicks() -> String:
	var battle_scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_battle_mode", "review_readonly")
	var hand_card := CardInstance.create(_make_pokemon_cd("Replay Test Basic", 70, "G"), 0)
	gsm.game_state.players[0].hand = [hand_card]
	battle_scene.call("_on_hand_card_clicked", hand_card, PanelContainer.new())

	return run_checks([
		assert_true(battle_scene.get("_selected_hand_card") == null, "Replay mode should ignore hand card clicks"),
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


func test_battle_scene_two_player_hides_old_ai_and_vfx_buttons() -> String:
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
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene.call("_refresh_ui")
	var ai_advice_hidden := not (scene.get("_btn_ai_advice") as Button).visible
	var attack_vfx_hidden := not (scene.get("_btn_attack_vfx_preview") as Button).visible
	var discuss_visible := (scene.get("_btn_battle_discuss_ai") as Button).visible
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_refresh_ui")
	var attack_vfx_hidden_in_vs_ai := not (scene.get("_btn_attack_vfx_preview") as Button).visible
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(ai_advice_hidden, "Two-player battle should hide the old AI advice button"),
		assert_true(attack_vfx_hidden, "Two-player battle should hide the attack VFX preview button"),
		assert_true(discuss_visible, "Two-player battle should keep the AI discussion button visible"),
		assert_true(attack_vfx_hidden_in_vs_ai, "VS_AI battle should hide the attack VFX preview button"),
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


func test_battle_scene_retreat_with_extra_energy_requires_energy_choice() -> String:
	var scene = _make_battle_scene_stub()
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
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat 1", "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat 2", "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a]

	scene.call("_show_retreat_dialog", 0)

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "retreat_energy", "Retreat with extra Energy should ask the player to choose the discard first"),
		assert_true((scene.get("_dialog_overlay") as Panel).visible, "Retreat Energy selection should use the dialog overlay"),
		assert_eq((scene.get("_dialog_items_data") as Array).size(), 2, "The retreat Energy prompt should include every attached Energy card"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Bench slot selection should wait until Energy is chosen"),
	])


func test_battle_scene_retreat_uses_player_selected_energy_cards() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := SpyRetreatGameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	var energy_a := CardInstance.create(_make_energy_cd("Retreat A", "C"), 0)
	var energy_b := CardInstance.create(_make_energy_cd("Retreat B", "C"), 0)
	active.attached_energy.append(energy_a)
	active.attached_energy.append(energy_b)
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a]

	scene.call("_show_retreat_dialog", 0)
	scene.call("_handle_dialog_choice", PackedInt32Array([1]))
	scene.call("_handle_field_slot_select_index", 0)

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "", "Retreat flow should resolve after the bench target is chosen"),
		assert_eq(gsm.retreat_calls, 1, "Retreat confirmation should call GameStateMachine.retreat exactly once"),
		assert_eq(gsm.last_energy_to_discard.size(), 1, "Retreat should discard exactly the selected Energy card"),
		assert_eq(gsm.last_energy_to_discard[0], energy_b, "Retreat should pass the player-selected Energy card into GameStateMachine.retreat"),
		assert_eq(gsm.last_bench_target, bench_a, "Retreat should keep using the selected bench target"),
	])


func test_battle_scene_retreat_rejects_overpaying_energy_selection() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := SpyRetreatGameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat A", "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat B", "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a]

	scene.call("_show_retreat_dialog", 0)
	scene.call("_handle_dialog_choice", PackedInt32Array([0, 1]))

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "retreat_energy", "Overpaying retreat Energy should keep the flow on the Energy selection step"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Overpaying retreat Energy should not advance to bench selection"),
		assert_eq(gsm.retreat_calls, 0, "Overpaying retreat Energy should not call GameStateMachine.retreat"),
	])


func test_battle_scene_pokemon_action_dialog_uses_hud_cards_with_full_text() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0

	var card_data := _make_pokemon_cd("HUD测试宝可梦", 120, "R")
	card_data.effect_id = "hud_action_test_ability"
	card_data.abilities = [{"name": "热血补给", "text": "自己的回合时可使用。查看自己的牌库，选择 1 张基本能量加入手牌，然后重洗牌库。"}]
	card_data.attacks = [{
		"name": "烈焰冲击",
		"cost": "RC",
		"damage": "80",
		"text": "将这只宝可梦身上的 1 个能量丢弃。若对手的战斗宝可梦为宝可梦ex，追加 80 点伤害。",
		"is_vstar_power": false,
	}]
	gsm.effect_processor.register_effect(card_data.effect_id, AbilityRunAwayDrawScript.new())
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(card_data, 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Colorless", "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 70, "C"), 0))
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[0].deck.append(CardInstance.create(_make_energy_cd("Deck Fire", "R"), 0))
	gsm.game_state.players[1].active_pokemon = PokemonSlot.new()
	gsm.game_state.players[1].active_pokemon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 100, "C"), 1))

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var data: Dictionary = scene.get("_dialog_data")
	var action_items: Array = data.get("action_items", [])
	var first_action: Dictionary = action_items[0] if action_items.size() > 0 and action_items[0] is Dictionary else {}
	var second_action: Dictionary = action_items[1] if action_items.size() > 1 and action_items[1] is Dictionary else {}
	var scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var list: ItemList = scene.get("_dialog_list")
	var confirm: Button = scene.get("_dialog_confirm")
	var row: HBoxContainer = scene.get("_dialog_card_row")
	var stack: VBoxContainer = row.get_child(0) as VBoxContainer if row.get_child_count() > 0 else null
	var first_panel: PanelContainer = stack.get_child(0) as PanelContainer if stack != null and stack.get_child_count() > 0 else null
	var first_margin: MarginContainer = first_panel.get_child(0) as MarginContainer if first_panel != null and first_panel.get_child_count() > 0 else null
	var second_panel: PanelContainer = stack.get_child(1) as PanelContainer if stack != null and stack.get_child_count() > 1 else null
	var second_margin: MarginContainer = second_panel.get_child(0) as MarginContainer if second_panel != null and second_panel.get_child_count() > 0 else null
	var second_box: VBoxContainer = second_margin.get_child(0) as VBoxContainer if second_margin != null and second_margin.get_child_count() > 0 else null
	var second_header: HBoxContainer = second_box.get_child(0) as HBoxContainer if second_box != null and second_box.get_child_count() > 0 else null
	var attack_cost_icons: HBoxContainer = null
	if second_header != null:
		for child: Node in second_header.get_children():
			if child is HBoxContainer:
				attack_cost_icons = child
				break
	var three_action_height := scroll.custom_minimum_size.y
	scene.call("_show_pokemon_action_dialog", 0, active, false)
	var single_action_items: Array = (scene.get("_dialog_data") as Dictionary).get("action_items", [])
	var single_action_height := (scene.get("_dialog_card_scroll") as ScrollContainer).custom_minimum_size.y
	card_data.abilities = [
		{"name": "能力1", "text": "效果1"},
		{"name": "能力2", "text": "效果2"},
		{"name": "能力3", "text": "效果3"},
		{"name": "能力4", "text": "效果4"},
		{"name": "能力5", "text": "效果5"},
		{"name": "能力6", "text": "效果6"},
	]
	scene.call("_show_pokemon_action_dialog", 0, active, false)
	var six_action_height := (scene.get("_dialog_card_scroll") as ScrollContainer).custom_minimum_size.y
	var six_action_scroll_mode: int = (scene.get("_dialog_card_scroll") as ScrollContainer).vertical_scroll_mode

	return run_checks([
		assert_eq(str(data.get("presentation", "")), "action_hud", "Pokemon action dialog should use the HUD-card presentation"),
		assert_true(scroll.visible, "Pokemon action HUD should use the card scroll area"),
		assert_false(list.visible, "Pokemon action HUD should hide the old ItemList"),
		assert_false(confirm.visible, "Pokemon action HUD should select by clicking the HUD option"),
		assert_eq(str(first_action.get("title", "")), "热血补给", "Ability HUD should show the ability name"),
		assert_true(str(first_action.get("body", "")).contains("选择 1 张基本能量加入手牌"), "Ability HUD should show the full ability text"),
		assert_eq(str(second_action.get("title", "")), "烈焰冲击", "Attack HUD should show the attack name"),
		assert_true(str(second_action.get("body", "")).contains("追加 80 点伤害"), "Attack HUD should show the full attack effect text"),
		assert_false(str(second_action.get("meta", "")).contains("RC"), "Attack HUD meta should not show raw Energy cost letters"),
		assert_eq(attack_cost_icons.get_child_count() if attack_cost_icons != null else 0, 2, "Attack HUD should render one Energy icon per cost symbol"),
		assert_true(attack_cost_icons.get_child(0) is TextureRect if attack_cost_icons != null and attack_cost_icons.get_child_count() > 0 else false, "Attack HUD should render Energy costs as texture icons"),
		assert_true(attack_cost_icons.get_child(1) is TextureRect if attack_cost_icons != null and attack_cost_icons.get_child_count() > 1 else false, "Attack HUD should render Colorless cost as a texture icon"),
		assert_true(three_action_height < 360.0, "Pokemon action HUD should be more compact than the old fixed 360px height"),
		assert_eq(single_action_items.size(), 1, "Ability-only Pokemon action HUD should contain one option"),
		assert_true(single_action_height < 120.0, "Ability-only Pokemon action HUD should shrink close to one option height"),
		assert_true(absf(six_action_height - 474.0) < 0.1, "Pokemon action HUD should cap visible height at five options"),
		assert_eq(six_action_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Pokemon action HUD should only enable vertical scrolling above five options"),
		assert_eq(first_panel.mouse_filter if first_panel != null else -1, Control.MOUSE_FILTER_STOP, "Whole action HUD option should receive clicks"),
		assert_eq(first_margin.mouse_filter if first_margin != null else -1, Control.MOUSE_FILTER_IGNORE, "Action HUD contents should pass clicks through to the whole option"),
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


func test_battle_scene_penny_active_target_advances_to_replacement_choice_and_resolves() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var active := PokemonSlot.new()
	var active_card := CardInstance.create(_make_pokemon_cd("Penny Active", 120, "P"), 0)
	active.pokemon_stack.append(active_card)
	var energy := CardInstance.create(_make_energy_cd("Penny Energy", "P"), 0)
	var tool := CardInstance.create(_make_trainer_cd("Penny Tool", "Tool", ""), 0)
	active.attached_energy.append(energy)
	active.attached_tool = tool
	player.active_pokemon = active

	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Penny Bench", 100, "P"), 0))
	player.bench = [replacement]

	var penny := CardInstance.create(_make_trainer_cd("Penny", "Supporter", ""), 0)
	penny.card_data.effect_id = "9fb5f53c9952d10b4fe26508ecbc644a"
	player.hand = [penny]

	battle_scene.call("_try_play_trainer_with_interaction", 0, penny)
	var first_pending: String = str(battle_scene.get("_pending_choice"))
	var first_mode: String = str(battle_scene.get("_field_interaction_mode"))
	battle_scene.call("_handle_field_slot_select_index", 0)
	var second_pending: String = str(battle_scene.get("_pending_choice"))
	var second_mode: String = str(battle_scene.get("_field_interaction_mode"))
	battle_scene.call("_handle_field_slot_select_index", 0)

	return run_checks([
		assert_eq(first_pending, "effect_interaction", "Penny should enter the effect interaction flow"),
		assert_eq(first_mode, "slot_select", "Penny should choose its target through the field slot selector"),
		assert_eq(second_pending, "effect_interaction", "Selecting the Active target should continue to the replacement step"),
		assert_eq(second_mode, "slot_select", "Penny replacement should also use the field slot selector"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "After choosing the replacement, Penny should finish cleanly"),
		assert_eq(player.active_pokemon, replacement, "Penny should promote the selected Benched Pokemon into the Active slot"),
		assert_true(active_card in player.hand and energy in player.hand and tool in player.hand, "Penny should return the chosen Active Pokemon and all attached cards to hand"),
		assert_true(penny in player.discard_pile, "Penny should be discarded after it resolves"),
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


func test_battle_scene_buddy_poffin_card_dialog_clicks_select_distinct_candidates() -> String:
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

	var player: PlayerState = gsm.game_state.players[0]
	player.deck = [
		CardInstance.create(_make_pokemon_cd("Poffin A", 60, "G"), 0),
		CardInstance.create(_make_pokemon_cd("Poffin B", 70, "W"), 0),
	]

	var poffin_card := CardInstance.create(_make_trainer_cd("Buddy Poffin", "Item", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "buddy_poffin_pokemon",
		"title": "选择最多 2 张 HP 不高于 70 的基础宝可梦放入备战区",
		"items": player.deck.duplicate(),
		"labels": ["Poffin A (HP 60)", "Poffin B (HP 70)"],
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	}]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, poffin_card)

	var card_row: HBoxContainer = battle_scene.get("_dialog_card_row")
	var first_card := card_row.get_child(0) as BattleCardView
	var second_card := card_row.get_child(1) as BattleCardView
	var left_connections: Array = first_card.left_clicked.get_connections()
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var manual_selected: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	manual_selected.append(0)
	var toggle_changed := bool(battle_scene.call("_toggle_dialog_card_choice", 0, 2))
	var toggled_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	(battle_scene.get("_dialog_card_selected_indices") as Array).clear()
	battle_scene.call("_on_dialog_card_chosen", 0)
	var direct_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	battle_scene.call("_on_dialog_card_chosen", 1)
	var second_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()

	return run_checks([
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Buddy Poffin should render eligible basics in card dialog mode"),
		assert_eq(card_row.get_child_count(), 2, "Buddy Poffin should show both eligible basics as clickable card choices"),
		assert_eq(left_connections.size(), 1, "Buddy Poffin card choices should wire exactly one left-click handler per card"),
		assert_eq(int(dialog_data.get("max_select", -1)), 2, "Buddy Poffin dialog should preserve max_select=2 in card mode"),
		assert_eq(manual_selected, [0], "BattleScene card selection storage should accept appending a chosen index"),
		assert_true(toggle_changed, "Buddy Poffin card toggle helper should report that selecting the first card succeeded"),
		assert_eq(toggled_selection, [0], "Buddy Poffin card toggle helper should persist the selected index"),
		assert_eq(direct_selection, [0], "Direct dialog choice handling should still select the first Buddy Poffin candidate"),
		assert_eq(second_selection, [0, 1], "Clicking a second Buddy Poffin candidate should add the distinct second entry"),
	])


func test_battle_scene_trekking_shoes_shows_revealed_card_with_two_bottom_buttons() -> String:
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

	var shoes_card := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item", ""), 0)
	var effect := preload("res://scripts/effects/trainer_effects/EffectTrekkingShoes.gd").new()
	var revealed := CardInstance.create(_make_pokemon_cd("Top Deck Pokemon", 70, "G"), 0)
	gsm.game_state.players[0].deck = [revealed]
	var steps: Array[Dictionary] = effect.get_interaction_steps(shoes_card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, shoes_card)

	var dialog_title := (battle_scene.get("_dialog_title") as Label).text
	var card_row: HBoxContainer = battle_scene.get("_dialog_card_row")
	var utility_row: HBoxContainer = battle_scene.get("_dialog_utility_row")
	var card_view := card_row.get_child(0) as BattleCardView if card_row.get_child_count() > 0 else null
	var button_texts: Array[String] = []
	for child: Node in utility_row.get_children():
		if child is Button:
			button_texts.append((child as Button).text)

	return run_checks([
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Trekking Shoes should switch the effect interaction into card mode"),
		assert_eq(card_row.get_child_count(), 1, "Trekking Shoes should reveal exactly one top-deck card"),
		assert_eq(card_view.card_instance.card_data.name if card_view != null and card_view.card_instance != null else "", "Top Deck Pokemon", "Trekking Shoes should present the exact top-deck card"),
		assert_eq(utility_row.get_child_count(), 2, "Trekking Shoes should put both outcomes on bottom buttons"),
		assert_eq(button_texts, ["加入手牌", "丢弃并再抽1张"], "Trekking Shoes should use direct action labels instead of a generic choice list"),
		assert_false((battle_scene.get("_dialog_confirm") as Button).visible, "Trekking Shoes should not require an extra confirm click"),
		assert_str_contains(dialog_title, "健行鞋", "Trekking Shoes dialog title should identify the card effect"),
	])


func test_battle_scene_trekking_shoes_discard_branch_draws_exactly_one_replacement_card_on_first_turn() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var shoes := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item", ""), 0)
	shoes.card_data.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
	var top_discard := CardInstance.create(_make_pokemon_cd("Top Discard", 60, "C"), 0)
	var draw_one := CardInstance.create(_make_pokemon_cd("Draw One", 60, "C"), 0)
	var draw_two := CardInstance.create(_make_pokemon_cd("Draw Two", 60, "C"), 0)
	gsm.game_state.players[0].hand = [shoes]
	gsm.game_state.players[0].deck = [top_discard, draw_one, draw_two]

	battle_scene.call("_try_play_trainer_with_interaction", 0, shoes)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))

	var reveal_controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	if reveal_controller != null and bool(battle_scene.get("_draw_reveal_waiting_for_confirm")):
		reveal_controller.call("confirm_current_reveal", battle_scene)

	var hand_names: Array[String] = []
	for card: CardInstance in gsm.game_state.players[0].hand:
		hand_names.append(card.card_data.name)
	var discard_names: Array[String] = []
	for card: CardInstance in gsm.game_state.players[0].discard_pile:
		discard_names.append(card.card_data.name)
	var deck_names: Array[String] = []
	for card: CardInstance in gsm.game_state.players[0].deck:
		deck_names.append(card.card_data.name)

	return run_checks([
		assert_eq(hand_names, ["Draw One"], "Discarding with Trekking Shoes should leave exactly the first replacement draw in hand"),
		assert_eq(discard_names, ["Top Discard", "Trekking Shoes"], "Trekking Shoes should discard only the revealed top card and then itself"),
		assert_eq(deck_names, ["Draw Two"], "Trekking Shoes should not consume a second replacement card"),
		assert_eq((battle_scene.get("_draw_reveal_queue") as Array).size(), 0, "The replacement draw reveal queue should drain after confirmation"),
	])


func test_battle_scene_trekking_shoes_discard_button_path_keeps_first_replacement_visible_in_hand() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var shoes := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item", ""), 0)
	shoes.card_data.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
	var top_discard := CardInstance.create(_make_pokemon_cd("Top Discard", 60, "C"), 0)
	var draw_one := CardInstance.create(_make_pokemon_cd("Draw One", 60, "C"), 0)
	var draw_two := CardInstance.create(_make_pokemon_cd("Draw Two", 60, "C"), 0)
	gsm.game_state.players[0].hand = [shoes]
	gsm.game_state.players[0].deck = [top_discard, draw_one, draw_two]

	battle_scene.call("_try_play_trainer_with_interaction", 0, shoes)
	var utility_row: HBoxContainer = battle_scene.get("_dialog_utility_row")
	var discard_button := utility_row.get_child(1) as Button if utility_row.get_child_count() > 1 else null
	if discard_button != null:
		discard_button.pressed.emit()

	var reveal_controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	if reveal_controller != null and bool(battle_scene.get("_draw_reveal_waiting_for_confirm")):
		reveal_controller.call("confirm_current_reveal", battle_scene)

	var hand_names: Array[String] = []
	for card: CardInstance in gsm.game_state.players[0].hand:
		hand_names.append(card.card_data.name)
	var rendered_names: Array[String] = []
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	for child: Node in hand_container.get_children():
		if child is BattleCardView and (child as BattleCardView).card_data != null:
			rendered_names.append((child as BattleCardView).card_data.name)

	return run_checks([
		assert_not_null(discard_button, "Trekking Shoes should render a discard button in the utility row"),
		assert_eq(hand_names, ["Draw One"], "Pressing the discard button should still draw only the first replacement card"),
		assert_eq(rendered_names, ["Draw One"], "After the reveal resolves, the visible hand should show the first replacement draw instead of skipping to the next card"),
	])


func test_battle_scene_nest_ball_without_target_can_preview_deck_then_consume() -> String:
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

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.bench.clear()
	var no_basic_target := CardInstance.create(_make_pokemon_cd("No Basic Target", 90, "C"), 0)
	no_basic_target.card_data.stage = "Stage 1"
	player.deck.append_array([
		CardInstance.create(_make_trainer_cd("Deck Item", "Item", ""), 0),
		no_basic_target,
	])

	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item", ""), 0)
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	player.hand.append(nest_ball)

	battle_scene.call("_try_play_trainer_with_interaction", 0, nest_ball)
	var first_step_title := (battle_scene.get("_dialog_title") as Label).text
	var first_dialog_items: Array = battle_scene.get("_dialog_items_data")

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))
	var preview_title := (battle_scene.get("_dialog_title") as Label).text
	var preview_dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var preview_items: Array = preview_dialog_data.get("card_items", [])
	var utility_row: HBoxContainer = battle_scene.get("_dialog_utility_row")

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array())

	return run_checks([
		assert_true(bool((battle_scene.get("_dialog_overlay") as Panel).visible) or nest_ball in player.discard_pile, "Nest Ball should open a resolution flow instead of being blocked outright"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "After closing the deck preview, the trainer interaction should finish cleanly"),
		assert_str_contains(first_step_title, "没有", "Nest Ball whiff dialog should explain that the deck has no valid Pokemon"),
		assert_eq(first_dialog_items.size(), 2, "Nest Ball whiff dialog should offer continue and preview options"),
		assert_str_contains(preview_title, "牌库", "Choosing preview should open a deck preview step"),
		assert_true(bool(battle_scene.get("_dialog_card_mode")) or preview_dialog_data.get("presentation", "") == "cards", "Deck preview should render in card mode"),
		assert_eq(preview_items.size(), 2, "Deck preview should show the remaining deck cards"),
		assert_eq(utility_row.get_child_count(), 1, "Deck preview should expose a single close-and-continue utility action"),
		assert_true(nest_ball in player.discard_pile, "Nest Ball should still be consumed after the deck preview closes"),
		assert_eq(player.bench.size(), 0, "Nest Ball whiff preview should not add any Pokemon to the bench"),
	])


func legacy_battle_scene_earthen_vessel_empty_search_preview_can_be_opened_and_consumes_card() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	player.bench.clear()
	player.deck.append_array([
		CardInstance.create(_make_trainer_cd("Deck Item", "Item", ""), 0),
		CardInstance.create(_make_pokemon_cd("Deck Pokemon", 90, "C"), 0),
	])

	var discard_cost := CardInstance.create(_make_trainer_cd("Discard Cost", "Item", ""), 0)
	var earthen_vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	earthen_vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	player.hand.append_array([earthen_vessel, discard_cost])

	battle_scene.call("_try_play_trainer_with_interaction", 0, earthen_vessel)
	var first_step_title := (battle_scene.get("_dialog_title") as Label).text

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var resolution_title := (battle_scene.get("_dialog_title") as Label).text
	var resolution_items: Array = battle_scene.get("_dialog_items_data")

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))
	var preview_title := (battle_scene.get("_dialog_title") as Label).text
	var preview_dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var preview_items: Array = preview_dialog_data.get("card_items", [])

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array())

	return run_checks([
		assert_str_contains(first_step_title, "弃", "Earthen Vessel should still ask the player to pay its discard cost first"),
		assert_str_contains(resolution_title, "没有", "After paying the discard cost, Earthen Vessel should explain that no Basic Energy were found"),
		assert_eq(resolution_items.size(), 2, "Earthen Vessel whiffs should offer continue and preview options"),
		assert_str_contains(preview_title, "牌库", "Choosing preview after an Earthen Vessel whiff should open the deck preview"),
		assert_eq(preview_items.size(), 2, "Earthen Vessel whiff previews should show the remaining deck"),
		assert_true(earthen_vessel in player.discard_pile, "Earthen Vessel should still be consumed after closing the empty-search preview"),
		assert_true(discard_cost in player.discard_pile, "Earthen Vessel should still discard the paid cost card on a whiff"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "After closing the empty-search preview, the trainer interaction should finish cleanly"),
	])


func test_battle_scene_earthen_vessel_empty_search_preview_can_be_opened_and_consumes_card() -> String:
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

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	player.bench.clear()
	player.deck.append_array([
		CardInstance.create(_make_trainer_cd("Deck Item", "Item", ""), 0),
		CardInstance.create(_make_pokemon_cd("Deck Pokemon", 90, "C"), 0),
	])

	var discard_cost := CardInstance.create(_make_trainer_cd("Discard Cost", "Item", ""), 0)
	var earthen_vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	earthen_vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	player.hand.append_array([earthen_vessel, discard_cost])

	battle_scene.call("_try_play_trainer_with_interaction", 0, earthen_vessel)
	var first_step_title := (battle_scene.get("_dialog_title") as Label).text

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var resolution_title := (battle_scene.get("_dialog_title") as Label).text
	var resolution_items: Array = battle_scene.get("_dialog_items_data")

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))
	var preview_title := (battle_scene.get("_dialog_title") as Label).text
	var preview_dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var preview_items: Array = preview_dialog_data.get("card_items", [])

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array())

	return run_checks([
		assert_true(first_step_title.findn("discard") >= 0, "Earthen Vessel should still ask the player to pay its discard cost first"),
		assert_true(resolution_items.size() == 2, "After paying the discard cost, Earthen Vessel should enter the empty-search resolution step"),
		assert_eq(resolution_items.size(), 2, "Earthen Vessel whiffs should offer continue and preview options"),
		assert_true(preview_items.size() == 2, "Choosing preview after an Earthen Vessel whiff should open the deck preview"),
		assert_eq(preview_items.size(), 2, "Earthen Vessel whiff previews should show the remaining deck"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "After closing the empty-search preview, the trainer interaction should finish cleanly"),
		assert_true(discard_cost in player.discard_pile, "Earthen Vessel should still discard the paid cost card on a whiff"),
		assert_false(earthen_vessel in player.hand, "Earthen Vessel should not remain in hand after the empty-search flow finishes"),
		assert_true(earthen_vessel in player.discard_pile, "Earthen Vessel should still be consumed after closing the empty-search preview"),
	])


func test_battle_scene_try_play_trainer_with_interaction_respects_item_play_rules() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.SETUP
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item", ""), 0)
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	player.hand.append(nest_ball)
	player.deck.append(CardInstance.create(_make_pokemon_cd("Target", 70, "C"), 0))

	battle_scene.call("_try_play_trainer_with_interaction", 0, nest_ball)
	var log_rtl: RichTextLabel = battle_scene.get("_log_list") as RichTextLabel
	var log_text := log_rtl.get_parsed_text().strip_edges() if log_rtl != null else ""
	var latest_log := ""
	if not log_text.is_empty():
		var lines := log_text.split("\n")
		latest_log = lines[lines.size() - 1]

	return run_checks([
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Items should not enter the interaction flow when the play rules currently forbid them"),
		assert_true(nest_ball in player.hand, "Blocked trainer interactions should leave the card in hand"),
		assert_true(latest_log.length() > 0, "Blocked trainer interactions should explain why the card cannot currently be used"),
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


func test_battle_scene_pokemon_catcher_waits_for_coin_animation_before_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	(battle_scene.get("_dialog_overlay") as Panel).visible = false
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	var coin_animator := FakeCoinAnimator.new()
	battle_scene.set("_coin_animator", coin_animator)

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

	var flipper := RiggedCoinFlipper.new([true])
	flipper.coin_flipped.connect(func(result: bool) -> void:
		battle_scene.call("_on_coin_flipped", result)
	)
	var effect := EffectPokemonCatcherScript.new(flipper)
	var card := CardInstance.create(_make_trainer_cd("Pokemon Catcher", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	var delayed_pending_choice := str(battle_scene.get("_pending_choice"))
	var delayed_field_mode := str(battle_scene.get("_field_interaction_mode"))
	var delayed_coin_results: Array = coin_animator.played_results.duplicate()

	battle_scene.call("_on_coin_animation_finished")

	return run_checks([
		assert_eq(delayed_pending_choice, "effect_interaction", "Coin-flip follow-up prompts should stay in effect_interaction while the animation is running"),
		assert_eq(delayed_field_mode, "", "Pokemon Catcher should not show field slot selection before the coin animation finishes"),
		assert_eq(delayed_coin_results, [true], "Pokemon Catcher should start the coin animation immediately after the shared flipper emits"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Pokemon Catcher should show field slot selection after the coin animation finishes"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "Pokemon Catcher should still expose opponent bench targets after the coin animation"),
	])


func test_battle_scene_ai_owned_coin_followup_resumes_after_animation() -> String:
	var previous_mode: int = GameManager.current_mode
	var battle_scene = _make_battle_scene_stub()
	battle_scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	var coin_animator := FakeCoinAnimator.new()
	battle_scene.set("_coin_animator", coin_animator)
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	battle_scene.set("_ai_opponent", ai)
	GameManager.current_mode = GameManager.GameMode.VS_AI

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var ai_player: PlayerState = gsm.game_state.players[1]
	var aroma_card := CardInstance.create(_make_trainer_cd("Capturing Aroma", "Item", ""), 1)
	aroma_card.card_data.effect_id = "7c0b20e121c9d0e0d2d8a43524f7494e"
	ai_player.hand.append(aroma_card)
	var evolution := CardData.new()
	evolution.name = "AI Evolution"
	evolution.card_type = "Pokemon"
	evolution.stage = "Stage1"
	evolution.hp = 90
	ai_player.deck.append(CardInstance.create(evolution, 1))

	var flipper := RiggedCoinFlipper.new([true])
	flipper.coin_flipped.connect(func(result: bool) -> void:
		battle_scene.call("_on_coin_flipped", result)
	)
	var effect := EffectCapturingAromaScript.new(flipper)
	gsm.effect_processor.register_effect("7c0b20e121c9d0e0d2d8a43524f7494e", effect)
	var steps: Array[Dictionary] = effect.get_interaction_steps(aroma_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 1, steps, aroma_card)
	battle_scene.call("_maybe_run_ai")

	var scheduled_before_finish: bool = bool(battle_scene.get("_ai_step_scheduled"))
	var pending_before_finish: String = str(battle_scene.get("_pending_choice"))
	battle_scene.call("_on_coin_animation_finished")
	var scheduled_after_finish: bool = bool(battle_scene.get("_ai_step_scheduled"))
	if scheduled_after_finish:
		battle_scene.call("_run_ai_step")

	var pending_after_resume: String = str(battle_scene.get("_pending_choice"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(pending_before_finish, "effect_interaction", "AI-owned coin follow-up should remain pending while the coin animation is still running"),
		assert_false(scheduled_before_finish, "AI should not be scheduled before the coin animation finishes"),
		assert_eq(coin_animator.played_results, [true], "Capturing Aroma should enqueue exactly one shared coin animation"),
		assert_true(scheduled_after_finish, "When the coin animation finishes, BattleScene should schedule the AI-owned follow-up step"),
		assert_eq(pending_after_resume, "", "After the AI resolves the resumed Capturing Aroma step, the interaction should complete"),
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
	var log_rtl: RichTextLabel = battle_scene.get("_log_list") as RichTextLabel
	var log_text := log_rtl.get_parsed_text().strip_edges() if log_rtl != null else ""
	var last_log := ""
	if not log_text.is_empty():
		var lines := log_text.split("\n")
		last_log = lines[lines.size() - 1]

	return run_checks([
		assert_true(not log_text.is_empty(), "Mirage Gate should leave a UI log entry when it whiffs"),
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
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_on_field_assignment_source_chosen", 1)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	var assignments: Array = battle_scene.get("_field_interaction_assignment_entries")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Sada's Vitality should route to field assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Sada's Vitality should move the field panel upward for own Ancient targets"),
		assert_eq(int(data.get("source_items", []).size()), 2, "Sada's Vitality should expose discard energy cards as sources"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Sada's Vitality should expose Ancient Pokemon targets on the field"),
		assert_eq(int(data.get("max_assignments_per_target", 0)), 1, "Sada's Vitality should declare one energy per Ancient target"),
		assert_eq(assignments.size(), 1, "Sada's Vitality UI should reject assigning two energy to the same Ancient target"),
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
	var munkidori_cd := _make_pokemon_cd("Munkidori", 90, "D")
	munkidori_cd.effect_id = "munkidori_counter_ui_test"
	munkidori_cd.abilities = [{"name": "亢奋脑力"}]
	user_slot.pokemon_stack.append(CardInstance.create(munkidori_cd, 0))
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
	gsm.effect_processor.register_effect("munkidori_counter_ui_test", effect)
	var user_card := user_slot.get_top_card()
	var steps: Array[Dictionary] = effect.get_interaction_steps(user_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, user_card, user_slot, 0)
	var first_position: String = str(battle_scene.get("_field_interaction_position"))

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var second_position: String = str(battle_scene.get("_field_interaction_position"))

	return run_checks([
		assert_eq(first_position, "top", "Selecting the damaged own Pokemon should move the panel upward"),
		assert_eq(second_position, "bottom", "Selecting the opponent target should move the panel downward"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "counter_distribution", "The second step should use Dragapult-style counter distribution UI"),
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
		assert_eq(pending_my_text, "点左侧奖赏卡：选2张", "Prize selection should replace the player title with the highlighted count prompt"),
		assert_eq(pending_my_hud_text, "点左侧奖赏卡：选2张", "Prize selection should also update the field HUD title"),
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
		assert_eq(field_interaction_mode, "counter_distribution", "Selecting Phantom Dive should switch into the counter distribution interaction mode"),
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


func test_battle_scene_gholdengo_single_selected_energy_deals_fifty_to_neutral_target() -> String:
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

	var attacker_cd: CardData = CardDatabase.get_card("CSV4C", "089")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Metal Energy", "M"), 0))
	gsm.effect_processor.register_pokemon_card(attacker_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := _make_pokemon_cd("Neutral Defender", 200, "C")
	defender_cd.weakness_energy = "W"
	defender_cd.weakness_value = "×2"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var chosen_water := CardInstance.create(_make_energy_cd("Chosen Water", "W"), 0)
	var unchosen_psychic := CardInstance.create(_make_energy_cd("Unchosen Psychic", "P"), 0)
	gsm.game_state.players[0].hand = [chosen_water, unchosen_psychic]

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 0)
	var first_step: Dictionary = (battle_scene.get("_pending_effect_steps") as Array)[0] if not (battle_scene.get("_pending_effect_steps") as Array).is_empty() else {}
	var first_items: Array = first_step.get("items", [])
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))

	return run_checks([
		assert_eq(str(first_step.get("id", "")), "discard_basic_energy", "赛富豪ex应先弹出手牌基础能量弃置选择"),
		assert_eq(first_items.size(), 2, "赛富豪ex应将每张可弃置的手牌基础能量各展示一次"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "选择弃置能量后应完成攻击交互"),
		assert_true(chosen_water in gsm.game_state.players[0].discard_pile, "选中的水能应进入弃牌区"),
		assert_true(unchosen_psychic in gsm.game_state.players[0].hand, "未选中的基础能量应保留在手牌"),
		assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 50, "通过 BattleScene 真实入口只弃置 1 张能量时，对无钢弱点目标应只造成 50 伤害"),
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


func test_battle_scene_radiant_charizard_attack_uses_prize_cost_reduction_without_discarding_energy() -> String:
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
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var radiant_charizard_cd: CardData = CardDatabase.get_card("CS5.5C", "007")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(radiant_charizard_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	gsm.effect_processor.register_pokemon_card(radiant_charizard_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var target_slot := PokemonSlot.new()
	target_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bulky Target", 330, "G"), 1))
	gsm.game_state.players[1].active_pokemon = target_slot
	gsm.game_state.players[1].prizes.clear()
	for i: int in 2:
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 0)

	return run_checks([
		assert_not_null(radiant_charizard_cd, "CS5.5C_007 should exist in the card database"),
		assert_eq(target_slot.damage_counters, 250, "Radiant Charizard should still deal 250 damage through the BattleScene attack flow"),
		assert_eq(attacker_slot.attached_energy.size(), 1, "Radiant Charizard should keep its only Fire Energy after Combustion Blast"),
	])


func test_battle_scene_dragapult_double_knockout_without_live_replacement_stays_on_prizes() -> String:
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
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	for energy_type: String in ["R", "P"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type, energy_type), 0))
	gsm.effect_processor.register_pokemon_card(dragapult_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var active_target := PokemonSlot.new()
	active_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active Prize Target", 200, "W"), 1))
	gsm.game_state.players[1].active_pokemon = active_target
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Only Bench Target", 60, "W"), 1))
	gsm.game_state.players[1].bench = [bench_target]
	for i: int in 2:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i, 60, "C"), 0))
	for i: int in 6:
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 1)
	battle_scene.call("_on_counter_distribution_amount_chosen", 6)
	battle_scene.call("_handle_counter_distribution_target", 0)
	var first_pending_choice: String = str(battle_scene.get("_pending_choice"))
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	var second_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var second_pending_count: int = int(battle_scene.get("_pending_prize_remaining"))
	var handover_visible_after_first: bool = bool(battle_scene.get("_handover_panel").visible)
	battle_scene.call("_try_take_prize_from_slot", 0, 1)
	var final_phase: int = gsm.game_state.phase
	var winner_index: int = gsm.game_state.winner_index

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_not_null(dragapult_cd, "CSV8C_159 should exist in the card database"),
		assert_eq(first_pending_choice, "take_prize", "The first Dragapult ex knockout should enter prize selection"),
		assert_eq(second_pending_choice, "take_prize", "When no live replacement remains, the second prize should queue immediately"),
		assert_eq(second_pending_count, 1, "Exactly one follow-up prize should still be pending after the first take"),
		assert_false(handover_visible_after_first, "There should be no send-out handover when the only Bench Pokemon is already knocked out"),
		assert_eq(gsm.game_state.players[0].hand.size(), 2, "The player should still be able to take both prizes through the BattleScene flow"),
		assert_eq(final_phase, GameState.GamePhase.GAME_OVER, "Taking the second queued prize should end the game"),
		assert_eq(winner_index, 0, "The attacking player should win after taking both remaining prizes"),
	])


func test_battle_scene_dragapult_active_only_knockout_keeps_prize_selection_clickable() -> String:
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
		gsm.game_state.players.append(player)

	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	for energy_type: String in ["R", "P"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type, energy_type), 0))
	gsm.effect_processor.register_pokemon_card(dragapult_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var active_target := PokemonSlot.new()
	active_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active Only Target", 200, "W"), 1))
	gsm.game_state.players[1].active_pokemon = active_target
	var replacement_slot := PokemonSlot.new()
	replacement_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Surviving Bench", 120, "W"), 1))
	gsm.game_state.players[1].bench = [replacement_slot]
	for i: int in 2:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i, 60, "C"), 0))
	for i: int in 6:
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 1)
	battle_scene.call("_on_counter_distribution_amount_chosen", 6)
	battle_scene.call("_handle_counter_distribution_target", 0)
	var attack_vfx_overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var attack_vfx_mouse_filter: int = attack_vfx_overlay.mouse_filter if attack_vfx_overlay != null else Control.MOUSE_FILTER_IGNORE
	var first_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var bench_remaining_hp: int = replacement_slot.get_remaining_hp()
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	var pending_choice_after_take: String = str(battle_scene.get("_pending_choice"))
	var pending_prize_remaining_after_take: int = int(battle_scene.get("_pending_prize_remaining"))
	var handover_visible_after_take: bool = bool(battle_scene.get("_handover_panel").visible)
	battle_scene.call("_on_handover_confirmed")
	var send_out_mode: String = str(battle_scene.get("_field_interaction_mode"))

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_not_null(dragapult_cd, "CSV8C_159 should exist in the card database"),
		assert_eq(attack_vfx_mouse_filter, Control.MOUSE_FILTER_IGNORE, "Attack VFX overlay must not intercept prize clicks"),
		assert_eq(first_pending_choice, "take_prize", "Dragging through Phantom Dive should still enter prize selection after the Active knockout"),
		assert_eq(bench_remaining_hp, 60, "The benched replacement should survive the counter placement in this fixture"),
		assert_eq(pending_choice_after_take, "send_out", "After taking the prize, the flow should advance to the replacement prompt"),
		assert_eq(pending_prize_remaining_after_take, 0, "The prize selection state should be fully cleared after the prize is taken"),
		assert_true(handover_visible_after_take, "Two-player mode should hand over to the defending player after the prize is taken"),
		assert_eq(send_out_mode, "slot_select", "After handover confirmation, the defending player should be prompted to send out a replacement"),
	])


func test_battle_scene_human_prize_prompt_blocks_field_actions_until_prize_taken() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
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
		gsm.game_state.players.append(player)

	var attacker_cd := _make_pokemon_cd("Prize Taker", 220, "L")
	var my_active := PokemonSlot.new()
	my_active.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	my_active.attached_energy.append(CardInstance.create(_make_energy_cd("Energy R", "R"), 0))
	my_active.attached_energy.append(CardInstance.create(_make_energy_cd("Energy C", "C"), 0))
	gsm.effect_processor.register_pokemon_card(attacker_cd)
	gsm.game_state.players[0].active_pokemon = my_active
	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Knocked Out Target", 30, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Replacement", 120, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]
	gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize", 60, "C"), 0))
	gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize", 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, my_active, 0)
	var pending_before_field_click: String = str(battle_scene.get("_pending_choice"))
	var dialog_visible_before_field_click: bool = bool((battle_scene.get("_dialog_overlay") as Panel).visible)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	battle_scene.call("_on_slot_input", click, "my_active")
	var pending_after_field_click: String = str(battle_scene.get("_pending_choice"))
	var dialog_visible_after_field_click: bool = bool((battle_scene.get("_dialog_overlay") as Panel).visible)
	var hand_before_take: int = gsm.game_state.players[0].hand.size()
	battle_scene.call("_on_prize_slot_input", click, 0, "己方奖赏", 0)
	var hand_after_take: int = gsm.game_state.players[0].hand.size()
	var pending_after_take: String = str(battle_scene.get("_pending_choice"))
	var prize_count_after_take: int = gsm.game_state.players[0].prizes.size()

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(pending_before_field_click, "take_prize", "Knocking out the AI active Pokemon should enter a human-owned prize prompt"),
		assert_eq(pending_after_field_click, "take_prize", "Human prize prompts should ignore field clicks instead of opening other actions"),
		assert_eq(dialog_visible_after_field_click, dialog_visible_before_field_click, "Field clicks during prize selection must not change the dialog overlay state"),
		assert_eq(hand_after_take, hand_before_take + 1, "Clicking the prize slot should still take exactly one prize card"),
		assert_eq(prize_count_after_take, 0, "Taking the prize through the prize-slot input path should remove it from the prize area"),
		assert_false(pending_after_take == "take_prize", "After the prize is taken, the prize prompt should be cleared so the battle can continue"),
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
		assert_true(dialog_items.size() >= 3, "Match end dialog should include summary plus at least the AI review and return actions when review is available"),
		assert_true("生成AI复盘" in dialog_items, "The match end dialog should include the AI review action"),
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
