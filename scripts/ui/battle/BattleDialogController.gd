class_name BattleDialogController
extends RefCounted

const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")
const ENERGY_ICON_TEXTURES := {
	"R": preload("res://assets/ui/e-huo.png"),
	"W": preload("res://assets/ui/e-shui.png"),
	"G": preload("res://assets/ui/e-cao.png"),
	"L": preload("res://assets/ui/e-lei.png"),
	"P": preload("res://assets/ui/e-chao.png"),
	"F": preload("res://assets/ui/e-dou.png"),
	"D": preload("res://assets/ui/e-e.png"),
	"M": preload("res://assets/ui/e-gang.png"),
	"N": preload("res://assets/ui/e-long.png"),
	"C": preload("res://assets/ui/e-wu.png"),
}


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func _replace_int_array(scene: Object, property_name: String, values: Array) -> void:
	var snapshot := values.duplicate()
	var target: Array[int] = scene.get(property_name)
	target.clear()
	for value_variant: Variant in snapshot:
		target.append(int(value_variant))
	scene.set(property_name, target)


func _replace_dictionary_array(scene: Object, property_name: String, values: Array) -> void:
	var snapshot := values.duplicate(true)
	var target: Array[Dictionary] = scene.get(property_name)
	target.clear()
	for value_variant: Variant in snapshot:
		if value_variant is Dictionary:
			target.append((value_variant as Dictionary).duplicate(true))
	scene.set(property_name, target)


func dialog_item_has_card_visual(item: Variant) -> bool:
	return item is CardInstance or item is CardData or item is PokemonSlot


func dialog_choice_subtitle(scene: Object, item: Variant, label: String) -> String:
	if item is PokemonSlot:
		var slot: PokemonSlot = item
		return "HP %d/%d" % [scene.call("_get_display_remaining_hp", slot), scene.call("_get_display_max_hp", slot)]
	if item is CardInstance:
		var card: CardInstance = item
		if label != "" and label != card.card_data.name:
			return label
		return str(scene.call("_hand_card_subtext", card.card_data))
	if item is CardData:
		var data: CardData = item
		if label != "" and label != data.name:
			return label
		return str(scene.call("_hand_card_subtext", data))
	return label


func selection_label_from_item(item: Variant, fallback: String = "") -> String:
	if fallback.strip_edges() != "":
		return fallback.strip_edges()
	if item is PokemonSlot:
		return (item as PokemonSlot).get_pokemon_name()
	if item is CardInstance:
		var card: CardInstance = item
		return card.card_data.name if card.card_data != null else ""
	if item is CardData:
		return (item as CardData).name
	if item is Dictionary:
		var entry: Dictionary = item
		for key: String in ["pokemon_name", "card_name", "name", "title"]:
			var text := str(entry.get(key, "")).strip_edges()
			if text != "":
				return text
	return str(item).strip_edges()


func selected_dialog_labels(scene: Object, sel_items: PackedInt32Array) -> Array[String]:
	var labels: Array[String] = []
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_items_data: Array = scene.get("_dialog_items_data")
	var choice_labels: Array = dialog_data.get("choice_labels", dialog_items_data)
	for idx: int in sel_items:
		if idx < 0:
			continue
		var item: Variant = dialog_items_data[idx] if idx < dialog_items_data.size() else null
		var fallback := str(choice_labels[idx]) if idx < choice_labels.size() else ""
		labels.append(selection_label_from_item(item, fallback))
	return labels


func selected_assignment_labels(assignments: Array[Dictionary]) -> Array[String]:
	var labels: Array[String] = []
	for assignment: Dictionary in assignments:
		var source_label := selection_label_from_item(assignment.get("source"))
		var target_label := selection_label_from_item(assignment.get("target"))
		if source_label != "" and target_label != "":
			labels.append("%s -> %s" % [source_label, target_label])
		elif source_label != "":
			labels.append(source_label)
		elif target_label != "":
			labels.append(target_label)
	return labels


func setup_dialog_card_view(scene: Object, card_view: BattleCardView, item: Variant, label: String) -> void:
	if item is CardInstance:
		card_view.setup_from_instance(item, BattleCardView.MODE_CHOICE)
		card_view.set_info(item.card_data.name, dialog_choice_subtitle(scene, item, label))
	elif item is CardData:
		card_view.setup_from_card_data(item, BattleCardView.MODE_CHOICE)
		card_view.set_info(item.name, dialog_choice_subtitle(scene, item, label))
	elif item is PokemonSlot:
		var slot: PokemonSlot = item
		card_view.setup_from_card_data(slot.get_card_data(), scene.call("_battle_card_mode_for_slot", slot))
		card_view.set_badges()
		card_view.set_battle_status(scene.call("_build_battle_status", slot))
	else:
		card_view.setup_from_instance(null, BattleCardView.MODE_CHOICE)
		card_view.set_info(str(label), "")


func dialog_should_use_card_mode(items: Array, extra_data: Dictionary) -> bool:
	var presentation := str(extra_data.get("presentation", "auto"))
	if presentation == "cards":
		return true
	if presentation in ["list", "action_hud"]:
		return false
	var card_items: Array = extra_data.get("card_items", items)
	for item: Variant in card_items:
		if not dialog_item_has_card_visual(item):
			return false
	return not card_items.is_empty()


func reset_dialog_assignment_state(scene: Object) -> void:
	scene.set("_dialog_assignment_mode", false)
	scene.set("_dialog_assignment_selected_source_index", -1)
	_replace_dictionary_array(scene, "_dialog_assignment_assignments", [])
	var assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	if assignment_panel != null:
		assignment_panel.visible = false
	var summary_label: Label = scene.get("_dialog_assignment_summary_lbl")
	if summary_label != null:
		summary_label.text = ""


