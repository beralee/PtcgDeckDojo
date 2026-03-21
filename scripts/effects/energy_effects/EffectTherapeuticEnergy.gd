## 治疗能量 - 提供1个无色能量，附着的宝可梦免疫睡眠/麻痹/混乱，已有的也恢复
class_name EffectTherapeuticEnergy
extends BaseEffect


## 附着时触发：清除睡眠/麻痹/混乱
func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	# 查找附着了此能量的宝可梦
	for slot: PokemonSlot in player.get_all_pokemon():
		for energy: CardInstance in slot.attached_energy:
			if energy.instance_id == card.instance_id:
				_clear_status(slot)
				return


func _clear_status(slot: PokemonSlot) -> void:
	slot.status_conditions["asleep"] = false
	slot.status_conditions["paralyzed"] = false
	slot.status_conditions["confused"] = false


## 持续效果：提供1个无色能量
func get_energy_type_provides() -> String:
	return "C"


func get_energy_count() -> int:
	return 1


## 检查宝可梦是否附有治疗能量（用于状态免疫判定）
static func has_therapeutic_energy(slot: PokemonSlot) -> bool:
	for energy: CardInstance in slot.attached_energy:
		if energy.card_data.effect_id == "2c65697c2aceac4e6a1f85f810fa386f":
			return true
	return false


func get_description() -> String:
	return "提供1个无色能量，附着宝可梦免疫睡眠/麻痹/混乱"
