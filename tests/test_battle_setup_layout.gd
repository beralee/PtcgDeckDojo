class_name TestBattleSetupLayout
extends TestBase

const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")


func _set_navigation_suppressed(suppressed: bool) -> void:
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", suppressed)


func _force_two_player_mode(scene: Control) -> void:
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	if mode_option == null:
		return
	mode_option.select(0)
	scene.call("_refresh_deck_options")
	scene.call("_refresh_ai_ui_visibility")


func test_battle_setup_applies_hud_visual_theme() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)

	var setup_frame := scene.find_child("SetupFrame", true, false) as PanelContainer
	var left_column := scene.find_child("LeftColumn", true, false) as PanelContainer
	var right_column := scene.find_child("RightColumn", true, false) as PanelContainer
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var start_button := scene.find_child("BtnStart", true, false) as Button
	var frame_style := setup_frame.get_theme_stylebox("panel") as StyleBoxFlat if setup_frame != null else null
	var left_style := left_column.get_theme_stylebox("panel") as StyleBoxFlat if left_column != null else null
	var right_style := right_column.get_theme_stylebox("panel") as StyleBoxFlat if right_column != null else null
	var option_style := mode_option.get_theme_stylebox("normal") as StyleBoxFlat if mode_option != null else null
	var button_style := start_button.get_theme_stylebox("normal") as StyleBoxFlat if start_button != null else null

	var result := run_checks([
		assert_true(frame_style != null and frame_style.bg_color.a < 0.9, "Battle setup frame should use a translucent HUD panel instead of a solid black block"),
		assert_true(frame_style != null and frame_style.border_color.a > 0.8, "Battle setup frame should have a visible HUD border instead of blending into the background"),
		assert_true(left_style != null and left_style.bg_color.a < 1.0 and left_style.border_color.a > 0.5, "Left setup column should use a translucent bordered HUD card"),
		assert_true(right_style != null and right_style.bg_color.a < 1.0 and right_style.border_color.a > 0.5, "Right setup column should use a translucent bordered HUD card"),
		assert_true(option_style != null and option_style.bg_color.a < 1.0, "Battle setup option controls should use translucent HUD inputs"),
		assert_true(button_style != null and button_style.border_color.a > 0.8, "Battle setup buttons should use explicit HUD borders"),
	])

	scene.queue_free()
	return result


func test_battle_setup_uses_true_two_column_layout() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var content_columns := scene.find_child("ContentColumns", true, false)
	var left_column := scene.find_child("LeftColumn", true, false)
	var right_column := scene.find_child("RightColumn", true, false)
	var background_gallery := scene.find_child("BackgroundGallery", true, false)
	var bgm_option := scene.find_child("BgmOption", true, false)

	var result := run_checks([
		assert_true(content_columns != null, "Battle setup should have a two-column content container"),
		assert_true(left_column != null and right_column != null, "Battle setup should keep separate left and right columns"),
		assert_true(background_gallery != null, "Left column should keep the background gallery"),
		assert_true(bgm_option != null, "Right column should keep the music selector"),
	])

	scene.queue_free()
	return result


func test_battle_setup_right_column_exposes_ai_strategy_discussion_button() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var discuss_button := scene.find_child("BtnDiscussStrategyAI", true, false) as Button

	var result := run_checks([
		assert_not_null(discuss_button, "Battle setup right column should expose the AI strategy discussion button"),
		assert_eq(discuss_button.text, "与AI探讨策略", "Strategy discussion button should use the requested label"),
		assert_false(discuss_button.disabled, "Strategy discussion button should be enabled when two decks are selected"),
	])

	scene.queue_free()
	return result


