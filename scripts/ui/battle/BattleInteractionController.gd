class_name BattleInteractionController
extends RefCounted

const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func setup_field_interaction_panel(scene: Object) -> void:
	ensure_field_interaction_panel(scene)
	update_field_interaction_panel_metrics(scene)
	hide_field_interaction(scene)


func ensure_field_interaction_panel(scene: Object) -> void:
	if scene.get("_field_interaction_overlay") != null:
		return

	var overlay := Control.new()
	overlay.name = "FieldInteractionOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 80
	(scene as Node).add_child(overlay)
	scene.set("_field_interaction_overlay", overlay)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(layout)
	scene.set("_field_interaction_layout", layout)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(top_spacer)
	scene.set("_field_interaction_top_spacer", top_spacer)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(row)

	var panel := PanelContainer.new()
	panel.name = "FieldInteractionPanel"
	panel.custom_minimum_size = Vector2(760, 136)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(panel)
	scene.set("_field_interaction_panel", panel)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(bottom_spacer)
	scene.set("_field_interaction_bottom_spacer", bottom_spacer)
	apply_field_interaction_position(scene, "center")

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.06, 0.1, 0.92)
	panel_style.border_color = Color(0.28, 0.82, 0.92, 0.88)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.02, 0.04, 0.08, 0.42)
	panel_style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	vbox.add_child(title_label)
	scene.set("_field_interaction_title_lbl", title_label)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.65, 0.9, 0.96))
	vbox.add_child(status_label)
	scene.set("_field_interaction_status_lbl", status_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(scroll)
	scene.set("_field_interaction_scroll", scroll)

	var interaction_row := HBoxContainer.new()
	interaction_row.alignment = BoxContainer.ALIGNMENT_CENTER
	interaction_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	interaction_row.add_theme_constant_override("separation", 14)
	interaction_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(interaction_row)
	scene.set("_field_interaction_row", interaction_row)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 10)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(buttons)
	scene.set("_field_interaction_buttons", buttons)

	var clear_button := Button.new()
	clear_button.text = "清除"
	clear_button.custom_minimum_size = Vector2(110, 34)
	clear_button.pressed.connect(Callable(scene, "_on_field_interaction_clear_pressed"))
	buttons.add_child(clear_button)
	scene.set("_field_interaction_clear_btn", clear_button)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.custom_minimum_size = Vector2(110, 34)
	cancel_button.pressed.connect(Callable(scene, "_on_field_interaction_cancel_pressed"))
	buttons.add_child(cancel_button)
	scene.set("_field_interaction_cancel_btn", cancel_button)

	var confirm_button := Button.new()
	confirm_button.text = "确认"
	confirm_button.custom_minimum_size = Vector2(140, 34)
	confirm_button.pressed.connect(Callable(scene, "_on_field_interaction_confirm_pressed"))
	buttons.add_child(confirm_button)
	scene.set("_field_interaction_confirm_btn", confirm_button)


func hide_field_interaction(scene: Object) -> void:
	scene.set("_field_interaction_mode", "")
	scene.set("_field_interaction_data", {})
	scene.set("_field_interaction_slot_index_by_id", {})
	_replace_int_array(scene, "_field_interaction_selected_indices", [])
	scene.set("_field_interaction_assignment_selected_source_index", -1)
	_replace_dictionary_array(scene, "_field_interaction_assignment_entries", [])
	apply_field_interaction_position(scene, "center")

	var title_label: Label = scene.get("_field_interaction_title_lbl")
	if title_label != null:
		title_label.text = ""
	var status_label: Label = scene.get("_field_interaction_status_lbl")
	if status_label != null:
		status_label.text = ""
	var row: HBoxContainer = scene.get("_field_interaction_row")
	if row != null:
		scene.call("_clear_container_children", row)
	var overlay: Control = scene.get("_field_interaction_overlay")
	if overlay != null:
		overlay.visible = false


