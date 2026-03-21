## 按特殊能量数追加伤害效果 - 根据攻击方附带的特殊能量数量追加伤害
## 适用: 奇诺栗鼠"特殊滚动"(每个特殊能量+70伤害)
## 参数: damage_per_special
class_name AttackSpecialEnergyMultiDamage
extends BaseEffect

## 每个特殊能量追加的伤害
var damage_per_special: int = 70


func _init(dmg_per_special: int = 70) -> void:
	damage_per_special = dmg_per_special


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	# 统计攻击方身上附带的特殊能量数量
	var special_count: int = 0
	for energy: CardInstance in attacker.attached_energy:
		if energy.card_data != null and energy.card_data.card_type == "Special Energy":
			special_count += 1

	# 追加伤害
	defender.damage_counters += damage_per_special * special_count


func get_description() -> String:
	return "自身每个特殊能量追加%d伤害" % damage_per_special
