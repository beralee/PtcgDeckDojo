## 全局游戏管理器 - 跨场景共享数据和场景切换
extends Node

const SwissTournamentScript := preload("res://scripts/tournament/SwissTournament.gd")

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
	"opening_mode": "default",
	"fixed_deck_order_path": "",
}
## AI 卡组策略 ("generic" | "gardevoir_greedy" | "gardevoir_mcts" | "miraidon_greedy" | "miraidon_mcts")
var ai_deck_strategy: String = "generic"
## 先攻选择 (-1=随机, 0=玩家1, 1=玩家2)
var first_player_choice: int = -1
## 对战背景资源路径
var selected_battle_background: String = "res://assets/ui/background.png"
var selected_battle_music_id: String = "none"
var battle_bgm_volume_percent: int = 20

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
const SCENE_TOURNAMENT_DECK_SELECT := "res://scenes/tournament/TournamentDeckSelect.tscn"
const SCENE_TOURNAMENT_SETUP := "res://scenes/tournament/TournamentSetup.tscn"
const SCENE_TOURNAMENT_OVERVIEW := "res://scenes/tournament/TournamentOverview.tscn"
const SCENE_TOURNAMENT_STANDINGS := "res://scenes/tournament/TournamentStandings.tscn"
const BATTLE_REVIEW_API_CONFIG_PATH := "user://battle_review_api.json"
const BATTLE_SETUP_SETTINGS_PATH := "user://battle_setup.json"
const TOURNAMENT_SAVE_PATH := "user://tournament_mode_save.json"
const DEFAULT_BATTLE_BGM_VOLUME_PERCENT := 20
const DEFAULT_BATTLE_REVIEW_MODEL := "kimi-k2.6"
const SUPPORTED_BATTLE_REVIEW_MODELS: Array[Dictionary] = [
	{
		"id": "kimi-k2.6",
		"label": "Kimi K2.6",
	},
	{
		"id": "z-ai/glm-5.1",
		"label": "GLM 5.1",
	},
	{
		"id": "qwen/qwen3.6-plus",
		"label": "Qwen 3.6 Plus",
	},
	{
		"id": "deepseek/deepseek-chat",
		"label": "DeepSeek chat",
	},
	{
		"id": "gpt-5.5",
		"label": "gpt-5.5",
	},
	{
		"id": "x-ai/grok-4.2-fast-non-reasoning",
		"label": "x-ai/grok-4.2-fast-non-reasoning",
	},
	{
		"id": "claude-sonnet-4-6",
		"label": "claude-sonnet-4-6",
	},
]

var _battle_replay_launch: Dictionary = {}
var _deck_editor_deck_id: int = -1
var _deck_editor_return_context: Dictionary = {}
var tournament_selected_player_deck_id: int = -1
var current_tournament: RefCounted = null
var battle_player_display_names: Array[String] = ["", ""]
var tournament_battle_in_progress: bool = false
var suppress_scene_navigation_for_tests: bool = false
var last_requested_scene_path: String = ""


func _ready() -> void:
	load_battle_setup_preferences()
	reload_tournament_state_from_disk()
	_ensure_desktop_window_size()


func _ensure_desktop_window_size() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var desired_width := int(ProjectSettings.get_setting("display/window/size/window_width", ProjectSettings.get_setting("display/window/size/viewport_width", 1600)))
	var desired_height := int(ProjectSettings.get_setting("display/window/size/window_height", ProjectSettings.get_setting("display/window/size/viewport_height", 900)))
	if desired_width <= 0 or desired_height <= 0:
		return
	var desired := Vector2i(desired_width, desired_height)
	var current := DisplayServer.window_get_size()
	if current.x < desired.x or current.y < desired.y:
		DisplayServer.window_set_size(desired)


## 切换到指定场景
func goto_scene(path: String) -> void:
	# 延迟调用以避免在信号处理中切换场景
	if suppress_scene_navigation_for_tests:
		last_requested_scene_path = path
		return
	call_deferred("_deferred_goto_scene", path)


func set_scene_navigation_suppressed_for_tests(suppressed: bool) -> void:
	suppress_scene_navigation_for_tests = suppressed
	if not suppressed:
		last_requested_scene_path = ""


func consume_last_requested_scene_path() -> String:
	var path := last_requested_scene_path
	last_requested_scene_path = ""
	return path


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


func resolve_selected_battle_deck(player_index: int) -> DeckData:
	if player_index < 0 or player_index >= selected_deck_ids.size():
		return null
	var deck_id := int(selected_deck_ids[player_index])
	if current_mode == GameMode.VS_AI and player_index == 1:
		var ai_deck: DeckData = CardDatabase.get_ai_deck(deck_id)
		if ai_deck != null:
			return ai_deck
	return CardDatabase.get_deck(deck_id)


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


func goto_tournament_deck_select() -> void:
	goto_scene(SCENE_TOURNAMENT_DECK_SELECT)


