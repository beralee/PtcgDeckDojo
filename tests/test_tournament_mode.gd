class_name TestTournamentMode
extends TestBase

const TournamentDeckSelectScene = preload("res://scenes/tournament/TournamentDeckSelect.tscn")
const TournamentSetupScene = preload("res://scenes/tournament/TournamentSetup.tscn")
const TournamentOverviewScene = preload("res://scenes/tournament/TournamentOverview.tscn")
const TournamentStandingsScene = preload("res://scenes/tournament/TournamentStandings.tscn")
const MainMenuScene = preload("res://scenes/main_menu/MainMenu.tscn")
const SwissTournamentScript = preload("res://scripts/tournament/SwissTournament.gd")


func _set_navigation_suppressed(suppressed: bool) -> void:
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", suppressed)


func test_main_menu_exposes_tournament_entry() -> String:
	var scene: Control = MainMenuScene.instantiate()
	return run_checks([
		assert_true(scene.find_child("BtnTournament", true, false) is Button, "首页应包含比赛模式按钮"),
	])


func test_hidden_champion_preview_builds_final_standings() -> String:
	var previous_tournament := GameManager.current_tournament
	var previous_tournament_deck_id := GameManager.tournament_selected_player_deck_id
	var previous_in_progress := GameManager.tournament_battle_in_progress
	_set_navigation_suppressed(true)

	var scene: Control = MainMenuScene.instantiate()
	scene.call("_open_champion_preview")
	var tournament = GameManager.current_tournament
	var summary: Dictionary = tournament.last_round_summary if tournament != null else {}
	var standings: Array = summary.get("standings", [])
	var requested_path := GameManager.consume_last_requested_scene_path()

	var result := run_checks([
		assert_eq(requested_path, GameManager.SCENE_TOURNAMENT_STANDINGS, "Hidden champion preview should open the final standings scene"),
		assert_not_null(tournament, "Hidden champion preview should create a tournament object"),
		assert_true(tournament != null and bool(tournament.finished), "Hidden champion preview should mark the tournament as finished"),
		assert_true(not standings.is_empty() and int((standings[0] as Dictionary).get("rank", -1)) == 1, "Hidden champion preview should rank the player first"),
		assert_false(GameManager.is_tournament_battle_active(), "Hidden champion preview must not leave a battle in progress"),
	])

	scene.queue_free()
	_set_navigation_suppressed(false)
	GameManager.clear_tournament()
	GameManager.current_tournament = previous_tournament
	GameManager.tournament_selected_player_deck_id = previous_tournament_deck_id
	GameManager.tournament_battle_in_progress = previous_in_progress
	return result


func test_tournament_scenes_instantiate() -> String:
	var deck_select: Control = TournamentDeckSelectScene.instantiate()
	var setup: Control = TournamentSetupScene.instantiate()
	var overview: Control = TournamentOverviewScene.instantiate()
	var standings: Control = TournamentStandingsScene.instantiate()
	return run_checks([
		assert_not_null(deck_select, "TournamentDeckSelect 应可实例化"),
		assert_not_null(setup, "TournamentSetup 应可实例化"),
		assert_not_null(overview, "TournamentOverview 应可实例化"),
		assert_not_null(standings, "TournamentStandings 应可实例化"),
		assert_true(deck_select.find_child("DeckOption", true, false) is OptionButton, "DeckSelect 应包含 DeckOption"),
		assert_true(setup.find_child("SizeOption", true, false) is OptionButton, "TournamentSetup 应包含 SizeOption"),
		assert_true(setup.find_child("RoundInfoLabel", true, false) is Label, "TournamentSetup 应显示预计轮数"),
		assert_true(overview.find_child("RosterText", true, false) is TextEdit, "TournamentOverview 应包含参赛名单文本框"),
		assert_true(overview.find_child("DistributionText", true, false) is TextEdit, "TournamentOverview 应包含卡组分布文本框"),
		assert_true(standings.find_child("StandingsText", true, false) is TextEdit, "TournamentStandings 应包含积分榜文本框"),
	])


