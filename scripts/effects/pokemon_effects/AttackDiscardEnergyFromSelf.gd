## 弃自身能量效果 - 攻击后弃置攻击方宝可梦上的指定能量
## 适用: 怒鹦哥ex"鼓足干劲"(弃置1个任意能量)
## 参数: discard_count, energy_type
class_name AttackDiscardEnergyFromSelf
extends BaseEffect

## 弃置的能量数量
var discard_count: int = 1
## 能量类型过滤（空 = 任意类型）
var energy_type: String = ""


func _init(count: int = 1, e_type: String = "") -> void:
	discard_count = count
	energy_type = e_type


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var player: PlayerState = state.players[pi]

	# TODO: 需要UI交互 — 自动从末尾移除符合条件的能量
	var removed: int = 0
	var i: int = attacker.attached_energy.size() - 1
	while i >= 0 and removed < discard_count:
		var energy: CardInstance = attacker.attached_energy[i]
		if energy_type == "" or (energy.card_data != null and energy.card_data.energy_provides == energy_type):
			attacker.attached_energy.remove_at(i)
			player.discard_pile.append(energy)
			removed += 1
		i -= 1


func get_description() -> String:
	var type_str: String = energy_type if energy_type != "" else "任意"
	return "弃置自身%d个%s能量" % [discard_count, type_str]