func update_field_interaction_panel_metrics(scene: Object, viewport_size: Vector2 = Vector2.ZERO) -> void:
	var panel: PanelContainer = scene.get("_field_interaction_panel")
	var scroll: ScrollContainer = scene.get("_field_interaction_scroll")
	var row: HBoxContainer = scene.get("_field_interaction_row")
	if panel == null or scroll == null or row == null:
		return
	var effective_viewport: Vector2 = viewport_size
	if effective_viewport == Vector2.ZERO and (scene as Node).is_inside_tree():
		effective_viewport = (scene as CanvasItem).get_viewport().get_visible_rect().size
	if effective_viewport == Vector2.ZERO:
		effective_viewport = Vector2(1366, 768)
	var play_card_size: Vector2 = scene.get("_play_card_size")
	var card_height: float = play_card_size.y if play_card_size.y > 0.0 else 152.0
	var strip_height: float = card_height + 8.0
	var panel_width: float = clampf(effective_viewport.x * 0.54, 680.0, 980.0)
	panel.custom_minimum_size = Vector2(panel_width, maxf(strip_height + 86.0, 136.0))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.custom_minimum_size = Vector2(0.0, strip_height)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	apply_field_interaction_position(scene, str(scene.get("_field_interaction_position")))


func is_field_interaction_active(scene: Object) -> bool:
	return str(scene.get("_field_interaction_mode")) != ""


func field_interaction_target_owner(_scene: Object, slot: PokemonSlot) -> int:
	if slot == null:
		return -1
	var top_card: CardInstance = slot.get_top_card()
	return top_card.owner_index if top_card != null else -1


func resolve_field_interaction_position(scene: Object, slots: Array) -> String:
	var own_targets := 0
	var opponent_targets := 0
	var view_player := int(scene.get("_view_player"))
	for item: Variant in slots:
		if not (item is PokemonSlot):
			continue
		var owner_index := field_interaction_target_owner(scene, item as PokemonSlot)
		if owner_index == view_player:
			own_targets += 1
		elif owner_index >= 0:
			opponent_targets += 1
	if own_targets > 0 and opponent_targets == 0:
		return "top"
	if opponent_targets > 0 and own_targets == 0:
		return "bottom"
	return "center"


func apply_field_interaction_position(scene: Object, position: String) -> void:
	scene.set("_field_interaction_position", position)
	var top_spacer: Control = scene.get("_field_interaction_top_spacer")
	var bottom_spacer: Control = scene.get("_field_interaction_bottom_spacer")
	if top_spacer == null or bottom_spacer == null:
		return
	match position:
		"top":
			top_spacer.size_flags_stretch_ratio = 0.22
			bottom_spacer.size_flags_stretch_ratio = 6.45
		"bottom":
			top_spacer.size_flags_stretch_ratio = 6.45
			bottom_spacer.size_flags_stretch_ratio = 0.22
		_:
			top_spacer.size_flags_stretch_ratio = 1.0
			bottom_spacer.size_flags_stretch_ratio = 1.0


func show_field_slot_choice(scene: Object, title: String, items: Array, data: Dictionary = {}) -> void:
	ensure_field_interaction_panel(scene)
	update_field_interaction_panel_metrics(scene)
	hide_field_interaction(scene)
	scene.set("_field_interaction_mode", "slot_select")
	var interaction_data := data.duplicate(true)
	interaction_data["title"] = title
	interaction_data["items"] = items.duplicate()
	scene.set("_field_interaction_data", interaction_data)
	apply_field_interaction_position(scene, resolve_field_interaction_position(scene, items))
	rebuild_field_slot_index_map(scene, items)
	var overlay: Control = scene.get("_field_interaction_overlay")
	if overlay != null:
		overlay.visible = true
	refresh_field_interaction_status(scene)
	scene.call("_record_battle_event", {
		"event_type": "choice_context",
		"prompt_source": "field_slot",
		"prompt_type": str(data.get("prompt_type", scene.get("_pending_choice"))),
		"title": title,
		"items": items.duplicate(true),
		"extra_data": data.duplicate(true),
		"player_index": int(data.get("player", _current_player_index(scene))),
		"turn_number": _turn_number(scene),
		"phase": scene.call("_recording_phase_name"),
	})


