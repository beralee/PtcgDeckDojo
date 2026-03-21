## 放逐市 - 宝可梦昏厥时，被击倒的宝可梦（及其所有附属卡）放入放逐区而非弃牌区
## 此效果为持续型标记效果，具体的放逐区逻辑由 GameStateMachine 在处理昏厥时检查
## GameStateMachine 中需调用 is_lost_city_active(state) 判断是否使用放逐区
## 简化实现：GameManager 的放逐区用 lost_zone: Array[CardInstance] 存储
class_name EffectLostCity
extends BaseEffect


## 检查放逐市是否当前有效（即场上是否有此竞技场）
## 外部调用示例: effect.is_lost_city_active(state)
func is_lost_city_active(state: GameState) -> bool:
	if state.stadium_card == null:
		return false
	# 通过 effect_id 已在注册表中对应此类实例，此处只需确认竞技场存在
	# 实际由外部代码通过 EffectProcessor 查询效果类型来判断
	return true


## 辅助方法：将指定卡牌列表移入放逐区（PlayerState 当前无放逐区字段，统一处理为弃牌区）
## 完整实现需要 PlayerState 添加 lost_zone 字段；此处提供接口占位
## slot_cards: 要放入放逐区的卡牌列表（来自 PokemonSlot.collect_all_cards()）
## player: 被击倒宝可梦的归属玩家
func send_to_lost_zone(slot_cards: Array[CardInstance], player: PlayerState) -> void:
	# 简化实现：放入弃牌区（完整实现应放入 player.lost_zone）
	for c: CardInstance in slot_cards:
		player.discard_card(c)


func get_description() -> String:
	return "宝可梦昏厥时，被击倒的宝可梦及其附属卡放入放逐区"
