## 薄雾能量 - 提供1个无色能量，附着宝可梦不受对手招式效果影响
## （已经受到的效果不会消失）
class_name EffectMistEnergy
extends BaseEffect


## 能量类型
func get_energy_type_provides() -> String:
	return "C"


func get_energy_count() -> int:
	return 1


## 检查宝可梦是否附有薄雾能量（用于招式效果免疫判定）
static func has_mist_energy(slot: PokemonSlot) -> bool:
	for energy: CardInstance in slot.attached_energy:
		if energy.card_data.effect_id == "fb0948c721db1f31767aa6cf0c2ea692":
			return true
	return false


func get_description() -> String:
	return "提供1个无色能量，附着宝可梦不受对手招式效果影响"
