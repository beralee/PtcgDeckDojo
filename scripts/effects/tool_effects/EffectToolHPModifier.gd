## 宝可梦道具HP修正 - 附着时增加最大HP
## 适用: "突击背心"（HP+50但不能使用特性）等
## 参数: hp_modifier, disable_ability
class_name EffectToolHPModifier
extends BaseEffect

## 最大HP增加量
var hp_modifier: int = 0
## 是否禁用特性
var disable_ability: bool = false


func _init(hp_mod: int = 50, disable: bool = false) -> void:
	hp_modifier = hp_mod
	disable_ability = disable


func get_description() -> String:
	var parts: Array[String] = []
	if hp_modifier != 0:
		parts.append("HP+%d" % hp_modifier)
	if disable_ability:
		parts.append("无法使用特性")
	return "，".join(parts)
