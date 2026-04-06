class_name BattleAdviceController
extends RefCounted

const BattleAdviceServiceScript := preload("res://scripts/engine/BattleAdviceService.gd")
const BattleReviewServiceScript := preload("res://scripts/engine/BattleReviewService.gd")


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func ensure_battle_review_service(scene: Object) -> void:
	if scene.get("_battle_review_service") != null:
		return
	var battle_review_service: RefCounted = BattleReviewServiceScript.new()
	scene.set("_battle_review_service", battle_review_service)
	if battle_review_service == null:
		return
	var battle_review_store: RefCounted = scene.get("_battle_review_store")
	if battle_review_service.has_method("configure_dependencies"):
		battle_review_service.call("configure_dependencies", null, null, battle_review_store, null)
	if battle_review_service.has_signal("status_changed") and not battle_review_service.status_changed.is_connected(Callable(scene, "_on_battle_review_status_changed")):
		battle_review_service.status_changed.connect(Callable(scene, "_on_battle_review_status_changed"))
	if battle_review_service.has_signal("review_completed") and not battle_review_service.review_completed.is_connected(Callable(scene, "_on_battle_review_completed")):
		battle_review_service.review_completed.connect(Callable(scene, "_on_battle_review_completed"))


func begin_battle_review_generation(scene: Object) -> void:
	var match_dir := str(scene.get("_battle_review_match_dir"))
	if match_dir.strip_edges() == "":
		scene.set("_battle_review_last_review", {
			"status": "failed",
			"errors": [{"message": "match_dir unavailable"}],
		})
		scene.call("_show_match_end_dialog", int(scene.get("_battle_review_winner_index")), str(scene.get("_battle_review_reason")))
		return
	ensure_battle_review_service(scene)
	var battle_review_service: RefCounted = scene.get("_battle_review_service")
	if battle_review_service == null:
		return
	scene.set("_battle_review_busy", true)
	scene.set("_battle_review_progress_text", "正在筛选关键回合...")
	scene.call("_show_match_end_dialog", int(scene.get("_battle_review_winner_index")), str(scene.get("_battle_review_reason")))
	battle_review_service.call("generate_review", scene, match_dir, GameManager.get_battle_review_api_config())


func on_battle_review_status_changed(scene: Object, status: String, context: Dictionary) -> void:
	match status:
		"selecting_turns":
			scene.set("_battle_review_busy", true)
			scene.set("_battle_review_progress_text", "正在筛选关键回合...")
		"analyzing_turn":
			scene.set("_battle_review_busy", true)
			var current_turn: int = int(context.get("turn_index", 0)) + 1
			var total: int = int(context.get("total", 0))
			scene.set("_battle_review_progress_text", "正在分析关键回合 %d / %d..." % [current_turn, total])
		"writing_review":
			scene.set("_battle_review_busy", true)
			scene.set("_battle_review_progress_text", "正在写入 AI 复盘...")
		"completed", "failed":
			scene.set("_battle_review_busy", false)
			scene.set("_battle_review_progress_text", "")
	scene.call("_refresh_match_end_dialog_if_visible")


func on_battle_review_completed(scene: Object, review: Dictionary) -> void:
	scene.set("_battle_review_last_review", review.duplicate(true))
	scene.set("_battle_review_busy", false)
	scene.set("_battle_review_progress_text", "")
	scene.call("_refresh_match_end_dialog_if_visible")


func format_battle_review(scene: Object, review: Dictionary) -> String:
	var formatter: RefCounted = scene.get("_battle_review_formatter")
	return str(formatter.call("format_review", review))


func on_review_regenerate_pressed(scene: Object) -> void:
	if str(scene.get("_review_overlay_mode")) == "advice":
		scene.call("_on_ai_advice_pressed")
		return
	begin_battle_review_generation(scene)


