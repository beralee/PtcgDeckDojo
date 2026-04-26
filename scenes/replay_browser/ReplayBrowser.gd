extends Control

const MatchRecordIndexScript = preload("res://scripts/engine/MatchRecordIndex.gd")
const BattleReplayLocatorScript = preload("res://scripts/engine/BattleReplayLocator.gd")
const HUD_ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const HUD_DANGER := Color(1.0, 0.28, 0.22, 1.0)
const HUD_TEXT := Color(0.92, 0.98, 1.0, 1.0)
const HUD_TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)

var _record_index: RefCounted = MatchRecordIndexScript.new()
var _replay_locator: RefCounted = BattleReplayLocatorScript.new()
var _auto_navigate_to_battle: bool = true


func _ready() -> void:
	_apply_hud_theme()
	%BtnBack.pressed.connect(_on_back_pressed)
	_render_rows()


func _apply_hud_theme() -> void:
	var shade := get_node_or_null("BackgroundShade") as ColorRect
	if shade != null:
		shade.color = Color(0.01, 0.025, 0.045, 0.18)
	_ensure_hud_frame()
	var title := get_node_or_null("%Title") as Label
	if title != null:
		title.add_theme_font_size_override("font_size", 34)
		title.add_theme_color_override("font_color", HUD_TEXT)
		title.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.72))
		title.add_theme_constant_override("shadow_offset_y", 2)
	var back_button := get_node_or_null("%BtnBack") as Button
	if back_button != null:
		_style_hud_button(back_button, HUD_ACCENT)


func _ensure_hud_frame() -> void:
	if get_node_or_null("HudFrame") != null:
		return
	var margin := get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		return
	var frame := PanelContainer.new()
	frame.name = "HudFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.layout_mode = margin.layout_mode
	frame.anchors_preset = margin.anchors_preset
	frame.anchor_left = margin.anchor_left
	frame.anchor_top = margin.anchor_top
	frame.anchor_right = margin.anchor_right
	frame.anchor_bottom = margin.anchor_bottom
	frame.offset_left = margin.offset_left + 8
	frame.offset_top = margin.offset_top + 8
	frame.offset_right = margin.offset_right - 8
	frame.offset_bottom = margin.offset_bottom - 8
	frame.grow_horizontal = margin.grow_horizontal
	frame.grow_vertical = margin.grow_vertical
	frame.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.72), Color(0.30, 0.86, 1.0, 0.86), 24))
	add_child(frame)
	move_child(frame, margin.get_index())


func _hud_panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border.r, border.g, border.b, 0.22)
	style.shadow_size = 10
	style.set_content_margin_all(10)
	return style