func test_tournament_scenes_use_hud_visual_theme() -> String:
	var scenes: Array[Control] = [
		TournamentDeckSelectScene.instantiate(),
		TournamentSetupScene.instantiate(),
		TournamentOverviewScene.instantiate(),
		TournamentStandingsScene.instantiate(),
	]
	var checks: Array[String] = []
	for scene: Control in scenes:
		scene.call("_ready")
		var panel := scene.find_child("Panel", true, false) as PanelContainer
		var primary_button := scene.find_child("BtnStart", true, false) as Button
		if primary_button == null:
			primary_button = scene.find_child("BtnNext", true, false) as Button
		if primary_button == null:
			primary_button = scene.find_child("BtnStartRound", true, false) as Button
		if primary_button == null:
			primary_button = scene.find_child("BtnPrimary", true, false) as Button
		var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat if panel != null else null
		var button_style := primary_button.get_theme_stylebox("normal") as StyleBoxFlat if primary_button != null else null
		checks.append(assert_true(panel_style != null and panel_style.bg_color.a < 0.9, "%s should use a translucent HUD panel" % scene.name))
		checks.append(assert_true(button_style != null and button_style.border_color.a > 0.8, "%s primary action should use HUD button styling" % scene.name))
		scene.queue_free()
	return run_checks(checks)


func test_tournament_final_page_celebrates_player_champion() -> String:
	var previous_tournament := GameManager.current_tournament
	var tournament := SwissTournamentScript.new()
	tournament.setup("冠军玩家", 575716, 16, 12345)
	tournament.current_round = tournament.total_rounds
	tournament.finished = true
	tournament.last_round_summary = {
		"round": tournament.total_rounds,
		"result": "win",
		"is_final_round": true,
		"player": {
			"id": 0,
			"name": "冠军玩家",
			"wins": 4,
			"losses": 0,
			"draws": 0,
			"points": 12,
		},
		"opponent": {
			"id": 1,
			"name": "决赛对手",
		},
		"standings": [
			{
				"id": 0,
				"name": "冠军玩家",
				"wins": 4,
				"losses": 0,
				"draws": 0,
				"points": 12,
				"rank": 1,
			},
			{
				"id": 1,
				"name": "决赛对手",
				"wins": 3,
				"losses": 1,
				"draws": 0,
				"points": 9,
				"rank": 2,
			},
		],
	}
	GameManager.current_tournament = tournament
	var scene: Control = TournamentStandingsScene.instantiate()
	scene.call("_ready")
	var banner := scene.find_child("ChampionBanner", true, false) as Control
	var champion_title := scene.find_child("ChampionTitle", true, false) as Label
	var summary_text := scene.find_child("SummaryText", true, false) as RichTextLabel
	var result := run_checks([
		assert_true(banner != null and banner.visible, "玩家最终排名第 1 时应显示冠军横幅"),
		assert_true(champion_title != null and champion_title.text.find("获得冠军") >= 0, "冠军横幅应明确恭喜玩家获得冠军"),
		assert_true(summary_text != null and summary_text.text.find("恭喜你") >= 0, "最终摘要应包含直接面向玩家的祝贺文案"),
	])
	scene.queue_free()
	GameManager.clear_tournament()
	GameManager.clear_tournament()
	GameManager.current_tournament = previous_tournament
	return result


func test_tournament_setup_requires_name_before_continue() -> String:
	var previous_mode := GameManager.current_mode
	var previous_selected_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first := GameManager.first_player_choice
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_tournament := GameManager.current_tournament
	var previous_tournament_deck_id := GameManager.tournament_selected_player_deck_id

	GameManager.clear_tournament()
	GameManager.set_tournament_selected_player_deck_id(575716)
	_set_navigation_suppressed(true)
	var setup: Control = TournamentSetupScene.instantiate()
	setup.call("_ready")
	var name_edit := setup.find_child("NameEdit", true, false) as LineEdit
	var error_label := setup.find_child("ErrorLabel", true, false) as Label
	name_edit.text = ""
	setup.call("_on_start_pressed")

	var result := run_checks([
		assert_true(GameManager.current_tournament == null, "未填写名字时不应创建比赛"),
		assert_true(error_label.visible, "未填写名字时应显示错误提示"),
		assert_true(error_label.text.strip_edges() != "", "错误提示文本不应为空"),
	])

	_set_navigation_suppressed(false)
	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_selected_ids
	GameManager.first_player_choice = previous_first
	GameManager.ai_selection = previous_ai_selection
	GameManager.current_tournament = previous_tournament
	GameManager.tournament_selected_player_deck_id = previous_tournament_deck_id
	return result