func setup_battle_advice_ui(scene: Object) -> void:
	var review_regenerate_btn: Button = scene.get("_review_regenerate_btn")
	var review_pin_btn: Button = scene.get("_review_pin_btn")
	var review_buttons := review_regenerate_btn.get_parent() as HBoxContainer
	if review_buttons != null and review_pin_btn == null:
		review_pin_btn = Button.new()
		review_pin_btn.name = "ReviewPinBtn"
		review_pin_btn.text = _bt(scene, "battle.review.pin")
		review_buttons.add_child(review_pin_btn)
		review_buttons.move_child(review_pin_btn, review_buttons.get_child_count() - 1)
		review_pin_btn.pressed.connect(Callable(scene, "_on_review_pin_pressed"))
		scene.call("_style_hud_button", review_pin_btn)
		review_pin_btn.visible = false
		scene.set("_review_pin_btn", review_pin_btn)

	if scene.get("_battle_advice_panel") != null:
		return
	var log_panel := (scene as Node).get_node_or_null("MainArea/LogPanel") as VBoxContainer
	if log_panel == null:
		return

	var battle_advice_panel := PanelContainer.new()
	battle_advice_panel.name = "AdvicePanel"
	battle_advice_panel.visible = false
	battle_advice_panel.size_flags_vertical = Control.SIZE_FILL
	scene.call("_style_panel", battle_advice_panel, Color(0.02, 0.08, 0.12, 0.86), Color(0.18, 0.62, 0.78, 0.9), 12)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	battle_advice_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var battle_advice_panel_title := Label.new()
	battle_advice_panel_title.text = _bt(scene, "battle.top.ai_advice")
	battle_advice_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(battle_advice_panel_title)

	var battle_advice_panel_toggle_btn := Button.new()
	battle_advice_panel_toggle_btn.text = _bt(scene, "battle.advice.toggle_collapse")
	battle_advice_panel_toggle_btn.pressed.connect(Callable(scene, "_on_battle_advice_panel_toggle_pressed"))
	scene.call("_style_hud_button", battle_advice_panel_toggle_btn)
	header.add_child(battle_advice_panel_toggle_btn)

	var battle_advice_panel_content := RichTextLabel.new()
	battle_advice_panel_content.bbcode_enabled = true
	battle_advice_panel_content.fit_content = false
	battle_advice_panel_content.scroll_active = true
	battle_advice_panel_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(battle_advice_panel_content)

	log_panel.add_child(battle_advice_panel)
	log_panel.move_child(battle_advice_panel, 1)
	scene.set("_battle_advice_panel", battle_advice_panel)
	scene.set("_battle_advice_panel_title", battle_advice_panel_title)
	scene.set("_battle_advice_panel_toggle_btn", battle_advice_panel_toggle_btn)
	scene.set("_battle_advice_panel_content", battle_advice_panel_content)


func should_offer_battle_advice(_scene: Object) -> bool:
	return GameManager.current_mode == GameManager.GameMode.TWO_PLAYER


func current_battle_advice_match_dir(scene: Object) -> String:
	var review_match_dir := str(scene.get("_battle_review_match_dir"))
	if review_match_dir.strip_edges() != "":
		return review_match_dir
	var battle_recorder: RefCounted = scene.get("_battle_recorder")
	if battle_recorder != null and battle_recorder.has_method("get_match_dir"):
		return str(battle_recorder.call("get_match_dir"))
	return ""


func ensure_battle_advice_service(scene: Object) -> void:
	if scene.get("_battle_advice_service") != null:
		return
	var battle_advice_service: RefCounted = BattleAdviceServiceScript.new()
	scene.set("_battle_advice_service", battle_advice_service)
	if battle_advice_service == null:
		return
	if battle_advice_service.has_signal("status_changed") and not battle_advice_service.status_changed.is_connected(Callable(scene, "_on_battle_advice_status_changed")):
		battle_advice_service.status_changed.connect(Callable(scene, "_on_battle_advice_status_changed"))
	if battle_advice_service.has_signal("advice_completed") and not battle_advice_service.advice_completed.is_connected(Callable(scene, "_on_battle_advice_completed")):
		battle_advice_service.advice_completed.connect(Callable(scene, "_on_battle_advice_completed"))


func on_ai_advice_pressed(scene: Object) -> void:
	if not bool(scene.call("_can_accept_live_action")) or not should_offer_battle_advice(scene) or bool(scene.get("_battle_advice_busy")):
		return
	var match_dir := current_battle_advice_match_dir(scene)
	if match_dir.strip_edges() == "":
		show_battle_advice_overlay(scene, {
			"status": "failed",
			"errors": [{"message": "match_dir unavailable"}],
		})
		return
	var battle_advice_initial_snapshot: Dictionary = scene.get("_battle_advice_initial_snapshot")
	if battle_advice_initial_snapshot.is_empty():
		battle_advice_initial_snapshot = build_battle_advice_initial_snapshot(scene)
		scene.set("_battle_advice_initial_snapshot", battle_advice_initial_snapshot)

	ensure_battle_advice_service(scene)
	var battle_advice_service: RefCounted = scene.get("_battle_advice_service")
	if battle_advice_service == null:
		return
	scene.set("_battle_advice_busy", true)
	scene.set("_battle_advice_progress_text", _bt(scene, "battle.advice.progress"))
	show_battle_advice_overlay(scene, {"status": "running"})
	battle_advice_service.call(
		"generate_advice",
		scene,
		match_dir,
		scene.call("_build_battle_state_snapshot"),
		battle_advice_initial_snapshot,
		GameManager.get_battle_review_api_config(),
		int(scene.get("_view_player"))
	)
	scene.call("_refresh_ui")


func on_battle_advice_status_changed(scene: Object, status: String, _context: Dictionary) -> void:
	if status == "completed" or status == "failed":
		scene.set("_battle_advice_busy", false)
		scene.set("_battle_advice_progress_text", "")
	else:
		scene.set("_battle_advice_busy", true)
		if str(scene.get("_battle_advice_progress_text")) == "":
			scene.set("_battle_advice_progress_text", _bt(scene, "battle.advice.progress"))
	if str(scene.get("_review_overlay_mode")) == "advice" and bool((scene.get("_review_overlay") as Panel).visible):
		var review_regenerate_btn: Button = scene.get("_review_regenerate_btn")
		review_regenerate_btn.disabled = bool(scene.get("_battle_advice_busy"))
		var review_pin_btn: Button = scene.get("_review_pin_btn")
		if review_pin_btn != null:
			review_pin_btn.disabled = bool(scene.get("_battle_advice_busy"))
	scene.call("_refresh_ui")


