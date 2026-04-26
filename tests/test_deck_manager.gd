class_name TestDeckManager
extends TestBase

const DeckManagerScene = preload("res://scenes/deck_manager/DeckManager.tscn")


func test_deck_manager_uses_hud_visual_theme() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene.call("_apply_hud_theme")
	var frame := scene.get_node_or_null("HudFrame") as PanelContainer
	var frame_style := frame.get_theme_stylebox("panel") as StyleBoxFlat if frame != null else null
	var import_box := scene.find_child("ImportBox", true, false) as PanelContainer
	var import_style := import_box.get_theme_stylebox("panel") as StyleBoxFlat if import_box != null else null
	var import_button := scene.get_node_or_null("%BtnImport") as Button
	var button_style := import_button.get_theme_stylebox("normal") as StyleBoxFlat if import_button != null else null

	scene.queue_free()
	return run_checks([
		assert_true(frame_style != null and frame_style.bg_color.a < 0.9, "Deck manager should use a translucent HUD frame"),
		assert_true(import_style != null and import_style.bg_color.a < 1.0, "Deck import dialog should use HUD panel styling"),
		assert_true(button_style != null and button_style.border_color.a > 0.8, "Deck manager buttons should use explicit HUD borders"),
	])


func test_import_deck_name_validation_rejects_empty_and_duplicates() -> String:
	_cleanup_decks([910001])
	var existing := _make_deck(910001, "重复名称")
	CardDatabase.save_deck(existing)

	var scene: Control = DeckManagerScene.instantiate()
	var empty_error: String = scene._validate_import_deck_name("   ")
	var duplicate_error: String = scene._validate_import_deck_name("重复名称")
	var unique_error: String = scene._validate_import_deck_name("新名称")

	_cleanup_decks([existing.id])
	scene.queue_free()

	return run_checks([
		assert_true(empty_error != "", "空白名称应返回错误"),
		assert_true(duplicate_error != "", "重复名称应返回错误"),
		assert_eq(unique_error, "", "唯一名称不应返回错误"),
	])


func test_import_completed_saves_immediately_when_name_is_unique() -> String:
	_cleanup_decks([910002])
	var imported := _make_deck(910002, "唯一导入名")
	var scene: Control = DeckManagerScene.instantiate()

	scene._on_import_completed(imported, PackedStringArray())

	var saved: DeckData = CardDatabase.get_deck(imported.id)
	var pending_deck = scene._pending_import_deck

	_cleanup_decks([imported.id])
	scene.queue_free()

	return run_checks([
		assert_not_null(saved, "唯一名称导入后应直接保存"),
		assert_eq(saved.deck_name, "唯一导入名", "应保留原始唯一名称"),
		assert_null(pending_deck, "唯一名称不应进入待改名状态"),
	])


func test_import_completed_requires_rename_before_saving_duplicate_name() -> String:
	_cleanup_decks([910003, 910004])
	var existing := _make_deck(910003, "冲突卡组")
	var imported := _make_deck(910004, "冲突卡组")
	CardDatabase.save_deck(existing)

	var scene: Control = DeckManagerScene.instantiate()
	scene._on_import_completed(imported, PackedStringArray())

	var not_saved_yet: DeckData = CardDatabase.get_deck(imported.id)
	var pending_before = scene._pending_import_deck
	var confirm_before: bool = scene._rename_confirm_button.disabled if scene._rename_confirm_button != null else false

	scene._on_import_rename_text_changed("冲突卡组")
	if scene._rename_input != null:
		scene._rename_input.text = "改名后卡组"
	scene._on_import_rename_text_changed("改名后卡组")
	scene._on_confirm_import_rename()

	var saved: DeckData = CardDatabase.get_deck(imported.id)
	var pending_after = scene._pending_import_deck

	_cleanup_decks([existing.id, imported.id])
	scene.queue_free()

	return run_checks([
		assert_null(not_saved_yet, "重名导入时不应立即保存"),
		assert_not_null(pending_before, "重名导入时应进入待改名状态"),
		assert_true(confirm_before, "重名初始值时确认按钮应禁用"),
		assert_not_null(saved, "改成唯一名称后应保存卡组"),
		assert_eq(saved.deck_name, "改名后卡组", "保存后的卡组应使用新名称"),
		assert_null(pending_after, "保存后应清空待改名状态"),
	])


