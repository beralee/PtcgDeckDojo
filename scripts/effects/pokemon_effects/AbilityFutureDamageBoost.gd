## 未来宝可梦攻击加成特性 - 铁头壳ex（蔚蓝指令）
## 己方未来宝可梦攻击伤害+20（每只铁头壳ex提供+20，可叠加）
## 被动特性，由 EffectProcessor 在计算己方未来宝可梦攻击伤害时调用 get_future_damage_boost()
class_name AbilityFutureDamageBoost
extends BaseEffect

## 特性名称标识
const ABILITY_NAME: String = "蔚蓝指令"
## 每只铁头壳ex提供的攻击加成值
const BOOST_PER_POKEMON: int = 20


## 被动特性无需主动执行
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需执行动作
	pass


## 计算己方场上所有铁头壳ex提供的未来宝可梦攻击加成总量
## 每只在场（战斗位或备战区）且拥有"蔚蓝指令"特性的铁头壳ex提供 +20
## 仅对“未来”宝可梦生效，且铁头壳ex自己不能获得该加成
static func get_future_damage_boost(player: PlayerState, attacker: PokemonSlot) -> int:
	if not _is_boosted_target(attacker):
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
			if _has_azure_command(ps):
				total_boost += BOOST_PER_POKEMON
	return total_boost


static func _is_boosted_target(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null or not cd.is_future_pokemon():
		return false
	return not _has_azure_command(slot)


## 检查单个 PokemonSlot 是否拥有"蔚蓝指令"特性
static func _has_azure_command(slot: PokemonSlot) -> bool:
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
	return "特性【蔚蓝指令】：己方未来宝可梦攻击伤害+20。（可叠加）"
