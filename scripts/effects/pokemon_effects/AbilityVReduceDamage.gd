## V宝可梦伤害减免特性 - 光辉沙奈朵（慈爱帘幕）
## 己方非V宝可梦受到对手V/VSTAR/VMAX宝可梦的伤害-20
## 被动特性，由 EffectProcessor 在计算防守方受到的伤害时调用 get_v_damage_reduction()
class_name AbilityVReduceDamage
extends BaseEffect

## 特性名称标识
const ABILITY_NAME: String = "慈爱帘幕"
## 伤害减免量
const DAMAGE_REDUCTION: int = 20


## 被动特性无需主动执行
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需执行动作
	pass


## 计算防守方受到的V系伤害减免量
## 条件：
##   1. 防守方玩家场上有光辉沙奈朵（拥有"慈爱帘幕"特性）
##   2. 防守方宝可梦（defender）不是规则宝可梦（非ex/V/VSTAR/VMAX）
##   3. 攻击方宝可梦（attacker）是规则宝可梦（V/VSTAR/VMAX/ex）
## 满足条件时返回 -20（负数表示减伤），否则返回 0
static func get_v_damage_reduction(
	defending_player: PlayerState,
	defender: PokemonSlot,
	attacker: PokemonSlot
) -> int:
	# 检查防守方是否有光辉沙奈朵在场
	if not _has_loving_veil_in_play(defending_player):
		return 0

	# 检查防守方宝可梦是否为非规则宝可梦
	if not _is_non_rule_box(defender):
		return 0

	# 检查攻击方宝可梦是否为规则宝可梦
	if not _is_rule_box(attacker):
		return 0

	return -DAMAGE_REDUCTION


## 检查防守方场上（战斗位或备战区）是否有拥有"慈爱帘幕"特性的宝可梦
static func _has_loving_veil_in_play(player: PlayerState) -> bool:
	var all_slots: Array = []
	if player.active_pokemon != null:
		all_slots.append(player.active_pokemon)
	for bench_slot: PokemonSlot in player.bench:
		all_slots.append(bench_slot)

	for slot: Variant in all_slots:
		if slot is PokemonSlot:
			var ps: PokemonSlot = slot as PokemonSlot
			if _has_ability(ps):
				return true
	return false


## 检查单个 PokemonSlot 是否拥有"慈爱帘幕"特性
static func _has_ability(slot: PokemonSlot) -> bool:
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


## 检查宝可梦是否为非规则宝可梦（不是ex/V/VSTAR/VMAX）
static func _is_non_rule_box(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return true
	var cd: CardData = top.card_data
	if cd == null:
		return true
	return not cd.is_rule_box_pokemon()


## 检查宝可梦是否为规则宝可梦（ex/V/VSTAR/VMAX）
static func _is_rule_box(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var cd: CardData = top.card_data
	if cd == null:
		return false
	return cd.is_rule_box_pokemon()


func get_description() -> String:
	return "特性【慈爱帘幕】：己方非V宝可梦受到对手V/VSTAR/VMAX宝可梦伤害-20。"
