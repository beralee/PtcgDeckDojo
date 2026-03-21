## 放逐区道具数×伤害加成效果 - 废品短路（洛托姆V）
## 计算己方弃牌区（简化代替放逐区）中的道具卡数量，追加对应伤害
## 参数:
##   damage_per_tool  每张道具卡追加的伤害值（默认40）
class_name AttackScrapShort
extends BaseEffect

## 每张道具卡追加的伤害值
var damage_per_tool: int = 40


func _init(per_tool: int = 40) -> void:
	damage_per_tool = per_tool


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	var pi: int = top_card.owner_index
	var player: PlayerState = state.players[pi]

	# 统计己方弃牌区中的道具卡数量
	# 注：放逐区尚未独立追踪，简化为弃牌区中标记了 lost_zone=true 的道具卡
	# 或直接统计弃牌区所有道具卡（完全简化版）
	var tool_count: int = 0
	for card: CardInstance in player.discard_pile:
		var cd: CardData = card.card_data
		if cd == null:
			continue
		# 统计道具类卡牌（Tool 类型）
		if cd.card_type == "Tool":
			tool_count += 1

	# 追加伤害
	var bonus_damage: int = damage_per_tool * tool_count
	defender.damage_counters += bonus_damage


func get_description() -> String:
	return "废品短路：己方弃牌区中每有1张道具卡，追加%d伤害。" % damage_per_tool