func show_field_assignment_interaction(scene: Object, step: Dictionary) -> void:
	ensure_field_interaction_panel(scene)
	update_field_interaction_panel_metrics(scene)
	hide_field_interaction(scene)
	scene.set("_field_interaction_mode", "assignment")
	scene.set("_field_interaction_data", step.duplicate(true))
	apply_field_interaction_position(scene, resolve_field_interaction_position(scene, step.get("target_items", [])))
	rebuild_field_slot_index_map(scene, step.get("target_items", []))
	build_field_assignment_source_cards(scene)
	var overlay: Control = scene.get("_field_interaction_overlay")
	if overlay != null:
		overlay.visible = true
	refresh_field_interaction_status(scene)
	scene.call("_record_battle_event", {
		"event_type": "choice_context",
		"prompt_source": "field_assignment",
		"prompt_type": str(step.get("prompt_type", scene.get("_pending_choice"))),
		"title": str(step.get("title", "请选择")),
		"items": (step.get("target_items", []) as Array).duplicate(true),
		"extra_data": step.duplicate(true),
		"player_index": int(step.get("player", _current_player_index(scene))),
		"turn_number": _turn_number(scene),
		"phase": scene.call("_recording_phase_name"),
	})


func rebuild_field_slot_index_map(scene: Object, items: Array) -> void:
	var index_by_id: Dictionary = {}
	for i: int in items.size():
		var slot_variant: Variant = items[i]
		if not (slot_variant is PokemonSlot):
			continue
		var slot_id := str(scene.call("_slot_id_from_slot", slot_variant))
		if slot_id != "":
			index_by_id[slot_id] = i
	scene.set("_field_interaction_slot_index_by_id", index_by_id)


func build_field_assignment_source_cards(scene: Object) -> void:
	var row: HBoxContainer = scene.get("_field_interaction_row")
	if row == null:
		return
	scene.call("_clear_container_children", row)

	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var source_items: Array = interaction_data.get("source_items", [])
	var source_labels: Array = interaction_data.get("source_labels", [])
	var source_groups: Array = interaction_data.get("source_groups", [])
	if source_groups.is_empty():
		for i: int in source_items.size():
			add_field_assignment_source_card(scene, source_items, source_labels, i)
		return

	for group_index: int in source_groups.size():
		var group: Dictionary = source_groups[group_index]
		var slot_variant: Variant = group.get("slot")
		var energy_indices: Array = group.get("energy_indices", [])
		if group_index > 0:
			var separator := VSeparator.new()
			separator.custom_minimum_size = Vector2(2, 0)
			separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(separator)
		if slot_variant is PokemonSlot:
			var header_view := BattleCardViewScript.new()
			header_view.custom_minimum_size = scene.get("_play_card_size")
			header_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			header_view.set_clickable(false)
			var slot: PokemonSlot = slot_variant
			header_view.setup_from_card_data(slot.get_card_data(), scene.call("_battle_card_mode_for_slot", slot))
			header_view.set_badges()
			header_view.set_battle_status(scene.call("_build_battle_status", slot))
			row.add_child(header_view)
		for energy_index_variant: Variant in energy_indices:
			add_field_assignment_source_card(scene, source_items, source_labels, int(energy_index_variant))


func add_field_assignment_source_card(scene: Object, source_items: Array, source_labels: Array, source_index: int) -> void:
	if source_index < 0 or source_index >= source_items.size():
		return
	var row: HBoxContainer = scene.get("_field_interaction_row")
	if row == null:
		return
	var source_view := BattleCardViewScript.new()
	source_view.custom_minimum_size = scene.get("_play_card_size")
	source_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	source_view.set_clickable(true)
	scene.call(
		"_setup_dialog_card_view",
		source_view,
		source_items[source_index],
		str(source_labels[source_index]) if source_index < source_labels.size() else ""
	)
	source_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		scene.call("_on_field_assignment_source_chosen", source_index)
	)
	source_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
		if cd != null:
			scene.call("_show_card_detail", cd)
	)
	source_view.set_meta("field_assignment_source_index", source_index)
	row.add_child(source_view)


