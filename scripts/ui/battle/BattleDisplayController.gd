class_name BattleDisplayController
extends RefCounted

const BENCH_SIZE := 5
const USED_ABILITY_TILT_DEGREES := 15.0
const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func refresh_ui(scene: Object) -> void:
	scene.call("_refresh_replay_controls")
	var gsm: Variant = scene.get("_gsm")
	if gsm == null:
		return
	var gs: GameState = gsm.game_state
	var current_player: int = gs.current_player_index
	var view_player: int = int(scene.get("_view_player"))
	var opponent_player: int = 1 - view_player

	var my_player: PlayerState = gs.players[view_player]
	var opponent: PlayerState = gs.players[opponent_player]
	var opponent_visible_discard: Array[CardInstance] = _visible_discard_pile(scene, opponent_player, opponent.discard_pile)
	var my_visible_discard: Array[CardInstance] = _visible_discard_pile(scene, view_player, my_player.discard_pile)
	var phase_label: Label = scene.get("_lbl_phase")
	var turn_label: Label = scene.get("_lbl_turn")
	phase_label.text = _bt(scene, "battle.top.phase_line", {
		"deck": get_selected_deck_name(current_player),
		"count": opponent.hand.size(),
	})
	turn_label.text = _bt(scene, "battle.top.turn_line", {
		"turn": gs.turn_number,
		"player": current_player + 1,
	})

	var opponent_hand_button: Button = scene.get("_btn_opponent_hand")
	if opponent_hand_button != null:
		opponent_hand_button.visible = (not bool(scene.call("_is_review_mode"))) and GameManager.current_mode == GameManager.GameMode.VS_AI
	var ai_advice_button: Button = scene.get("_btn_ai_advice")
	if ai_advice_button != null:
		ai_advice_button.visible = (not bool(scene.call("_is_review_mode"))) and GameManager.current_mode == GameManager.GameMode.TWO_PLAYER
		ai_advice_button.disabled = bool(scene.get("_battle_advice_busy"))
	var zeus_help_button: Button = scene.get("_btn_zeus_help")
	if zeus_help_button != null:
		zeus_help_button.visible = not bool(scene.call("_is_review_mode"))

	var opp_prizes: Label = scene.get("_opp_prizes")
	var opp_deck: Label = scene.get("_opp_deck")
	var opp_discard: Label = scene.get("_opp_discard")
	var opp_hand_label: Label = scene.get("_opp_hand_lbl")
	var opp_hand_bar: PanelContainer = scene.get("_opp_hand_bar")
	var opp_prize_hud_count: Label = scene.get("_opp_prize_hud_count")
	var opp_deck_hud_value: Label = scene.get("_opp_deck_hud_value")
	var opp_discard_hud_value: Label = scene.get("_opp_discard_hud_value")
	opp_prizes.text = "x%d" % opponent.prizes.size()
	opp_deck.text = "%d" % opponent.deck.size()
	opp_discard.text = "%d" % opponent_visible_discard.size()
	opp_hand_label.text = _bt(scene, "battle.top.opponent_hand_count", {"count": opponent.hand.size()})
	opp_hand_bar.visible = false
	opp_prize_hud_count.text = "x%d" % opponent.prizes.size()
	opp_deck_hud_value.text = _bt(scene, "battle.top.card_count", {"count": opponent.deck.size()})
	opp_discard_hud_value.text = _bt(scene, "battle.top.card_count", {"count": opponent_visible_discard.size()})

	var my_prizes: Label = scene.get("_my_prizes")
	var my_deck: Label = scene.get("_my_deck")
	var my_discard: Label = scene.get("_my_discard")
	var my_prize_hud_count: Label = scene.get("_my_prize_hud_count")
	var my_deck_hud_value: Label = scene.get("_my_deck_hud_value")
	var my_discard_hud_value: Label = scene.get("_my_discard_hud_value")
	my_prizes.text = "x%d" % my_player.prizes.size()
	my_deck.text = "%d" % my_player.deck.size()
	my_discard.text = "%d" % my_visible_discard.size()
	my_prize_hud_count.text = "x%d" % my_player.prizes.size()
	my_deck_hud_value.text = _bt(scene, "battle.top.card_count", {"count": my_player.deck.size()})
	my_discard_hud_value.text = _bt(scene, "battle.top.card_count", {"count": my_visible_discard.size()})

	scene.call("_refresh_prize_titles")
	update_side_previews(scene, opponent, my_player)
	scene.call("_refresh_deck_shuffle_detection", gs)
	refresh_field_card_views(scene, gs)

	var is_my_turn: bool = (not bool(scene.call("_is_review_mode"))) and current_player == view_player and gs.phase == GameState.GamePhase.MAIN
	var end_turn_button: Button = scene.get("_btn_end_turn")
	var hud_end_turn_button: Button = scene.get("_hud_end_turn_btn")
	end_turn_button.disabled = not is_my_turn
	hud_end_turn_button.disabled = end_turn_button.disabled
	refresh_stadium_area(scene, gs, current_player, is_my_turn)
	refresh_info_hud(scene, gs, view_player, opponent_player)

	refresh_hand(scene)
	if bool(scene.call("_is_field_interaction_active")):
		scene.call("_refresh_field_interaction_status")
	scene.call("_refresh_battle_advice_panel")
	scene.call("_runtime_log_ui_state_if_changed")


