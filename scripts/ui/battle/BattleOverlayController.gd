class_name BattleOverlayController
extends RefCounted

const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func start_prize_selection(scene: Object, player_index: int, count: int) -> void:
	scene.set("_pending_choice", "take_prize")
	scene.set("_pending_prize_player_index", player_index)
	scene.set("_pending_prize_remaining", count)
	scene.set("_pending_prize_animating", false)
	scene.call("_refresh_ui")
	focus_prize_panel(scene, player_index)
	scene.call("_log", _bt(scene, "battle.prize.prompt", {"count": count}))


func clear_prize_selection(scene: Object) -> void:
	if str(scene.get("_pending_choice")) == "take_prize":
		scene.set("_pending_choice", "")
	scene.set("_pending_prize_player_index", -1)
	scene.set("_pending_prize_remaining", 0)
	scene.set("_pending_prize_animating", false)
	refresh_prize_titles(scene)


func refresh_prize_titles(scene: Object) -> void:
	var view_player: int = int(scene.get("_view_player"))
	update_prize_title(scene, scene.get("_opp_prizes_title"), 1 - view_player, _bt(scene, "battle.prize.opponent"), false)
	update_prize_title(scene, scene.get("_my_prizes_title"), view_player, _bt(scene, "battle.prize.self"), false)
	update_prize_title(scene, scene.get("_opp_prize_hud_title"), 1 - view_player, _bt(scene, "battle.prize.opponent"), true)
	update_prize_title(scene, scene.get("_my_prize_hud_title"), view_player, _bt(scene, "battle.prize.self"), true)


func update_prize_title(scene: Object, label: Label, player_index: int, default_text: String, is_hud: bool) -> void:
	if label == null:
		return
	var is_pending := (
		str(scene.get("_pending_choice")) == "take_prize"
		and int(scene.get("_pending_prize_player_index")) == player_index
		and int(scene.get("_pending_prize_remaining")) > 0
	)
	label.text = _bt(scene, "battle.prize.pending_title", {
		"count": int(scene.get("_pending_prize_remaining")),
	}) if is_pending else default_text
	label.add_theme_font_size_override("font_size", 15 if is_hud else 11)
	var normal_color := Color(0.54, 0.9, 0.94, 0.9) if is_hud else Color(0.93, 0.97, 1.0, 0.9)
	var active_color := Color(1.0, 0.87, 0.34, 1.0)
	label.add_theme_color_override("font_color", active_color if is_pending else normal_color)


