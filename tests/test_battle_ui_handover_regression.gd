class_name TestBattleUIHandoverRegression
extends TestBase


func test_handover_confirmation_executes_pending_follow_up() -> String:
	var battle_scene_script: GDScript = load("res://scenes/battle/BattleScene.gd")
	var scene: Control = battle_scene_script.new()

	var dialog_overlay := Panel.new()
	var handover_panel := Panel.new()
	var handover_label := Label.new()
	dialog_overlay.visible = false
	handover_panel.visible = false
	scene.set("_dialog_overlay", dialog_overlay)
	scene.set("_handover_panel", handover_panel)
	scene.set("_handover_lbl", handover_label)
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_pending_choice", "send_out")
	scene.set("_view_player", 0)

	scene.call("_show_handover_prompt", 1, func() -> void:
		scene.set("_view_player", 1)
		dialog_overlay.visible = true
	)
	scene.call("_on_handover_confirmed")
	var remaining_action: Callable = scene.get("_pending_handover_action")

	return run_checks([
		assert_eq(scene.get("_view_player"), 1, "handover should switch to the defending player"),
		assert_eq(scene.get("_pending_choice"), "send_out", "replacement choice should stay active"),
		assert_true(dialog_overlay.visible, "replacement dialog should be visible after handover"),
		assert_false(handover_panel.visible, "handover overlay should close once the dialog is shown"),
		assert_false(remaining_action.is_valid(), "pending handover action should be cleared after confirmation"),
	])


func test_reset_effect_interaction_preserves_knockout_send_out_prompt() -> String:
	var battle_scene_script: GDScript = load("res://scenes/battle/BattleScene.gd")
	var scene: Control = battle_scene_script.new()

	var dialog_overlay := Panel.new()
	dialog_overlay.visible = false
	scene.set("_dialog_overlay", dialog_overlay)
	var handover_panel := Panel.new()
	handover_panel.visible = false
	scene.set("_handover_panel", handover_panel)
	var coin_overlay := Panel.new()
	coin_overlay.visible = false
	scene.set("_coin_overlay", coin_overlay)
	var detail_overlay := Panel.new()
	detail_overlay.visible = false
	scene.set("_detail_overlay", detail_overlay)
	var discard_overlay := Panel.new()
	discard_overlay.visible = false
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_dialog_data", {"player": 1})
	scene.set("_dialog_items_data", ["placeholder"])
	scene.set("_dialog_multi_selected_indices", [0])
	scene.set("_dialog_card_selected_indices", [0])
	scene.set("_pending_choice", "send_out")
	scene.set("_pending_effect_kind", "attack")
	scene.set("_pending_effect_player_index", 0)
	scene.set("_pending_effect_step_index", 0)
	scene.set("_pending_effect_context", {"discard_basic_energy": []})
	dialog_overlay.visible = true

	scene.call("_reset_effect_interaction")

	return run_checks([
		assert_eq(scene.get("_pending_choice"), "send_out", "reset should not clear the replacement prompt"),
		assert_true(dialog_overlay.visible, "reset should not hide a follow-up prompt opened during the attack"),
		assert_eq(scene.get("_dialog_data").get("player", -1), 1, "reset should preserve the follow-up dialog context"),
	])


func test_check_two_player_handover_preserves_special_follow_up() -> String:
	var battle_scene_script: GDScript = load("res://scenes/battle/BattleScene.gd")
	var scene: Control = battle_scene_script.new()
	var gsm := GameStateMachine.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]

	scene.set("_gsm", gsm)
	var dialog_overlay := Panel.new()
	dialog_overlay.visible = false
	scene.set("_dialog_overlay", dialog_overlay)
	var handover_panel := Panel.new()
	handover_panel.visible = false
	scene.set("_handover_panel", handover_panel)
	scene.set("_handover_lbl", Label.new())
	var coin_overlay := Panel.new()
	coin_overlay.visible = false
	scene.set("_coin_overlay", coin_overlay)
	var detail_overlay := Panel.new()
	detail_overlay.visible = false
	scene.set("_detail_overlay", detail_overlay)
	var discard_overlay := Panel.new()
	discard_overlay.visible = false
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_pending_choice", "send_out")
	scene.set("_view_player", 1)

	var original_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene.call("_show_handover_prompt", 0, func() -> void:
		scene.set("_view_player", 0)
	)
	scene.call("_check_two_player_handover")
	var remaining_action: Callable = scene.get("_pending_handover_action")
	GameManager.current_mode = original_mode

	return run_checks([
		assert_true(handover_panel.visible, "special handover prompt should remain visible until confirmed"),
		assert_true(remaining_action.is_valid(), "special follow-up should not be cleared by generic handover checks"),
		assert_eq(scene.get("_view_player"), 1, "view should not switch before the confirmation button is pressed"),
	])


func test_slot_input_is_blocked_while_handover_overlay_is_visible() -> String:
	var battle_scene_script: GDScript = load("res://scenes/battle/BattleScene.gd")
	var scene: Control = battle_scene_script.new()
	var gsm := GameStateMachine.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]

	scene.set("_gsm", gsm)
	var dialog_overlay := Panel.new()
	dialog_overlay.visible = false
	scene.set("_dialog_overlay", dialog_overlay)
	var handover_panel := Panel.new()
	handover_panel.visible = false
	scene.set("_handover_panel", handover_panel)
	scene.set("_handover_lbl", Label.new())
	var coin_overlay := Panel.new()
	coin_overlay.visible = false
	scene.set("_coin_overlay", coin_overlay)
	var detail_overlay := Panel.new()
	detail_overlay.visible = false
	scene.set("_detail_overlay", detail_overlay)
	var discard_overlay := Panel.new()
	discard_overlay.visible = false
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_view_player", 1)
	handover_panel.visible = true

	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	scene.call("_on_slot_input", click, "my_active")

	return run_checks([
		assert_false(scene.get("_dialog_overlay").visible, "board clicks should not open dialogs while handover is active"),
		assert_true(handover_panel.visible, "handover overlay should stay visible after blocked board input"),
	])
