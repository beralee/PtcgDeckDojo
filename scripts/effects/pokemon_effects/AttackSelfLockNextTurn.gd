## 下回合不可使用此招式效果 - 自锁招式
## 适用:
##   光辉喷火龙（炎爆）
##   铁斑叶ex（棱镜利刃）
##   密勒顿ex（光子引爆）
## 使用后在攻击者的 effects 列表中记录本回合使用了此招式
## RuleValidator 在下回合判断时检查此记录，禁止再次使用该招式
class_name AttackSelfLockNextTurn
extends BaseEffect


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	# 获取本招式名称
	var attack_name: String = _get_attack_name(attacker, attack_index)

	# 在攻击者的效果列表中记录自锁标记
	# RuleValidator 需要检查此条目：若 turn == 上回合编号，则本回合禁止使用同名招式
	attacker.effects.append({
		"type": "attack_lock",
		"attack_name": attack_name,
		"attack_index": attack_index,
		"turn": state.turn_number,
	})


## 获取指定索引的招式名称
func _get_attack_name(slot: PokemonSlot, index: int) -> String:
	var attacks: Array = slot.get_attacks()
	if attacks.is_empty() or index >= attacks.size():
		return ""
	var atk: Variant = attacks[index]
	if atk is Dictionary:
		return str(atk.get("name", ""))
	return ""


func get_description() -> String:
	return "使用此招式后，下回合不可再次使用此招式。"