func show_dialog(scene: Object, title: String, items: Array, extra_data: Dictionary = {}) -> void:
	var dialog_title: Label = scene.get("_dialog_title")
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	dialog_title.text = title
	dialog_list.clear()
	scene.set("_dialog_items_data", items)
	scene.set("_dialog_data", extra_data)
	_replace_int_array(scene, "_dialog_multi_selected_indices", [])
	_replace_int_array(scene, "_dialog_card_selected_indices", [])
	reset_dialog_assignment_state(scene)

	var presentation := str(extra_data.get("presentation", "auto"))
	var assignment_mode := str(extra_data.get("ui_mode", "")) == "card_assignment"
	var action_hud_mode := presentation == "action_hud"
	scene.set("_dialog_assignment_mode", assignment_mode)
	var card_mode := false if assignment_mode or action_hud_mode else dialog_should_use_card_mode(items, extra_data)
	scene.set("_dialog_card_mode", card_mode)

	if assignment_mode:
		show_assignment_dialog(scene, extra_data)
	elif action_hud_mode:
		show_action_hud_dialog(scene, items, extra_data)
	elif card_mode:
		show_card_dialog(scene, items, extra_data)
	else:
		show_text_dialog(scene, items, extra_data)

	dialog_overlay.visible = true
	dialog_cancel.visible = bool(extra_data.get("allow_cancel", true))
	update_dialog_confirm_state(scene)
	scene.call(
		"_runtime_log",
		"show_dialog",
		"title=%s mode=%s items=%d %s" % [
			title,
			"assignment" if assignment_mode else ("action_hud" if action_hud_mode else ("cards" if card_mode else "list")),
			items.size(),
			scene.call("_dialog_state_snapshot"),
		]
	)
	scene.call("_record_battle_state_snapshot", "before_choice_context", {
		"prompt_source": "dialog",
		"prompt_type": str(extra_data.get("prompt_type", scene.get("_pending_choice"))),
		"title": title,
	})
	scene.call("_record_battle_event", {
		"event_type": "choice_context",
		"prompt_source": "dialog",
		"prompt_type": str(extra_data.get("prompt_type", scene.get("_pending_choice"))),
		"title": title,
		"items": items.duplicate(true),
		"extra_data": extra_data.duplicate(true),
		"player_index": int(extra_data.get("player", _current_player_index(scene))),
		"turn_number": _turn_number(scene),
		"phase": scene.call("_recording_phase_name"),
	})
	if not assignment_mode and int(extra_data.get("max_select", 1)) > 1:
		scene.call("_log", "已启用多选：先选择卡牌，再点击确认。")


func show_text_dialog(scene: Object, items: Array, extra_data: Dictionary) -> void:
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_list: ItemList = scene.get("_dialog_list")
	dialog_card_scroll.visible = false
	dialog_assignment_panel.visible = false
	dialog_status_lbl.visible = false
	dialog_utility_row.visible = false
	dialog_confirm.visible = true
	dialog_list.visible = true
	dialog_list.custom_minimum_size = Vector2(0, clampi(items.size() * 32, 60, 240))
	scene.call("_clear_container_children", dialog_utility_row)
	for item: Variant in items:
		dialog_list.add_item(str(item))
	dialog_list.select_mode = ItemList.SELECT_TOGGLE if int(extra_data.get("max_select", 1)) > 1 else ItemList.SELECT_SINGLE
	if dialog_list.item_selected.is_connected(Callable(scene, "_on_dialog_item_selected")):
		dialog_list.item_selected.disconnect(Callable(scene, "_on_dialog_item_selected"))
	if dialog_list.multi_selected.is_connected(Callable(scene, "_on_dialog_item_multi_selected")):
		dialog_list.multi_selected.disconnect(Callable(scene, "_on_dialog_item_multi_selected"))
	if dialog_list.select_mode != ItemList.SELECT_SINGLE:
		dialog_list.multi_selected.connect(Callable(scene, "_on_dialog_item_multi_selected"))
	else:
		dialog_list.item_selected.connect(Callable(scene, "_on_dialog_item_selected"))


func show_card_dialog(scene: Object, items: Array, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var card_click_selectable: bool = bool(extra_data.get("card_click_selectable", true))

	dialog_list.visible = false
	dialog_card_scroll.visible = true
	dialog_assignment_panel.visible = false
	dialog_card_scroll.scroll_horizontal = 0
	dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.custom_minimum_size = Vector2(0, dialog_card_size.y + 2.0)
	if dialog_list.item_selected.is_connected(Callable(scene, "_on_dialog_item_selected")):
		dialog_list.item_selected.disconnect(Callable(scene, "_on_dialog_item_selected"))
	if dialog_list.multi_selected.is_connected(Callable(scene, "_on_dialog_item_multi_selected")):
		dialog_list.multi_selected.disconnect(Callable(scene, "_on_dialog_item_multi_selected"))
	scene.call("_clear_container_children", dialog_card_row)
	scene.call("_clear_container_children", dialog_utility_row)

	var card_items: Array = extra_data.get("card_items", items)
	var card_indices: Array = extra_data.get("card_indices", [])
	var labels: Array = extra_data.get("choice_labels", items)
	for i: int in card_items.size():
		var real_index := i
		if i < card_indices.size():
			real_index = int(card_indices[i])
		var card_view := BattleCardViewScript.new()
		card_view.custom_minimum_size = dialog_card_size
		card_view.set_clickable(card_click_selectable)
		setup_dialog_card_view(scene, card_view, card_items[i], labels[i] if i < labels.size() else "")
		if card_click_selectable:
			card_view.left_clicked.connect(Callable(scene, "_on_dialog_card_left_signal").bind(real_index))
		card_view.right_clicked.connect(Callable(scene, "_on_dialog_card_right_signal"))
		card_view.set_meta("dialog_choice_index", real_index)
		dialog_card_row.add_child(card_view)

	var utility_actions: Array = extra_data.get("utility_actions", [])
	dialog_utility_row.visible = not utility_actions.is_empty()
	for action_variant: Variant in utility_actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = str(action.get("label", _bt(scene, "battle.dialog.action_label")))
		var action_index := int(action.get("index", -1))
		button.pressed.connect(func() -> void:
			confirm_dialog_selection(scene, PackedInt32Array([action_index]))
		)
		dialog_utility_row.add_child(button)

	var min_select := int(extra_data.get("min_select", 1))
	var max_select := int(extra_data.get("max_select", 1))
	var show_confirm := max_select > 1 or min_select > 1
	dialog_confirm.visible = show_confirm
	dialog_status_lbl.visible = show_confirm
	if show_confirm:
		update_dialog_status_text(scene)


func show_action_hud_dialog(scene: Object, _items: Array, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")

	dialog_list.visible = false
	dialog_card_scroll.visible = true
	dialog_assignment_panel.visible = false
	dialog_utility_row.visible = false
	dialog_confirm.visible = false
	dialog_status_lbl.visible = false
	var action_items: Array = extra_data.get("action_items", [])
	dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if action_items.size() > 5 else ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.custom_minimum_size = Vector2(0, _action_hud_scroll_height(action_items.size()))
	if dialog_list.item_selected.is_connected(Callable(scene, "_on_dialog_item_selected")):
		dialog_list.item_selected.disconnect(Callable(scene, "_on_dialog_item_selected"))
	if dialog_list.multi_selected.is_connected(Callable(scene, "_on_dialog_item_multi_selected")):
		dialog_list.multi_selected.disconnect(Callable(scene, "_on_dialog_item_multi_selected"))
	scene.call("_clear_container_children", dialog_card_row)
	scene.call("_clear_container_children", dialog_utility_row)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	dialog_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_card_row.add_child(stack)

	for i: int in action_items.size():
		var action: Dictionary = action_items[i] if action_items[i] is Dictionary else {}
		stack.add_child(_build_action_hud_option(scene, action, i))


func _action_hud_scroll_height(action_count: int) -> float:
	var visible_count: int = clampi(action_count, 1, 5)
	return float(visible_count * 88 + maxi(visible_count - 1, 0) * 8 + 2)


func _build_action_hud_option(scene: Object, action: Dictionary, action_index: int) -> Control:
	var enabled := bool(action.get("enabled", true))
	var accent := _action_hud_accent(str(action.get("type", "")), enabled)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", _action_hud_panel_style(accent, enabled))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				confirm_dialog_selection(scene, PackedInt32Array([action_index]))
	)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var kind := Label.new()
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kind.text = str(action.get("kind", "行动"))
	kind.custom_minimum_size = Vector2(58, 22)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kind.add_theme_font_size_override("font_size", 13)
	kind.add_theme_color_override("font_color", Color(0.04, 0.06, 0.08, 1.0))
	kind.add_theme_stylebox_override("normal", _action_hud_pill_style(accent, enabled))
	header.add_child(kind)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = str(action.get("title", ""))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0) if enabled else Color(0.62, 0.66, 0.70, 1.0))
	header.add_child(title)

	var cost_text := str(action.get("cost", "")).strip_edges()
	if cost_text != "":
		header.add_child(_build_energy_cost_icons(cost_text, enabled))

	var meta := Label.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.text = str(action.get("meta", ""))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_theme_font_size_override("font_size", 14)
	meta.add_theme_color_override("font_color", Color(0.76, 0.86, 0.96, 1.0) if enabled else Color(0.50, 0.54, 0.58, 1.0))
	header.add_child(meta)

	var body := RichTextLabel.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = str(action.get("body", ""))
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_color_override("default_color", Color(0.84, 0.89, 0.94, 1.0) if enabled else Color(0.55, 0.59, 0.63, 1.0))
	box.add_child(body)

	var reason := str(action.get("reason", "")).strip_edges()
	if not enabled and reason != "":
		var reason_label := Label.new()
		reason_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reason_label.text = "不可用：%s" % reason
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.add_theme_font_size_override("font_size", 13)
		reason_label.add_theme_color_override("font_color", Color(1.0, 0.67, 0.50, 1.0))
		box.add_child(reason_label)

	return panel