func on_field_assignment_source_chosen(scene: Object, source_index: int) -> void:
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var source_items: Array = interaction_data.get("source_items", [])
	if source_index < 0 or source_index >= source_items.size():
		return
	var assigned_index := find_field_assignment_index_for_source(scene, source_index)
	var assignment_entries: Array = scene.get("_field_interaction_assignment_entries")
	if assigned_index >= 0:
		assignment_entries.remove_at(assigned_index)
		scene.set("_field_interaction_assignment_entries", assignment_entries)
		if int(scene.get("_field_interaction_assignment_selected_source_index")) == source_index:
			scene.set("_field_interaction_assignment_selected_source_index", -1)
		refresh_field_interaction_status(scene)
		scene.call("_refresh_ui")
		return

	var max_assignments: int = int(interaction_data.get("max_select", source_items.size()))
	if max_assignments > 0 and assignment_entries.size() >= max_assignments:
		scene.call("_log", "已达到可分配卡牌上限")
		return

	if int(scene.get("_field_interaction_assignment_selected_source_index")) == source_index:
		scene.set("_field_interaction_assignment_selected_source_index", -1)
	else:
		scene.set("_field_interaction_assignment_selected_source_index", source_index)
	refresh_field_interaction_status(scene)
	scene.call("_refresh_ui")


func find_field_assignment_index_for_source(scene: Object, source_index: int) -> int:
	var assignment_entries: Array = scene.get("_field_interaction_assignment_entries")
	for i: int in assignment_entries.size():
		if int((assignment_entries[i] as Dictionary).get("source_index", -1)) == source_index:
			return i
	return -1


func field_interaction_selected_slot_ids(scene: Object) -> Array[String]:
	var result: Array[String] = []
	var mode := str(scene.get("_field_interaction_mode"))
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	if mode == "slot_select":
		var items: Array = interaction_data.get("items", [])
		var selected_indices: Array = scene.get("_field_interaction_selected_indices")
		for selected_index: int in selected_indices:
			if selected_index < 0 or selected_index >= items.size():
				continue
			var slot_variant: Variant = items[selected_index]
			if slot_variant is PokemonSlot:
				var slot_id := str(scene.call("_slot_id_from_slot", slot_variant))
				if slot_id != "":
					result.append(slot_id)
	elif mode in ["assignment", "counter_distribution"]:
		var entries: Array = scene.get("_field_interaction_assignment_entries")
		for entry_variant: Variant in entries:
			if not (entry_variant is Dictionary):
				continue
			var target_variant: Variant = (entry_variant as Dictionary).get("target")
			if target_variant is PokemonSlot:
				var target_slot_id := str(scene.call("_slot_id_from_slot", target_variant))
				if target_slot_id != "":
					result.append(target_slot_id)
	return result