func test_tournament_setup_flows_into_overview_before_battle() -> String:
	var previous_mode := GameManager.current_mode
	var previous_selected_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first := GameManager.first_player_choice
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_tournament := GameManager.current_tournament
	var previous_tournament_deck_id := GameManager.tournament_selected_player_deck_id

	GameManager.clear_tournament()
	GameManager.set_tournament_selected_player_deck_id(575716)
	_set_navigation_suppressed(true)
	var setup: Control = TournamentSetupScene.instantiate()
	setup.call("_ready")
	var name_edit := setup.find_child("NameEdit", true, false) as LineEdit
	name_edit.text = "测试玩家"
	setup.call("_on_start_pressed")

	var tournament = GameManager.current_tournament
	var overview: Control = TournamentOverviewScene.instantiate()
	overview.call("_ready")
	var meta_label := overview.find_child("MetaLabel", true, false) as RichTextLabel
	var roster_text := overview.find_child("RosterText", true, false) as TextEdit
	var distribution_text := overview.find_child("DistributionText", true, false) as TextEdit

	var result := run_checks([
		assert_not_null(tournament, "点击查看比赛情况后应创建比赛对象"),
		assert_true(tournament != null and int(tournament.current_round) == 0, "进入总览页前不应提前开始第一轮"),
		assert_true(meta_label.text.find("测试玩家") >= 0, "总览页应显示玩家名字"),
		assert_true(roster_text.text.find("测试玩家") >= 0, "总览页应列出玩家参赛信息"),
		assert_true(distribution_text.text.find("卡组分布") >= 0, "总览页应显示卡组分布区块"),
	])

	_set_navigation_suppressed(false)
	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_selected_ids
	GameManager.first_player_choice = previous_first
	GameManager.ai_selection = previous_ai_selection
	GameManager.current_tournament = previous_tournament
	GameManager.tournament_selected_player_deck_id = previous_tournament_deck_id
	return result


func test_practice_battle_does_not_count_as_tournament_when_tournament_exists() -> String:
	var previous_tournament := GameManager.current_tournament
	var previous_tournament_deck_id := GameManager.tournament_selected_player_deck_id
	var previous_in_progress := GameManager.tournament_battle_in_progress
	var previous_names := GameManager.battle_player_display_names.duplicate()

	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345)
	GameManager.current_tournament = tournament
	GameManager.tournament_selected_player_deck_id = 575716
	GameManager.tournament_battle_in_progress = true
	GameManager.battle_player_display_names = ["测试玩家", "比赛对手"]
	GameManager.mark_current_battle_as_non_tournament()

	var result := run_checks([
		assert_true(GameManager.has_active_tournament(), "Practice setup may keep a resumable tournament object"),
		assert_false(GameManager.is_tournament_battle_active(), "Practice battle must not be finalized as a tournament match"),
		assert_eq(GameManager.battle_player_display_names, ["", ""], "Practice battle should clear tournament display names"),
	])

	GameManager.clear_tournament()
	GameManager.current_tournament = previous_tournament
	GameManager.tournament_selected_player_deck_id = previous_tournament_deck_id
	GameManager.tournament_battle_in_progress = previous_in_progress
	GameManager.battle_player_display_names = previous_names
	return result


func test_game_manager_prepares_first_tournament_round_for_battle() -> String:
	var previous_mode := GameManager.current_mode
	var previous_selected_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first := GameManager.first_player_choice
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_ai_deck_strategy := GameManager.ai_deck_strategy
	var previous_tournament := GameManager.current_tournament
	var previous_tournament_deck_id := GameManager.tournament_selected_player_deck_id

	GameManager.ai_deck_strategy = "raging_bolt_ogerpon_llm"
	GameManager.set_tournament_selected_player_deck_id(575716)
	GameManager.start_swiss_tournament("测试玩家", 16)
	var ok := GameManager.prepare_current_tournament_battle()
	var tournament = GameManager.current_tournament

	var result := run_checks([
		assert_true(ok, "应能准备第一轮比赛"),
		assert_not_null(tournament, "当前比赛对象应已创建"),
		assert_eq(GameManager.current_mode, GameManager.GameMode.VS_AI, "比赛模式对局应使用 VS_AI"),
		assert_eq(GameManager.selected_deck_ids.size(), 2, "比赛对局应写入双方卡组"),
		assert_eq(int(GameManager.selected_deck_ids[0]), 575716, "玩家卡组应写入 0 号槽"),
		assert_eq(GameManager.first_player_choice, -1, "比赛模式应随机先后攻"),
		assert_eq(GameManager.ai_deck_strategy, "generic", "比赛模式不应继承普通 AI 对战里残留的 LLM/手动策略变体"),
		assert_true(str(GameManager.ai_selection.get("display_name", "")).strip_edges() != "", "应为 AI 对手写入显示名"),
		assert_true(tournament != null and int(tournament.current_round) == 1, "准备第一轮后 round 应为 1"),
	])

	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_selected_ids
	GameManager.first_player_choice = previous_first
	GameManager.ai_selection = previous_ai_selection
	GameManager.ai_deck_strategy = previous_ai_deck_strategy
	GameManager.current_tournament = previous_tournament
	GameManager.tournament_selected_player_deck_id = previous_tournament_deck_id
	return result