func _build_energy_cost_icons(cost_text: String, enabled: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	for symbol: String in cost_text:
		row.add_child(_build_energy_cost_icon(symbol, enabled))
	return row


func _build_energy_cost_icon(symbol: String, enabled: bool) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ENERGY_ICON_TEXTURES.get(symbol, ENERGY_ICON_TEXTURES.get("C"))
	icon.modulate = Color(1, 1, 1, 1) if enabled else Color(0.45, 0.45, 0.45, 0.82)
	return icon


func _action_hud_accent(action_type: String, enabled: bool) -> Color:
	if not enabled:
		return Color(0.34, 0.38, 0.42, 1.0)
	match action_type:
		"ability":
			return Color(0.35, 0.80, 0.95, 1.0)
		"attack", "granted_attack":
			return Color(1.0, 0.48, 0.24, 1.0)
		"retreat":
			return Color(0.62, 0.90, 0.42, 1.0)
		_:
			return Color(0.72, 0.78, 0.86, 1.0)


func _action_hud_panel_style(accent: Color, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.96) if enabled else Color(0.028, 0.035, 0.043, 0.90)
	style.border_color = accent
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.22 if enabled else 0.08)
	style.shadow_size = 8 if enabled else 2
	return style


func _action_hud_pill_style(accent: Color, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent if enabled else Color(0.30, 0.33, 0.36, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func show_assignment_dialog(scene: Object, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_assignment_source_scroll: ScrollContainer = scene.get("_dialog_assignment_source_scroll")
	var dialog_assignment_target_scroll: ScrollContainer = scene.get("_dialog_assignment_target_scroll")
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_assignment_target_row: HBoxContainer = scene.get("_dialog_assignment_target_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")

	dialog_list.visible = false
	dialog_card_scroll.visible = false
	dialog_assignment_panel.visible = true
	dialog_assignment_source_scroll.scroll_horizontal = 0
	dialog_assignment_target_scroll.scroll_horizontal = 0
	scene.call("_clear_container_children", dialog_card_row)
	scene.call("_clear_container_children", dialog_utility_row)
	scene.call("_clear_container_children", dialog_assignment_source_row)
	scene.call("_clear_container_children", dialog_assignment_target_row)
	reset_dialog_assignment_state(scene)
	scene.set("_dialog_assignment_mode", true)
	dialog_assignment_panel.visible = true

	var source_items: Array = extra_data.get("source_items", [])
	var source_labels: Array = extra_data.get("source_labels", [])
	var source_groups: Array = extra_data.get("source_groups", [])
	if not source_groups.is_empty():
		populate_grouped_source_items(scene, source_items, source_labels, source_groups)
	else:
		for i: int in source_items.size():
			add_assignment_source_card(scene, source_items, source_labels, i)

	var target_items: Array = extra_data.get("target_items", [])
	var target_labels: Array = extra_data.get("target_labels", [])
	for i: int in target_items.size():
		var target_view := BattleCardViewScript.new()
		target_view.custom_minimum_size = dialog_card_size
		target_view.set_clickable(true)
		setup_dialog_card_view(scene, target_view, target_items[i], target_labels[i] if i < target_labels.size() else "")
		target_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			scene.call("_on_assignment_target_chosen", i)
		)
		target_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
			if cd != null:
				scene.call("_show_card_detail", cd)
		)
		target_view.set_meta("assignment_target_index", i)
		dialog_assignment_target_row.add_child(target_view)

	dialog_utility_row.visible = true
	var clear_button := Button.new()
	clear_button.custom_minimum_size = Vector2(140, 40)
	clear_button.text = _bt(scene, "battle.dialog.clear")
	clear_button.pressed.connect(func() -> void:
		_replace_dictionary_array(scene, "_dialog_assignment_assignments", [])
		scene.set("_dialog_assignment_selected_source_index", -1)
		refresh_assignment_dialog_views(scene)
	)
	dialog_utility_row.add_child(clear_button)

	dialog_confirm.visible = true
	dialog_status_lbl.visible = false
	refresh_assignment_dialog_views(scene)


func populate_grouped_source_items(scene: Object, source_items: Array, source_labels: Array, source_groups: Array) -> void:
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	for group_index: int in source_groups.size():
		var group: Dictionary = source_groups[group_index]
		var slot_variant: Variant = group.get("slot")
		var indices: Array = group.get("energy_indices", [])
		if not (slot_variant is PokemonSlot) or indices.is_empty():
			continue
		if group_index > 0:
			var separator := VSeparator.new()
			separator.custom_minimum_size = Vector2(2, 0)
			separator.size_flags_vertical = Control.SIZE_EXPAND_FILL
			dialog_assignment_source_row.add_child(separator)
		var header_view := BattleCardViewScript.new()
		header_view.custom_minimum_size = dialog_card_size
		header_view.set_clickable(false)
		var pokemon_slot: PokemonSlot = slot_variant as PokemonSlot
		header_view.setup_from_card_data(pokemon_slot.get_card_data(), scene.call("_battle_card_mode_for_slot", pokemon_slot))
		header_view.set_badges()
		header_view.set_battle_status(scene.call("_build_battle_status", pokemon_slot))
		dialog_assignment_source_row.add_child(header_view)
		for energy_idx: Variant in indices:
			add_assignment_source_card(scene, source_items, source_labels, int(energy_idx))


func add_assignment_source_card(scene: Object, source_items: Array, source_labels: Array, source_index: int) -> void:
	if source_index < 0 or source_index >= source_items.size():
		return
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var source_view := BattleCardViewScript.new()
	source_view.custom_minimum_size = dialog_card_size
	source_view.set_clickable(true)
	var source_label: String = source_labels[source_index] if source_index < source_labels.size() else ""
	setup_dialog_card_view(scene, source_view, source_items[source_index], source_label)
	source_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		scene.call("_on_assignment_source_chosen", source_index)
	)
	source_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
		if cd != null:
			scene.call("_show_card_detail", cd)
	)
	source_view.set_meta("assignment_source_index", source_index)
	dialog_assignment_source_row.add_child(source_view)