func get_selected_deck_name(player_index: int) -> String:
	if player_index < 0 or player_index >= GameManager.selected_deck_ids.size():
		return BattleI18n.t("battle.deck.unknown")
	var deck_id: int = GameManager.selected_deck_ids[player_index]
	var deck_data: DeckData = CardDatabase.get_deck(deck_id)
	if deck_data != null and deck_data.deck_name != "":
		return deck_data.deck_name
	return BattleI18n.t("battle.player.default", {"index": player_index + 1})


func update_side_previews(scene: Object, opp: PlayerState, my_player: PlayerState) -> void:
	var view_player: int = int(scene.get("_view_player"))
	update_prize_slots(
		scene,
		scene.get("_opp_prize_slots"),
		opp.get_prize_layout(),
		str(scene.get("_pending_choice")) == "take_prize"
			and int(scene.get("_pending_prize_player_index")) == (1 - int(scene.get("_view_player")))
			and not bool(scene.get("_pending_prize_animating"))
	)
	update_prize_slots(
		scene,
		scene.get("_my_prize_slots"),
		my_player.get_prize_layout(),
		str(scene.get("_pending_choice")) == "take_prize"
			and int(scene.get("_pending_prize_player_index")) == int(scene.get("_view_player"))
			and not bool(scene.get("_pending_prize_animating"))
	)
	update_pile_preview(scene.get("_opp_deck_preview"), null, not opp.deck.is_empty())
	update_pile_preview(scene.get("_my_deck_preview"), null, not my_player.deck.is_empty())
	var visible_opp_discard: Array[CardInstance] = _visible_discard_pile(scene, 1 - view_player, opp.discard_pile)
	var visible_my_discard: Array[CardInstance] = _visible_discard_pile(scene, view_player, my_player.discard_pile)
	update_pile_preview(scene.get("_opp_discard_preview"), visible_opp_discard.back() if not visible_opp_discard.is_empty() else null, false)
	update_pile_preview(scene.get("_my_discard_preview"), visible_my_discard.back() if not visible_my_discard.is_empty() else null, false)

	# 根据当前视角交换上下区域的卡背纹理
	var my_back: Texture2D
	var opp_back: Texture2D
	if view_player == 0:
		my_back = scene.get("_player_card_back_texture")
		opp_back = scene.get("_opponent_card_back_texture")
	else:
		my_back = scene.get("_opponent_card_back_texture")
		opp_back = scene.get("_player_card_back_texture")
	_apply_back_textures(scene.get("_opp_prize_slots"), opp_back)
	_apply_back_textures(scene.get("_my_prize_slots"), my_back)
	var opp_deck_pv: BattleCardView = scene.get("_opp_deck_preview")
	var my_deck_pv: BattleCardView = scene.get("_my_deck_preview")
	if opp_deck_pv != null:
		opp_deck_pv.set_back_texture(opp_back)
	if my_deck_pv != null:
		my_deck_pv.set_back_texture(my_back)