func test_tournament_strong_ai_opponent_uses_fixed_opening_when_available() -> String:
	var previous_mode := GameManager.current_mode
	var previous_selected_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first := GameManager.first_player_choice
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_tournament := GameManager.current_tournament
	var previous_tournament_deck_id := GameManager.tournament_selected_player_deck_id

	GameManager.clear_tournament()
	GameManager.set_tournament_selected_player_deck_id(575720)
	GameManager.start_swiss_tournament("测试玩家", 16)
	var tournament = GameManager.current_tournament
	var pairing: Dictionary = tournament.prepare_next_round()
	var opponent_id := int(pairing.get("player_b_id", -1))
	if int(pairing.get("player_a_id", -1)) != int(tournament.player_participant_id):
		opponent_id = int(pairing.get("player_a_id", -1))
	for index: int in tournament.participants.size():
		var participant: Dictionary = tournament.participants[index]
		if int(participant.get("id", -1)) == opponent_id:
			participant["deck_id"] = 575716
			participant["ai_mode"] = "strong"
			tournament.participants[index] = participant
			break
	var ok := GameManager.prepare_current_tournament_battle()
	var fixed_path := str(GameManager.ai_selection.get("fixed_deck_order_path", ""))

	var result := run_checks([
		assert_true(ok, "强 AI 对手应能正常准备比赛对局"),
		assert_eq(str(GameManager.ai_selection.get("opening_mode", "")), "fixed_order", "强 AI 且存在固定起手时应自动启用 fixed_order"),
		assert_true(fixed_path.ends_with("/575716.json"), "强 AI 应挂接对应 deck_id 的 fixed order 文件"),
	])

	GameManager.clear_tournament()
	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_selected_ids
	GameManager.first_player_choice = previous_first
	GameManager.ai_selection = previous_ai_selection
	GameManager.current_tournament = previous_tournament
	GameManager.tournament_selected_player_deck_id = previous_tournament_deck_id
	return result


func test_persisted_in_progress_tournament_auto_forfeits_on_reload() -> String:
	var previous_mode := GameManager.current_mode
	var previous_selected_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first := GameManager.first_player_choice
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_tournament := GameManager.current_tournament
	var previous_tournament_deck_id := GameManager.tournament_selected_player_deck_id
	var previous_names := GameManager.battle_player_display_names.duplicate()
	var previous_in_progress := GameManager.tournament_battle_in_progress

	GameManager.clear_tournament()
	GameManager.set_tournament_selected_player_deck_id(575716)
	GameManager.start_swiss_tournament("测试玩家", 16)
	GameManager.prepare_current_tournament_battle()
	GameManager.reload_tournament_state_from_disk()

	var tournament = GameManager.current_tournament
	var summary: Dictionary = tournament.last_round_summary if tournament != null else {}

	var result := run_checks([
		assert_not_null(tournament, "重新加载后应恢复比赛对象"),
		assert_true(tournament != null and int(tournament.current_round) == 1, "自动判负后仍应停留在第 1 轮结算状态"),
		assert_eq(str(summary.get("result", "")), "loss", "中途退出的上一场比赛应被记为失败"),
		assert_true(str(summary.get("reason", "")).find("技术负") >= 0, "自动判负应写入技术负原因"),
		assert_false(GameManager.tournament_battle_in_progress, "自动判负后不应仍处于对局进行中状态"),
	])

	GameManager.clear_tournament()
	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_selected_ids
	GameManager.first_player_choice = previous_first
	GameManager.ai_selection = previous_ai_selection
	GameManager.current_tournament = previous_tournament
	GameManager.tournament_selected_player_deck_id = previous_tournament_deck_id
	GameManager.battle_player_display_names = previous_names
	GameManager.tournament_battle_in_progress = previous_in_progress
	return result