func find_assignment_index_for_source(scene: Object, source_index: int) -> int:
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	for i: int in assignments.size():
		if int((assignments[i] as Dictionary).get("source_index", -1)) == source_index:
			return i
	return -1


func dialog_assignment_last_target_index(scene: Object) -> int:
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	if assignments.is_empty():
		return -1
	return int((assignments.back() as Dictionary).get("target_index", -1))


func on_assignment_source_chosen(scene: Object, source_index: int) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var source_items: Array = dialog_data.get("source_items", [])
	if source_index < 0 or source_index >= source_items.size():
		return
	var assigned_index := find_assignment_index_for_source(scene, source_index)
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	if assigned_index >= 0:
		assignments.remove_at(assigned_index)
		_replace_dictionary_array(scene, "_dialog_assignment_assignments", assignments)
		if int(scene.get("_dialog_assignment_selected_source_index")) == source_index:
			scene.set("_dialog_assignment_selected_source_index", -1)
		refresh_assignment_dialog_views(scene)
		return
	var max_assignments := int(dialog_data.get("max_select", source_items.size()))
	if max_assignments > 0 and assignments.size() >= max_assignments:
		scene.call("_log", _bt(scene, "battle.dialog.assign_limit_reached"))
		return
	if int(scene.get("_dialog_assignment_selected_source_index")) == source_index:
		scene.set("_dialog_assignment_selected_source_index", -1)
	else:
		scene.set("_dialog_assignment_selected_source_index", source_index)
	refresh_assignment_dialog_views(scene)


func on_assignment_target_chosen(scene: Object, target_index: int) -> void:
	var selected_source_index := int(scene.get("_dialog_assignment_selected_source_index"))
	if selected_source_index < 0:
		scene.call("_log", _bt(scene, "battle.dialog.choose_target"))
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var source_items: Array = dialog_data.get("source_items", [])
	var target_items: Array = dialog_data.get("target_items", [])
	if selected_source_index >= source_items.size():
		return
	if target_index < 0 or target_index >= target_items.size():
		return
	var exclude_map: Dictionary = dialog_data.get("source_exclude_targets", {})
	var excluded: Array = exclude_map.get(selected_source_index, [])
	if target_index in excluded:
		scene.call("_log", _bt(scene, "battle.dialog.target_invalid"))
		return
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	var max_per_target: int = int(dialog_data.get("max_assignments_per_target", 0))
	if max_per_target > 0 and _count_assignments_for_target_index(assignments, target_index) >= max_per_target:
		scene.call("_log", _bt(scene, "battle.dialog.target_invalid"))
		return
	assignments.append({
		"source_index": selected_source_index,
		"source": source_items[selected_source_index],
		"target_index": target_index,
		"target": target_items[target_index],
	})
	_replace_dictionary_array(scene, "_dialog_assignment_assignments", assignments)
	scene.set("_dialog_assignment_selected_source_index", -1)
	refresh_assignment_dialog_views(scene)


func refresh_assignment_dialog_views(scene: Object) -> void:
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_assignment_target_row: HBoxContainer = scene.get("_dialog_assignment_target_row")
	var selected_source_index := int(scene.get("_dialog_assignment_selected_source_index"))
	for child: Node in dialog_assignment_source_row.get_children():
		if not (child is BattleCardView):
			continue
		var card_view := child as BattleCardView
		var idx := int(card_view.get_meta("assignment_source_index", -1))
		var source_selected := idx == selected_source_index
		var source_assigned := find_assignment_index_for_source(scene, idx) >= 0
		card_view.set_selected(source_selected)
		card_view.set_selectable_hint(not source_selected and not source_assigned)
		card_view.set_disabled(source_assigned)
	for child: Node in dialog_assignment_target_row.get_children():
		if not (child is BattleCardView):
			continue
		var target_view := child as BattleCardView
		var idx := int(target_view.get_meta("assignment_target_index", -1))
		var target_selected := idx == dialog_assignment_last_target_index(scene)
		target_view.set_selected(target_selected)
		target_view.set_selectable_hint(not target_selected)
		target_view.set_disabled(false)
	update_assignment_dialog_state(scene)


func update_assignment_dialog_state(scene: Object) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var summary_label: Label = scene.get("_dialog_assignment_summary_lbl")
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	var min_assignments := int(dialog_data.get("min_select", 0))
	var max_assignments := int(dialog_data.get("max_select", 0))
	dialog_confirm.disabled = assignments.size() < min_assignments

	var target_counts: Dictionary = {}
	for assignment_variant: Variant in assignments:
		if not (assignment_variant is Dictionary):
			continue
		var assignment := assignment_variant as Dictionary
		var target: Variant = assignment.get("target")
		if target == null:
			continue
		target_counts[target] = int(target_counts.get(target, 0)) + 1

	var summary_parts: Array[String] = []
	for target: Variant in target_counts.keys():
		if target is PokemonSlot:
			var slot: PokemonSlot = target as PokemonSlot
			summary_parts.append("%s×%d" % [slot.get_pokemon_name(), int(target_counts[target])])

	var summary := ""
	if max_assignments > 0:
		summary = _bt(scene, "battle.dialog.assignment_summary", {
			"assigned_count": assignments.size(),
			"max_assignments": max_assignments,
		})
	else:
		summary = _bt(scene, "battle.dialog.assignment_summary_unlimited", {
			"assigned_count": assignments.size(),
		})
	var selected_source_index := int(scene.get("_dialog_assignment_selected_source_index"))
	if selected_source_index >= 0:
		var source_items: Array = dialog_data.get("source_items", [])
		if selected_source_index < source_items.size():
			var selected_source: Variant = source_items[selected_source_index]
			if selected_source is CardInstance:
				summary += " " + _bt(scene, "battle.dialog.assignment_current_source", {
					"name": (selected_source as CardInstance).card_data.name,
				})
	if not summary_parts.is_empty():
		summary += " 已分配到：" + ", ".join(summary_parts)
	summary_label.text = summary


