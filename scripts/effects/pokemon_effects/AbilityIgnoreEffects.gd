## 无视招式效果特性 - 火恐龙（闪焰之幕）/ 卡比兽（无畏脂肪）
## 此宝可梦不受对手招式效果影响（仍受伤害，但附加效果无效）
## 被动特性，由 EffectProcessor 在尝试施加招式效果前调用 has_ignore_effects()
class_name AbilityIgnoreEffects
extends BaseEffect

## 支持的特性名称列表
const ABILITY_NAMES: Array = ["闪焰之幕", "无畏脂肪"]


## 被动特性无需主动执行
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需执行动作
	pass


## 检查指定 PokemonSlot 是否拥有无视招式效果的特性
## EffectProcessor 应在对宝可梦施加招式附加效果（状态/弃牌等）前调用此方法
## 若返回 true，则跳过招式的附加效果（伤害照常计算）
static func has_ignore_effects(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var cd: CardData = top.card_data
	if cd == null:
		return false
	# 遍历卡牌的 abilities 列表，查找匹配的特性名称
	var abilities: Variant = cd.abilities
	if abilities == null:
		return false
	for ability: Variant in abilities:
		if ability is Dictionary:
			var ab_name: Variant = ability.get("name", "")
			if ab_name is String:
				for target_name: String in ABILITY_NAMES:
					if (ab_name as String).contains(target_name):
						return true
	return false


func get_description() -> String:
	return "特性【闪焰之幕/无畏脂肪】：此宝可梦不受对手招式效果影响。"
