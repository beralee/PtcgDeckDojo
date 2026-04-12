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
