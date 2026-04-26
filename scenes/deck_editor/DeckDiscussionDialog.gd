extends AcceptDialog

signal assistant_response_finished

const DeckDiscussionServiceScript = preload("res://scripts/engine/DeckDiscussionService.gd")

const DIALOG_SIZE := Vector2i(980, 760)
const DIALOG_MIN_SIZE := Vector2i(820, 620)
const MAX_BUBBLE_WIDTH := 620.0
const MIN_BUBBLE_WIDTH := 320.0
const HEADER_COMPACT_BOTTOM := 166.0
const HEADER_BATTLE_BOTTOM := 126.0
const TRANSCRIPT_TOP := 180.0
const TRANSCRIPT_BATTLE_TOP := 144.0
const TRANSCRIPT_BOTTOM := -164.0
const TRANSCRIPT_BOTTOM_WITH_SUGGESTIONS := -206.0
const STREAM_CHARS_PER_TICK := 8
const STREAM_INTERVAL_SECONDS := 0.018
const PENDING_TEXT := "正在分析当前卡组和你的问题..."
const COLOR_PANEL := Color(0.035, 0.055, 0.095, 0.98)
const COLOR_SURFACE := Color(0.055, 0.085, 0.135, 0.92)
const COLOR_SURFACE_2 := Color(0.075, 0.105, 0.17, 0.94)
const COLOR_LINE := Color(0.22, 0.72, 0.86, 0.42)
const COLOR_TEXT := Color(0.90, 0.94, 0.98, 1.0)
const COLOR_MUTED := Color(0.58, 0.68, 0.78, 1.0)
const COLOR_ACCENT := Color(0.18, 0.88, 0.92, 1.0)
const COLOR_WARN := Color(1.0, 0.72, 0.34, 1.0)

var _service = DeckDiscussionServiceScript.new()
var _deck: DeckData = null
var _forced_external_tool_results: Array[Dictionary] = []
var _battle_context_provider: Callable = Callable()
var _latest_suggestions: Array[String] = []
var _stream_timer: Timer = null
var _stream_body: RichTextLabel = null
var _stream_full_text := ""
var _stream_index := 0
var _stream_metadata: Dictionary = {}


func _ready() -> void:
	title = _discussion_title()
	ok_button_text = "关闭"
	dialog_hide_on_ok = true
	min_size = DIALOG_MIN_SIZE
	size = DIALOG_SIZE
	_service.message_completed.connect(_on_service_message_completed)
	_service.status_changed.connect(_on_service_status_changed)
	close_requested.connect(_on_dialog_close_requested)
	%SendButton.pressed.connect(_on_send_pressed)
	%ResetButton.pressed.connect(_on_reset_pressed)
	%CloseButton.pressed.connect(_on_dialog_close_requested)
	%QuestionInput.gui_input.connect(_on_question_input_gui_input)
	%StatusLabel.text = ""
	%TitleLabel.text = _discussion_title()
	_apply_compact_layout()
	_stream_timer = Timer.new()
	_stream_timer.one_shot = false
	_stream_timer.wait_time = STREAM_INTERVAL_SECONDS
	_stream_timer.timeout.connect(_on_stream_tick)
	add_child(_stream_timer)
	_apply_visual_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _on_dialog_close_requested() -> void:
	_stop_stream_timer()
	hide()


func _clamp_dialog_position(target: Vector2i) -> Vector2i:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2i.ZERO
	var viewport_rect := viewport.get_visible_rect()
	var min_pos := Vector2i(viewport_rect.position)
	var max_pos := Vector2i(
		int(viewport_rect.position.x + viewport_rect.size.x) - size.x,
		int(viewport_rect.position.y + viewport_rect.size.y) - size.y
	)
	return Vector2i(
		clampi(target.x, min_pos.x, maxi(min_pos.x, max_pos.x)),
		clampi(target.y, min_pos.y, maxi(min_pos.y, max_pos.y))
	)


func setup_for_deck(deck: DeckData) -> void:
	_stop_stream_timer()
	_stream_body = null
	_forced_external_tool_results.clear()
	_battle_context_provider = Callable()
	_deck = deck
	_apply_battle_layout()
	%TitleLabel.text = _discussion_title()
	%DeckNameLabel.text = deck.deck_name
	%SummaryLabel.text = _format_summary_stats(_service.build_quick_summary(deck))
	%SummaryLabel.visible = false
	%StatusLabel.text = ""
	%SendButton.disabled = false
	_apply_fixed_window_size.call_deferred()
	_reload_transcript()
	_refresh_suggestion_buttons([])
	%QuestionInput.call_deferred("grab_focus")