func test_battle_setup_strategy_discussion_uses_pair_session_and_resets_on_deck_change() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 101
	deck1.deck_name = "玩家测试牌"
	deck1.total_cards = 60
	deck1.cards = [{"name": "玩家牌", "count": 4, "card_type": "Pokemon", "set_code": "UTEST", "card_index": "001"}]
	var deck2 := DeckData.new()
	deck2.id = 202
	deck2.deck_name = "对手测试牌"
	deck2.total_cards = 60
	deck2.cards = [{"name": "对手牌", "count": 4, "card_type": "Pokemon", "set_code": "UTEST", "card_index": "002"}]
	scene.set("_deck_list", [deck1, deck2])

	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("玩家测试牌")
	deck1_option.add_item("对手测试牌")
	deck2_option.add_item("对手测试牌")
	deck1_option.select(0)
	deck2_option.select(0)

	scene.call("_on_discuss_strategy_ai_pressed")
	var first_signature := str(scene.get("_strategy_discussion_signature"))
	var dialog := scene.get("_strategy_discussion_dialog") as AcceptDialog
	var first_title := ""
	if dialog != null:
		var deck_name_label := dialog.get_node_or_null("%DeckNameLabel") as Label
		if deck_name_label != null:
			first_title = deck_name_label.text
	deck1_option.select(1)
	scene.call("_on_deck1_changed", 1)
	var reset_signature := str(scene.get("_strategy_discussion_signature"))

	var result := run_checks([
		assert_eq(first_signature, "pvp:101:202", "Strategy discussion session should be keyed by mode and both deck ids"),
		assert_true(first_title.contains("玩家测试牌") and first_title.contains("对手测试牌"), "Strategy discussion dialog should show both current decks"),
		assert_eq(reset_signature, "", "Changing either deck should force the next discussion to start from a fresh session"),
	])

	scene.queue_free()
	return result


func test_battle_setup_includes_per_player_deck_view_and_edit_actions() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1_view := scene.find_child("Deck1ViewButton", true, false)
	var deck1_edit := scene.find_child("Deck1EditButton", true, false)
	var deck2_view := scene.find_child("Deck2ViewButton", true, false)
	var deck2_edit := scene.find_child("Deck2EditButton", true, false)

	var result := run_checks([
		assert_true(deck1_view is Button, "Player 1 deck area should expose a view button"),
		assert_true(deck1_edit is Button, "Player 1 deck area should expose an edit button"),
		assert_true(deck2_view is Button, "Player 2 deck area should expose a view button"),
		assert_true(deck2_edit is Button, "Player 2 deck area should expose an edit button"),
	])

	scene.queue_free()
	return result


func test_battle_setup_deck_action_buttons_use_readable_chinese_labels() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1_view := scene.find_child("Deck1ViewButton", true, false) as Button
	var deck1_edit := scene.find_child("Deck1EditButton", true, false) as Button
	var deck2_view := scene.find_child("Deck2ViewButton", true, false) as Button
	var deck2_edit := scene.find_child("Deck2EditButton", true, false) as Button

	var result := run_checks([
		assert_eq(deck1_view.text, "查看", "Deck1 view button should use readable Chinese"),
		assert_eq(deck1_edit.text, "编辑", "Deck1 edit button should use readable Chinese"),
		assert_eq(deck2_view.text, "查看", "Deck2 view button should use readable Chinese"),
		assert_eq(deck2_edit.text, "编辑", "Deck2 edit button should use readable Chinese"),
	])

	scene.queue_free()
	return result


func test_battle_setup_deck_labels_use_readable_chinese() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1_label := scene.find_child("Deck1Label", true, false) as Label
	var deck2_label := scene.find_child("Deck2Label", true, false) as Label

	var result := run_checks([
		assert_eq(deck1_label.text, "玩家1 卡组", "Deck1 label should use readable Chinese"),
		assert_eq(deck2_label.text, "玩家2 卡组", "Deck2 label should use readable Chinese before VS_AI mode remaps it"),
	])

	scene.queue_free()
	return result