func _apply_back_textures(slots: Array[BattleCardView], texture: Texture2D) -> void:
	for slot in slots:
		slot.set_back_texture(texture)


func refresh_stadium_area(scene: Object, gs: GameState, current_player: int, is_my_turn: bool) -> void:
	var stadium_label: Label = scene.get("_stadium_lbl")
	var stadium_action_button: Button = scene.get("_btn_stadium_action")
	if gs.stadium_card == null:
		stadium_label.visible = true
		stadium_label.text = _bt(scene, "battle.stadium.none")
		stadium_action_button.visible = false
		stadium_action_button.disabled = true
		return

	var stadium_name: String = gs.stadium_card.card_data.name
	var gsm: Variant = scene.get("_gsm")
	var effect: BaseEffect = gsm.effect_processor.get_effect(gs.stadium_card.card_data.effect_id)
	var is_action_stadium: bool = effect != null and effect.can_use_as_stadium_action(gs.stadium_card, gs)
	if is_action_stadium:
		stadium_label.visible = false
		stadium_action_button.visible = true
		stadium_action_button.text = _bt(scene, "battle.stadium.action_button", {"name": stadium_name})
		stadium_action_button.disabled = not (is_my_turn and gsm.can_use_stadium_effect(current_player))
		return

	stadium_label.visible = true
	stadium_label.text = _bt(scene, "battle.stadium.label", {"name": stadium_name})
	stadium_action_button.visible = false
	stadium_action_button.disabled = true


func refresh_info_hud(scene: Object, gs: GameState, view_player: int, opponent_player: int) -> void:
	var my_player: PlayerState = gs.players[view_player]
	var opponent: PlayerState = gs.players[opponent_player]
	apply_info_metric(
		scene.get("_enemy_vstar_value"),
		gs.vstar_power_used[opponent_player],
		_bt(scene, "battle.info.enemy_vstar_ready"),
		_bt(scene, "battle.info.enemy_vstar_used")
	)
	apply_info_metric(
		scene.get("_my_vstar_value"),
		gs.vstar_power_used[view_player],
		_bt(scene, "battle.info.self_vstar_ready"),
		_bt(scene, "battle.info.self_vstar_used")
	)
	var enemy_lost_value: Label = scene.get("_enemy_lost_value")
	var my_lost_value: Label = scene.get("_my_lost_value")
	if enemy_lost_value != null:
		enemy_lost_value.text = _bt(scene, "battle.info.enemy_lost_zone", {"count": opponent.lost_zone.size()})
	if my_lost_value != null:
		my_lost_value.text = _bt(scene, "battle.info.self_lost_zone", {"count": my_player.lost_zone.size()})



func apply_info_metric(label: Label, is_used: bool, ready_text: String, used_text: String) -> void:
	if label == null:
		return
	label.text = used_text if is_used else ready_text
	label.add_theme_color_override("font_color", Color(0.98, 0.43, 0.43) if is_used else Color(0.41, 1.0, 0.75))


func update_prize_slots(scene: Object, slots: Array, prize_layout: Array, is_selectable: bool) -> void:
	for i: int in slots.size():
		var prize_view: BattleCardView = slots[i]
		if prize_view == null:
			continue
		var prize_card: CardInstance = null
		if i < prize_layout.size() and prize_layout[i] is CardInstance:
			prize_card = prize_layout[i] as CardInstance
		var filled := prize_card != null
		prize_view.visible = true
		if filled:
			prize_view.setup_from_instance(prize_card, BattleCardView.MODE_PREVIEW)
			prize_view.set_face_down(true)
		else:
			prize_view.setup_from_instance(null, BattleCardView.MODE_PREVIEW)
			prize_view.set_face_down(true)
		prize_view.set_selected(filled and is_selectable)
		prize_view.set_disabled(not filled or (str(scene.get("_pending_choice")) == "take_prize" and not is_selectable))
		prize_view.self_modulate = Color(1, 1, 1, 1) if filled else Color(1, 1, 1, 0.02)


