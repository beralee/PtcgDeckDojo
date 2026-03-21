## 奇迹之力 - 沙奈朵ex
## 攻击后清除自身所有特殊状态
class_name AttackClearOwnStatus
extends BaseEffect


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	for status_name: String in attacker.status_conditions.keys():
		attacker.set_status(status_name, false)


func get_description() -> String:
	return "将自身的特殊状态全部恢复。"
