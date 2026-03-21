## 竞技场抽卡效果 - 每回合各玩家可从竞技场额外抽卡
## 适用: "每回合1次，当前回合玩家可额外抽1张"等竞技场
## 注意: 竞技场效果在回合开始时由 EffectProcessor 查询可用性
## 参数: draw_count, once_per_turn
class_name EffectStadiumDraw
extends BaseEffect

## 抽卡数量
var draw_count: int = 1
## 是否每回合仅限1次
var once_per_turn: bool = true


func _init(count: int = 1, once: bool = true) -> void:
	draw_count = count
	once_per_turn = once


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


## 竞技场效果通过手动使用触发（玩家选择"使用竞技场效果"）
func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	player.draw_cards(draw_count)


func get_description() -> String:
	var once_str: String = "（每回合1次）" if once_per_turn else ""
	return "当前回合玩家可抽%d张牌%s" % [draw_count, once_str]
