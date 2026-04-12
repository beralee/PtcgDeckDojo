class_name TestBattleAIAdviceCopy
extends TestBase

const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


func _u(codepoints: Array[int]) -> String:
	var text := ""
	for codepoint: int in codepoints:
		text += char(codepoint)
	return text


func _make_scene_stub() -> Control:
	var scene := BattleSceneScript.new()
	scene.set("_log_list", RichTextLabel.new())
	scene.set("_hand_container", HBoxContainer.new())
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_review_overlay", Panel.new())
	return scene


func _make_basic_pokemon(name: String) -> CardInstance:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = 70
	cd.energy_type = "R"
	return CardInstance.create(cd, 0)


func test_ai_advice_format_uses_readable_chinese_sections() -> String:
	var scene := _make_scene_stub()
	var formatted := str(scene.call("_format_battle_advice", {
		"status": "completed",
		"strategic_thesis": _u([0x8FD9, 0x56DE, 0x5408, 0x5148, 0x628A, 0x6C99, 0x5948, 0x6735, 0x7EBF, 0x7AD9, 0x9F50, 0xFF0C, 0x4E0D, 0x8981, 0x4E3A, 0x4E86, 0x5C0F, 0x4F24, 0x5BB3, 0x6253, 0x4E71, 0x5C55, 0x5F00, 0x3002]),
		"current_turn_main_line": [
			{"step": 1, "action": _u([0x5148, 0x7528, 0x6D3E, 0x5E15, 0x627E, 0x62DB, 0x5F0F, 0x5B66, 0x4E60, 0x5668, 0x20, 0x8FDB, 0x5316, 0x548C, 0x5927, 0x5730, 0x5BB9, 0x5668]), "why": _u([0x8FD9, 0x4E24, 0x5F20, 0x6700, 0x76F4, 0x63A5, 0x63A8, 0x8FDB, 0x540E, 0x624B, 0x4E00, 0x56DE, 0x5408, 0x5C55, 0x5F00, 0x3002])},
			{"step": 2, "action": _u([0x7528, 0x5927, 0x5730, 0x5BB9, 0x5668, 0x5F03, 0x31, 0x5F20, 0x724C, 0x5E76, 0x627E, 0x57FA, 0x672C, 0x8D85, 0x80FD, 0x91CF, 0x8D34, 0x6218, 0x6597, 0x533A]), "why": _u([0x4FDD, 0x8BC1, 0x5F53, 0x524D, 0x56DE, 0x5408, 0x624B, 0x8D34, 0xFF0C, 0x540C, 0x65F6, 0x4E3A, 0x540E, 0x7EED, 0x7CBE, 0x795E, 0x62E5, 0x62B1, 0x505A, 0x51C6, 0x5907, 0x3002])},
		],
		"conditional_branches": [
			{"if": _u([0x53CB, 0x597D, 0x5B9D, 0x82AC, 0x5DF2, 0x7ECF, 0x62FF, 0x5230, 0x7B2C, 0x4E8C, 0x53EA, 0x62C9, 0x9C81, 0x62C9, 0x4E1D]), "then": [_u([0x4F18, 0x5148, 0x8BA9, 0x4E24, 0x4E2A, 0x540E, 0x6392, 0x90FD, 0x80FD, 0x5728, 0x4E0B, 0x56DE, 0x5408, 0x8FDB, 0x5316, 0x3002])]},
		],
		"prize_plan": [
			{"horizon": "next_two_turns", "goal": _u([0x4E24, 0x56DE, 0x5408, 0x5185, 0x505A, 0x51FA, 0x6C99, 0x5948, 0x6735, 0x65E0, 0x9650, 0xFF2D, 0x65E0, 0x9650, 0x4E0D, 0x5BF9])},
		],
		"why_this_line": [_u([0x5C55, 0x5F00, 0x548C, 0x80FD, 0x91CF, 0x5E03, 0x5C40, 0x7684, 0x6536, 0x76CA, 0x660E, 0x663E, 0x9AD8, 0x4E8E, 0x5F53, 0x524D, 0x56DE, 0x5408, 0x6253, 0x5C0F, 0x4F24, 0x5BB3, 0x3002])],
		"risk_watchouts": [
			{"risk": _u([0x5982, 0x679C, 0x5148, 0x628A, 0x652F, 0x63F4, 0x8005, 0x7528, 0x5728, 0x4F4E, 0x6536, 0x76CA, 0x62BD, 0x724C, 0x4E0A, 0xFF0C, 0x4F1A, 0x62D6, 0x6162, 0x8FDB, 0x5316, 0x8282, 0x594F, 0x3002]), "mitigation": _u([0x4F18, 0x5148, 0x62FF, 0x80FD, 0x76F4, 0x63A5, 0x5C55, 0x5F00, 0x7684, 0x68C0, 0x7D22, 0x4EF6, 0x3002])},
		],
		"confidence": "high",
	}))

	return run_checks([
		assert_str_contains(formatted, _u([0x6838, 0x5FC3, 0x5224, 0x65AD]), "Advice formatter should render a readable thesis title"),
		assert_str_contains(formatted, _u([0x672C, 0x56DE, 0x5408, 0x4E3B, 0x7EBF]), "Advice formatter should render the main-line section title"),
		assert_str_contains(formatted, _u([0x6761, 0x4EF6, 0x5206, 0x652F]), "Advice formatter should render the branch section title"),
		assert_str_contains(formatted, _u([0x62FF, 0x5956, 0x8282, 0x594F]), "Advice formatter should render the prize-plan section title"),
		assert_str_contains(formatted, _u([0x4E3A, 0x4EC0, 0x4E48, 0x8FD9, 0x6837, 0x6253]), "Advice formatter should render the rationale section title"),
		assert_str_contains(formatted, _u([0x98CE, 0x9669, 0x63D0, 0x9192]), "Advice formatter should render the risk section title"),
		assert_str_contains(formatted, _u([0x7F6E, 0x4FE1, 0x5EA6]), "Advice formatter should render the confidence label"),
		assert_false("??" in formatted, "Advice formatter should not emit placeholder question-mark copy"),
		assert_false(_u([0x6FE1, 0x59A7, 0x7075]) in formatted, "Advice formatter should not emit mojibake branch copy"),
	])


