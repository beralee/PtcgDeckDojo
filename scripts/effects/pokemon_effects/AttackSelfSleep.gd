## 自身陷入睡眠效果 - 轰隆鼾声（卡比兽）
## 攻击后攻击者自身陷入睡眠状态
class_name AttackSelfSleep
extends BaseEffect


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	# 攻击者自身陷入睡眠
	attacker.set_status("asleep", true)


func get_description() -> String:
	return "轰隆鼾声：使用此招式后，自身陷入睡眠状态。"