func setup_for_match(player_deck: DeckData, opponent_deck: DeckData, opponent_label: String = "AI 卡组", session_id: int = 0, reset_session: bool = false) -> void:
	if player_deck == null or opponent_deck == null:
		return
	_stop_stream_timer()
	_stream_body = null
	_battle_context_provider = Callable()
	var match_deck := _make_match_session_deck(player_deck, opponent_deck, opponent_label, session_id)
	_forced_external_tool_results = [_make_deck_tool_result(opponent_deck, opponent_label)]
	_deck = match_deck
	_apply_battle_layout()
	if reset_session:
		_service.clear_history(_deck.id)
	%TitleLabel.text = _discussion_title()
	%DeckNameLabel.text = "对战设置：%s  vs  %s" % [player_deck.deck_name, opponent_deck.deck_name]
	%SummaryLabel.text = "玩家卡组：%s\n%s：%s" % [
		_format_summary_stats(_service.build_quick_summary(player_deck)),
		opponent_label,
		_format_summary_stats(_service.build_quick_summary(opponent_deck)),
	]
	%SummaryLabel.visible = false
	%StatusLabel.text = ""
	%SendButton.disabled = false
	_apply_fixed_window_size.call_deferred()
	_reload_transcript()
	_refresh_suggestion_buttons([])
	%QuestionInput.call_deferred("grab_focus")


func setup_for_battle_context(view_deck: DeckData, battle_context: Dictionary, session_id: int = 0, reset_session: bool = false, context_provider: Callable = Callable()) -> void:
	if view_deck == null:
		return
	_stop_stream_timer()
	_stream_body = null
	_battle_context_provider = context_provider
	var context_deck := _make_battle_session_deck(view_deck, battle_context, session_id)
	_forced_external_tool_results = [{
		"tool_name": "get_live_battle_context",
		"query": "当前对战场面",
		"status": "ok",
		"battle_context": battle_context.duplicate(true),
	}]
	_deck = context_deck
	_apply_battle_layout()
	if reset_session:
		_service.clear_history(_deck.id)
	%TitleLabel.text = _discussion_title()
	%DeckNameLabel.text = "当前对战：%s" % str(battle_context.get("perspective_label", view_deck.deck_name))
	%SummaryLabel.text = ""
	%SummaryLabel.visible = false
	%StatusLabel.text = ""
	%SendButton.disabled = false
	_apply_fixed_window_size.call_deferred()
	_reload_transcript()
	_refresh_suggestion_buttons([])
	%QuestionInput.call_deferred("grab_focus")


func _make_battle_session_deck(view_deck: DeckData, battle_context: Dictionary, session_id: int) -> DeckData:
	var result := DeckData.new()
	result.id = session_id if session_id > 0 else 730000000 + (abs(view_deck.id) % 100000)
	result.deck_name = "对战探讨：%s" % view_deck.deck_name
	result.variant_name = result.deck_name
	result.total_cards = view_deck.total_cards
	result.cards = view_deck.cards.duplicate(true)
	result.strategy = "当前讨论发生在对战页面。主视角为%s。回答必须结合 live battle_context 里的当前公开场面、己方手牌、己方卡组信息和奖赏/弃牌情况；不得假设或引用对手隐藏手牌、奖赏身份或牌库内容。" % str(battle_context.get("perspective_label", view_deck.deck_name))
	return result


