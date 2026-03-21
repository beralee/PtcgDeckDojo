## 特殊能量持续修正效果 - 附着期间提供持续伤害/撤退修正
## 适用: 附着期间攻击伤害+10, 或撤退费用-1 等
## 参数: damage_modifier, retreat_modifier, energy_type_provides
class_name EffectSpecialEnergyModifier
extends BaseEffect

## 攻击伤害修正（附着在攻击者身上时生效）
var damage_modifier: int = 0
## 撤退费用修正（负数=减少）
var retreat_modifier: int = 0
## 提供的能量类型（空=无色 "C"）
var energy_type_provides: String = "C"
## 提供的能量数量
var energy_count: int = 1


func _init(dmg_mod: int = 0, retreat_mod: int = 0, energy_type: String = "C", count: int = 1) -> void:
	damage_modifier = dmg_mod
	retreat_modifier = retreat_mod
	energy_type_provides = energy_type
	energy_count = count


func get_description() -> String:
	var parts: Array[String] = []
	if energy_count > 1:
		parts.append("提供%d个%s能量" % [energy_count, energy_type_provides])
	if damage_modifier != 0:
		var sign: String = "+" if damage_modifier > 0 else ""
		parts.append("攻击伤害%s%d" % [sign, damage_modifier])
	if retreat_modifier != 0:
		parts.append("撤退费用%d" % retreat_modifier)
	return "，".join(parts) if not parts.is_empty() else "特殊能量"
