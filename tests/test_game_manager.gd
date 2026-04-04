class_name TestGameManager
extends TestBase

const GameManagerPath := "res://scripts/autoload/GameManager.gd"
const CONFIG_PATH := "user://battle_review_api.json"


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


func test_battle_review_api_config_uses_defaults_when_file_is_missing() -> String:
	var original_config_text := _read_config_text()
	_remove_config_file()
	var manager: Node = _load_game_manager_script().new()
	var config: Dictionary = manager.call("get_battle_review_api_config")
	_restore_config_text(original_config_text)

	return run_checks([
		assert_eq(str(manager.call("get_battle_review_api_config_path")), CONFIG_PATH, "GameManager should expose the fixed user:// config path"),
		assert_eq(str(config.get("endpoint", "")), "", "missing config file should keep default endpoint"),
		assert_eq(str(config.get("api_key", "")), "", "missing config file should keep default api_key"),
		assert_eq(str(config.get("model", "")), "", "missing config file should keep default model"),
		assert_eq(float(config.get("timeout_seconds", 0.0)), 30.0, "missing config file should keep default timeout"),
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
