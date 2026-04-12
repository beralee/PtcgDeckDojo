## 全局游戏管理器 - 跨场景共享数据和场景切换
extends Node

## 游戏模式
enum GameMode {
	TWO_PLAYER,  ## 双人操控
	VS_AI,       ## 对战AI
}

## 当前选择的游戏模式
var current_mode: GameMode = GameMode.TWO_PLAYER
## 选择的卡组（两个卡组ID）
var selected_deck_ids: Array[int] = [0, 0]
## AI 难度等级 (0=简单, 1=普通, 2=困难, 3=专家)
var ai_difficulty: int = 1
var ai_selection: Dictionary = {
	"source": "default",
	"version_id": "",
	"agent_config_path": "",
	"value_net_path": "",
	"action_scorer_path": "",
	"interaction_scorer_path": "",
	"display_name": "",
}
## AI 卡组策略 ("generic" | "gardevoir_greedy" | "gardevoir_mcts" | "miraidon_greedy" | "miraidon_mcts")
var ai_deck_strategy: String = "generic"
## 先攻选择 (-1=随机, 0=玩家1, 1=玩家2)
var first_player_choice: int = -1
## 对战背景资源路径
var selected_battle_background: String = "res://assets/ui/background.png"
var selected_battle_music_id: String = "none"
var battle_bgm_volume_percent: int = 70

## 当前游戏状态（对战中有效）
var game_state: GameState = null

## 场景路径
const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_DECK_MANAGER := "res://scenes/deck_manager/DeckManager.tscn"
const SCENE_BATTLE_SETUP := "res://scenes/battle_setup/BattleSetup.tscn"
const SCENE_BATTLE := "res://scenes/battle/BattleScene.tscn"
const SCENE_DECK_EDITOR := "res://scenes/deck_editor/DeckEditor.tscn"
const SCENE_REPLAY_BROWSER := "res://scenes/replay_browser/ReplayBrowser.tscn"
const SCENE_SETTINGS := "res://scenes/settings/Settings.tscn"
const BATTLE_REVIEW_API_CONFIG_PATH := "user://battle_review_api.json"

var _battle_replay_launch: Dictionary = {}
var _deck_editor_deck_id: int = -1
var _deck_editor_return_context: Dictionary = {}


## 切换到指定场景
func goto_scene(path: String) -> void:
	# 延迟调用以避免在信号处理中切换场景
	call_deferred("_deferred_goto_scene", path)


func _deferred_goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


## 切换到主菜单
func goto_main_menu() -> void:
	goto_scene(SCENE_MAIN_MENU)


## 切换到卡组管理
func goto_deck_manager() -> void:
	goto_scene(SCENE_DECK_MANAGER)


## 切换到对战设置
func goto_battle_setup() -> void:
	goto_scene(SCENE_BATTLE_SETUP)


## 切换到对战场景
func goto_battle() -> void:
	goto_scene(SCENE_BATTLE)


func goto_deck_editor(deck_id: int, return_context: Dictionary = {}) -> void:
	_deck_editor_deck_id = deck_id
	_deck_editor_return_context = return_context.duplicate(true)
	goto_scene(SCENE_DECK_EDITOR)


func consume_deck_editor_id() -> int:
	var id := _deck_editor_deck_id
	_deck_editor_deck_id = -1
	return id


func set_deck_editor_return_context(context: Dictionary) -> void:
	_deck_editor_return_context = context.duplicate(true)


func consume_deck_editor_return_context() -> Dictionary:
	var context := _deck_editor_return_context.duplicate(true)
	_deck_editor_return_context = {}
	return context


func goto_replay_browser() -> void:
	goto_scene(SCENE_REPLAY_BROWSER)


func goto_settings() -> void:
	goto_scene(SCENE_SETTINGS)


func set_battle_replay_launch(launch: Dictionary) -> void:
	_battle_replay_launch = launch.duplicate(true)


func consume_battle_replay_launch() -> Dictionary:
	var launch := _battle_replay_launch.duplicate(true)
	_battle_replay_launch = {}
	return launch


func get_battle_review_api_config_path() -> String:
	return BATTLE_REVIEW_API_CONFIG_PATH


func get_battle_review_api_config() -> Dictionary:
	var config := _default_battle_review_api_config()
	if not FileAccess.file_exists(BATTLE_REVIEW_API_CONFIG_PATH):
		return config
	var file := FileAccess.open(BATTLE_REVIEW_API_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return config
	var raw_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return config
	var parsed_dict: Dictionary = parsed
	for key: String in ["endpoint", "api_key", "model"]:
		if parsed_dict.has(key):
			config[key] = str(parsed_dict[key])
	if parsed_dict.has("timeout_seconds"):
		config["timeout_seconds"] = float(parsed_dict["timeout_seconds"])
	return config


func _default_battle_review_api_config() -> Dictionary:
	return {
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "",
		"model": "openai/gpt-5.4",
		"timeout_seconds": 60.0,
	}


func reset_ai_selection() -> void:
	ai_selection = {
		"source": "default",
		"version_id": "",
		"agent_config_path": "",
		"value_net_path": "",
		"action_scorer_path": "",
		"interaction_scorer_path": "",
		"display_name": "",
	}
