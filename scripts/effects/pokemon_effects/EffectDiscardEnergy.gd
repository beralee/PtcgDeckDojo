## 弃置能量效果 - 攻击后弃置己方宝可梦上的能量
## 适用: "弃置1个火能量"、"弃置全部能量"等招式
## 参数: discard_count, energy_type_filter
class_name EffectDiscardEnergy
extends BaseEffect

## 弃置能量数量（-1 = 全部）
var discard_count: int = 1
## 能量类型过滤（空 = 任意类型）
var energy_type_filter: String = ""


func _init(count: int = 1, energy_filter: String = "") -> void:
	discard_count = count
	energy_type_filter = energy_filter


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	if discard_count == -1:
		# 弃置全部能量
		var all_energy: Array[CardInstance] = attacker.attached_energy.duplicate()
		attacker.attached_energy.clear()
		var pi: int = attacker.get_top_card().owner_index
		var player: PlayerState = _state.players[pi]
		for energy: CardInstance in all_energy:
			player.discard_pile.append(energy)
	else:
		var pi: int = attacker.get_top_card().owner_index
		var player: PlayerState = _state.players[pi]
		var removed: int = 0
		# 从后往前移除以保持索引正确
		var i: int = attacker.attached_energy.size() - 1
		while i >= 0 and removed < discard_count:
			var energy: CardInstance = attacker.attached_energy[i]
			if energy_type_filter == "" or (energy.card_data and energy.card_data.energy_provides == energy_type_filter):
				attacker.attached_energy.remove_at(i)
				player.discard_pile.append(energy)
				removed += 1
			i -= 1


func get_description() -> String:
	var type_str: String = energy_type_filter if energy_type_filter != "" else "任意"
	if discard_count == -1:
		return "弃置全部能量"
	return "弃置%d个%s能量" % [discard_count, type_str]