func test_existing_deck_name_validation_ignores_current_deck() -> String:
	_cleanup_decks([910005, 910006])
	var current := _make_deck(910005, "Current Deck")
	var other := _make_deck(910006, "Other Deck")
	CardDatabase.save_deck(current)
	CardDatabase.save_deck(other)

	var scene: Control = DeckManagerScene.instantiate()
	var keep_current_error: String = scene._validate_deck_name("  Current Deck  ", current.id)
	var other_duplicate_error: String = scene._validate_deck_name("Other Deck", current.id)

	_cleanup_decks([current.id, other.id])
	scene.queue_free()

	return run_checks([
		assert_eq(keep_current_error, "", "current deck name should remain valid when ignoring self"),
		assert_true(other_duplicate_error != "", "other deck name should still be rejected"),
	])


func test_confirm_existing_deck_rename_persists_trimmed_name() -> String:
	_cleanup_decks([910007])
	var deck := _make_deck(910007, "Old Deck Name")
	CardDatabase.save_deck(deck)

	var scene: Control = DeckManagerScene.instantiate()
	scene._on_rename_deck(deck)

	var initial_validation_error: String = scene._rename_error_label.text if scene._rename_error_label != null else "__missing__"
	if scene._rename_input != null:
		scene._rename_input.text = "  New Deck Name  "
	scene._on_rename_text_changed("  New Deck Name  ")
	scene._on_confirm_rename()

	var saved: DeckData = CardDatabase.get_deck(deck.id)

	_cleanup_decks([deck.id])
	scene.queue_free()

	return run_checks([
		assert_eq(initial_validation_error, "", "existing deck name should be valid at dialog open"),
		assert_not_null(saved, "renamed deck should still exist"),
		assert_eq(saved.deck_name, "New Deck Name", "rename should persist the trimmed deck name"),
	])


func test_duplicate_import_rename_dialog_stays_clamped_with_visible_confirm_controls() -> String:
	var scene: Control = DeckManagerScene.instantiate()
	scene._show_import_rename_dialog("Duplicate Deck Name")

	var dialog: AcceptDialog = scene._rename_dialog
	var scroll: ScrollContainer = null
	if dialog != null:
		for child: Node in dialog.get_children():
			if child is ScrollContainer:
				scroll = child
				break

	scene.queue_free()

	return run_checks([
		assert_not_null(dialog, "duplicate import should open the rename dialog"),
		assert_eq(dialog.size, Vector2i(460, 230), "rename dialog should use the fixed clamped size"),
		assert_not_null(scroll, "rename dialog should wrap content in a scroll container"),
		assert_not_null(scene._rename_confirm_button, "rename dialog should still expose the confirm button"),
	])


func test_import_completed_does_not_reprompt_rename_for_same_saved_deck_id() -> String:
	_cleanup_decks([910008])
	var deck := _make_deck(910008, "Same Saved Deck")
	CardDatabase.save_deck(deck)

	var scene: Control = DeckManagerScene.instantiate()
	scene._on_import_completed(deck, PackedStringArray())

	var pending_deck = scene._pending_import_deck
	var rename_dialog = scene._rename_dialog
	var saved: DeckData = CardDatabase.get_deck(deck.id)

	_cleanup_decks([deck.id])
	scene.queue_free()

	return run_checks([
		assert_not_null(saved, "same-id imported deck should remain saved"),
		assert_null(pending_deck, "same-id import completion should not enter pending rename state"),
		assert_null(rename_dialog, "same-id import completion should not reopen the rename dialog"),
	])


func _make_deck(deck_id: int, deck_name: String) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = deck_name
	deck.source_url = "https://tcg.mik.moe/decks/list/%d" % deck_id
	deck.import_date = "2026-03-25 00:00:00"
	deck.variant_name = deck_name
	deck.deck_code = "UTEST_%d" % deck_id
	deck.total_cards = 60
	deck.cards = []
	return deck


func _cleanup_decks(deck_ids: Array[int]) -> void:
	for deck_id: int in deck_ids:
		if CardDatabase.has_deck(deck_id):
			CardDatabase.delete_deck(deck_id)
