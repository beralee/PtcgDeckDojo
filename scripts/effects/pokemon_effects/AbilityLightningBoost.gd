## 雷属性攻击加成特性 - 闪电鸟（电气象征）
## 己方基础雷宝可梦（Basic + 属性L）攻击伤害+10
## 被动特性，由 EffectProcessor 在计算己方宝可梦攻击伤害时调用 get_lightning_boost()
class_name AbilityLightningBoost
extends BaseEffect

## 特性名称标识
const ABILITY_NAME: String = "电气象征"
## 每只闪电鸟提供的攻击加成值
const BOOST_PER_POKEMON: int = 10
## 雷属性能量类型代码
const LIGHTNING_TYPE: String = "L"
## 基础阶段标识
const BASIC_STAGE: String = "Basic"


## 被动特性无需主动执行
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需执行动作
	pass


## 计算己方场上所有闪电鸟对指定攻击者提供的攻击加成总量
## 条件：攻击者必须是基础雷宝可梦（stage == "Basic" 且 energy_type == "L"）
## EffectProcessor 应在己方宝可梦发动攻击时调用此方法
static func get_lightning_boost(player: PlayerState, attacker: PokemonSlot) -> int:
	# 检查攻击者是否为基础雷宝可梦
	if not _is_basic_lightning(attacker):
		return 0

	var total_boost: int = 0
	# 收集战斗位和备战区所有宝可梦
	var all_slots: Array = []
	if player.active_pokemon != null:
		all_slots.append(player.active_pokemon)
	for bench_slot: PokemonSlot in player.bench:
		all_slots.append(bench_slot)

	for slot: Variant in all_slots:
		if slot is PokemonSlot:
			var ps: PokemonSlot = slot as PokemonSlot
			if _has_electric_symbol(ps):
				total_boost += BOOST_PER_POKEMON
	return total_boost


## 检查 PokemonSlot 是否为基础雷宝可梦
static func _is_basic_lightning(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var cd: CardData = top.card_data
	if cd == null:
		return false
	# 必须是宝可梦、基础阶段、雷属性
	if not cd.is_pokemon():
		return false
	if cd.stage != BASIC_STAGE:
		return false
	return cd.energy_type == LIGHTNING_TYPE


## 检查单个 PokemonSlot 是否拥有"电气象征"特性
static func _has_electric_symbol(slot: PokemonSlot) -> bool:
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


func get_description() -> String:
	return "特性【电气象征】：己方基础雷宝可梦攻击伤害+10。（可叠加）"