func update_pile_preview(preview: BattleCardView, card: CardInstance, face_down: bool) -> void:
	if preview == null:
		return
	if card != null:
		preview.setup_from_instance(card, BattleCardView.MODE_PREVIEW)
		preview.set_face_down(false)
	else:
		preview.setup_from_instance(null, BattleCardView.MODE_PREVIEW)
		preview.set_face_down(face_down)
	preview.set_selected(false)
	preview.set_disabled(false)
	preview.set_badges("", "")
	preview.set_info("", "")


func _visible_discard_pile(scene: Object, player_index: int, actual_discard: Array[CardInstance]) -> Array[CardInstance]:
	var current_reveal: GameAction = scene.get("_draw_reveal_current_action") as GameAction
	if current_reveal == null:
		return actual_discard
	if current_reveal.action_type != GameAction.ActionType.DISCARD:
		return actual_discard
	if str(current_reveal.data.get("source_zone", "")) != "hand":
		return actual_discard
	if current_reveal.player_index != player_index:
		return actual_discard
	var reveal_ids: Dictionary = {}
	for id_variant: Variant in current_reveal.data.get("card_instance_ids", []):
		reveal_ids[int(id_variant)] = true
	var visible_ids: Dictionary = {}
	for id_variant: Variant in scene.get("_draw_reveal_visible_instance_ids"):
		visible_ids[int(id_variant)] = true
	var visible_discard: Array[CardInstance] = []
	for discard_card: CardInstance in actual_discard:
		if discard_card == null:
			continue
		if reveal_ids.has(discard_card.instance_id) and not visible_ids.has(discard_card.instance_id):
			continue
		visible_discard.append(discard_card)
	return visible_discard


func refresh_field_card_views(scene: Object, gs: GameState) -> void:
	var view_player: int = int(scene.get("_view_player"))
	var opponent_player: int = 1 - view_player
	refresh_slot_card_view(scene, "my_active", gs.players[view_player].active_pokemon, true)
	refresh_slot_card_view(scene, "opp_active", gs.players[opponent_player].active_pokemon, true)

	for i: int in BENCH_SIZE:
		var my_bench_slot: PokemonSlot = gs.players[view_player].bench[i] if i < gs.players[view_player].bench.size() else null
		var opp_bench_slot: PokemonSlot = gs.players[opponent_player].bench[i] if i < gs.players[opponent_player].bench.size() else null
		refresh_slot_card_view(scene, "my_bench_%d" % i, my_bench_slot, false)
		refresh_slot_card_view(scene, "opp_bench_%d" % i, opp_bench_slot, false)


func refresh_slot_card_view(scene: Object, slot_id: String, slot: PokemonSlot, is_active: bool) -> void:
	var slot_card_views: Dictionary = scene.get("_slot_card_views")
	var card_view: BattleCardView = slot_card_views.get(slot_id)
	if card_view == null:
		return
	var slot_panel := card_view.get_parent() as PanelContainer
	var field_slot_index_map: Dictionary = scene.get("_field_interaction_slot_index_by_id")
	var is_selectable := field_slot_index_map.has(slot_id)
	var selected_slot_ids: Array[String] = scene.call("_field_interaction_selected_slot_ids")
	var is_selected := slot_id in selected_slot_ids
	var should_disable := bool(scene.call("_is_field_interaction_active")) and not is_selectable

	if slot == null or slot.pokemon_stack.is_empty():
		card_view.setup_from_instance(null, BattleCardView.MODE_SLOT_ACTIVE if is_active else BattleCardView.MODE_SLOT_BENCH)
		card_view.set_badges()
		card_view.clear_battle_status()
		card_view.set_info("", "")
		card_view.set_tilt_degrees(0.0)
		card_view.set_disabled(false)
		card_view.set_selected(false)
		apply_field_slot_style(scene, slot_panel, slot_id, false, is_active)
		return

	var top_card: CardInstance = slot.get_top_card()
	card_view.setup_from_instance(top_card, BattleCardView.MODE_SLOT_ACTIVE if is_active else BattleCardView.MODE_SLOT_BENCH)
	card_view.set_disabled(should_disable)
	card_view.set_selected(is_selected or is_selectable)
	card_view.set_badges()
	card_view.set_battle_status(build_battle_status(scene, slot))
	card_view.set_tilt_degrees(USED_ABILITY_TILT_DEGREES if slot_used_ability_this_turn(scene, slot) else 0.0)
	apply_field_slot_style(scene, slot_panel, slot_id, true, is_active)


