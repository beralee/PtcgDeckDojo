class_name TestAttackVfxPreviewUI
extends TestBase


const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")
const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")


func _make_battle_scene_stub() -> Control:
	var battle_scene = BattleSceneScript.new()
	battle_scene.set("_dialog_title", Label.new())
	battle_scene.set("_dialog_list", ItemList.new())
	battle_scene.set("_dialog_card_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_card_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_panel", VBoxContainer.new())
	battle_scene.set("_dialog_assignment_source_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_source_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_target_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_target_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_summary_lbl", Label.new())
	battle_scene.set("_dialog_utility_row", HBoxContainer.new())
	battle_scene.set("_dialog_confirm", Button.new())
	battle_scene.set("_dialog_cancel", Button.new())
	battle_scene.set("_dialog_status_lbl", Label.new())
	battle_scene.set("_dialog_overlay", Panel.new())
	battle_scene.set("_handover_panel", Panel.new())
	battle_scene.set("_handover_lbl", Label.new())
	battle_scene.set("_handover_btn", Button.new())
	battle_scene.set("_coin_overlay", Panel.new())
	battle_scene.set("_detail_overlay", Panel.new())
	battle_scene.set("_discard_overlay", Panel.new())
	battle_scene.set("_log_list", RichTextLabel.new())
	battle_scene.set("_btn_attack_vfx_preview", Button.new())
	battle_scene.set("_btn_ai_advice", Button.new())
	return battle_scene


func test_battle_scene_tscn_attack_vfx_preview_button_uses_clean_chinese_copy() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var preview_button := scene.find_child("BtnAttackVfxPreview", true, false)
	var preview_text: String = preview_button.text if preview_button is Button else ""
	return run_checks([
		assert_true(preview_button is Button, "BattleScene should expose the fireworks preview button in the top bar"),
		assert_eq(preview_text, "放烟花", "Fireworks preview button copy should stay clean Chinese"),
	])


func test_attack_vfx_preview_sequence_uses_root_overlay_coordinates() -> String:
	var battle_scene = _make_battle_scene_stub()
	var main_area := HBoxContainer.new()
	main_area.name = "MainArea"
	main_area.position = Vector2(48, 36)
	main_area.size = Vector2(1280, 720)
	battle_scene.add_child(main_area)

	var center_field := Control.new()
	center_field.name = "CenterField"
	center_field.position = Vector2(80, 20)
	center_field.size = Vector2(1200, 760)
	main_area.add_child(center_field)

	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.size = my_active.custom_minimum_size
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.size = opp_active.custom_minimum_size
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	battle_scene.call("_on_attack_vfx_preview_pressed")
	battle_scene.call("_handle_dialog_choice", PackedInt32Array([0]))
	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Control = sequence.get_node_or_null("AttackVfxCast") as Control if sequence != null else null
	var expected_local := my_active.global_position + my_active.size * 0.5

	return run_checks([
		assert_not_null(overlay, "Attack VFX preview should create an overlay"),
		assert_eq(overlay.get_parent(), battle_scene, "Attack VFX overlay should attach to the scene root instead of the MainArea container"),
		assert_not_null(sequence, "Attack VFX preview should create a sequence"),
		assert_not_null(cast_node, "Attack VFX preview should create an attacker-side cast node"),
		assert_eq(cast_node.position, expected_local, "Attack VFX preview should use root-overlay coordinates"),
	])