func _count_assignments_for_target_index(assignments: Array, target_index: int) -> int:
	var count := 0
	for assignment_variant: Variant in assignments:
		if not (assignment_variant is Dictionary):
			continue
		if int((assignment_variant as Dictionary).get("target_index", -1)) == target_index:
			count += 1
	return count


func on_dialog_card_chosen(scene: Object, real_index: int) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	var is_multi := max_select > 1 or min_select > 1
	if not is_multi:
		confirm_dialog_selection(scene, PackedInt32Array([real_index]))
		return
	if not bool(scene.call("_toggle_dialog_card_choice", real_index, max_select)):
		return
	sync_dialog_card_selection(scene)
	update_dialog_confirm_state(scene)


func sync_dialog_card_selection(scene: Object) -> void:
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	for child: Node in dialog_card_row.get_children():
		if not (child is BattleCardView):
			continue
		var card_view := child as BattleCardView
		var idx := int(card_view.get_meta("dialog_choice_index", -1))
		var selected := idx in selected_indices
		card_view.set_selected(selected)
		card_view.set_selectable_hint(not selected)


func update_dialog_confirm_state(scene: Object) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_list: ItemList = scene.get("_dialog_list")
	var min_select := int(dialog_data.get("min_select", 1))
	if bool(scene.get("_dialog_assignment_mode")):
		update_assignment_dialog_state(scene)
		return
	if bool(scene.get("_dialog_card_mode")):
		var selected_indices: Array = scene.get("_dialog_card_selected_indices")
		dialog_confirm.disabled = selected_indices.size() < min_select
		update_dialog_status_text(scene)
		return
	if dialog_list.select_mode == ItemList.SELECT_SINGLE:
		dialog_confirm.disabled = dialog_list.get_selected_items().size() < min_select
	else:
		var multi_selected: Array = scene.get("_dialog_multi_selected_indices")
		dialog_confirm.disabled = multi_selected.size() < min_select


func update_dialog_status_text(scene: Object) -> void:
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	if dialog_status_lbl == null or not dialog_status_lbl.visible:
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	if max_select > 1:
		dialog_status_lbl.text = _bt(scene, "battle.dialog.card_status_with_max", {
			"selected_count": selected_indices.size(),
			"min_select": min_select,
			"max_select": max_select,
		})
	else:
		dialog_status_lbl.text = _bt(scene, "battle.dialog.card_status", {
			"selected_count": selected_indices.size(),
			"min_select": min_select,
		})


func confirm_dialog_selection(scene: Object, sel_items: PackedInt32Array) -> void:
	scene.call(
		"_runtime_log",
		"confirm_dialog_selection",
		"choice=%s selected=%s %s" % [scene.get("_pending_choice"), JSON.stringify(sel_items), scene.call("_dialog_state_snapshot")]
	)
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	dialog_overlay.visible = false
	scene.call("_handle_dialog_choice", sel_items)


func on_dialog_item_selected(scene: Object, idx: int) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	if dialog_list.select_mode != ItemList.SELECT_SINGLE:
		return
	dialog_confirm.disabled = false
	if not bool(scene.get("_dialog_card_mode")):
		confirm_dialog_selection(scene, PackedInt32Array([idx]))


func on_dialog_item_multi_selected(scene: Object, idx: int, selected: bool) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	if dialog_list.select_mode == ItemList.SELECT_SINGLE:
		return
	var selected_indices: Array = scene.get("_dialog_multi_selected_indices")
	if selected:
		if idx not in selected_indices:
			selected_indices.append(idx)
	else:
		selected_indices.erase(idx)
	_replace_int_array(scene, "_dialog_multi_selected_indices", selected_indices)
	update_dialog_confirm_state(scene)


func on_dialog_confirm(scene: Object) -> void:
	if bool(scene.get("_dialog_assignment_mode")):
		confirm_assignment_dialog(scene)
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var sel_items := PackedInt32Array()
	if bool(scene.get("_dialog_card_mode")):
		var selected_indices: Array = scene.get("_dialog_card_selected_indices")
		for selected_idx: int in selected_indices:
			sel_items.append(selected_idx)
	else:
		var dialog_list: ItemList = scene.get("_dialog_list")
		sel_items = dialog_list.get_selected_items()
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	if sel_items.size() < min_select:
		scene.call("_log", _bt(scene, "battle.dialog.select_at_least", {"count": min_select}))
		return
	if max_select > 0 and sel_items.size() > max_select:
		scene.call("_log", _bt(scene, "battle.dialog.select_at_most", {"count": max_select}))
		return
	confirm_dialog_selection(scene, sel_items)


func on_dialog_cancel(scene: Object) -> void:
	scene.call(
		"_runtime_log",
		"dialog_cancel",
		"choice=%s %s" % [scene.get("_pending_choice"), scene.call("_dialog_state_snapshot")]
	)
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	dialog_overlay.visible = false
	_replace_int_array(scene, "_dialog_card_selected_indices", [])
	reset_dialog_assignment_state(scene)
	if str(scene.get("_pending_choice")) == "effect_interaction":
		scene.call("_reset_effect_interaction")
	scene.set("_pending_choice", "")


func confirm_assignment_dialog(scene: Object) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var min_select := int(dialog_data.get("min_select", 0))
	var max_select := int(dialog_data.get("max_select", 0))
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	var assignment_count := assignments.size()
	if assignment_count < min_select:
		scene.call("_log", _bt(scene, "battle.dialog.assign_at_least", {"count": min_select}))
		return
	if max_select > 0 and assignment_count > max_select:
		scene.call("_log", _bt(scene, "battle.dialog.assign_at_most", {"count": max_select}))
		return
	var pending_step_index := int(scene.get("_pending_effect_step_index"))
	var pending_steps: Array = scene.get("_pending_effect_steps")
	if pending_step_index < 0 or pending_step_index >= pending_steps.size():
		return
	var stored_assignments: Array[Dictionary] = []
	for assignment_variant: Variant in assignments:
		if assignment_variant is Dictionary:
			stored_assignments.append((assignment_variant as Dictionary).duplicate())
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	dialog_overlay.visible = false
	reset_dialog_assignment_state(scene)
	scene.call("_commit_effect_assignment_selection", stored_assignments)