func goto_tournament_setup() -> void:
	goto_scene(SCENE_TOURNAMENT_SETUP)


func goto_tournament_overview() -> void:
	goto_scene(SCENE_TOURNAMENT_OVERVIEW)


func goto_tournament_standings() -> void:
	goto_scene(SCENE_TOURNAMENT_STANDINGS)


func load_battle_setup_preferences() -> void:
	selected_battle_music_id = "none"
	battle_bgm_volume_percent = DEFAULT_BATTLE_BGM_VOLUME_PERCENT
	if not FileAccess.file_exists(BATTLE_SETUP_SETTINGS_PATH):
		return
	var file := FileAccess.open(BATTLE_SETUP_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if not data is Dictionary:
		return
	selected_battle_music_id = str(data.get("battle_music_id", selected_battle_music_id))
	battle_bgm_volume_percent = clampi(int(data.get("battle_bgm_volume_percent", battle_bgm_volume_percent)), 0, 100)


func set_battle_replay_launch(launch: Dictionary) -> void:
	_battle_replay_launch = launch.duplicate(true)


func consume_battle_replay_launch() -> Dictionary:
	var launch := _battle_replay_launch.duplicate(true)
	_battle_replay_launch = {}
	return launch


func get_battle_review_api_config_path() -> String:
	return BATTLE_REVIEW_API_CONFIG_PATH


func get_supported_battle_review_models() -> Array[Dictionary]:
	return SUPPORTED_BATTLE_REVIEW_MODELS.duplicate(true)


func normalize_battle_review_model(model_id: String) -> String:
	var normalized := model_id.strip_edges()
	match normalized:
		"deepseek-chat":
			return "deepseek/deepseek-chat"
		"deepseek-v4-flash", "deepseek/deepseek-v4-flash":
			return "deepseek/deepseek-chat"
	for model: Dictionary in SUPPORTED_BATTLE_REVIEW_MODELS:
		if str(model.get("id", "")) == normalized:
			return normalized
	return DEFAULT_BATTLE_REVIEW_MODEL


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
	for key: String in ["endpoint", "api_key", "ai_personality"]:
		if parsed_dict.has(key):
			config[key] = str(parsed_dict[key])
	if parsed_dict.has("model"):
		config["model"] = normalize_battle_review_model(str(parsed_dict["model"]))
	if parsed_dict.has("timeout_seconds"):
		config["timeout_seconds"] = float(parsed_dict["timeout_seconds"])
	if parsed_dict.has("ai_test_passed"):
		config["ai_test_passed"] = bool(parsed_dict["ai_test_passed"])
	if parsed_dict.has("ai_test_signature"):
		config["ai_test_signature"] = str(parsed_dict["ai_test_signature"])
	return config


func _default_battle_review_api_config() -> Dictionary:
	return {
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "",
		"model": DEFAULT_BATTLE_REVIEW_MODEL,
		"timeout_seconds": 60.0,
		"ai_personality": "",
		"ai_test_passed": false,
		"ai_test_signature": "",
	}


func battle_review_ai_config_signature(config: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(config.get("endpoint", "")).strip_edges(),
		str(config.get("api_key", "")).strip_edges(),
		normalize_battle_review_model(str(config.get("model", ""))),
	]


func is_battle_review_ai_ready_for_llm_opponents() -> bool:
	var config := get_battle_review_api_config()
	if str(config.get("endpoint", "")).strip_edges() == "":
		return false
	if str(config.get("api_key", "")).strip_edges() == "":
		return false
	if not bool(config.get("ai_test_passed", false)):
		return false
	return str(config.get("ai_test_signature", "")) == battle_review_ai_config_signature(config)


func reset_ai_selection() -> void:
	ai_selection = {
		"source": "default",
		"version_id": "",
		"agent_config_path": "",
		"value_net_path": "",
		"action_scorer_path": "",
		"interaction_scorer_path": "",
		"display_name": "",
		"opening_mode": "default",
		"fixed_deck_order_path": "",
	}


func set_battle_player_display_names(names: Array[String]) -> void:
	battle_player_display_names = ["", ""]
	for index: int in min(names.size(), 2):
		battle_player_display_names[index] = str(names[index]).strip_edges()


func clear_battle_player_display_names() -> void:
	battle_player_display_names = ["", ""]


func resolve_battle_player_display_name(player_index: int) -> String:
	if player_index < 0 or player_index >= 2:
		return "玩家%d" % (player_index + 1)
	var explicit_name: String = ""
	if player_index < battle_player_display_names.size():
		explicit_name = str(battle_player_display_names[player_index]).strip_edges()
	if explicit_name != "":
		return explicit_name
	if current_mode == GameMode.VS_AI and player_index == 1:
		var ai_name := str(ai_selection.get("display_name", "")).strip_edges()
		if ai_name != "":
			return ai_name
	return "玩家%d" % (player_index + 1)


func set_tournament_selected_player_deck_id(deck_id: int) -> void:
	tournament_selected_player_deck_id = deck_id


func start_swiss_tournament(player_name: String, tournament_size: int) -> void:
	if tournament_selected_player_deck_id <= 0:
		return
	var tournament := SwissTournamentScript.new()
	tournament.setup(
		player_name,
		tournament_selected_player_deck_id,
		tournament_size,
		0,
		is_battle_review_ai_ready_for_llm_opponents()
	)
	current_tournament = tournament
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()


func has_active_tournament() -> bool:
	return current_tournament != null


func is_tournament_battle_active() -> bool:
	return current_tournament != null and tournament_battle_in_progress


func mark_current_battle_as_non_tournament() -> void:
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	if current_tournament != null:
		_persist_tournament_state()


func clear_tournament() -> void:
	current_tournament = null
	tournament_selected_player_deck_id = -1
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()


func discard_tournament_keep_selected_deck() -> void:
	current_tournament = null
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()


func prepare_current_tournament_battle() -> bool:
	if current_tournament == null:
		return false
	var pairing: Dictionary = current_tournament.prepare_next_round()
	if pairing.is_empty():
		return false
	var player_id := int(current_tournament.player_participant_id)
	var opponent_id := int(pairing.get("player_b_id", -1))
	if int(pairing.get("player_a_id", -1)) != player_id:
		opponent_id = int(pairing.get("player_a_id", -1))
	selected_deck_ids = [
		int(current_tournament.player_deck_id),
		int(current_tournament.participant_deck_id(opponent_id)),
	]
	set_battle_player_display_names([
		str(current_tournament.player_name),
		str(current_tournament.participant_display_name(opponent_id)),
	])
	current_mode = GameMode.VS_AI
	first_player_choice = -1
	reset_ai_selection()
	# Tournament opponents should use their own deck-local rule strategy.
	# Do not inherit the manual AI strategy variant selected in BattleSetup
	# (for example the Raging Bolt LLM variant) across modes.
	ai_deck_strategy = "generic"
	ai_selection["display_name"] = str(current_tournament.participant_display_name(opponent_id))
	if str(current_tournament.participant_ai_mode(opponent_id)) == "llm" and is_battle_review_ai_ready_for_llm_opponents():
		ai_deck_strategy = "raging_bolt_ogerpon_llm"
		ai_selection["display_name"] = "%s（LLM）" % str(current_tournament.participant_display_name(opponent_id))
	var fixed_order_path := str(current_tournament.participant_fixed_order_path(opponent_id))
	if fixed_order_path != "":
		ai_selection["opening_mode"] = "fixed_order"
		ai_selection["fixed_deck_order_path"] = fixed_order_path
	tournament_battle_in_progress = true
	_persist_tournament_state()
	return true


func finalize_current_tournament_battle(winner_index: int, reason: String) -> Dictionary:
	if current_tournament == null:
		return {}
	var player_won := winner_index == 0
	var summary: Dictionary = current_tournament.record_player_match(player_won, reason)
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()
	return summary


func forfeit_current_tournament_battle(reason: String = "技术负（中途退出）") -> Dictionary:
	if current_tournament == null:
		return {}
	var summary: Dictionary = current_tournament.record_player_match(false, reason)
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()
	return summary


func reload_tournament_state_from_disk() -> void:
	current_tournament = null
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	if not FileAccess.file_exists(TOURNAMENT_SAVE_PATH):
		return
	var file := FileAccess.open(TOURNAMENT_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		_delete_tournament_state_file()
		return
	file.close()
	if not (json.data is Dictionary):
		_delete_tournament_state_file()
		return
	var data: Dictionary = json.data
	var tournament_data: Dictionary = data.get("tournament", {})
	if tournament_data.is_empty():
		_delete_tournament_state_file()
		return
	var tournament := SwissTournamentScript.new()
	tournament.restore_state(tournament_data)
	current_tournament = tournament
	tournament_selected_player_deck_id = int(tournament.player_deck_id)
	tournament_battle_in_progress = bool(data.get("battle_in_progress", false))
	if tournament_battle_in_progress and not current_tournament.finished:
		forfeit_current_tournament_battle("技术负（中途退出）")
	else:
		_persist_tournament_state()


func has_resumable_tournament_overview() -> bool:
	return has_active_tournament() and current_tournament.current_round <= 0 and current_tournament.last_round_summary.is_empty()


func _persist_tournament_state() -> void:
	if current_tournament == null:
		_delete_tournament_state_file()
		return
	var payload := {
		"battle_in_progress": tournament_battle_in_progress,
		"tournament": current_tournament.serialize_state(),
	}
	var file := FileAccess.open(TOURNAMENT_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func _delete_tournament_state_file() -> void:
	if FileAccess.file_exists(TOURNAMENT_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TOURNAMENT_SAVE_PATH))