func test_battle_setup_edit_action_prepares_battle_setup_return_context() -> String:
	_set_navigation_suppressed(true)
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 101
	deck1.deck_name = "Deck A"
	deck1.total_cards = 60
	var deck2 := DeckData.new()
	deck2.id = 202
	deck2.deck_name = "Deck B"
	deck2.total_cards = 60
	scene.set("_deck_list", [deck1, deck2])

	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("Deck A")
	deck2_option.add_item("Deck B")
	deck1_option.select(0)
	deck2_option.select(0)

	if not scene.has_method("_on_deck_edit_pressed"):
		scene.queue_free()
		return "BattleSetup should expose a deck edit handler"
	if not GameManager.has_method("consume_deck_editor_return_context"):
		scene.queue_free()
		return "GameManager should expose deck editor return context"

	scene.call("_on_deck_edit_pressed", 0)
	var context: Dictionary = GameManager.call("consume_deck_editor_return_context")

	var result := run_checks([
		assert_eq(str(context.get("return_scene", "")), "battle_setup", "BattleSetup deck edit should set battle_setup as the return scene"),
		assert_eq(int(context.get("deck1_id", 0)), 101, "BattleSetup deck edit should preserve player 1 deck selection"),
		assert_eq(int(context.get("deck2_id", 0)), 202, "BattleSetup deck edit should preserve player 2 deck selection"),
	])

	scene.queue_free()
	_set_navigation_suppressed(false)
	return result


func test_battle_setup_edit_button_press_is_wired_to_navigation_handler() -> String:
	_set_navigation_suppressed(true)
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 111
	deck1.deck_name = "Deck View"
	deck1.total_cards = 60
	var deck2 := DeckData.new()
	deck2.id = 222
	deck2.deck_name = "Deck Edit"
	deck2.total_cards = 60
	scene.set("_deck_list", [deck1, deck2])

	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("Deck View")
	deck2_option.add_item("Deck Edit")
	deck1_option.select(0)
	deck2_option.select(0)
	scene.call("_refresh_deck_action_buttons")

	var deck1_edit := scene.find_child("Deck1EditButton", true, false) as Button
	scene.call("_on_deck_edit_pressed", 0)
	var context: Dictionary = GameManager.call("consume_deck_editor_return_context")

	var result := run_checks([
		assert_false(deck1_edit.disabled, "Battle setup edit button should stay enabled when a deck is selected"),
		assert_eq(str(context.get("return_scene", "")), "battle_setup", "Pressing the battle setup edit button should queue a return to battle_setup"),
		assert_eq(int(context.get("deck1_id", 0)), 111, "Pressing the battle setup edit button should preserve deck1 selection"),
		assert_eq(int(context.get("deck2_id", 0)), 222, "Pressing the battle setup edit button should preserve deck2 selection"),
	])

	scene.queue_free()
	_set_navigation_suppressed(false)
	return result


func test_battle_setup_view_button_press_opens_deck_dialog() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	_force_two_player_mode(scene)

	var deck1 := DeckData.new()
	deck1.id = 333
	deck1.deck_name = "Deck Preview"
	deck1.total_cards = 1
	deck1.cards = [{
		"name": "Test Card",
		"count": 1,
		"card_type": "Pokemon",
		"set_code": "UTEST",
		"card_index": "001",
	}]
	var deck2 := DeckData.new()
	deck2.id = 444
	deck2.deck_name = "Deck Spare"
	deck2.total_cards = 1
	scene.set("_deck_list", [deck1, deck2])

	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("Deck Preview")
	deck2_option.add_item("Deck Spare")
	deck1_option.select(0)
	deck2_option.select(0)
	scene.call("_refresh_deck_action_buttons")

	var deck1_view := scene.find_child("Deck1ViewButton", true, false) as Button
	scene.call("_on_deck_view_pressed", 0)

	var dialog_opened := false
	for child: Node in scene.get_children():
		if child is AcceptDialog and (child as AcceptDialog).title == "Deck Preview":
			dialog_opened = true
			break

	var result := run_checks([
		assert_false(deck1_view.disabled, "Battle setup view button should stay enabled when a deck is selected"),
		assert_true(dialog_opened, "Pressing the battle setup view button should open the selected deck dialog"),
	])

	scene.queue_free()
	return result


func test_battle_setup_hides_ai_edit_button_in_vs_ai_mode() -> String:
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")

	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck2_view := scene.find_child("Deck2ViewButton", true, false) as Button
	var deck2_edit := scene.find_child("Deck2EditButton", true, false) as Button
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")

	var result := run_checks([
		assert_true(deck2_view.visible, "AI deck row should keep the view button in VS_AI mode"),
		assert_false(deck2_edit.visible, "AI deck row should hide the edit button in VS_AI mode"),
	])

	scene.queue_free()
	return result
