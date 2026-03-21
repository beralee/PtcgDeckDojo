## 宝可梦道具HP修正 - 附着时增加最大HP
## 适用: "突击背心"（HP+50但不能使用特性）等
## 参数: hp_modifier, disable_ability, basic_only
class_name EffectToolHPModifier
extends BaseEffect

## 最大HP增加量
var hp_modifier: int = 0
## 是否禁用特性
var disable_ability: bool = false
## 是否仅对基础宝可梦生效
var basic_only: bool = false


func _init(hp_mod: int = 50, disable: bool = false, basic: bool = false) -> void:
	hp_modifier = hp_mod
	disable_ability = disable
	basic_only = basic


func get_hp_modifier(slot: PokemonSlot, _state: GameState = null) -> int:
	return hp_modifier if _applies_to(slot) else 0


func disables_ability(slot: PokemonSlot, _state: GameState = null) -> bool:
	return disable_ability and _applies_to(slot)


func _applies_to(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	if not basic_only:
		return true
	var card_data: CardData = slot.get_card_data()
	return card_data != null and card_data.stage == "Basic"


func get_description() -> String:
	var parts: Array[String] = []
	if hp_modifier != 0:
		parts.append(("基础宝可梦HP+%d" if basic_only else "HP+%d") % hp_modifier)
	if disable_ability:
		parts.append("无法使用特性")
	return "，".join(parts)
