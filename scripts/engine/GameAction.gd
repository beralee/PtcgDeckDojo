## 游戏操作记录 - 用于动作日志、回放和撤销
class_name GameAction
extends RefCounted

enum ActionType {
	GAME_START,       # 游戏开始
	GAME_END,         # 游戏结束
	TURN_START,       # 回合开始
	TURN_END,         # 回合结束
	DRAW_CARD,        # 抽牌
	MULLIGAN,         # 重抽（无基础宝可梦）
	SETUP_PLACE_ACTIVE,   # 准备阶段放出战斗宝可梦
	SETUP_PLACE_BENCH,    # 准备阶段放出备战宝可梦
	SETUP_SET_PRIZES,     # 摆放奖赏卡
	PLAY_POKEMON,     # 从手牌放出基础宝可梦到备战区
	EVOLVE,           # 进化宝可梦
	ATTACH_ENERGY,    # 附着能量
	PLAY_TRAINER,     # 使用训练家卡
	PLAY_TOOL,        # 附着道具卡
	PLAY_STADIUM,     # 使出竞技场
	USE_STADIUM,      # 使用竞技场效果
	USE_ABILITY,      # 使用特性
	RETREAT,          # 撤退
	ATTACK,           # 使用招式
	COIN_FLIP,        # 投币
	KNOCKOUT,         # 宝可梦昏厥
	TAKE_PRIZE,       # 拿取奖赏卡
	SEND_OUT,         # 派出宝可梦（昏厥后替换）
	STATUS_APPLIED,   # 特殊状态施加
	STATUS_REMOVED,   # 特殊状态解除
	DAMAGE_DEALT,     # 造成伤害
	HEAL,             # 治疗
	POKEMON_CHECK,    # 宝可梦检查
	DISCARD,          # 弃牌
	SHUFFLE_DECK,     # 洗牌
}

## 操作类型
var action_type: ActionType
## 执行操作的玩家索引（-1表示游戏系统）
var player_index: int = -1
## 操作附加数据
var data: Dictionary = {}
## 操作时间戳（回合数）
var turn_number: int = 0
## 操作描述文本（用于日志显示）
var description: String = ""


## 创建一个操作记录
static func create(
	type: ActionType,
	player: int,
	action_data: Dictionary,
	turn: int,
	desc: String = ""
) -> GameAction:
	var action := GameAction.new()
	action.action_type = type
	action.player_index = player
	action.data = action_data
	action.turn_number = turn
	action.description = desc
	return action


## 序列化为 Dictionary（用于日志导出）
func to_dict() -> Dictionary:
	return {
		"action_type": action_type,
		"player_index": player_index,
		"data": data,
		"turn_number": turn_number,
		"description": description,
	}
