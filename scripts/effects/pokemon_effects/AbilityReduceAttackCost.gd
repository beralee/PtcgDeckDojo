## 减少火能量消耗特性 - 光辉喷火龙（振奋之心）
## 己方宝可梦招式消耗的火能量（R）-1（每只光辉喷火龙提供-1，可叠加）
## 被动特性，由 EffectProcessor 在计算招式能量消耗时调用 get_fire_cost_reduction()
class_name AbilityReduceAttackCost
extends BaseEffect

## 特性名称标识
const ABILITY_NAME: String = "振奋之心"
## 每只光辉喷火龙提供的火能量消耗减少量
const REDUCTION_PER_POKEMON: int = 1


## 被动特性无需主动执行
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需执行动作
	pass


## 计算己方场上所有光辉喷火龙提供的火能量消耗减少总量
## 每只在场（战斗位或备战区）且拥有"振奋之心"特性的光辉喷火龙提供 -1 火能量消耗
## EffectProcessor 应在己方宝可梦计算招式所需能量时调用此方法
static func get_fire_cost_reduction(player: PlayerState) -> int:
	var total_reduction: int = 0
	# 收集战斗位和备战区所有宝可梦
	var all_slots: Array = []
	if player.active_pokemon != null:
		all_slots.append(player.active_pokemon)
	for bench_slot: PokemonSlot in player.bench:
		all_slots.append(bench_slot)

	for slot: Variant in all_slots:
		if slot is PokemonSlot:
			var ps: PokemonSlot = slot as PokemonSlot
			if _has_spirited_heart(ps):
				total_reduction += REDUCTION_PER_POKEMON
	return total_reduction


## 检查单个 PokemonSlot 是否拥有"振奋之心"特性
static func _has_spirited_heart(slot: PokemonSlot) -> bool:
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
	return "特性【振奋之心】：己方宝可梦招式消耗的火能量-1。（可叠加）"