func _hud_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.92) if pressed else Color(0.035, 0.075, 0.105, 0.92)
	if hover and not pressed:
		style.bg_color = Color(0.055, 0.13, 0.17, 0.96)
	style.border_color = accent
	style.set_border_width_all(2 if hover else 1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28 if hover else 0.12)
	style.shadow_size = 8 if hover else 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _style_hud_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.12, 0.16, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	button.add_theme_stylebox_override("normal", _hud_button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _hud_button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _hud_button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _hud_button_style(Color(0.26, 0.31, 0.36, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_back_pressed() -> void:
	GameManager.goto_main_menu()


func _render_rows() -> void:
	var list_container := %ListContainer
	for child: Node in list_container.get_children():
		child.queue_free()

	var rows: Array = _record_index.call("list_rows") if _record_index != null and _record_index.has_method("list_rows") else []
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无对局记录"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
		list_container.add_child(empty_label)
		return
	for row_variant: Variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		list_container.add_child(_build_row_widget(row))


func _build_row_widget(row: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.035, 0.075, 0.11, 0.88), Color(0.26, 0.84, 1.0, 0.58), 16))

	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)

	var labels: Array = row.get("player_labels", [])
	var p1_name := str(labels[0]) if labels.size() > 0 else "玩家1"
	var p2_name := str(labels[1]) if labels.size() > 1 else "玩家2"
	var winner_index := int(row.get("winner_index", -1))
	var first_player_index := int(row.get("first_player_index", -1))
	var turn_count := int(row.get("turn_count", 0))
	var final_prize_counts: Array = row.get("final_prize_counts", [])
	var recorded_at := str(row.get("recorded_at", ""))

	# 胜者名称
	var winner_name := "未知"
	if winner_index == 0:
		winner_name = p1_name
	elif winner_index == 1:
		winner_name = p2_name

	# 先手名称
	var first_name := ""
	if first_player_index == 0:
		first_name = p1_name
	elif first_player_index == 1:
		first_name = p2_name

	# 奖品数
	var prize_text := ""
	if final_prize_counts.size() >= 2:
		prize_text = "%d-%d" % [int(final_prize_counts[0]), int(final_prize_counts[1])]

	# 信息区域（左侧）
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)

	# 第一行：对阵双方 + 胜者
	var line1 := Label.new()
	line1.text = "%s vs %s    胜者：%s" % [p1_name, p2_name, winner_name]
	line1.add_theme_font_size_override("font_size", 16)
	line1.add_theme_color_override("font_color", HUD_TEXT)
	info_vbox.add_child(line1)

	# 第二行：详细信息
	var details: Array[String] = []
	if recorded_at != "":
		details.append(recorded_at)
	if turn_count > 0:
		details.append("%d回合" % turn_count)
	if first_name != "":
		details.append("先手：%s" % first_name)
	if prize_text != "":
		details.append("剩余奖品：%s" % prize_text)
	var line2 := Label.new()
	line2.text = "  ".join(details)
	line2.add_theme_font_size_override("font_size", 12)
	line2.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	info_vbox.add_child(line2)

	layout.add_child(info_vbox)

	# 按钮区域（右侧）
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 6)

	var replay_button := Button.new()
	replay_button.name = "ReplayButton"
	replay_button.text = "复盘"
	replay_button.custom_minimum_size = Vector2(70, 0)
	replay_button.disabled = str(row.get("match_dir", "")).strip_edges() == "" or _replay_locator == null or not _replay_locator.has_method("locate")
	_style_hud_button(replay_button, HUD_ACCENT)
	replay_button.pressed.connect(func() -> void:
		_on_replay_pressed(row)
	)
	btn_box.add_child(replay_button)

	var delete_button := Button.new()
	delete_button.name = "DeleteButton"
	delete_button.text = "删除"
	delete_button.custom_minimum_size = Vector2(60, 0)
	_style_hud_button(delete_button, HUD_DANGER)
	delete_button.pressed.connect(func() -> void:
		_on_delete_pressed(row, panel)
	)
	btn_box.add_child(delete_button)

	layout.add_child(btn_box)
	return panel


func _on_replay_pressed(row: Dictionary) -> void:
	var match_dir := str(row.get("match_dir", ""))
	if match_dir.strip_edges() == "":
		return
	if _replay_locator == null or not _replay_locator.has_method("locate"):
		return
	var located_variant: Variant = _replay_locator.call("locate", match_dir)
	var located: Dictionary = located_variant if located_variant is Dictionary else {}
	if located.is_empty():
		return
	var launch := {
		"match_dir": match_dir,
		"entry_turn_number": int(located.get("entry_turn_number", 0)),
		"entry_source": str(located.get("entry_source", "unknown")),
		"turn_numbers": (located.get("turn_numbers", []) as Array).duplicate(true),
	}
	GameManager.set_battle_replay_launch(launch)
	if _auto_navigate_to_battle:
		GameManager.goto_battle()


func _on_delete_pressed(row: Dictionary, row_widget: Control) -> void:
	var match_dir := str(row.get("match_dir", ""))
	if match_dir.strip_edges() == "":
		return
	var global_dir := ProjectSettings.globalize_path(match_dir)
	if not DirAccess.dir_exists_absolute(global_dir):
		row_widget.queue_free()
		return
	_remove_directory_recursive(global_dir)
	row_widget.queue_free()
	# 如果列表为空，显示空提示
	await get_tree().process_frame
	var list_container := %ListContainer
	if list_container.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "暂无对局记录"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
		list_container.add_child(empty_label)


func _remove_directory_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == "..":
			continue
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_remove_directory_recursive(full_path)
		else:
			DirAccess.remove_absolute(full_path)
	dir.list_dir_end()
	DirAccess.remove_absolute(dir_path)
