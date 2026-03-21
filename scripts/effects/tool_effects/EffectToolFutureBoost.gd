## 驱劲能量 未来 - 附着于"未来"宝可梦时，撤退费用变为0，攻击伤害+20
## 仅对带有 "Future" 标签（is_tags 中含 "Future"）的宝可梦生效
## 撤退费用效果由 EffectProcessor.get_retreat_cost_modifier 查询时使用
## 攻击加成效果由 EffectProcessor.get_attacker_modifier 查询时使用
class_name EffectToolFutureBoost
extends BaseEffect

## 攻击伤害加成量
const DAMAGE_BONUS: int = 20


## 检查宝可梦是否拥有 "Future" 标签
func _is_future_pokemon(slot: PokemonSlot) -> bool:
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	return cd.is_future_pokemon()


## 获取撤退费用修正量
## 若宝可梦是未来宝可梦，返回一个足以将撤退费用归零的极大负数
## 实际归零处理由 EffectProcessor.get_effective_retreat_cost 中的 maxi(0, ...) 保证
func get_retreat_modifier(slot: PokemonSlot) -> int:
	if not _is_future_pokemon(slot):
		return 0
	# 返回 -999 确保撤退费用被 maxi(0, ...) 截断为 0
	return -999


## 获取攻击伤害加成
## 若宝可梦是未来宝可梦，返回 +20
func get_attack_bonus(slot: PokemonSlot) -> int:
	if not _is_future_pokemon(slot):
		return 0
	return DAMAGE_BONUS


func get_description() -> String:
	return "未来宝可梦撤退费用变为0，攻击伤害+%d" % DAMAGE_BONUS
