class_name TestDeckDiscussionDialog
extends TestBase

const DialogScene := preload("res://scenes/deck_editor/DeckDiscussionDialog.tscn")


func test_dialog_instantiates_and_accepts_deck_context() -> String:
	var dialog := DialogScene.instantiate()
	var deck := DeckData.new()
	deck.id = 900001
	deck.deck_name = "讨论测试卡组"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "SV1", "card_index": "001", "count": 8, "card_type": "Pokemon", "name": "基础宝可梦"},
		{"set_code": "SV1", "card_index": "050", "count": 12, "card_type": "Basic Energy", "name": "能量"},
	]

	dialog.call("setup_for_deck", deck)
	var deck_name_label := dialog.get_node_or_null("%DeckNameLabel")
	var summary_label := dialog.get_node_or_null("%SummaryLabel")
	var question_input := dialog.get_node_or_null("%QuestionInput")
	var input_panel := dialog.get_node_or_null("%InputPanel")
	var transcript_list := dialog.get_node_or_null("%TranscriptList")
	var transcript_scroll := dialog.get_node_or_null("%TranscriptScroll")
	var suggestions_panel := dialog.get_node_or_null("%SuggestionsPanel")
	var header_panel := dialog.get_node_or_null("%HeaderPanel")
	var deck_art_panel := dialog.get_node_or_null("%DeckArtPanel")
	var title_label := dialog.get_node_or_null("%TitleLabel")
	var clamped_position: Vector2i = dialog.call("_clamp_dialog_position", Vector2i(-1000, -1000))
	var first_bubble_width := 0.0
	var first_has_ai_avatar := false
	var input_panel_height := 0.0
	var header_height := 0.0
	var header_bottom := 0.0
	var transcript_top := 0.0
	var transcript_bottom_with_suggestions := 0.0
	var suggestions_visible := false
	if transcript_list != null and transcript_list.get_child_count() > 0:
		var row := transcript_list.get_child(0)
		first_has_ai_avatar = row.get_child_count() > 0 and row.get_child(0) is PanelContainer
		for child: Node in row.get_children():
			if not (child is PanelContainer):
				continue
			var panel := child as PanelContainer
			if panel.get_child_count() > 0 and panel.get_child(0) is VBoxContainer:
				first_bubble_width = panel.custom_minimum_size.x
				break
	if input_panel != null:
		input_panel_height = (input_panel as Control).custom_minimum_size.y
	if header_panel != null:
		header_height = (header_panel as Control).offset_bottom - (header_panel as Control).offset_top
		header_bottom = (header_panel as Control).offset_bottom
	if transcript_scroll != null:
		transcript_top = (transcript_scroll as Control).offset_top
	var suggestions: Array[String] = ["洗翠沉重球有多大必要性？", "这张牌能换掉吗？"]
	dialog.call("_refresh_suggestion_buttons", suggestions)
	var empty_suggestions: Array[String] = []
	dialog.call("_refresh_suggestion_buttons", empty_suggestions, true)
	if transcript_scroll != null:
		transcript_bottom_with_suggestions = (transcript_scroll as Control).offset_bottom
	if suggestions_panel != null:
		suggestions_visible = (suggestions_panel as Control).visible
	dialog.queue_free()

	return run_checks([
		assert_not_null(deck_name_label, "对话框应包含卡组名标签"),
		assert_not_null(summary_label, "对话框应包含摘要标签"),
		assert_not_null(question_input, "对话框应包含固定底部输入框"),
		assert_true((title_label as Label).text.contains("探讨"), "标题应显示当前模型探讨文案"),
		assert_eq(clamped_position, Vector2i.ZERO, "对话框拖动位置应被限制在可见窗口内"),
		assert_eq((deck_name_label as Label).text, "讨论测试卡组", "应显示当前卡组名"),
		assert_true((summary_label as Label).text.contains("60张"), "摘要应包含基础统计"),
		assert_false((summary_label as Label).visible, "卡组编辑页的 AI 探讨应隐藏摘要，和对战时保持一致的紧凑 UI"),
		assert_true(header_height <= 76.0, "顶部卡组信息区域应使用对战式紧凑高度"),
		assert_true(transcript_top >= header_bottom + 12.0, "聊天滚动区不能和顶部卡组信息区域重叠"),
		assert_false((deck_art_panel as Control).visible, "顶部不应显示大 AI 头像方框"),
		assert_true(first_has_ai_avatar, "AI 头像应显示在 AI 气泡左侧"),
		assert_true(first_bubble_width >= 300.0, "消息气泡应有稳定横向宽度，避免每个字竖排换行"),
		assert_true(input_panel_height >= 130.0, "输入面板应保留足够高度，不能被聊天记录挤出屏幕"),
		assert_true(suggestions_visible, "生成结束时若没有新追问，应保留上一组三个追问按钮"),
		assert_true(transcript_bottom_with_suggestions <= -200.0, "聊天滚动区应为单行追问按钮预留底部空间"),
	])


func test_match_discussion_uses_compact_battle_style_header() -> String:
	var dialog := DialogScene.instantiate()
	var player_deck := DeckData.new()
	player_deck.id = 900101
	player_deck.deck_name = "玩家测试牌"
	player_deck.total_cards = 60
	var opponent_deck := DeckData.new()
	opponent_deck.id = 900202
	opponent_deck.deck_name = "对手测试牌"
	opponent_deck.total_cards = 60

	dialog.call("setup_for_match", player_deck, opponent_deck, "AI 卡组", 900101202, true)
	var deck_name_label := dialog.get_node_or_null("%DeckNameLabel") as Label
	var summary_label := dialog.get_node_or_null("%SummaryLabel") as Label
	var header_panel := dialog.get_node_or_null("%HeaderPanel") as Control
	var transcript_scroll := dialog.get_node_or_null("%TranscriptScroll") as Control
	var header_bottom := header_panel.offset_bottom if header_panel != null else 0.0
	var transcript_top := transcript_scroll.offset_top if transcript_scroll != null else 0.0
	dialog.queue_free()

	return run_checks([
		assert_not_null(deck_name_label, "Match discussion should keep the matchup title label"),
		assert_true(deck_name_label.text.contains("玩家测试牌") and deck_name_label.text.contains("对手测试牌"), "Match discussion should show both decks in the title line"),
		assert_not_null(summary_label, "Match discussion should still keep the summary node for other modes"),
		assert_false(summary_label.visible, "Battle setup strategy discussion should hide deck summary stats to free vertical space"),
		assert_true(header_bottom <= 126.0, "Battle setup strategy discussion should use the compact battle header height"),
		assert_true(transcript_top <= 144.0, "Battle setup strategy discussion transcript should start immediately below the compact header"),
	])