func apply_field_slot_style(scene: Object, panel: PanelContainer, slot_id: String, occupied: bool, is_active: bool) -> void:
	if panel == null:
		return
	var is_player_slot := slot_id.begins_with("my_")
	var field_slot_index_map: Dictionary = scene.get("_field_interaction_slot_index_by_id")
	var is_selectable := field_slot_index_map.has(slot_id)
	var is_selected := slot_id in (scene.call("_field_interaction_selected_slot_ids") as Array[String])
	var border_color := Color(0.52, 0.72, 0.58) if is_player_slot else Color(0.63, 0.68, 0.79)
	if not is_active:
		border_color = Color(0.32, 0.5, 0.44) if is_player_slot else Color(0.33, 0.39, 0.5)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(18 if is_active else 16)
	style.set_border_width_all(2)
	if occupied:
		if is_selected:
			style.bg_color = Color(0.95, 0.75, 0.14, 0.12)
			style.border_color = Color(0.98, 0.82, 0.22, 0.98)
			style.set_border_width_all(3)
		elif is_selectable:
			style.bg_color = Color(0.14, 0.72, 0.84, 0.10)
			style.border_color = Color(0.38, 0.88, 0.98, 0.94)
		else:
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0, 0, 0, 0)
	else:
		style.bg_color = Color(0.04, 0.07, 0.1, 0.18)
		style.border_color = Color(border_color.r, border_color.g, border_color.b, 0.65)
	panel.add_theme_stylebox_override("panel", style)


func slot_overlay_text(scene: Object, slot: PokemonSlot) -> String:
	var parts: Array[String] = []
	parts.append("%d/%d" % [get_display_remaining_hp(scene, slot), get_display_max_hp(scene, slot)])
	var energy_summary := slot_energy_summary(scene, slot)
	if energy_summary != "":
		parts.append(energy_summary)
	if slot.attached_tool != null:
		parts.append(slot.attached_tool.card_data.name)
	return " | ".join(parts)


func build_battle_status(scene: Object, slot: PokemonSlot) -> Dictionary:
	var hp_current := get_display_remaining_hp(scene, slot)
	var hp_max := maxi(get_display_max_hp(scene, slot), 1)
	return {
		"hp_current": hp_current,
		"hp_max": hp_max,
		"hp_ratio": float(hp_current) / float(hp_max),
		"energy_icons": slot_energy_icon_codes(scene, slot),
		"tool_name": slot.attached_tool.card_data.name if slot.attached_tool != null else "",
		"ability_used_this_turn": slot_used_ability_this_turn(scene, slot),
	}


func slot_used_ability_this_turn(scene: Object, slot: PokemonSlot) -> bool:
	var gsm: Variant = scene.get("_gsm")
	if slot == null or gsm == null or gsm.game_state == null:
		return false
	var current_turn: int = gsm.game_state.turn_number
	for effect_data: Dictionary in slot.effects:
		if int(effect_data.get("turn", -999)) != current_turn:
			continue
		var effect_type: String = str(effect_data.get("type", ""))
		if effect_type.contains("ability"):
			return true
	return false


func get_display_max_hp(scene: Object, slot: PokemonSlot) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.effect_processor != null and gsm.game_state != null:
		return gsm.effect_processor.get_effective_max_hp(slot, gsm.game_state)
	return slot.get_max_hp()


func get_display_remaining_hp(scene: Object, slot: PokemonSlot) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.effect_processor != null and gsm.game_state != null:
		return gsm.effect_processor.get_effective_remaining_hp(slot, gsm.game_state)
	return slot.get_remaining_hp()


func battle_card_mode_for_slot(scene: Object, slot: PokemonSlot) -> String:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return BattleCardView.MODE_SLOT_BENCH
	for player: PlayerState in gsm.game_state.players:
		if player.active_pokemon == slot:
			return BattleCardView.MODE_SLOT_ACTIVE
	return BattleCardView.MODE_SLOT_BENCH