func _battle_context_summary(view_deck: DeckData, battle_context: Dictionary) -> String:
	var state: Dictionary = battle_context.get("state", {})
	var public_info: Dictionary = battle_context.get("public_counts", {})
	return "%s\nTurn %s | Phase %s | Acting player %s (%s)\nPrize remaining: %s | Prizes taken: %s\nMy hand/deck %s/%s | Opp hand/deck %s/%s" % [
		_format_summary_stats(_service.build_quick_summary(view_deck)),
		str(state.get("turn_number", "")),
		str(state.get("phase", "")),
		str(int(state.get("current_player_index", -1)) + 1),
		str(state.get("acting_side_from_perspective", "?")),
		str(public_info.get("prize_remaining_score", "?")),
		str(public_info.get("prizes_taken_score", "?")),
		str(public_info.get("my_hand_count", "?")),
		str(public_info.get("my_deck_count", "?")),
		str(public_info.get("opponent_hand_count", "?")),
		str(public_info.get("opponent_deck_count", "?")),
	]
	return "%s\n回合：%s | 阶段：%s | 当前行动方：玩家%s\n己方手牌%s张，牌库%s张，奖赏%s张；对方手牌%s张，牌库%s张，奖赏%s张" % [
		_format_summary_stats(_service.build_quick_summary(view_deck)),
		str(state.get("turn_number", "")),
		str(state.get("phase", "")),
		str(int(state.get("current_player_index", -1)) + 1),
		str(public_info.get("my_hand_count", "?")),
		str(public_info.get("my_deck_count", "?")),
		str(public_info.get("my_prize_count", "?")),
		str(public_info.get("opponent_hand_count", "?")),
		str(public_info.get("opponent_deck_count", "?")),
		str(public_info.get("opponent_prize_count", "?")),
	]


func _make_match_session_deck(player_deck: DeckData, opponent_deck: DeckData, opponent_label: String, session_id: int) -> DeckData:
	var result := DeckData.new()
	result.id = session_id if session_id > 0 else _match_session_id(player_deck.id, opponent_deck.id, opponent_label)
	result.deck_name = "对战策略：%s vs %s" % [player_deck.deck_name, opponent_deck.deck_name]
	result.variant_name = result.deck_name
	result.total_cards = player_deck.total_cards
	result.cards = player_deck.cards.duplicate(true)
	result.strategy = "当前讨论是对战设置页的策略分析。主视角为玩家卡组：%s。对手为%s：%s。回答必须结合两套牌，不要只分析其中一套。" % [
		player_deck.deck_name,
		opponent_label,
		opponent_deck.deck_name,
	]
	return result


func _make_deck_tool_result(deck: DeckData, opponent_label: String) -> Dictionary:
	var deck_context: Dictionary = _service.build_context(deck)
	deck_context["context_role"] = opponent_label
	return {
		"tool_name": "get_other_deck_detail",
		"query": deck.deck_name,
		"status": "ok",
		"deck_context": deck_context,
	}


func _match_session_id(player_deck_id: int, opponent_deck_id: int, opponent_label: String) -> int:
	var mode_offset := 700000000 if opponent_label.contains("AI") else 710000000
	return mode_offset + (abs(player_deck_id) % 10000) * 10000 + (abs(opponent_deck_id) % 10000)


func _apply_fixed_window_size() -> void:
	min_size = DIALOG_MIN_SIZE
	size = DIALOG_SIZE


func _apply_compact_layout() -> void:
	if has_node("%HeaderPanel"):
		%HeaderPanel.offset_bottom = HEADER_COMPACT_BOTTOM
	if has_node("%SummaryLabel"):
		%SummaryLabel.visible = true
	if has_node("%TranscriptScroll"):
		%TranscriptScroll.offset_top = TRANSCRIPT_TOP
		%TranscriptScroll.offset_bottom = TRANSCRIPT_BOTTOM


func _apply_battle_layout() -> void:
	if has_node("%HeaderPanel"):
		%HeaderPanel.offset_bottom = HEADER_BATTLE_BOTTOM
	if has_node("%SummaryLabel"):
		%SummaryLabel.visible = false
	if has_node("%TranscriptScroll"):
		%TranscriptScroll.offset_top = TRANSCRIPT_BATTLE_TOP
		%TranscriptScroll.offset_bottom = TRANSCRIPT_BOTTOM


