class_name TestBattleSetupLayout
extends TestBase

const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")


func test_battle_setup_uses_true_two_column_layout() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)

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


func test_battle_setup_includes_per_player_deck_view_and_edit_actions() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)

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

	var deck1_label := scene.find_child("Deck1Label", true, false) as Label
	var deck2_label := scene.find_child("Deck2Label", true, false) as Label

	var result := run_checks([
		assert_eq(deck1_label.text, "玩家1 卡组", "Deck1 label should use readable Chinese"),
		assert_eq(deck2_label.text, "玩家2 卡组", "Deck2 label should use readable Chinese before VS_AI mode remaps it"),
	])

	scene.queue_free()
	return result


func test_battle_setup_edit_action_prepares_battle_setup_return_context() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)

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
	return result


func test_battle_setup_edit_button_press_is_wired_to_navigation_handler() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)

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
	return result


func test_battle_setup_view_button_press_opens_deck_dialog() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)

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
