## 伤害修正特性效果 - 持续增加或减少攻击/防守伤害
## 适用: "己方宝可梦攻击伤害+20"、"受到的攻击伤害-30"等
## 参数: modifier_amount, modifier_type
class_name AbilityDamageModifier
extends BaseEffect

## 伤害修正量（正=增伤，负=减伤）
var modifier_amount: int = 0
## 修正类型: "attack"=增加攻击伤害, "defense"=减少受到伤害
var modifier_type: String = "attack"
## 是否仅对自身生效（false=对全队生效）
var self_only: bool = true


func _init(amount: int = 20, type: String = "attack", only_self: bool = true) -> void:
	modifier_amount = amount
	modifier_type = type
	self_only = only_self


## 该特性为被动特性，不需要手动执行
## 伤害修正通过 EffectProcessor 的 get_attacker_modifier / get_defender_modifier 查询
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性无需执行动作
	pass


func get_modifier() -> int:
	return modifier_amount


func is_attack_modifier() -> bool:
	return modifier_type == "attack"


func is_defense_modifier() -> bool:
	return modifier_type == "defense"


func get_description() -> String:
	if modifier_type == "attack":
		return "特性：攻击伤害+%d" % modifier_amount
	return "特性：受到伤害%d" % modifier_amount
