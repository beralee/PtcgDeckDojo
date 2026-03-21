## 条件防御特性 - 藏玛然特（金属之盾）
## 附着基础钢能量时，受到的伤害-30
## 被动特性，由 EffectProcessor 在计算防守方受到伤害时调用 get_conditional_defense()
class_name AbilityConditionalDefense
extends BaseEffect

## 特性名称标识
const ABILITY_NAME: String = "金属之盾"
## 伤害减免量
const DAMAGE_REDUCTION: int = 30
## 钢属性能量类型代码
const METAL_TYPE: String = "M"


## 被动特性无需主动执行
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需执行动作
	pass


## 计算藏玛然特的条件减伤量
## 条件：该宝可梦拥有"金属之盾"特性，且附有至少一张基础钢能量
## 满足条件返回 -30（负数表示减伤），否则返回 0
static func get_conditional_defense(slot: PokemonSlot) -> int:
	# 检查是否拥有"金属之盾"特性
	if not _has_metal_shield(slot):
		return 0

	# 检查是否附着有基础钢能量（Basic Metal Energy）
	if not _has_basic_metal_energy(slot):
		return 0

	return -DAMAGE_REDUCTION


## 检查单个 PokemonSlot 是否拥有"金属之盾"特性
static func _has_metal_shield(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var cd: CardData = top.card_data
	if cd == null:
		return false
	var abilities: Variant = cd.abilities
	if abilities == null:
		return false
	for ability: Variant in abilities:
		if ability is Dictionary:
			var ab_name: Variant = ability.get("name", "")
			if ab_name is String and (ab_name as String).contains(ABILITY_NAME):
				return true
	return false


## 检查宝可梦是否附着至少一张基础钢能量
## 基础钢能量：card_type == "Basic Energy" 且 energy_provides == "M"
static func _has_basic_metal_energy(slot: PokemonSlot) -> bool:
	for energy_card: CardInstance in slot.attached_energy:
		var cd: CardData = energy_card.card_data
		if cd == null:
			continue
		# 判断为基础钢能量
		if cd.card_type == "Basic Energy" and cd.energy_provides == METAL_TYPE:
			return true
	return false


func get_description() -> String:
	return "特性【金属之盾】：此宝可梦附着基础钢能量时，受到的伤害-30。"