func focus_prize_panel(scene: Object, player_index: int) -> void:
	var view_player: int = int(scene.get("_view_player"))
	var target_panel: Control = scene.get("_my_hud_left") if player_index == view_player else scene.get("_opp_hud_left")
	if target_panel == null or not (scene as Node).is_inside_tree():
		return
	target_panel.pivot_offset = target_panel.size * 0.5
	target_panel.scale = Vector2.ONE
	var tween := (scene as Node).create_tween()
	tween.tween_property(target_panel, "scale", Vector2(1.05, 1.05), 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func show_opponent_hand_cards(scene: Object) -> void:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return
	var view_player: int = int(scene.get("_view_player"))
	var opponent_index: int = 1 - view_player
	if opponent_index < 0 or opponent_index >= gsm.game_state.players.size():
		return
	var player: PlayerState = gsm.game_state.players[opponent_index]
	var discard_title: Label = scene.get("_discard_title")
	var discard_list: ItemList = scene.get("_discard_list")
	var discard_card_row: HBoxContainer = scene.get("_discard_card_row")
	var discard_overlay: Panel = scene.get("_discard_overlay")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	discard_title.text = _bt(scene, "battle.overlay.opponent_hand", {"count": player.hand.size()})
	discard_list.clear()
	if discard_card_row != null:
		scene.call("_clear_container_children", discard_card_row)
		if player.hand.is_empty():
			var empty_label := Label.new()
			empty_label.text = _bt(scene, "battle.overlay.empty")
			discard_card_row.add_child(empty_label)
		else:
			for hand_card: CardInstance in player.hand:
				var card_view := BattleCardViewScript.new()
				card_view.custom_minimum_size = dialog_card_size
				card_view.set_clickable(true)
				card_view.setup_from_instance(hand_card, BattleCardView.MODE_PREVIEW)
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
		if player.hand.is_empty():
			discard_list.add_item(_bt(scene, "battle.overlay.empty"))
		else:
			for hand_card: CardInstance in player.hand:
				var card_data: CardData = hand_card.card_data
				discard_list.add_item("%s [%s]" % [card_data.name, scene.call("_card_type_cn", card_data)])
	discard_overlay.visible = true
	scene.call("_runtime_log", "show_opponent_hand", "player=%d count=%d" % [opponent_index, player.hand.size()])


func show_handover_prompt(scene: Object, target_player: int, follow_up: Callable = Callable()) -> void:
	if follow_up.is_valid():
		scene.call("_set_pending_handover_action", follow_up, "show_prompt_follow_up")
	elif not (scene.get("_pending_handover_action") as Callable).is_valid():
		scene.call("_set_pending_handover_action", Callable(), "show_prompt_generic")
	else:
		scene.call(
			"_runtime_log",
			"handover_action_preserved",
			"reason=show_prompt_generic target=%d %s" % [target_player, scene.call("_state_snapshot")]
		)
	scene.call("_set_handover_panel_visible", true, "show_prompt_target_%d" % target_player)
	var handover_label: Label = scene.get("_handover_lbl")
	handover_label.text = _bt(scene, "battle.handover.prompt", {"player": target_player + 1})


func check_two_player_handover(scene: Object) -> void:
	var gsm: Variant = scene.get("_gsm")
	if GameManager.current_mode != GameManager.GameMode.TWO_PLAYER:
		scene.call("_set_pending_handover_action", Callable(), "handover_check_non_two_player")
		scene.call("_set_handover_panel_visible", false, "handover_check_non_two_player")
		return
	if gsm == null or gsm.game_state.phase == GameState.GamePhase.GAME_OVER:
		scene.call("_set_pending_handover_action", Callable(), "handover_check_game_over")
		scene.call("_set_handover_panel_visible", false, "handover_check_game_over")
		return
	if (scene.get("_pending_handover_action") as Callable).is_valid():
		scene.call("_runtime_log", "handover_check_deferred", scene.call("_state_snapshot"))
		return
	var current_player: int = gsm.game_state.current_player_index
	if current_player != int(scene.get("_view_player")):
		show_handover_prompt(scene, current_player)
		scene.call("_runtime_log", "handover_required", scene.call("_state_snapshot"))
		return
	scene.call("_set_pending_handover_action", Callable(), "handover_check_aligned")
	scene.call("_set_handover_panel_visible", false, "handover_check_aligned")


func on_handover_confirmed(scene: Object) -> void:
	var pending_handover_action: Callable = scene.get("_pending_handover_action")
	scene.call(
		"_runtime_log",
		"handover_confirm_requested",
		"follow_up_valid=%s %s" % [str(pending_handover_action.is_valid()), scene.call("_state_snapshot")]
	)
	scene.call("_set_handover_panel_visible", false, "handover_confirm")
	scene.call("_set_pending_handover_action", Callable(), "handover_confirm")
	if pending_handover_action.is_valid():
		pending_handover_action.call()
	else:
		var gsm: Variant = scene.get("_gsm")
		var current_player: int = gsm.game_state.current_player_index
		scene.set("_view_player", current_player)
		scene.call("_refresh_ui")
	var draw_reveal_controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	if draw_reveal_controller != null and draw_reveal_controller.has_method("resume_if_ready"):
		draw_reveal_controller.call("resume_if_ready", scene)
	scene.call("_maybe_run_ai")
	scene.call("_runtime_log", "handover_confirmed", scene.call("_state_snapshot"))


func refresh_match_end_dialog_if_visible(scene: Object) -> void:
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	if str(scene.get("_pending_choice")) != "game_over" or dialog_overlay == null or not dialog_overlay.visible:
		return
	scene.call("_show_match_end_dialog", int(scene.get("_battle_review_winner_index")), str(scene.get("_battle_review_reason")))


func open_cached_battle_review(scene: Object) -> void:
	var review: Dictionary = scene.call("_load_cached_battle_review")
	if review.is_empty():
		review = (scene.get("_battle_review_last_review") as Dictionary).duplicate(true)
	if review.is_empty():
		return
	show_battle_review_overlay(scene, review)


func show_battle_review_overlay(scene: Object, review: Dictionary) -> void:
	var review_title: Label = scene.get("_review_title")
	var review_content: RichTextLabel = scene.get("_review_content")
	var review_overlay: Panel = scene.get("_review_overlay")
	var regenerate_button: Button = scene.get("_review_regenerate_btn")
	review_title.text = _bt(scene, "battle.review.title")
	review_content.text = str(scene.call("_format_battle_review", review))
	review_overlay.visible = true
	regenerate_button.disabled = bool(scene.get("_battle_review_busy"))
