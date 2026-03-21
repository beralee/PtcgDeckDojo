## 宝可梦道具撤退修正 - 附着时减少撤退费用
## 适用: "气球"（撤退费用-2）等
## 参数: retreat_modifier
class_name EffectToolRetreatModifier
extends BaseEffect

## 撤退费用修正（负数=减少）
var retreat_modifier: int = -1


func _init(modifier: int = -1) -> void:
	retreat_modifier = modifier


func get_description() -> String:
	return "撤退费用%d" % retreat_modifier