func _format_summary_stats(summary: String) -> String:
	var parts := summary.split(",", false)
	var labels: Array[String] = ["CARDS", "BASIC", "ENERGY", "OPEN", "REDRAW"]
	var out: PackedStringArray = []
	for i: int in parts.size():
		var part := str(parts[i]).strip_edges()
		if part == "":
			continue
		var label: String = labels[i] if i < labels.size() else "STAT"
		out.append("%s  %s" % [label, part])
	return "    |    ".join(out)


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, Color(0.18, 0.35, 0.46, 0.75), 18, 0, 18))
	add_theme_color_override("title_color", COLOR_TEXT)
	add_theme_font_size_override("title_font_size", 18)
	if get_ok_button() != null:
		get_ok_button().text = "关闭"
		get_ok_button().visible = false
		_style_button(get_ok_button(), false)

	%TitleLabel.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	%TitleLabel.add_theme_color_override("font_shadow_color", Color(0.10, 0.55, 0.95, 0.65))
	%TitleLabel.add_theme_constant_override("shadow_offset_x", 0)
	%TitleLabel.add_theme_constant_override("shadow_offset_y", 2)
	_style_icon_button(%CloseButton)
	%HeaderPanel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_SURFACE, COLOR_LINE, 14, 14, 10))
	%DeckArtPanel.visible = false
	%DeckNameLabel.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	%DeckNameLabel.add_theme_font_size_override("font_size", 22)
	%SummaryLabel.add_theme_color_override("font_color", Color(0.74, 0.84, 0.92, 1.0))
	%SummaryLabel.add_theme_font_size_override("font_size", 16)
	%SummaryLabel.custom_minimum_size = Vector2(0, 40)
	%StatusLabel.add_theme_color_override("font_color", COLOR_WARN)
	%StatusLabel.add_theme_font_size_override("font_size", 13)
	if %TranscriptList != null:
		%TranscriptList.add_theme_constant_override("separation", 12)
	if %SuggestionsPanel != null:
		%SuggestionsPanel.add_theme_constant_override("separation", 8)

	%InputPanel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.028, 0.044, 0.072, 0.97), Color(0.18, 0.68, 0.82, 0.48), 16, 12, 12))
	%InputLabel.add_theme_color_override("font_color", Color(0.72, 0.84, 0.92, 1.0))
	%InputLabel.add_theme_font_size_override("font_size", 13)
	%QuestionInput.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	%QuestionInput.add_theme_color_override("placeholder_color", Color(0.50, 0.58, 0.66, 1.0))
	%QuestionInput.add_theme_font_size_override("font_size", 15)
	var input_normal := _make_panel_style(Color(0.015, 0.024, 0.042, 0.92), Color(0.18, 0.31, 0.40, 0.95), 12, 10, 0)
	var input_focus := _make_panel_style(Color(0.020, 0.036, 0.062, 0.97), Color(0.22, 0.86, 0.95, 0.95), 12, 10, 0)
	%QuestionInput.add_theme_stylebox_override("normal", input_normal)
	%QuestionInput.add_theme_stylebox_override("focus", input_focus)
	%QuestionInput.add_theme_stylebox_override("read_only", input_normal)
	_style_icon_button(%AttachButton)
	_style_button(%ResetButton, false)
	_style_button(%SendButton, true)


func _make_panel_style(bg: Color, border: Color, radius: int, margin: int, shadow_size: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0, 5)
	return style


func _style_button(button: Button, primary: bool) -> void:
	if button == null:
		return
	var normal_bg := Color(0.08, 0.13, 0.18, 0.96)
	var hover_bg := Color(0.11, 0.18, 0.24, 0.98)
	var pressed_bg := Color(0.05, 0.10, 0.14, 1.0)
	var border := Color(0.22, 0.34, 0.42, 0.9)
	if primary:
		normal_bg = Color(0.02, 0.55, 0.62, 1.0)
		hover_bg = Color(0.07, 0.70, 0.76, 1.0)
		pressed_bg = Color(0.02, 0.40, 0.48, 1.0)
		border = Color(0.50, 1.0, 0.96, 0.65)
	button.add_theme_stylebox_override("normal", _make_panel_style(normal_bg, border, 10, 10, 0))
	button.add_theme_stylebox_override("hover", _make_panel_style(hover_bg, border, 10, 10, 0))
	button.add_theme_stylebox_override("pressed", _make_panel_style(pressed_bg, border, 10, 10, 0))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.05, 0.07, 0.09, 0.80), Color(0.12, 0.15, 0.18, 0.8), 10, 10, 0))
	button.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.54, 0.60, 1.0))
	button.add_theme_font_size_override("font_size", 14)


func _style_icon_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.04, 0.07, 0.11, 0.0), Color(0, 0, 0, 0), 999, 0, 0))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.12, 0.20, 0.28, 0.85), Color(0.30, 0.76, 0.95, 0.55), 999, 0, 0))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.04, 0.12, 0.18, 0.95), Color(0.20, 0.70, 0.90, 0.75), 999, 0, 0))
	button.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.70, 0.94, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", 28)


