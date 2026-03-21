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
## 先攻选择 (-1=随机, 0=玩家1, 1=玩家2)
var first_player_choice: int = -1

## 当前游戏状态（对战中有效）
var game_state: GameState = null

## 场景路径
const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_DECK_MANAGER := "res://scenes/deck_manager/DeckManager.tscn"
const SCENE_BATTLE_SETUP := "res://scenes/battle_setup/BattleSetup.tscn"
const SCENE_BATTLE := "res://scenes/battle/BattleScene.tscn"


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