func on_battle_advice_completed(scene: Object, result: Dictionary) -> void:
	scene.set("_battle_advice_last_result", result.duplicate(true))
	scene.set("_battle_advice_busy", false)
	scene.set("_battle_advice_progress_text", "")
	show_battle_advice_overlay(scene, result)
	refresh_battle_advice_panel(scene)
	scene.call("_refresh_ui")


func show_battle_advice_overlay(scene: Object, result: Dictionary) -> void:
	scene.set("_review_overlay_mode", "advice")
	var review_title: Label = scene.get("_review_title")
	var review_regenerate_btn: Button = scene.get("_review_regenerate_btn")
	var review_pin_btn: Button = scene.get("_review_pin_btn")
	var review_content: RichTextLabel = scene.get("_review_content")
	var review_overlay: Panel = scene.get("_review_overlay")
	review_title.text = _bt(scene, "battle.top.ai_advice")
	review_regenerate_btn.visible = true
	review_regenerate_btn.text = _bt(scene, "battle.advice.regenerate")
	review_regenerate_btn.disabled = bool(scene.get("_battle_advice_busy"))
	if review_pin_btn != null:
		review_pin_btn.visible = true
		review_pin_btn.disabled = bool(scene.get("_battle_advice_busy"))
	review_content.text = format_battle_advice(scene, result)
	review_overlay.visible = true


func format_battle_advice(scene: Object, result: Dictionary) -> String:
	var formatter: RefCounted = scene.get("_battle_advice_formatter")
	return str(formatter.call("format_advice", result, str(scene.get("_battle_advice_progress_text"))))


func on_review_pin_pressed(scene: Object) -> void:
	scene.set("_battle_advice_pinned", true)
	refresh_battle_advice_panel(scene)


func on_battle_advice_panel_toggle_pressed(scene: Object) -> void:
	scene.set("_battle_advice_panel_collapsed", not bool(scene.get("_battle_advice_panel_collapsed")))
	refresh_battle_advice_panel(scene)


func refresh_battle_advice_panel(scene: Object) -> void:
	var battle_advice_panel: PanelContainer = scene.get("_battle_advice_panel")
	var battle_advice_panel_content: RichTextLabel = scene.get("_battle_advice_panel_content")
	if battle_advice_panel == null or battle_advice_panel_content == null:
		return
	var battle_advice_last_result: Dictionary = scene.get("_battle_advice_last_result")
	var has_content := not battle_advice_last_result.is_empty()
	var battle_advice_busy: bool = bool(scene.get("_battle_advice_busy"))
	var battle_advice_pinned: bool = bool(scene.get("_battle_advice_pinned"))
	var battle_advice_panel_collapsed: bool = bool(scene.get("_battle_advice_panel_collapsed"))
	battle_advice_panel.visible = battle_advice_pinned and (has_content or battle_advice_busy)
	if not battle_advice_panel.visible:
		return
	var battle_advice_panel_title: Label = scene.get("_battle_advice_panel_title")
	var battle_advice_panel_toggle_btn: Button = scene.get("_battle_advice_panel_toggle_btn")
	battle_advice_panel_title.text = _bt(scene, "battle.top.ai_advice")
	battle_advice_panel_toggle_btn.text = _bt(scene, "battle.advice.toggle_expand") if battle_advice_panel_collapsed else _bt(scene, "battle.advice.toggle_collapse")
	battle_advice_panel_content.visible = not battle_advice_panel_collapsed
	if battle_advice_busy and battle_advice_last_result.is_empty():
		battle_advice_panel_content.text = "[b]%s[/b]\n%s" % [_bt(scene, "battle.top.ai_advice"), str(scene.get("_battle_advice_progress_text"))]
	else:
		battle_advice_panel_content.text = format_battle_advice(scene, battle_advice_last_result)


func build_battle_advice_initial_snapshot(scene: Object) -> Dictionary:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return {}
	var state: GameState = gsm.game_state
	var players: Array[Dictionary] = []
	for player_variant: Variant in state.players:
		if not (player_variant is PlayerState):
			continue
		var player := player_variant as PlayerState
		players.append({
			"player_index": player.player_index,
			"decklist": scene.call("_serialize_card_list", player.deck),
		})
	var player_labels: Array[String] = []
	for deck_id_variant: Variant in GameManager.selected_deck_ids:
		var deck: DeckData = CardDatabase.get_deck(int(deck_id_variant))
		if deck != null and deck.deck_name.strip_edges() != "":
			player_labels.append(deck.deck_name)
		else:
			player_labels.append("player_%d" % player_labels.size())
	return {
		"players": players,
		"selected_deck_ids": GameManager.selected_deck_ids.duplicate(),
		"player_labels": player_labels,
	}