func refresh_field_interaction_status(scene: Object) -> void:
	ensure_field_interaction_panel(scene)
	if not is_field_interaction_active(scene):
		hide_field_interaction(scene)
		return
	var overlay: Control = scene.get("_field_interaction_overlay")
	if overlay != null:
		overlay.visible = true
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var title_label: Label = scene.get("_field_interaction_title_lbl")
	if title_label != null:
		title_label.text = str(interaction_data.get("title", "请选择"))
	var mode := str(scene.get("_field_interaction_mode"))
	var show_cards := mode in ["assignment", "counter_distribution"]
	var scroll: ScrollContainer = scene.get("_field_interaction_scroll")
	if scroll != null:
		scroll.visible = show_cards
	var buttons: HBoxContainer = scene.get("_field_interaction_buttons")
	if buttons != null:
		buttons.visible = true

	var status_label: Label = scene.get("_field_interaction_status_lbl")
	var clear_button: Button = scene.get("_field_interaction_clear_btn")
	var cancel_button: Button = scene.get("_field_interaction_cancel_btn")
	var confirm_button: Button = scene.get("_field_interaction_confirm_btn")

	if mode == "slot_select":
		var min_select: int = int(interaction_data.get("min_select", 1))
		var max_select: int = int(interaction_data.get("max_select", 1))
		var selected_indices: Array = scene.get("_field_interaction_selected_indices")
		var selected_count := selected_indices.size()
		var status := "请选择场上的目标。"
		if max_select > 1 or min_select > 1:
			status = "已选择 %d / %d" % [selected_count, min_select]
			if max_select > 1:
				status += "（最多 %d）" % max_select
		if status_label != null:
			status_label.text = status
		if clear_button != null:
			clear_button.visible = selected_count > 0 and max_select > 1
		if cancel_button != null:
			cancel_button.visible = bool(interaction_data.get("allow_cancel", true))
		if confirm_button != null:
			confirm_button.visible = max_select > 1 or min_select > 1
			confirm_button.disabled = selected_count < min_select
		return

	if mode == "counter_distribution":
		var total_counters: int = int(interaction_data.get("total_counters", 0))
		var min_counters: int = int(interaction_data.get("min_select", total_counters))
		var allow_partial := bool(interaction_data.get("allow_partial", false))
		var assigned_count: int = _get_counter_distribution_assigned_total(scene)
		var remaining: int = total_counters - assigned_count
		var selected_amount: int = int(scene.get("_field_interaction_assignment_selected_source_index"))
		var summary := ""
		if selected_amount > 0:
			summary = "已选 %d 个指示物，请点击场上目标宝可梦。" % selected_amount
		elif remaining > 0:
			summary = "请选择要放置的数量，再点击目标。剩余 %d / %d" % [remaining, total_counters]
		else:
			summary = "已分配全部 %d 个伤害指示物。" % total_counters
		var assignment_entries: Array = scene.get("_field_interaction_assignment_entries")
		var target_summary := _build_counter_target_summary(assignment_entries)
		if target_summary != "":
			summary += " " + target_summary
		if status_label != null:
			status_label.text = summary
		if clear_button != null:
			clear_button.visible = not assignment_entries.is_empty()
		if cancel_button != null:
			cancel_button.visible = bool(interaction_data.get("allow_cancel", true))
		if confirm_button != null:
			confirm_button.visible = allow_partial and assigned_count >= min_counters and remaining > 0
			confirm_button.disabled = assigned_count < min_counters
		return

	refresh_field_assignment_source_views(scene)
	var min_assignments: int = int(interaction_data.get("min_select", 0))
	var max_assignments: int = int(interaction_data.get("max_select", 0))
	var summary := "先选择左侧卡牌，再点击场上的目标宝可梦。"
	var selected_source_index := int(scene.get("_field_interaction_assignment_selected_source_index"))
	if selected_source_index >= 0:
		var source_items: Array = interaction_data.get("source_items", [])
		if selected_source_index < source_items.size():
			var selected_source: Variant = source_items[selected_source_index]
			if selected_source is CardInstance:
				summary = "当前选择：%s。请点击场上目标。" % (selected_source as CardInstance).card_data.name
	var assignment_entries: Array = scene.get("_field_interaction_assignment_entries")
	if not assignment_entries.is_empty():
		summary += " 已分配 %d 项" % assignment_entries.size()
		if max_assignments > 0:
			summary += " / %d" % max_assignments
	if status_label != null:
		status_label.text = summary
	if clear_button != null:
		clear_button.visible = not assignment_entries.is_empty()
	if cancel_button != null:
		cancel_button.visible = bool(interaction_data.get("allow_cancel", true))
	if confirm_button != null:
		confirm_button.visible = true
		confirm_button.disabled = assignment_entries.size() < min_assignments


func refresh_field_assignment_source_views(scene: Object) -> void:
	var row: HBoxContainer = scene.get("_field_interaction_row")
	if row == null:
		return
	var selected_source_index := int(scene.get("_field_interaction_assignment_selected_source_index"))
	for child: Node in row.get_children():
		if not (child is BattleCardView):
			continue
		var card_view := child as BattleCardView
		var idx: int = int(card_view.get_meta("field_assignment_source_index", -1))
		var source_selected := idx == selected_source_index
		var source_assigned := find_field_assignment_index_for_source(scene, idx) >= 0
		card_view.set_selected(source_selected)
		card_view.set_selectable_hint(not source_selected and not source_assigned)
		card_view.set_disabled(source_assigned)


func on_field_interaction_clear_pressed(scene: Object) -> void:
	var mode := str(scene.get("_field_interaction_mode"))
	if mode == "slot_select":
		_replace_int_array(scene, "_field_interaction_selected_indices", [])
	elif mode == "counter_distribution":
		scene.set("_field_interaction_assignment_selected_source_index", -1)
		_replace_dictionary_array(scene, "_field_interaction_assignment_entries", [])
		_build_counter_distribution_buttons(scene)
	else:
		scene.set("_field_interaction_assignment_selected_source_index", -1)
		_replace_dictionary_array(scene, "_field_interaction_assignment_entries", [])
	refresh_field_interaction_status(scene)
	scene.call("_refresh_ui")