func _style_chip_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.06, 0.12, 0.18, 0.86), Color(0.18, 0.62, 0.75, 0.55), 999, 9, 0))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.08, 0.20, 0.27, 0.95), Color(0.30, 0.88, 0.94, 0.85), 999, 9, 0))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.04, 0.16, 0.22, 1.0), Color(0.24, 0.74, 0.82, 0.9), 999, 9, 0))
	button.add_theme_color_override("font_color", Color(0.70, 0.90, 0.96, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.93, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.88, 1.0, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", 13)


func _reload_transcript() -> void:
	for child: Node in %TranscriptList.get_children():
		child.queue_free()
	if _deck == null:
		return
	var history: Array[Dictionary] = _service.load_history(_deck.id)
	if history.is_empty():
		if _forced_external_tool_results.is_empty():
			_add_hint_message("assistant", "可以直接问这套牌的起手稳定性、关键牌上手率、能量曲线、对局思路或换牌方向。每次提问都会自动带上当前卡组上下文。")
		elif not _forced_external_tool_results.is_empty() and str(_forced_external_tool_results[0].get("tool_name", "")) == "get_live_battle_context":
			_add_hint_message("assistant", "可以直接问当前场面怎么打、这回合优先做什么、该不该进攻/撤退/用支援者，以及后续几回合的奖赏路线。上下文只包含当前视角可见信息。")
		else:
			_add_hint_message("assistant", "可以直接问这两套牌的对局优劣、关键威胁、先后手计划、换牌方向和具体 counter。每次提问都会自动带上双方完整卡组上下文。")
		return

	var last_suggestions: Array[String] = []
	for entry: Dictionary in history:
		var role := str(entry.get("role", ""))
		var content := str(entry.get("content", ""))
		var metadata: Dictionary = entry.get("metadata", {})
		_add_message_bubble(role, content, metadata)
		if role == "assistant":
			var suggestions_variant: Variant = metadata.get("suggested_questions", [])
			if suggestions_variant is Array:
				last_suggestions.clear()
				for item: Variant in suggestions_variant:
					last_suggestions.append(str(item))
	_refresh_suggestion_buttons(last_suggestions)
	_queue_scroll_to_bottom()


func _add_hint_message(role: String, content: String) -> void:
	_add_message_bubble(role, content, {})
	_queue_scroll_to_bottom()


func _create_avatar(label_text: String, user: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(58, 58)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var bg := Color(0.08, 0.16, 0.25, 0.96) if not user else Color(0.22, 0.12, 0.04, 0.96)
	var border := Color(0.28, 0.78, 1.0, 0.85) if not user else Color(1.0, 0.62, 0.18, 0.90)
	panel.add_theme_stylebox_override("panel", _make_panel_style(bg, border, 999, 0, 6))
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.95, 0.99, 1.0, 1.0))
	panel.add_child(label)
	return panel


func _add_message_bubble(role: String, content: String, metadata: Dictionary) -> RichTextLabel:
	var outer := HBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.alignment = BoxContainer.ALIGNMENT_END if role == "user" else BoxContainer.ALIGNMENT_BEGIN
	outer.add_theme_constant_override("separation", 12)
	%TranscriptList.add_child(outer)

	var bubble_width := _bubble_width()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(bubble_width, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END if role == "user" else Control.SIZE_SHRINK_BEGIN
	var style := _make_panel_style(
		Color(0.05, 0.37, 0.43, 0.96) if role == "user" else Color(0.07, 0.105, 0.17, 0.95),
		Color(0.32, 0.90, 0.92, 0.52) if role == "user" else Color(0.22, 0.38, 0.56, 0.78),
		14,
		12,
		6
	)
	panel.add_theme_stylebox_override("panel", style)
	if role == "assistant":
		outer.add_child(_create_avatar("AI", false))
	outer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(maxf(bubble_width - 24.0, MIN_BUBBLE_WIDTH - 24.0), 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color", COLOR_TEXT)
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_font_size_override("bold_font_size", 15)
	body.text = _message_to_bbcode(content)
	vbox.add_child(body)

	if role == "user":
		outer.add_child(_create_avatar("你", true))

	if role != "assistant":
		return body

	var math_steps_variant: Variant = metadata.get("math_steps", [])
	if math_steps_variant is Array and not (math_steps_variant as Array).is_empty():
		var math_title := Label.new()
		math_title.text = "推导："
		math_title.add_theme_color_override("font_color", Color(0.8, 0.86, 0.95))
		vbox.add_child(math_title)
		for step_variant: Variant in math_steps_variant:
			var step_label := RichTextLabel.new()
			step_label.bbcode_enabled = true
			step_label.fit_content = true
			step_label.scroll_active = false
			step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			step_label.text = _message_to_bbcode("- %s" % str(step_variant))
			step_label.add_theme_color_override("default_color", Color(0.82, 0.82, 0.86))
			vbox.add_child(step_label)

	var footer_parts: PackedStringArray = []
	var confidence := str(metadata.get("confidence", "")).strip_edges()
	if confidence != "":
		footer_parts.append("置信度：%s" % confidence)
	var cards_variant: Variant = metadata.get("referenced_cards", [])
	if cards_variant is Array and not (cards_variant as Array).is_empty():
		var card_names: PackedStringArray = []
		for card_name: Variant in cards_variant:
			card_names.append(str(card_name))
		footer_parts.append("涉及：%s" % "、".join(card_names))
	if not footer_parts.is_empty():
		var footer := Label.new()
		footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		footer.text = " | ".join(footer_parts)
		footer.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
		footer.add_theme_font_size_override("font_size", 12)
		vbox.add_child(footer)
	return body


func _refresh_suggestion_buttons(suggestions: Array[String], preserve_existing: bool = false) -> void:
	if suggestions.is_empty() and preserve_existing:
		suggestions = _latest_suggestions.duplicate()
	else:
		_latest_suggestions = suggestions.duplicate()
	for child: Node in %SuggestionButtons.get_children():
		child.queue_free()
	var has_visible_suggestion := false
	for suggestion: String in _latest_suggestions:
		if suggestion.strip_edges() == "":
			continue
		has_visible_suggestion = true
		var button := Button.new()
		button.text = suggestion
		button.custom_minimum_size = Vector2(0, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_chip_button(button)
		button.pressed.connect(func() -> void:
			%QuestionInput.text = suggestion
			%QuestionInput.grab_focus()
		)
		%SuggestionButtons.add_child(button)
	%SuggestionsPanel.visible = has_visible_suggestion
	%TranscriptScroll.offset_bottom = TRANSCRIPT_BOTTOM_WITH_SUGGESTIONS if has_visible_suggestion else TRANSCRIPT_BOTTOM


func _on_send_pressed() -> void:
	if _deck == null:
		return
	if _service.is_busy():
		%StatusLabel.text = "上一条请求还在处理中。"
		return
	var question: String = %QuestionInput.text.strip_edges()
	if question == "":
		%QuestionInput.grab_focus()
		return
	var api_config: Dictionary = GameManager.get_battle_review_api_config()
	if str(api_config.get("endpoint", "")).strip_edges() == "" or str(api_config.get("api_key", "")).strip_edges() == "":
		%StatusLabel.text = "AI 未配置。请先在设置页填写 ZenMux endpoint 和 api_key。"
		return
	_refresh_live_battle_context_before_request()

	var result: Dictionary = _service.ask(self, _deck, question, api_config, _forced_external_tool_results)
	var status := str(result.get("status", ""))
	if status == "error":
		%StatusLabel.text = "请求没有发出去：%s" % str(result.get("message", "unknown_error"))
		%SendButton.disabled = false
		return
	if status == "ignored":
		%StatusLabel.text = "上一条请求还在处理中。"
		%SendButton.disabled = false
		return

	%StatusLabel.text = "请求中..."
	%SendButton.disabled = true
	_add_hint_message("user", question)
	%QuestionInput.clear()
	_add_hint_message("assistant", PENDING_TEXT)
	_queue_scroll_to_bottom()


func _refresh_live_battle_context_before_request() -> void:
	if not _battle_context_provider.is_valid():
		return
	var updated_variant: Variant = _battle_context_provider.call()
	if not (updated_variant is Dictionary):
		return
	var updated_context := updated_variant as Dictionary
	if _forced_external_tool_results.is_empty():
		return
	_forced_external_tool_results[0]["battle_context"] = updated_context.duplicate(true)
	if _deck != null:
		%SummaryLabel.text = _battle_context_summary(_deck, updated_context)


func _on_question_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ENTER and not key_event.shift_pressed:
			get_viewport().set_input_as_handled()
			_on_send_pressed()


func _on_service_status_changed(status: String, context: Dictionary) -> void:
	if status == "loading_detail":
		var reason := str(context.get("reason", "")).strip_edges()
		%StatusLabel.text = "正在读取完整卡组信息..." if reason == "" else "正在读取完整卡组信息：%s" % reason
	elif status == "loading_external_tool":
		var tool_name := str(context.get("tool_name", "")).strip_edges()
		var query := str(context.get("query", "")).strip_edges()
		if tool_name == "get_other_deck_detail":
			%StatusLabel.text = "正在读取卡组：%s" % query
		elif tool_name == "get_card_detail":
			%StatusLabel.text = "正在读取单卡：%s" % query


func _on_service_message_completed(result: Dictionary) -> void:
	if String(result.get("status", "")) == "error":
		%SendButton.disabled = false
		_remove_last_pending_message()
		%StatusLabel.text = "AI 对话失败：%s" % _format_error_message(result)
		_queue_scroll_to_bottom()
		return

	var metadata := {
		"confidence": str(result.get("confidence", "")),
		"suggested_questions": result.get("suggested_questions", []),
		"math_steps": result.get("math_steps", []),
		"referenced_cards": result.get("referenced_cards", []),
	}
	_start_streaming_assistant_message(str(result.get("answer_markdown", "")), metadata)


func _start_streaming_assistant_message(answer: String, metadata: Dictionary) -> void:
	_stream_body = _find_last_pending_body()
	if _stream_body == null:
		_stream_body = _add_message_bubble("assistant", "", {})
	else:
		_stream_body.text = ""
	_stream_full_text = answer
	_stream_index = 0
	_stream_metadata = metadata.duplicate(true)
	%StatusLabel.text = "正在生成回答..."
	if _stream_timer != null:
		_stream_timer.start()
	_on_stream_tick()


func _on_stream_tick() -> void:
	if _stream_body == null or not is_instance_valid(_stream_body):
		_stop_stream_timer()
		%SendButton.disabled = false
		return
	if _stream_full_text == "":
		_finish_streaming_assistant_message()
		return
	_stream_index = mini(_stream_index + STREAM_CHARS_PER_TICK, _stream_full_text.length())
	var visible_text := _stream_full_text.substr(0, _stream_index)
	_stream_body.text = _message_to_bbcode(visible_text)
	_queue_scroll_to_bottom()
	if _stream_index >= _stream_full_text.length():
		_finish_streaming_assistant_message()


func _finish_streaming_assistant_message() -> void:
	_stop_stream_timer()
	var old_outer: Node = null
	if _stream_body != null and is_instance_valid(_stream_body):
		_stream_body.text = _message_to_bbcode(_stream_full_text)
		old_outer = _stream_body.get_parent()
		if old_outer != null:
			old_outer = old_outer.get_parent()
		if old_outer != null:
			old_outer = old_outer.get_parent()
	if old_outer != null and is_instance_valid(old_outer):
		old_outer.visible = false
		old_outer.queue_free()
	_add_message_bubble("assistant", _stream_full_text, _stream_metadata)
	var next_suggestions := _to_string_array(_stream_metadata.get("suggested_questions", []))
	_refresh_suggestion_buttons(next_suggestions, true)
	%StatusLabel.text = ""
	%SendButton.disabled = false
	_stream_body = null
	_stream_full_text = ""
	_stream_index = 0
	_stream_metadata = {}
	_queue_scroll_to_bottom()
	assistant_response_finished.emit()


func _stop_stream_timer() -> void:
	if _stream_timer != null and not _stream_timer.is_stopped():
		_stream_timer.stop()


func _find_last_pending_body() -> RichTextLabel:
	var children := %TranscriptList.get_children()
	if children.is_empty():
		return null
	var last := children[children.size() - 1]
	if not (last is HBoxContainer):
		return null
	var bubble_container := last as HBoxContainer
	var body := _find_message_body_in_row(bubble_container)
	if body == null:
		return null
	if body.get_parsed_text() != PENDING_TEXT:
		return null
	return body


func _on_reset_pressed() -> void:
	if _deck == null:
		return
	_stop_stream_timer()
	_stream_body = null
	_service.clear_history(_deck.id)
	%StatusLabel.text = ""
	_reload_transcript()


func _remove_last_pending_message() -> void:
	var children := %TranscriptList.get_children()
	if children.is_empty():
		return
	var last := children[children.size() - 1]
	if not (last is HBoxContainer):
		return
	var bubble_container := last as HBoxContainer
	var body := _find_message_body_in_row(bubble_container)
	if body == null:
		return
	var text := body.get_parsed_text()
	if text == PENDING_TEXT:
		last.queue_free()


func _find_message_body_in_row(row: HBoxContainer) -> RichTextLabel:
	for child: Node in row.get_children():
		if not (child is PanelContainer):
			continue
		var panel := child as PanelContainer
		if panel.get_child_count() <= 0 or not (panel.get_child(0) is VBoxContainer):
			continue
		var vbox := panel.get_child(0) as VBoxContainer
		for vbox_child: Node in vbox.get_children():
			if vbox_child is RichTextLabel:
				return vbox_child as RichTextLabel
	return null


func _queue_scroll_to_bottom() -> void:
	call_deferred("_scroll_to_bottom_after_layout")


func _scroll_to_bottom_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	%TranscriptScroll.scroll_vertical = int(%TranscriptScroll.get_v_scroll_bar().max_value)


func _bubble_width() -> float:
	var available_width := float(size.x) - 150.0
	return clampf(available_width * 0.72, MIN_BUBBLE_WIDTH, MAX_BUBBLE_WIDTH)


func _discussion_title() -> String:
	var config: Dictionary = GameManager.get_battle_review_api_config()
	var model_id := str(config.get("model", "")).strip_edges()
	var model_name := _compact_model_name(model_id)
	return "和 %s 探讨" % model_name if model_name != "" else "与 AI 探讨"


func _compact_model_name(model_id: String) -> String:
	var trimmed := model_id.strip_edges()
	if trimmed == "":
		return ""
	var slash := trimmed.rfind("/")
	if slash >= 0 and slash + 1 < trimmed.length():
		trimmed = trimmed.substr(slash + 1)
	if trimmed.ends_with("-pro"):
		trimmed = trimmed.substr(0, trimmed.length() - 4)
	return trimmed


func _message_to_bbcode(content: String) -> String:
	var lines := content.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var out: PackedStringArray = []
	var in_code_block := false
	for raw_line: String in lines:
		var line := raw_line
		if line.strip_edges().begins_with("```"):
			in_code_block = not in_code_block
			out.append("[color=#aab3c5]----------------[/color]")
			continue
		if in_code_block:
			out.append("[font_size=14][color=#d7deea]%s[/color][/font_size]" % _escape_bbcode(line))
			continue
		var stripped := line.strip_edges()
		if stripped.begins_with("### "):
			out.append(_heading_bbcode(stripped.substr(4)))
		elif stripped.begins_with("## "):
			out.append(_heading_bbcode(stripped.substr(3)))
		elif stripped.begins_with("# "):
			out.append(_heading_bbcode(stripped.substr(2)))
		else:
			out.append(_inline_markdown_to_bbcode(line))
	return "\n".join(out)


func _heading_bbcode(text: String) -> String:
	return "[font_size=16][color=#ffffff]%s[/color][/font_size]" % _escape_bbcode(text)


func _inline_markdown_to_bbcode(line: String) -> String:
	var escaped := _escape_bbcode(line)
	escaped = _replace_wrapped(escaped, "**", "[color=#ffffff]", "[/color]")
	escaped = _replace_wrapped(escaped, "`", "[color=#d7deea]", "[/color]")
	return escaped


func _replace_wrapped(text: String, marker: String, open_tag: String, close_tag: String) -> String:
	var result := ""
	var remaining := text
	var open := true
	while true:
		var idx := remaining.find(marker)
		if idx < 0:
			result += remaining
			break
		result += remaining.substr(0, idx)
		result += open_tag if open else close_tag
		open = not open
		remaining = remaining.substr(idx + marker.length())
	if not open:
		result += close_tag
	return result


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "\\[").replace("]", "\\]")


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result


func _format_error_message(result: Dictionary) -> String:
	var message := str(result.get("message", "")).strip_edges()
	if message != "":
		return message
	var error_type := str(result.get("error_type", "")).strip_edges()
	if error_type != "":
		return error_type
	return "unknown_error"