func test_battle_scene_topbar_and_log_title_use_readable_copy() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var ai_button := scene.find_child("BtnAiAdvice", true, false) as Button
	var zeus_button := scene.find_child("BtnZeusHelp", true, false) as Button
	var log_title := scene.find_child("LogTitle", true, false) as Label
	var log_panel := scene.find_child("LogPanel", true, false) as PanelContainer
	var log_list := scene.find_child("LogList", true, false) as RichTextLabel

	return run_checks([
		assert_true(ai_button != null, "BattleScene should expose BtnAiAdvice"),
		assert_true(log_title != null, "BattleScene should expose LogTitle"),
		assert_true(log_panel != null, "BattleScene should expose LogPanel"),
		assert_true(log_list != null, "BattleScene should expose LogList"),
		assert_eq(ai_button.text, _u([0x41, 0x49, 0x5EFA, 0x8BAE]), "BtnAiAdvice should use readable Chinese copy"),
		assert_eq(zeus_button.text, _u([0x5B99, 0x65AF, 0x5E2E, 0x6211]), "BtnZeusHelp should preserve its readable Chinese copy"),
		assert_eq(log_title.text, _u([0x64CD, 0x4F5C, 0x65E5, 0x5FD7]), "Right-side log title should use readable Chinese copy"),
		assert_eq(log_panel.custom_minimum_size.x, 236.0, "Right-side log panel should reserve more width for readable copy"),
		assert_eq(log_title.get_theme_font_size("font_size"), 12, "Log title should use the larger readable font size"),
		assert_eq(log_list.get_theme_font_size("normal_font_size"), 11, "Log body should use the larger readable font size"),
	])


func test_selecting_basic_pokemon_writes_readable_log_copy() -> String:
	var scene := _make_scene_stub()
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

	var basic := _make_basic_pokemon(_u([0x5C0F, 0x706B, 0x9F99]))
	gsm.game_state.players[0].hand = [basic]

	scene.call("_on_hand_card_clicked", basic, PanelContainer.new())

	var log_list := scene.get("_log_list") as RichTextLabel
	if log_list == null or log_list.get_parsed_text().strip_edges().is_empty():
		return "Selecting a basic Pokemon should append at least one log entry"

	var lines := log_list.get_parsed_text().strip_edges().split("\n")
	var last_log := lines[lines.size() - 1]
	return run_checks([
		assert_eq(last_log, _u([0x5DF2, 0x9009, 0x4E2D, 0x20, 0x5C0F, 0x706B, 0x9F99, 0xFF0C, 0x70B9, 0x51FB, 0x5907, 0x6218, 0x533A, 0x8FDB, 0x884C, 0x653E, 0x7F6E]), "Selecting a basic Pokemon should write readable Chinese action guidance"),
		assert_false("??" in last_log, "Action log should not contain placeholder question marks"),
		assert_false(char(0xFFFD) in last_log, "Action log should not contain replacement characters"),
	])


func test_battle_scene_source_has_no_placeholder_copy() -> String:
	var source := FileAccess.get_file_as_string("res://scenes/battle/BattleScene.gd")
	var placeholder := "?" + "?" + "?"

	return run_checks([
		assert_false(placeholder in source, "BattleScene source should not contain placeholder question-mark copy"),
		assert_false(char(0xFFFD) in source, "BattleScene source should not contain replacement characters"),
	])
