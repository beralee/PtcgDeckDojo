## 紧急滑板 - 撤退费用-1，若宝可梦剩余HP≤30则撤退费用变为0
## 由 EffectProcessor.get_retreat_cost_modifier 在计算撤退费用时查询
## 注意：此效果与 EffectToolRetreatModifier 不同，具有动态HP判断逻辑
class_name EffectToolRescueBoard
extends BaseEffect

## 标准撤退费用减少量
const NORMAL_MODIFIER: int = -1
## HP低时的撤退费用阈值（剩余HP不超过此值时免费撤退）
const LOW_HP_THRESHOLD: int = 30


## 计算此道具对指定槽位的撤退费用修正量
## slot: 附有此道具的宝可梦槽位
## 返回: 撤退费用修正值（负数=减少）
func get_retreat_modifier(slot: PokemonSlot) -> int:
	var remaining_hp: int = slot.get_remaining_hp()
	# 剩余HP≤30时，撤退费用变为0（返回足够大的负数由 maxi(0,...) 截断）
	if remaining_hp <= LOW_HP_THRESHOLD:
		return -999
	# 否则正常减少1点
	return NORMAL_MODIFIER


func get_description() -> String:
	return "撤退费用-1；若剩余HP≤%d则撤退费用变为0" % LOW_HP_THRESHOLD