func slot_energy_icon_codes(scene: Object, slot: PokemonSlot) -> Array[String]:
	var codes: Array[String] = []
	for energy: CardInstance in slot.attached_energy:
		var energy_type := "C"
		var provided_count := 1
		if energy != null and energy.card_data != null:
			var gsm: Variant = scene.get("_gsm")
			if gsm != null and gsm.effect_processor != null:
				energy_type = gsm.effect_processor.get_energy_type(energy)
				provided_count = gsm.effect_processor.get_energy_colorless_count(energy)
			else:
				energy_type = energy.card_data.energy_provides if energy.card_data.energy_provides != "" else energy.card_data.energy_type
		if energy_type == "":
			energy_type = "C"
		for _unit: int in maxi(provided_count, 1):
			codes.append(energy_type)
	return codes


func slot_energy_summary(scene: Object, slot: PokemonSlot) -> String:
	if slot.attached_energy.is_empty():
		return ""

	var energy_map := {
		"R": "火",
		"W": "水",
		"G": "草",
		"L": "雷",
		"P": "超",
		"F": "斗",
		"D": "恶",
		"M": "钢",
		"N": "龙",
		"C": "无",
	}
	var counts: Dictionary = {}
	for energy: CardInstance in slot.attached_energy:
		var energy_type := "C"
		var provided_count := 1
		if energy != null and energy.card_data != null:
			var gsm: Variant = scene.get("_gsm")
			if gsm != null and gsm.effect_processor != null:
				energy_type = gsm.effect_processor.get_energy_type(energy)
				provided_count = gsm.effect_processor.get_energy_colorless_count(energy)
			else:
				energy_type = energy.card_data.energy_provides if energy.card_data.energy_provides != "" else energy.card_data.energy_type
			if energy_type == "":
				energy_type = "C"
		counts[energy_type] = int(counts.get(energy_type, 0)) + provided_count

	var ordered_types := ["R", "W", "G", "L", "P", "F", "D", "M", "N", "C"]
	var parts: Array[String] = []
	for energy_type: String in ordered_types:
		if counts.has(energy_type):
			parts.append("%s x%d" % [energy_map.get(energy_type, energy_type), counts[energy_type]])
	for key: Variant in counts.keys():
		var extra_type := str(key)
		if extra_type in ordered_types:
			continue
		parts.append("%s x%d" % [energy_map.get(extra_type, extra_type), counts[extra_type]])
	return " ".join(parts)


func refresh_slot_label(scene: Object, label: RichTextLabel, slot: PokemonSlot) -> void:
	if slot == null or slot.pokemon_stack.is_empty():
		label.text = "[空]"
		return
	var card_data := slot.get_card_data()
	var energy_map := {
		"R": "火",
		"W": "水",
		"G": "草",
		"L": "雷",
		"P": "超",
		"F": "斗",
		"D": "恶",
		"M": "钢",
		"N": "龙",
		"C": "无",
	}
	var energy_counts: Dictionary = {}
	for energy: CardInstance in slot.attached_energy:
		var energy_type := "C"
		var provided_count := 1
		var gsm: Variant = scene.get("_gsm")
		if gsm != null and gsm.effect_processor != null:
			energy_type = gsm.effect_processor.get_energy_type(energy)
			provided_count = gsm.effect_processor.get_energy_colorless_count(energy)
		elif energy.card_data.energy_provides != "":
			energy_type = energy.card_data.energy_provides
		energy_counts[energy_type] = int(energy_counts.get(energy_type, 0)) + provided_count

	var energy_parts: Array[String] = []
	for key: String in energy_counts:
		energy_parts.append("%s x%d" % [energy_map.get(key, key), energy_counts[key]])
	var energy_text := ", ".join(energy_parts) if not energy_parts.is_empty() else "无"

	var status_parts: Array[String] = []
	var status_names := {
		"poisoned": "中毒",
		"burned": "灼伤",
		"asleep": "睡眠",
		"paralyzed": "麻痹",
		"confused": "混乱",
	}
	for status_key: String in status_names:
		if slot.status_conditions.get(status_key, false):
			status_parts.append(status_names[status_key])

	label.text = "[b]%s[/b]  HP:%d/%d\n能量：%s%s" % [
		card_data.name,
		slot.get_remaining_hp(),
		slot.get_max_hp(),
		energy_text,
		("  [" + ", ".join(status_parts) + "]") if not status_parts.is_empty() else "",
	]


