## 清除古龙水 - 在回合结束前，对手战斗宝可梦的特性全部消除
## 简化实现：设置标记，由 EffectProcessor 查询时检查
class_name EffectCancelCologne
extends BaseEffect


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var opp: PlayerState = state.players[1 - pi]
	# 在对手战斗宝可梦上添加「特性消除」效果标记
	if opp.active_pokemon != null:
		# 使用 effects 数组存储临时效果标记
		# 这个效果在回合结束时应该被清除
		opp.active_pokemon.effects.append({
			"type": "ability_disabled",
			"source": "cancel_cologne",
			"turn": state.turn_number,
		})


func get_description() -> String:
	return "在回合结束前，对手战斗宝可梦的特性全部消除"