func cancel_field_interaction(scene: Object) -> void:
	var handled_choice := str(scene.get("_pending_choice"))
	hide_field_interaction(scene)
	if handled_choice == "effect_interaction":
		scene.call("_reset_effect_interaction")
		return
	scene.set("_pending_choice", "")
	scene.set("_dialog_data", {})
	scene.set("_dialog_items_data", [])


func handle_field_slot_select_index(scene: Object, target_index: int) -> void:
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var selected_indices: Array = scene.get("_field_interaction_selected_indices")
	var min_select: int = int(interaction_data.get("min_select", 1))
	var max_select: int = int(interaction_data.get("max_select", 1))
	if max_select <= 1 and min_select <= 1:
		_replace_int_array(scene, "_field_interaction_selected_indices", [target_index])
		finalize_field_slot_selection(scene)
		return
	if target_index in selected_indices:
		selected_indices.erase(target_index)
	else:
		if max_select > 0 and selected_indices.size() >= max_select:
			return
		selected_indices.append(target_index)
	_replace_int_array(scene, "_field_interaction_selected_indices", selected_indices)
	refresh_field_interaction_status(scene)
	scene.call("_refresh_ui")
	if min_select == max_select and max_select > 1 and selected_indices.size() == max_select:
		finalize_field_slot_selection(scene)


func handle_field_assignment_target_index(scene: Object, target_index: int) -> void:
	var selected_source_index := int(scene.get("_field_interaction_assignment_selected_source_index"))
	if selected_source_index < 0:
		scene.call("_log", "请选择 1 个目标")
		return
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var source_items: Array = interaction_data.get("source_items", [])
	var target_items: Array = interaction_data.get("target_items", [])
	if selected_source_index >= source_items.size():
		return
	if target_index < 0 or target_index >= target_items.size():
		return
	var exclude_map: Dictionary = interaction_data.get("source_exclude_targets", {})
	var excluded: Array = exclude_map.get(selected_source_index, [])
	if target_index in excluded:
		scene.call("_log", "当前选择的目标无效，请重新选择。")
		return
	var assignment_entries: Array = scene.get("_field_interaction_assignment_entries")
	var max_per_target: int = int(interaction_data.get("max_assignments_per_target", 0))
	if max_per_target > 0 and _count_assignments_for_target_index(assignment_entries, target_index) >= max_per_target:
		scene.call("_log", "褰撳墠鐩爣宸茶揪鍒板彲鍒嗛厤涓婇檺")
		return
	assignment_entries.append({
		"source_index": selected_source_index,
		"source": source_items[selected_source_index],
		"target_index": target_index,
		"target": target_items[target_index],
	})
	scene.set("_field_interaction_assignment_entries", assignment_entries)
	scene.set("_field_interaction_assignment_selected_source_index", -1)
	refresh_field_interaction_status(scene)
	scene.call("_refresh_ui")
	var min_assignments: int = int(interaction_data.get("min_select", 0))
	var max_assignments: int = int(interaction_data.get("max_select", 0))
	if min_assignments == max_assignments and max_assignments > 0 and assignment_entries.size() == max_assignments:
		finalize_field_assignment_selection(scene)


func finalize_field_slot_selection(scene: Object) -> void:
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var selected_indices: Array = scene.get("_field_interaction_selected_indices")
	var min_select: int = int(interaction_data.get("min_select", 1))
	if selected_indices.size() < min_select:
		scene.call("_log", "至少选择 %d 项。" % min_select)
		return
	var selected := PackedInt32Array(selected_indices)
	hide_field_interaction(scene)
	if str(scene.get("_pending_choice")) == "effect_interaction":
		scene.call("_handle_effect_interaction_choice", selected)
	else:
		scene.call("_handle_dialog_choice", selected)