func refresh_bench(container: HBoxContainer, bench: Array[PokemonSlot]) -> void:
	var children := container.get_children()
	for i: int in children.size():
		var slot_panel: Node = children[i]
		var label: RichTextLabel = null
		for child: Node in slot_panel.get_children():
			if child is RichTextLabel:
				label = child as RichTextLabel
				break
		if label == null:
			continue
		if i < bench.size():
			var slot: PokemonSlot = bench[i]
			label.text = "[b]%s[/b]\nHP:%d/%d" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()]
		else:
			label.text = "[空]"


func refresh_hand(scene: Object) -> void:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null:
		return
	if bool(scene.get("_draw_reveal_active")) and not bool(scene.get("_draw_reveal_allow_hand_refresh_during_fly")):
		scene.set("_draw_reveal_pending_hand_refresh", true)
		return
	var hand_container: HBoxContainer = scene.get("_hand_container")
	clear_container_children(hand_container)

	var gs: GameState = gsm.game_state
	var current_player: int = gs.current_player_index
	var view_player: int = int(scene.get("_view_player"))
	if gs.phase == GameState.GamePhase.SETUP:
		for card_inst: CardInstance in gs.players[view_player].hand:
			hand_container.add_child(build_hand_card(scene, card_inst))
		return
	if current_player != view_player:
		var waiting_label := Label.new()
		waiting_label.text = _bt(scene, "battle.hand.waiting")
		hand_container.add_child(waiting_label)
		return
	var current_reveal: GameAction = scene.get("_draw_reveal_current_action") as GameAction
	var hidden_reveal_lookup: Dictionary = {}
	var visible_reveal_lookup: Dictionary = {}
	if bool(scene.get("_draw_reveal_active")) and current_reveal != null and current_reveal.player_index == view_player:
		for id_variant: Variant in current_reveal.data.get("card_instance_ids", []):
			hidden_reveal_lookup[int(id_variant)] = true
		for id_variant: Variant in scene.get("_draw_reveal_visible_instance_ids"):
			visible_reveal_lookup[int(id_variant)] = true
	var queued_reveals: Array = scene.get("_draw_reveal_queue")
	for queued_variant: Variant in queued_reveals:
		var queued_action: GameAction = queued_variant as GameAction
		if queued_action == null:
			continue
		if queued_action.action_type != GameAction.ActionType.DRAW_CARD:
			continue
		if queued_action.player_index != view_player:
			continue
		for id_variant: Variant in queued_action.data.get("card_instance_ids", []):
			hidden_reveal_lookup[int(id_variant)] = true
	for card_inst: CardInstance in gs.players[view_player].hand:
		if hidden_reveal_lookup.has(card_inst.instance_id) and not visible_reveal_lookup.has(card_inst.instance_id):
			continue
		hand_container.add_child(build_hand_card(scene, card_inst))


func clear_container_children(container: Node) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func build_hand_card(scene: Object, inst: CardInstance) -> PanelContainer:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = scene.get("_play_card_size")
	card_view.setup_from_instance(inst, BattleCardView.MODE_HAND)
	card_view.set_selected(scene.get("_selected_hand_card") == inst)
	card_view.set_info(inst.card_data.name, hand_card_subtext(inst.card_data))
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		scene.call("_on_hand_card_clicked", inst, card_view)
	)
	card_view.right_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		scene.call("_show_card_detail", inst.card_data)
	)
	return card_view


func hand_card_subtext(card_data: CardData) -> String:
	var energy_map := {
		"R": "火",
		"W": "水",
		"G": "草",
		"L": "雷",
		"P": "超",
		"F": "斗",
		"D": "恶",
		"M": "钢",
		"N": "龙",
		"C": "无",
	}
	match card_data.card_type:
		"Pokemon":
			return "%s / %s / HP%d" % [card_data.stage, energy_map.get(card_data.energy_type, "?"), card_data.hp]
		"Item":
			return "物品"
		"Supporter":
			return "支援者"
		"Tool":
			return "宝可梦道具"
		"Stadium":
			return "竞技场"
		"Basic Energy":
			return "基本能量 / %s" % energy_map.get(card_data.energy_provides, "")
		"Special Energy":
			return "特殊能量"
		_:
			return card_data.card_type