func _current_player_index(scene: Object) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.game_state != null:
		return gsm.game_state.current_player_index
	return -1


func _turn_number(scene: Object) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.game_state != null:
		return gsm.game_state.turn_number
	return 0


func show_setup_active_dialog(scene: Object, pi: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[pi]
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	var items: Array[String] = []
	for card: CardInstance in basics:
		items.append("%s (HP %d)" % [card.card_data.name, card.card_data.hp])
	scene.set("_pending_choice", "setup_active_%d" % pi)
	var dialog_data := {
		"basics": basics,
		"player": pi,
		"presentation": "cards",
		"card_items": basics,
		"choice_labels": items,
	}
	scene.call("_ensure_ai_opponent")
	var ai_opponent: Variant = scene.get("_ai_opponent")
	var is_ai_prompt: bool = (
		GameManager.current_mode == GameManager.GameMode.VS_AI
		and ai_opponent != null
		and pi == ai_opponent.player_index
	)
	if is_ai_prompt:
		scene.set("_dialog_data", dialog_data)
		scene.set("_dialog_items_data", items)
		var dialog_overlay: Panel = scene.get("_dialog_overlay")
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_overlay != null:
			dialog_overlay.visible = false
		if dialog_cancel != null:
			dialog_cancel.visible = false
	else:
		show_dialog(scene, "玩家 %d：选择战斗宝可梦" % (pi + 1), items, dialog_data)
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_cancel != null:
			dialog_cancel.visible = false
	scene.call("_maybe_run_ai")


func show_setup_bench_dialog(scene: Object, pi: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[pi]
	if player.is_bench_full():
		scene.set("_pending_choice", "")
		scene.set("_dialog_data", {})
		scene.set("_dialog_items_data", [])
		scene.call("_after_setup_bench", pi)
		_schedule_followup_ai_step_if_ready(scene, gsm)
		return
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	if basics.is_empty():
		scene.set("_pending_choice", "")
		scene.set("_dialog_data", {})
		scene.set("_dialog_items_data", [])
		scene.call("_after_setup_bench", pi)
		_schedule_followup_ai_step_if_ready(scene, gsm)
		return
	var items: Array[String] = ["完成"]
	for card: CardInstance in basics:
		items.append("%s (HP %d)" % [card.card_data.name, card.card_data.hp])
	var choice_indices: Array[int] = []
	for card_idx: int in basics.size():
		choice_indices.append(card_idx + 1)
	scene.set("_pending_choice", "setup_bench_%d" % pi)
	var dialog_data := {
		"cards": basics,
		"player": pi,
		"presentation": "cards",
		"card_items": basics,
		"card_indices": choice_indices,
		"choice_labels": items.slice(1),
		"utility_actions": [{"label": "完成", "index": 0}],
	}
	scene.call("_ensure_ai_opponent")
	var ai_opponent: Variant = scene.get("_ai_opponent")
	var is_ai_prompt: bool = (
		GameManager.current_mode == GameManager.GameMode.VS_AI
		and ai_opponent != null
		and pi == ai_opponent.player_index
	)
	if is_ai_prompt:
		scene.set("_dialog_data", dialog_data)
		scene.set("_dialog_items_data", items)
		var dialog_overlay: Panel = scene.get("_dialog_overlay")
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_overlay != null:
			dialog_overlay.visible = false
		if dialog_cancel != null:
			dialog_cancel.visible = false
	else:
		show_dialog(scene, "玩家 %d：选择备战宝可梦（可选，最多 5 只）" % (pi + 1), items, dialog_data)
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_cancel != null:
			dialog_cancel.visible = false
	scene.call("_maybe_run_ai")


func _schedule_followup_ai_step_if_ready(scene: Object, gsm: Variant) -> void:
	if scene == null or gsm == null or gsm.game_state == null:
		return
	scene.call("_ensure_ai_opponent")
	var ai_opponent: Variant = scene.get("_ai_opponent")
	if GameManager.current_mode != GameManager.GameMode.VS_AI or ai_opponent == null:
		return
	if str(scene.get("_pending_choice")) != "":
		return
	if gsm.game_state.phase == GameState.GamePhase.SETUP:
		return
	if gsm.game_state.current_player_index != ai_opponent.player_index:
		return
	if bool(scene.get("_ai_running")):
		scene.set("_ai_followup_requested", true)
		return
	if bool(scene.get("_ai_step_scheduled")):
		return
	scene.set("_ai_step_scheduled", true)
	scene.call_deferred("_run_ai_step")


func show_send_out_dialog(scene: Object, pi: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[pi]
	var bench_choices: Array[PokemonSlot] = []
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and not gsm.effect_processor.is_effectively_knocked_out(bench_slot, gsm.game_state):
			bench_choices.append(bench_slot)
	scene.set("_pending_choice", "send_out")
	scene.set("_dialog_data", {
		"player": pi,
		"bench": bench_choices,
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	})
	scene.call("_show_field_slot_choice", "请选择玩家%d要派出的宝可梦" % (pi + 1), bench_choices, scene.get("_dialog_data"))

func show_heavy_baton_dialog(scene: Object, pi: int, bench_targets: Array[PokemonSlot], energy_count: int, source_name: String) -> void:
	scene.set("_pending_choice", "heavy_baton_target")
	scene.set("_dialog_data", {
		"player": pi,
		"bench": bench_targets.duplicate(),
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	})
	scene.call(
		"_show_field_slot_choice",
		"%s：选择接收 %d 个能量的备战宝可梦" % [source_name, energy_count],
		bench_targets,
		scene.get("_dialog_data")
	)


func show_pokemon_action_dialog(scene: Object, cp: int, slot: PokemonSlot, include_attacks: bool) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card_data: CardData = slot.get_card_data()
	var items: Array[String] = []
	var actions: Array[Dictionary] = []
	var action_items: Array[Dictionary] = []
	var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
	if effect != null:
		for i: int in card_data.abilities.size():
			var ability: Dictionary = card_data.abilities[i]
			if not effect.has_method("can_use_ability"):
				continue
			var can_use: bool = gsm.effect_processor.can_use_ability(slot, gsm.game_state, i)
			var ability_name := str(ability.get("name", ""))
			var ability_reason := "" if can_use else "%s 当前无法使用特性" % card_data.name
			items.append("%s[特性] %s" % ["" if can_use else "[不可用] ", ability_name])
			actions.append({
				"type": "ability",
				"slot": slot,
				"ability_index": i,
				"enabled": can_use,
				"reason": ability_reason,
			})
			action_items.append(_build_pokemon_action_item(
				"ability",
				"特性",
				ability_name,
				"",
				_action_body_from_text(str(ability.get("text", ""))),
				can_use,
				ability_reason
			))
	for granted: Dictionary in gsm.effect_processor.get_granted_abilities(slot, gsm.game_state):
		var can_use_granted: bool = bool(granted.get("enabled", false))
		var granted_name := str(granted.get("name", ""))
		var granted_reason := "" if can_use_granted else "%s 当前无法使用特性" % card_data.name
		items.append("%s[特性] %s" % ["" if can_use_granted else "[不可用] ", granted_name])
		actions.append({
			"type": "ability",
			"slot": slot,
			"ability_index": int(granted.get("ability_index", card_data.abilities.size())),
			"enabled": can_use_granted,
			"reason": granted_reason,
		})
		action_items.append(_build_pokemon_action_item(
			"ability",
			"特性",
			granted_name,
			"赋予",
			_action_body_from_text(str(granted.get("text", "由场上效果赋予的特性。"))),
			can_use_granted,
			granted_reason
		))
	if include_attacks:
		for i: int in card_data.attacks.size():
			var attack: Dictionary = card_data.attacks[i]
			var can_use_attack: bool = gsm.can_use_attack(cp, i)
			var attack_reason: String = "" if can_use_attack else gsm.get_attack_unusable_reason(cp, i)
			var preview_damage: int = gsm.get_attack_preview_damage(cp, i)
			items.append("%s[招式] %s [%s] %s" % [
				"" if can_use_attack else "[不可用] ",
				str(attack.get("name", "")),
				str(attack.get("cost", "")),
				str(attack.get("damage", "")),
			])
			actions.append({
				"type": "attack",
				"slot": slot,
				"attack_index": i,
				"enabled": can_use_attack,
				"reason": attack_reason,
			})
			action_items.append(_build_pokemon_action_item(
				"attack",
				"招式",
				str(attack.get("name", "")),
				_attack_damage_meta_text(attack, preview_damage),
				_attack_body_text(attack, preview_damage),
				can_use_attack,
				attack_reason,
				str(attack.get("cost", ""))
			))
		for granted_attack: Dictionary in gsm.effect_processor.get_granted_attacks(slot, gsm.game_state):
			var granted_can_use: bool = bool(scene.call("_can_use_granted_attack", cp, slot, granted_attack))
			var granted_reason: String = "" if granted_can_use else str(scene.call("_get_granted_attack_unusable_reason", cp, slot, granted_attack))
			items.append("%s[招式] %s [%s]" % [
				"" if granted_can_use else "[不可用] ",
				str(granted_attack.get("name", "")),
				str(granted_attack.get("cost", "")),
			])
			actions.append({
				"type": "granted_attack",
				"slot": slot,
				"granted_attack": granted_attack,
				"enabled": granted_can_use,
				"reason": granted_reason,
			})
			action_items.append(_build_pokemon_action_item(
				"granted_attack",
				"招式",
				str(granted_attack.get("name", "")),
				_attack_damage_meta_text(granted_attack, 0),
				_attack_body_text(granted_attack, 0),
				granted_can_use,
				granted_reason,
				str(granted_attack.get("cost", ""))
			))
		if slot == gsm.game_state.players[cp].active_pokemon:
			var can_retreat: bool = gsm.rule_validator.can_retreat(gsm.game_state, cp, gsm.effect_processor)
			var retreat_cost: int = gsm.effect_processor.get_effective_retreat_cost(slot, gsm.game_state)
			items.append("%s[行动] 撤退" % ("" if can_retreat else "[不可用] "))
			actions.append({
				"type": "retreat",
				"enabled": can_retreat,
				"reason": "当前无法撤退",
			})
			action_items.append(_build_pokemon_action_item(
				"retreat",
				"行动",
				"撤退",
				"费用 %d" % retreat_cost,
				"支付撤退费用，选择 1 只备战宝可梦与战斗宝可梦交换。",
				can_retreat,
				"当前无法撤退"
			))
	if actions.is_empty():
		scene.call("_log", "%s 当前没有可执行的行动" % card_data.name)
		return
	scene.set("_pending_choice", "pokemon_action")
	show_dialog(scene, "选择行动：%s" % card_data.name, items, {
		"player": cp,
		"actions": actions,
		"action_items": action_items,
		"presentation": "action_hud",
		"allow_cancel": true,
	})
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	if dialog_cancel != null:
		dialog_cancel.visible = true


func _build_pokemon_action_item(
	action_type: String,
	kind: String,
	title: String,
	meta: String,
	body: String,
	enabled: bool,
	reason: String,
	cost: String = ""
) -> Dictionary:
	return {
		"type": action_type,
		"kind": kind,
		"title": title if title.strip_edges() != "" else "未命名",
		"meta": meta,
		"body": body,
		"cost": cost,
		"enabled": enabled,
		"reason": reason,
	}


func _attack_damage_meta_text(attack: Dictionary, preview_damage: int) -> String:
	var damage := str(attack.get("damage", "")).strip_edges()
	if damage != "":
		return "伤害 %s" % damage
	if preview_damage > 0:
		return "预览 %d" % preview_damage
	return ""


func _attack_meta_text(attack: Dictionary, preview_damage: int) -> String:
	var parts: Array[String] = []
	var cost := str(attack.get("cost", "")).strip_edges()
	var damage := str(attack.get("damage", "")).strip_edges()
	if cost != "":
		parts.append("费用 %s" % cost)
	if damage != "":
		parts.append("伤害 %s" % damage)
	elif preview_damage > 0:
		parts.append("预览 %d" % preview_damage)
	return " · ".join(parts)


func _attack_body_text(attack: Dictionary, preview_damage: int) -> String:
	var lines: Array[String] = []
	var damage := str(attack.get("damage", "")).strip_edges()
	if damage != "":
		lines.append("基础伤害：%s。" % damage)
	elif preview_damage > 0:
		lines.append("预览伤害：%d。" % preview_damage)
	var text := str(attack.get("text", "")).strip_edges()
	if text != "":
		lines.append(text)
	if lines.is_empty():
		lines.append("无额外效果。")
	return "\n".join(lines)


func _action_body_from_text(text: String) -> String:
	var body := text.strip_edges()
	return body if body != "" else "无额外效果。"


func _legacy_show_pokemon_action_dialog(scene: Object, cp: int, slot: PokemonSlot, include_attacks: bool) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card_data: CardData = slot.get_card_data()
	var items: Array[String] = []
	var actions: Array[Dictionary] = []
	var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
	if effect != null:
		for i: int in card_data.abilities.size():
			var ability: Dictionary = card_data.abilities[i]
			if not effect.has_method("can_use_ability"):
				continue
			var can_use: bool = gsm.effect_processor.can_use_ability(slot, gsm.game_state, i)
			var ability_reason := "" if can_use else "%s 当前无法使用特性" % card_data.name
			var prefix := "" if can_use else "[不可用] "
			items.append("%s[特性] %s" % [prefix, ability.get("name", "")])
			actions.append({
				"type": "ability",
				"slot": slot,
				"ability_index": i,
				"enabled": can_use,
				"reason": ability_reason,
			})
	for granted: Dictionary in gsm.effect_processor.get_granted_abilities(slot, gsm.game_state):
		var can_use_granted: bool = bool(granted.get("enabled", false))
		var granted_name := str(granted.get("name", ""))
		var granted_reason := "" if can_use_granted else "%s 当前无法使用特性" % card_data.name
		var granted_prefix := "" if can_use_granted else "[不可用] "
		items.append("%s[特性] %s" % [granted_prefix, granted_name])
		actions.append({
			"type": "ability",
			"slot": slot,
			"ability_index": int(granted.get("ability_index", card_data.abilities.size())),
			"enabled": can_use_granted,
			"reason": granted_reason,
		})
	if include_attacks:
		for i: int in card_data.attacks.size():
			var attack: Dictionary = card_data.attacks[i]
			var can_use_attack: bool = gsm.can_use_attack(cp, i)
			var attack_reason: String = "" if can_use_attack else gsm.get_attack_unusable_reason(cp, i)
			var prefix: String = "" if can_use_attack else "[不可用] "
			var preview_damage: int = gsm.get_attack_preview_damage(cp, i)
			var preview_text := ""
			if String(attack.get("damage", "")) != "" or preview_damage > 0:
				preview_text = " 预览伤害:%d" % preview_damage
			items.append("%s[招式] %s [%s] %s%s" % [prefix, attack.get("name", ""), attack.get("cost", ""), attack.get("damage", ""), preview_text])
			actions.append({
				"type": "attack",
				"slot": slot,
				"attack_index": i,
				"enabled": can_use_attack,
				"reason": attack_reason,
			})
		for granted_attack: Dictionary in gsm.effect_processor.get_granted_attacks(slot, gsm.game_state):
			var granted_can_use: bool = bool(scene.call("_can_use_granted_attack", cp, slot, granted_attack))
			var granted_prefix: String = "" if granted_can_use else "[不可用] "
			var granted_reason: String = "" if granted_can_use else str(scene.call("_get_granted_attack_unusable_reason", cp, slot, granted_attack))
			items.append("%s[招式] %s [%s]" % [granted_prefix, str(granted_attack.get("name", "")), str(granted_attack.get("cost", ""))])
			actions.append({
				"type": "granted_attack",
				"slot": slot,
				"granted_attack": granted_attack,
				"enabled": granted_can_use,
				"reason": granted_reason,
			})
		if slot == gsm.game_state.players[cp].active_pokemon:
			var can_retreat: bool = gsm.rule_validator.can_retreat(gsm.game_state, cp, gsm.effect_processor)
			var retreat_prefix: String = "" if can_retreat else "[不可用] "
			items.append("%s[行动] 撤退" % retreat_prefix)
			actions.append({
				"type": "retreat",
				"enabled": can_retreat,
				"reason": "当前无法撤退",
			})
	if actions.is_empty():
		scene.call("_log", "%s 当前没有可执行的行动" % card_data.name)
		return
	scene.set("_pending_choice", "pokemon_action")
	show_dialog(scene, "选择行动：%s" % card_data.name, items, {"player": cp, "actions": actions})
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	if dialog_cancel != null:
		dialog_cancel.visible = true


func show_retreat_dialog(scene: Object, cp: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[cp]
	var active: PokemonSlot = player.active_pokemon
	var cost: int = gsm.effect_processor.get_effective_retreat_cost(active, gsm.game_state)
	var energy_discard: Array[CardInstance] = []
	var paid_units := 0
	for energy: CardInstance in active.attached_energy:
		if paid_units >= cost:
			break
		energy_discard.append(energy)
		paid_units += gsm.effect_processor.get_energy_colorless_count(energy)
	scene.set("_pending_choice", "retreat_bench")
	scene.set("_dialog_data", {
		"player": cp,
		"bench": player.bench,
		"energy_discard": energy_discard,
		"allow_cancel": true,
		"min_select": 1,
		"max_select": 1,
	})
	scene.call("_show_field_slot_choice", "选择接收 %d 个能量的备战宝可梦" % cost, player.bench, scene.get("_dialog_data"))


func show_match_end_dialog(scene: Object, winner_index: int, reason: String) -> void:
	var summary := match_end_summary_text(winner_index, reason)
	var items: Array[String] = [summary]
	var extra_data := {
		"winner": winner_index,
		"reason": reason,
		"action": "game_over",
	}
	var review_action := current_match_end_review_action(scene)
	if not review_action.is_empty():
		items.append(str(review_action.get("label", "生成AI复盘")))
		extra_data["review_action"] = str(review_action.get("kind", "generate"))
		extra_data["review_action_index"] = items.size() - 1
	var learning_action := current_match_end_learning_action(scene)
	if not learning_action.is_empty():
		items.append(str(learning_action.get("label", "让AI学习")))
		extra_data["learning_action"] = str(learning_action.get("kind", "mark"))
		extra_data["learning_action_index"] = items.size() - 1
	items.append("返回对战准备")
	extra_data["return_action_index"] = items.size() - 1
	scene.set("_pending_choice", "game_over")
	show_dialog(scene, "对战结束", items, extra_data)


func match_end_summary_text(winner_index: int, reason: String) -> String:
	return "玩家 %d 获胜\n原因：%s" % [winner_index + 1, reason]


func current_match_end_review_action(scene: Object) -> Dictionary:
	if not bool(scene.call("_should_offer_battle_review")):
		return {}
	if bool(scene.get("_battle_review_busy")):
		var progress_text := str(scene.get("_battle_review_progress_text"))
		return {
			"kind": "busy",
			"label": progress_text if progress_text != "" else "正在生成AI复盘...",
		}
	var cached_review: Dictionary = scene.call("_load_cached_battle_review")
	var cached_status := str(cached_review.get("status", ""))
	if cached_status in ["completed", "partial_success"]:
		scene.set("_battle_review_last_review", cached_review)
		return {"kind": "view", "label": "查看AI复盘"}
	if cached_status == "failed":
		scene.set("_battle_review_last_review", cached_review)
		return {"kind": "retry", "label": "生成失败，重试"}
	var last_review: Dictionary = scene.get("_battle_review_last_review")
	if str(last_review.get("status", "")) == "failed":
		return {"kind": "retry", "label": "生成失败，重试"}
	return {"kind": "generate", "label": "生成AI复盘"}


func current_match_end_learning_action(scene: Object) -> Dictionary:
	if not bool(scene.call("_should_offer_match_learning")):
		return {}
	if bool(scene.call("_is_current_match_marked_for_learning")):
		return {"kind": "marked", "label": "已加入学习池"}
	return {"kind": "mark", "label": "让AI学习"}
