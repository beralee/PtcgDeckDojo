## 备战区免疫特性效果 - 大牙狸（毫不在意）
## 当此宝可梦在备战区时，不受对手招式伤害影响
## 被动特性，由 EffectProcessor 在计算对备战区造成伤害时调用 has_bench_immune()
class_name AbilityBenchImmune
extends BaseEffect

## 匹配的特性名称（用于在 abilities 列表中识别）
const ABILITY_NAME: String = "毫不在意"


## 被动特性无需主动执行
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需执行动作
	pass


## 检查指定 PokemonSlot 是否拥有"毫不在意"特性
## EffectProcessor 应在对备战区宝可梦施加招式伤害前调用此方法
## 若返回 true，且该宝可梦当前在备战区，则跳过招式伤害
static func has_bench_immune(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var cd: CardData = top.card_data
	if cd == null:
		return false
	# 遍历卡牌的 abilities 列表，查找"毫不在意"特性
	var abilities: Variant = cd.abilities
	if abilities == null:
		return false
	for ability: Variant in abilities:
		if ability is Dictionary:
			var ab_name: Variant = ability.get("name", "")
			if ab_name == ABILITY_NAME:
				return true
	return false


func get_description() -> String:
	return "特性【毫不在意】：此宝可梦在备战区时，不受对手招式伤害。"
