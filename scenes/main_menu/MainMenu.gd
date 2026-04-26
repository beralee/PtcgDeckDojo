extends Control

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const SwissTournamentScript := preload("res://scripts/tournament/SwissTournament.gd")
const MENU_VERTICAL_SHIFT := 130.0
const CHAMPION_PREVIEW_PLAYER_NAME := "冠军玩家"
const CHAMPION_PREVIEW_DECK_ID := 575716
const CHAMPION_PREVIEW_PLAYER_COUNT := 16


func _ready() -> void:
	_apply_main_menu_hud()
	%BtnSettings.text = "AI 设置"
	%BtnStartBattle.pressed.connect(_on_start_battle)
	%BtnTournament.pressed.connect(_on_tournament)
	%BtnDeckManager.pressed.connect(_on_deck_manager)
	%BtnBattleReplay.pressed.connect(_on_battle_replay)
	%BtnSettings.pressed.connect(_on_settings)
	%BtnQuit.pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed and key_event.shift_pressed and key_event.keycode == KEY_C:
		get_viewport().set_input_as_handled()
		_open_champion_preview()


func _apply_main_menu_hud() -> void:
	var menu := get_node_or_null("VBoxContainer") as VBoxContainer
	if menu != null:
		menu.offset_top = -175.0 + MENU_VERTICAL_SHIFT
		menu.offset_bottom = 175.0 + MENU_VERTICAL_SHIFT
		menu.add_theme_constant_override("separation", 16)
	for button_name: String in ["BtnStartBattle", "BtnTournament", "BtnDeckManager", "BtnBattleReplay", "BtnSettings", "BtnQuit"]:
		var button := get_node_or_null("%" + button_name) as Button
		if button == null:
			continue
		var is_primary := button_name in ["BtnStartBattle", "BtnTournament"]
		var accent: Color = HudThemeScript.ACCENT_WARM if is_primary else HudThemeScript.ACCENT
		button.custom_minimum_size = Vector2(280, 48)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color(0.03, 0.07, 0.10, 1.0))
		button.add_theme_stylebox_override("normal", _main_menu_button_style(accent, is_primary, false, false))
		button.add_theme_stylebox_override("hover", _main_menu_button_style(accent, is_primary, true, false))
		button.add_theme_stylebox_override("pressed", _main_menu_button_style(accent, is_primary, true, true))
		button.add_theme_stylebox_override("disabled", _main_menu_button_style(Color(0.30, 0.34, 0.38, 1.0), false, false, false))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _main_menu_button_style(accent: Color, primary: bool, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.105, 0.145, 0.72)
	if primary:
		style.bg_color = Color(0.055, 0.115, 0.140, 0.76)
	if hover:
		style.bg_color = Color(0.070, 0.170, 0.215, 0.86)
	if pressed:
		style.bg_color = Color(0.35, 0.78, 0.88, 0.92)
	style.border_color = Color(0.42, 0.92, 1.0, 0.62)
	if primary:
		style.border_color = Color(accent.r, accent.g, accent.b, 0.52)
	if hover:
		style.border_color = Color(accent.r, accent.g, accent.b, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18 if hover else 0.08)
	style.shadow_size = 7 if hover else 3
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _on_start_battle() -> void:
	GameManager.goto_battle_setup()


func _on_tournament() -> void:
	if GameManager.has_resumable_tournament_overview():
		GameManager.goto_tournament_overview()
		return
	if GameManager.has_active_tournament():
		GameManager.goto_tournament_standings()
		return
	GameManager.goto_tournament_deck_select()


func _on_deck_manager() -> void:
	GameManager.goto_deck_manager()


func _on_battle_replay() -> void:
	GameManager.goto_replay_browser()


func _on_settings() -> void:
	GameManager.goto_settings()


func _on_quit() -> void:
	get_tree().quit()


func _open_champion_preview() -> void:
	var tournament = SwissTournamentScript.new()
	tournament.setup(CHAMPION_PREVIEW_PLAYER_NAME, CHAMPION_PREVIEW_DECK_ID, CHAMPION_PREVIEW_PLAYER_COUNT, 20260426)
	tournament.current_round = tournament.total_rounds
	tournament.finished = true
	tournament.last_round_summary = _build_champion_preview_summary(tournament)
	GameManager.current_tournament = tournament
	GameManager.tournament_selected_player_deck_id = CHAMPION_PREVIEW_DECK_ID
	GameManager.tournament_battle_in_progress = false
	GameManager.clear_battle_player_display_names()
	GameManager.goto_tournament_standings()


func _build_champion_preview_summary(tournament) -> Dictionary:
	var standings: Array[Dictionary] = [
		{
			"id": 0,
			"name": CHAMPION_PREVIEW_PLAYER_NAME,
			"wins": tournament.total_rounds,
			"losses": 0,
			"draws": 0,
			"points": tournament.total_rounds * 3,
			"rank": 1,
		},
		{
			"id": 1,
			"name": "决赛对手",
			"wins": max(0, tournament.total_rounds - 1),
			"losses": 1,
			"draws": 0,
			"points": max(0, tournament.total_rounds - 1) * 3,
			"rank": 2,
		},
		{
			"id": 2,
			"name": "稳定强敌",
			"wins": max(0, tournament.total_rounds - 1),
			"losses": 1,
			"draws": 0,
			"points": max(0, tournament.total_rounds - 1) * 3,
			"rank": 3,
		},
		{
			"id": 3,
			"name": "黑马选手",
			"wins": max(0, tournament.total_rounds - 2),
			"losses": 2,
			"draws": 0,
			"points": max(0, tournament.total_rounds - 2) * 3,
			"rank": 4,
		},
	]
	return {
		"round": tournament.total_rounds,
		"result": "win",
		"is_final_round": true,
		"reason": "隐藏冠军预览",
		"player": standings[0],
		"opponent": {
			"id": 1,
			"name": "决赛对手",
		},
		"standings": standings,
	}
