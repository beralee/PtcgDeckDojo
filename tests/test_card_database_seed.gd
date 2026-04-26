class_name TestCardDatabaseSeed
extends TestBase

const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")


func test_copy_missing_files_recursive_copies_nested_files_without_overwriting() -> String:
	var db := CardDatabaseScript.new()
	var source_root := "user://utest_bundled_source"
	var target_root := "user://utest_bundled_target"
	_remove_dir_recursive(source_root)
	_remove_dir_recursive(target_root)

	var source_cards_dir := source_root.path_join("cards")
	var source_images_dir := source_cards_dir.path_join("images/UTEST")
	var target_cards_dir := target_root.path_join("cards")
	var copied_json_path := target_cards_dir.path_join("sample.json")
	var copied_image_path := target_cards_dir.path_join("images/UTEST/sample.png")

	DirAccess.make_dir_recursive_absolute(source_images_dir)
	_write_text(source_cards_dir.path_join("sample.json"), "{\"id\":1,\"name\":\"Preset Deck Card\"}")
	_write_text(source_images_dir.path_join("sample.png.bin"), "image-bytes")
	_write_text(source_images_dir.path_join("sample.png.import"), "import-metadata")

	db._copy_missing_files_recursive(source_cards_dir, target_cards_dir)
	var first_copy_json := FileAccess.get_file_as_string(copied_json_path)
	var first_copy_image := FileAccess.get_file_as_string(copied_image_path)
	var copied_json_exists := FileAccess.file_exists(copied_json_path)
	var copied_image_exists := FileAccess.file_exists(copied_image_path)
	var copied_import_exists := FileAccess.file_exists(target_cards_dir.path_join("images/UTEST/sample.png.import"))

	_write_text(copied_json_path, "user-customized")
	db._copy_missing_files_recursive(source_cards_dir, target_cards_dir)
	var second_copy_json := FileAccess.get_file_as_string(copied_json_path)

	_remove_dir_recursive(source_root)
	_remove_dir_recursive(target_root)

	return run_checks([
		assert_true(copied_json_exists, "Bundled JSON should be copied into user:// target"),
		assert_true(copied_image_exists, "Nested bundled file should be copied recursively"),
		assert_false(copied_import_exists, "Godot import metadata should not be copied into user:// target"),
		assert_eq(first_copy_json, "{\"id\":1,\"name\":\"Preset Deck Card\"}", "Copied JSON content should match bundled source"),
		assert_eq(first_copy_image, "image-bytes", "Nested bundled file content should match bundled source"),
		assert_eq(second_copy_json, "user-customized", "Existing user file should not be overwritten by bundled seed"),
	])


func test_supported_ai_deck_ignores_user_override_and_reads_bundled_source() -> String:
	var db := CardDatabaseScript.new()
	db._ensure_directories()
	db._deck_cache = {}
	db._ai_deck_cache = {}
	var bundled_ai: DeckData = db._load_bundled_ai_deck(575720)
	if bundled_ai == null:
		return "Expected bundled AI deck 575720 to exist"
	var fake_ai := DeckData.new()
	fake_ai.id = 575720
	fake_ai.deck_name = "Fake Override Miraidon"
	fake_ai.total_cards = 60
	db.save_ai_deck(fake_ai)
	var resolved: DeckData = db.get_ai_deck(575720)
	return run_checks([
		assert_not_null(resolved, "Supported AI deck should still resolve"),
		assert_eq(str(resolved.deck_name if resolved != null else ""), str(bundled_ai.deck_name), "Supported AI decks should resolve from bundled source, not user overrides"),
	])


func test_get_all_ai_decks_returns_supported_bundled_shortlist() -> String:
	var db := CardDatabaseScript.new()
	db._ensure_directories()
	db._deck_cache = {}
	db._ai_deck_cache = {}
	var ai_decks: Array[DeckData] = db.get_all_ai_decks()
	var ids: Array[int] = []
	for deck: DeckData in ai_decks:
		ids.append(deck.id)
	ids.sort()
	var expected_ids := [569061, 575657, 575716, 575718, 575720, 575723, 578647, 579502]
	return run_checks([
		assert_eq(ai_decks.size(), expected_ids.size(), "AI deck list should expose exactly the backed-up AI deck set"),
		assert_eq(ids, expected_ids, "AI deck list should match the backed-up AI deck set"),
	])


func _write_text(path: String, content: String) -> void:
	var parent_dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("TestCardDatabaseSeed: failed to write %s" % path)
		return
	file.store_string(content)
	file.close()


func _remove_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path := path.path_join(entry)
		if dir.current_is_dir():
			_remove_dir_recursive(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
