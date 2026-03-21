## V防守能量 - 提供1个无色能量，附着宝可梦受到V宝可梦伤害-30（不叠加）
class_name EffectVGuardEnergy
extends BaseEffect

## 减伤量
var damage_reduction: int = -30


## 检查攻击方是否为V宝可梦
func is_v_attacker(attacker: PokemonSlot) -> bool:
	var cd: CardData = attacker.get_card_data()
	if cd == null:
		return false
	return cd.mechanic in ["V", "VSTAR", "VMAX"]


## 获取防守修正量（仅当攻击方为V时生效）
func get_defense_modifier(attacker: PokemonSlot) -> int:
	if is_v_attacker(attacker):
		return damage_reduction
	return 0


## 能量类型
func get_energy_type_provides() -> String:
	return "C"


func get_energy_count() -> int:
	return 1


func get_description() -> String:
	return "提供1个无色能量，受到V宝可梦伤害-30（不叠加）"