func finalize_field_assignment_selection(scene: Object) -> void:
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var assignment_entries: Array = scene.get("_field_interaction_assignment_entries")
	var min_select: int = int(interaction_data.get("min_select", 0))
	if assignment_entries.size() < min_select:
		scene.call("_log", "至少完成 %d 次分配。" % min_select)
		return
	if str(scene.get("_pending_choice")) != "effect_interaction":
		hide_field_interaction(scene)
		return
	var stored_assignments: Array[Dictionary] = []
	for assignment_variant: Variant in assignment_entries:
		if assignment_variant is Dictionary:
			stored_assignments.append((assignment_variant as Dictionary).duplicate())
	hide_field_interaction(scene)
	scene.call("_commit_effect_assignment_selection", stored_assignments)


## ===== 伤害指示物分配 UI（HUD 风格数字选择器） =====


func show_field_counter_distribution(scene: Object, step: Dictionary) -> void:
	ensure_field_interaction_panel(scene)
	update_field_interaction_panel_metrics(scene)
	hide_field_interaction(scene)
	scene.set("_field_interaction_mode", "counter_distribution")
	scene.set("_field_interaction_data", step.duplicate(true))
	apply_field_interaction_position(scene, resolve_field_interaction_position(scene, step.get("target_items", [])))
	rebuild_field_slot_index_map(scene, step.get("target_items", []))
	_build_counter_distribution_buttons(scene)
	var overlay: Control = scene.get("_field_interaction_overlay")
	if overlay != null:
		overlay.visible = true
	refresh_field_interaction_status(scene)
	scene.call("_record_battle_event", {
		"event_type": "choice_context",
		"prompt_source": "counter_distribution",
		"prompt_type": str(step.get("prompt_type", scene.get("_pending_choice"))),
		"title": str(step.get("title", "请选择")),
		"items": (step.get("target_items", []) as Array).duplicate(true),
		"extra_data": step.duplicate(true),
		"player_index": int(step.get("player", _current_player_index(scene))),
		"turn_number": _turn_number(scene),
		"phase": scene.call("_recording_phase_name"),
	})


func _build_counter_distribution_buttons(scene: Object) -> void:
	var row: HBoxContainer = scene.get("_field_interaction_row")
	if row == null:
		return
	scene.call("_clear_container_children", row)
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var total_counters: int = int(interaction_data.get("total_counters", 0))
	var assigned_count: int = _get_counter_distribution_assigned_total(scene)
	var remaining: int = total_counters - assigned_count
	var selected_amount: int = int(scene.get("_field_interaction_assignment_selected_source_index"))
	for amount: int in range(1, remaining + 1):
		var btn := Button.new()
		btn.text = str(amount)
		btn.custom_minimum_size = Vector2(52, 52)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.9, 0.2) if amount == selected_amount else Color.WHITE
		style.set_corner_radius_all(6)
		style.set_content_margin_all(4)
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate()
		hover_style.bg_color = Color(1.0, 0.95, 0.4) if amount == selected_amount else Color(0.9, 0.9, 0.9)
		btn.add_theme_stylebox_override("hover", hover_style)
		var pressed_style := style.duplicate()
		pressed_style.bg_color = Color(0.85, 0.85, 0.85)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_color_override("font_color", Color.BLACK)
		btn.add_theme_color_override("font_hover_color", Color.BLACK)
		btn.add_theme_color_override("font_pressed_color", Color.BLACK)
		btn.add_theme_font_size_override("font_size", 18)
		var captured_amount: int = amount
		btn.pressed.connect(func() -> void:
			scene.call("_on_counter_distribution_amount_chosen", captured_amount)
		)
		row.add_child(btn)


func on_counter_distribution_amount_chosen(scene: Object, amount: int) -> void:
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var total_counters: int = int(interaction_data.get("total_counters", 0))
	var assigned_count: int = _get_counter_distribution_assigned_total(scene)
	var remaining: int = total_counters - assigned_count
	if amount < 1 or amount > remaining:
		return
	if int(scene.get("_field_interaction_assignment_selected_source_index")) == amount:
		scene.set("_field_interaction_assignment_selected_source_index", -1)
	else:
		scene.set("_field_interaction_assignment_selected_source_index", amount)
	_build_counter_distribution_buttons(scene)
	refresh_field_interaction_status(scene)


