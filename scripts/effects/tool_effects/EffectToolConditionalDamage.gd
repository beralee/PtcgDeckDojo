## 条件伤害加成道具 - 满足特定条件时提供攻击伤害加成
## 适用: "极限腰带"（对手ex时+30）、"讲究腰带"（对手V时+30）、"不服输头带"（己方奖赏卡多时+20）等
## 参数: damage_bonus (int), condition (String)
## 条件类型:
##   "ex"          - 对手战斗宝可梦是ex时生效
##   "V"           - 对手战斗宝可梦是V时生效
##   "prize_behind" - 己方奖赏卡数量多于对手时生效
class_name EffectToolConditionalDamage
extends BaseEffect

## 伤害加成量
var damage_bonus: int = 0
## 触发条件类型
var condition: String = ""


func _init(bonus: int = 0, cond: String = "") -> void:
	damage_bonus = bonus
	condition = cond


## 检查当前游戏状态下条件是否满足
## attacker_slot: 持有此道具的攻击方宝可梦槽位
## state: 当前游戏状态
func is_active(attacker_slot: PokemonSlot, state: GameState) -> bool:
	# 获取攻击者归属的玩家索引
	var top: CardInstance = attacker_slot.get_top_card()
	if top == null:
		return false
	var attacker_pi: int = top.owner_index
	var opponent_pi: int = 1 - attacker_pi

	match condition:
		"ex":
			# 对手战斗宝可梦是ex时生效
			var opp_active: PokemonSlot = state.players[opponent_pi].active_pokemon
			if opp_active == null:
				return false
			var opp_data: CardData = opp_active.get_card_data()
			if opp_data == null:
				return false
			return opp_data.mechanic == "ex"

		"V":
			# 对手战斗宝可梦是V时生效（包括V、VSTAR、VMAX）
			var opp_active: PokemonSlot = state.players[opponent_pi].active_pokemon
			if opp_active == null:
				return false
			var opp_data: CardData = opp_active.get_card_data()
			if opp_data == null:
				return false
			return opp_data.mechanic in ["V", "VSTAR", "VMAX"]

		"prize_behind":
			# 己方奖赏卡数量多于对手时生效（即己方剩余奖赏卡更多，处于落后状态）
			var my_prizes: int = state.players[attacker_pi].prizes.size()
			var opp_prizes: int = state.players[opponent_pi].prizes.size()
			return my_prizes > opp_prizes

		_:
			return false


## 返回伤害加成量
func get_bonus() -> int:
	return damage_bonus


func get_description() -> String:
	var cond_map: Dictionary = {
		"ex": "对手战斗宝可梦为ex时",
		"V": "对手战斗宝可梦为V时",
		"prize_behind": "己方奖赏卡多于对手时",
	}
	var cond_str: String = cond_map.get(condition, condition)
	return "%s攻击伤害+%d" % [cond_str, damage_bonus]
