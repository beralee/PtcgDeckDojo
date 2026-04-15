class_name TestGameManager
extends TestBase

const GameManagerPath := "res://scripts/autoload/GameManager.gd"
const CONFIG_PATH := "user://battle_review_api.json"
const BATTLE_SETUP_SETTINGS_PATH := "user://battle_setup.json"


func _load_game_manager_script() -> GDScript:
	return load(GameManagerPath)


func _remove_config_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(CONFIG_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _read_config_text() -> String:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_config(payload: Dictionary) -> bool:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _restore_config_text(original_text: String) -> void:
	if original_text == "":
		_remove_config_file()
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(original_text)
	file.close()


func _read_battle_setup_settings_text() -> String:
	var file := FileAccess.open(BATTLE_SETUP_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_battle_setup_settings(payload: Dictionary) -> bool:
	var file := FileAccess.open(BATTLE_SETUP_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _remove_battle_setup_settings_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(BATTLE_SETUP_SETTINGS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _restore_battle_setup_settings_text(original_text: String) -> void:
	if original_text == "":
		_remove_battle_setup_settings_file()
		return
	var file := FileAccess.open(BATTLE_SETUP_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(original_text)
	file.close()


func test_battle_review_api_config_uses_defaults_when_file_is_missing() -> String:
	var original_config_text := _read_config_text()
	_remove_config_file()
	var manager: Node = _load_game_manager_script().new()
	var config: Dictionary = manager.call("get_battle_review_api_config")
	_restore_config_text(original_config_text)

	return run_checks([
		assert_eq(str(manager.call("get_battle_review_api_config_path")), CONFIG_PATH, "GameManager should expose the fixed user:// config path"),
		assert_eq(str(config.get("endpoint", "")), "https://zenmux.ai/api/v1", "missing config file should keep default endpoint"),
		assert_eq(str(config.get("api_key", "")), "", "missing config file should keep default api_key"),
		assert_eq(str(config.get("model", "")), "openai/gpt-5.4", "missing config file should keep default model"),
		assert_eq(float(config.get("timeout_seconds", 0.0)), 60.0, "missing config file should keep default timeout"),
	])


func test_battle_review_api_config_loads_user_file() -> String:
	var original_config_text := _read_config_text()
	_remove_config_file()
	_write_config({
		"endpoint": "https://example.invalid/v1/chat/completions",
		"api_key": "zenmux-key",
		"model": "gpt-test",
		"timeout_seconds": 45,
	})
	var manager: Node = _load_game_manager_script().new()
	var config: Dictionary = manager.call("get_battle_review_api_config")
	_restore_config_text(original_config_text)

	return run_checks([
		assert_eq(str(config.get("endpoint", "")), "https://example.invalid/v1/chat/completions", "GameManager should load endpoint from user config"),
		assert_eq(str(config.get("api_key", "")), "zenmux-key", "GameManager should load api_key from user config"),
		assert_eq(str(config.get("model", "")), "gpt-test", "GameManager should load model from user config"),
		assert_eq(float(config.get("timeout_seconds", 0.0)), 45.0, "GameManager should load timeout_seconds from user config"),
	])


func test_battle_replay_launch_request_is_one_shot() -> String:
	var manager: Node = _load_game_manager_script().new()
	if not manager.has_method("set_battle_replay_launch") or not manager.has_method("consume_battle_replay_launch"):
		return "GameManager should provide replay launch helpers"

	manager.call("set_battle_replay_launch", {
		"match_dir": "user://match_records/match_a",
		"entry_turn_number": 6,
	})
	var launch: Dictionary = manager.call("consume_battle_replay_launch")

	return run_checks([
		assert_eq(str(launch.get("match_dir", "")), "user://match_records/match_a", "Replay launch should preserve match_dir"),
		assert_eq(int(launch.get("entry_turn_number", 0)), 6, "Replay launch should preserve entry turn"),
		assert_true((manager.call("consume_battle_replay_launch") as Dictionary).is_empty(), "Replay launch should be one-shot"),
	])


func test_deck_editor_return_context_is_one_shot() -> String:
	var manager: Node = _load_game_manager_script().new()
	if not manager.has_method("set_deck_editor_return_context") or not manager.has_method("consume_deck_editor_return_context"):
		return "GameManager should provide deck editor return context helpers"

	manager.call("set_deck_editor_return_context", {
		"return_scene": "battle_setup",
		"deck1_id": 101,
		"deck2_id": 202,
	})
	var context: Dictionary = manager.call("consume_deck_editor_return_context")

	return run_checks([
		assert_eq(str(context.get("return_scene", "")), "battle_setup", "Deck editor return context should preserve return scene"),
		assert_eq(int(context.get("deck1_id", 0)), 101, "Deck editor return context should preserve deck1 id"),
		assert_eq(int(context.get("deck2_id", 0)), 202, "Deck editor return context should preserve deck2 id"),
		assert_true((manager.call("consume_deck_editor_return_context") as Dictionary).is_empty(), "Deck editor return context should be one-shot"),
	])


func test_resolve_selected_battle_deck_prefers_ai_deck_for_vs_ai_slot() -> String:
	var test_deck_id := 990001
	var previous_ids := GameManager.selected_deck_ids.duplicate()
	var previous_mode := GameManager.current_mode

	var normal_deck := DeckData.new()
	normal_deck.id = test_deck_id
	normal_deck.deck_name = "Normal Deck"
	normal_deck.total_cards = 60

	var ai_deck := DeckData.new()
	ai_deck.id = test_deck_id
	ai_deck.deck_name = "AI Deck"
	ai_deck.total_cards = 60

	CardDatabase.save_deck(normal_deck)
	CardDatabase.save_ai_deck(ai_deck)
	GameManager.selected_deck_ids = [123, test_deck_id]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var resolved := GameManager.resolve_selected_battle_deck(1)
	GameManager.selected_deck_ids = previous_ids.duplicate()
	GameManager.current_mode = previous_mode
	CardDatabase.delete_deck(test_deck_id)
	CardDatabase.delete_ai_deck(test_deck_id)

	return run_checks([
		assert_not_null(resolved, "GameManager should resolve a deck for the AI slot"),
		assert_eq(str(resolved.deck_name if resolved != null else ""), "AI Deck", "VS_AI should resolve player 2 from the dedicated AI deck cache"),
	])


func test_battle_audio_preferences_default_to_20_when_settings_file_is_missing() -> String:
	var original_settings_text := _read_battle_setup_settings_text()
	_remove_battle_setup_settings_file()
	var manager: Node = _load_game_manager_script().new()
	manager.call("load_battle_setup_preferences")
	var selected_track := str(manager.get("selected_battle_music_id"))
	var volume := int(manager.get("battle_bgm_volume_percent"))
	_restore_battle_setup_settings_text(original_settings_text)

	return run_checks([
		assert_eq(selected_track, "none", "Missing battle setup settings should keep the default track"),
		assert_eq(volume, 20, "Missing battle setup settings should default battle BGM volume to 20"),
	])


func test_battle_audio_preferences_load_saved_bgm_settings() -> String:
	var original_settings_text := _read_battle_setup_settings_text()
	_remove_battle_setup_settings_file()
	_write_battle_setup_settings({
		"battle_music_id": "pokemon_sv_battle_gym_leader",
		"battle_bgm_volume_percent": 37,
	})
	var manager: Node = _load_game_manager_script().new()
	manager.call("load_battle_setup_preferences")
	var selected_track := str(manager.get("selected_battle_music_id"))
	var volume := int(manager.get("battle_bgm_volume_percent"))
	_restore_battle_setup_settings_text(original_settings_text)

	return run_checks([
		assert_eq(selected_track, "pokemon_sv_battle_gym_leader", "GameManager should load the saved battle music id on startup"),
		assert_eq(volume, 37, "GameManager should load the saved battle BGM volume on startup"),
	])