func handle_counter_distribution_target(scene: Object, target_index: int) -> void:
	var selected_amount: int = int(scene.get("_field_interaction_assignment_selected_source_index"))
	if selected_amount <= 0:
		scene.call("_log", "请先选择要放置的伤害指示物数量")
		return
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var target_items: Array = interaction_data.get("target_items", [])
	if target_index < 0 or target_index >= target_items.size():
		return
	var target: Variant = target_items[target_index]
	if not (target is PokemonSlot):
		return
	var assignment_entries: Array = scene.get("_field_interaction_assignment_entries")
	var max_assignments: int = int(interaction_data.get("max_assignments", 0))
	if max_assignments > 0 and assignment_entries.size() >= max_assignments:
		return
	var max_per_target: int = int(interaction_data.get("max_assignments_per_target", 0))
	if max_per_target > 0 and _count_assignments_for_target_index(assignment_entries, target_index) >= max_per_target:
		return
	assignment_entries.append({
		"target_index": target_index,
		"target": target,
		"amount": selected_amount * 10,
	})
	scene.set("_field_interaction_assignment_entries", assignment_entries)
	scene.set("_field_interaction_assignment_selected_source_index", -1)
	var total_counters: int = int(interaction_data.get("total_counters", 0))
	var assigned_count: int = _get_counter_distribution_assigned_total(scene)
	_build_counter_distribution_buttons(scene)
	refresh_field_interaction_status(scene)
	scene.call("_refresh_ui")
	if assigned_count >= total_counters or (bool(interaction_data.get("allow_partial", false)) and max_assignments == 1):
		finalize_counter_distribution(scene)


func finalize_counter_distribution(scene: Object) -> void:
	var interaction_data: Dictionary = scene.get("_field_interaction_data")
	var assignment_entries: Array = scene.get("_field_interaction_assignment_entries")
	var total_counters: int = int(interaction_data.get("total_counters", 0))
	var assigned_count: int = _get_counter_distribution_assigned_total(scene)
	var min_counters: int = int(interaction_data.get("min_select", total_counters))
	var allow_partial := bool(interaction_data.get("allow_partial", false))
	if (not allow_partial and assigned_count < total_counters) or (allow_partial and assigned_count < min_counters):
		scene.call("_log", "还需分配 %d 个伤害指示物。" % (total_counters - assigned_count))
		return
	if str(scene.get("_pending_choice")) != "effect_interaction":
		hide_field_interaction(scene)
		return
	var stored_assignments: Array[Dictionary] = []
	for entry_variant: Variant in assignment_entries:
		if entry_variant is Dictionary:
			stored_assignments.append((entry_variant as Dictionary).duplicate())
	hide_field_interaction(scene)
	scene.call("_commit_effect_assignment_selection", stored_assignments)


func _get_counter_distribution_assigned_total(scene: Object) -> int:
	var assignment_entries: Array = scene.get("_field_interaction_assignment_entries")
	var total: int = 0
	for entry_variant: Variant in assignment_entries:
		if entry_variant is Dictionary:
			total += int((entry_variant as Dictionary).get("amount", 0)) / 10
	return total


func _build_counter_target_summary(assignment_entries: Array) -> String:
	var target_counts: Dictionary = {}
	for entry_variant: Variant in assignment_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var target: Variant = entry.get("target")
		var amount: int = int(entry.get("amount", 0)) / 10
		if target is PokemonSlot and amount > 0:
			var name: String = (target as PokemonSlot).get_pokemon_name()
			target_counts[name] = int(target_counts.get(name, 0)) + amount
	if target_counts.is_empty():
		return ""
	var parts: Array[String] = []
	for name: String in target_counts.keys():
		parts.append("%s×%d" % [name, int(target_counts[name])])
	return "已分配: " + ", ".join(parts)


func _current_player_index(scene: Object) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.game_state != null:
		return gsm.game_state.current_player_index
	return -1


func _count_assignments_for_target_index(assignment_entries: Array, target_index: int) -> int:
	var count := 0
	for entry_variant: Variant in assignment_entries:
		if not (entry_variant is Dictionary):
			continue
		if int((entry_variant as Dictionary).get("target_index", -1)) == target_index:
			count += 1
	return count


func _turn_number(scene: Object) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.game_state != null:
		return gsm.game_state.turn_number
	return 0


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