func slot_from_id(scene: Object, slot_id: String, gs: GameState) -> PokemonSlot:
	var view_player: int = int(scene.get("_view_player"))
	var opponent_player: int = 1 - view_player
	if slot_id == "my_active":
		return gs.players[view_player].active_pokemon
	if slot_id == "opp_active":
		return gs.players[opponent_player].active_pokemon
	if slot_id.begins_with("my_bench_"):
		var my_index: int = int(slot_id.split("_")[-1])
		var my_bench: Array[PokemonSlot] = gs.players[view_player].bench
		return my_bench[my_index] if my_index < my_bench.size() else null
	if slot_id.begins_with("opp_bench_"):
		var opp_index: int = int(slot_id.split("_")[-1])
		var opp_bench: Array[PokemonSlot] = gs.players[opponent_player].bench
		return opp_bench[opp_index] if opp_index < opp_bench.size() else null
	return null


func show_discard_pile(scene: Object, player_index: int, title: String) -> void:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null:
		return
	var player: PlayerState = gsm.game_state.players[player_index]
	_show_card_collection(scene, title, player.discard_pile, true, "show_discard", player_index)


func show_prize_cards(scene: Object, player_index: int, title: String) -> void:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null:
		return
	var player: PlayerState = gsm.game_state.players[player_index]
	_show_card_collection(scene, title, player.prizes, false, "show_prizes", player_index)


func show_deck_cards(scene: Object, player_index: int, title: String) -> void:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null:
		return
	var player: PlayerState = gsm.game_state.players[player_index]
	_show_card_collection(scene, title, player.deck, false, "show_deck", player_index)


func _show_card_collection(
	scene: Object,
	title: String,
	cards: Array,
	reverse_order: bool,
	event_name: String,
	player_index: int
) -> void:
	var discard_title: Label = scene.get("_discard_title")
	var discard_list: ItemList = scene.get("_discard_list")
	var discard_card_row: HBoxContainer = scene.get("_discard_card_row")
	var discard_overlay: Panel = scene.get("_discard_overlay")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	discard_title.text = _bt(scene, "battle.zone.count_title", {"title": title, "count": cards.size()})
	discard_list.clear()
	if discard_card_row != null:
		clear_container_children(discard_card_row)
		if cards.is_empty():
			var empty_label := Label.new()
			empty_label.text = _bt(scene, "battle.zone.empty")
			discard_card_row.add_child(empty_label)
		else:
			for card_variant: Variant in _ordered_cards(cards, reverse_order):
				var card: CardInstance = card_variant as CardInstance
				var card_view := BattleCardViewScript.new()
				card_view.custom_minimum_size = dialog_card_size
				card_view.set_clickable(true)
				card_view.setup_from_instance(card, BattleCardView.MODE_PREVIEW)
				card_view.set_badges("", "")
				card_view.set_info("", "")
				card_view.left_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						scene.call("_show_card_detail", cd)
				)
				card_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						scene.call("_show_card_detail", cd)
				)
				discard_card_row.add_child(card_view)
	else:
		if cards.is_empty():
			discard_list.add_item(_bt(scene, "battle.zone.empty"))
		else:
			for card_variant: Variant in _ordered_cards(cards, reverse_order):
				var listed_card: CardInstance = card_variant as CardInstance
				var card_data: CardData = listed_card.card_data
				discard_list.add_item("%s [%s]" % [card_data.name, scene.call("_card_type_cn", card_data)])
	discard_overlay.visible = true
	scene.call("_runtime_log", event_name, "player=%d title=%s count=%d" % [player_index, title, cards.size()])


func _ordered_cards(cards: Array, reverse_order: bool) -> Array:
	if not reverse_order:
		return cards
	var ordered: Array = []
	var index := cards.size() - 1
	while index >= 0:
		ordered.append(cards[index])
		index -= 1
	return ordered
