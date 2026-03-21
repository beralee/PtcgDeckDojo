## 宝可梦道具伤害修正 - 附着时增加/减少伤害
## 适用: "力量头带"（攻击+30对ex）、"学习装置"等
## 参数: damage_modifier, modifier_type, target_filter
class_name EffectToolDamageModifier
extends BaseEffect

## 伤害修正量
var damage_modifier: int = 0
## 修正类型: "attack" 或 "defense"
var modifier_type: String = "attack"
## 仅对特定目标生效: "" = 全部, "ex" = 仅对ex宝可梦, "V" = 仅对V宝可梦
var target_filter: String = ""


func _init(amount: int = 0, type: String = "attack", filter: String = "") -> void:
	damage_modifier = amount
	modifier_type = type
	target_filter = filter


## 检查目标是否匹配过滤条件
func matches_target(slot: PokemonSlot) -> bool:
	if target_filter == "":
		return true
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	match target_filter:
		"ex":
			return cd.mechanic == "ex"
		"V":
			return cd.mechanic == "V"
		"VSTAR":
			return cd.mechanic == "VSTAR"
		"VMAX":
			return cd.mechanic == "VMAX"
		"rule_box":
			return cd.is_rule_box_pokemon()
		_:
			return cd.mechanic == target_filter


func is_attack_modifier() -> bool:
	return modifier_type == "attack"


func is_defense_modifier() -> bool:
	return modifier_type == "defense"


func get_description() -> String:
	var filter_str: String = ""
	if target_filter != "":
		filter_str = "（对%s宝可梦）" % target_filter
	var type_str: String = "攻击伤害" if modifier_type == "attack" else "受到伤害"
	var sign: String = "+" if damage_modifier > 0 else ""
	return "%s%s%d%s" % [type_str, sign, damage_modifier, filter_str]
