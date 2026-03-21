## 复制对手招式效果 - 基因侵入（梦幻ex）
## 复制对手主战宝可梦的招式并执行
## 简化处理：使用对手第一个招式的基础伤害值直接对防守方造成伤害
## 参数: 无额外参数
class_name AttackCopyAttack
extends BaseEffect


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	var pi: int = top_card.owner_index
	var opponent_pi: int = 1 - pi
	var opponent: PlayerState = state.players[opponent_pi]

	# 获取对手主战宝可梦
	var opp_active: PokemonSlot = opponent.active_pokemon
	if opp_active == null:
		return

	# 获取对手主战宝可梦的招式列表
	var opp_attacks: Array = opp_active.get_attacks()
	if opp_attacks.is_empty():
		return

	# TODO: 需要UI交互 - 让玩家选择要复制的对手招式
	# 简化：复制第一个招式
	var copied_attack: Variant = opp_attacks[0]
	if copied_attack == null:
		return

	# 解析招式伤害字符串（如 "120"、"50+"）
	var damage_value: int = _parse_damage_string(copied_attack)
	if damage_value > 0:
		defender.damage_counters += damage_value


## 将招式伤害字符串解析为整数
## 支持纯数字或带后缀的字符串（如 "120"、"50+"、"30×"）
func _parse_damage_string(attack_data: Variant) -> int:
	var damage_str: String = ""
	# attack_data 可能是 Dictionary 或其他格式
	if attack_data is Dictionary:
		var raw: Variant = attack_data.get("damage", "")
		damage_str = str(raw)
	elif attack_data is String:
		damage_str = attack_data
	else:
		return 0

	# 去除非数字后缀（"+"、"×"、"-"等）
	damage_str = damage_str.strip_edges()
	if damage_str.is_empty():
		return 0

	# 仅保留开头的数字部分
	var num_str: String = ""
	for ch: String in damage_str:
		if ch >= "0" and ch <= "9":
			num_str += ch
		else:
			break

	if num_str.is_empty():
		return 0
	return num_str.to_int()


func get_description() -> String:
	return "基因侵入：复制对手主战宝可梦的1个招式，对其造成相应伤害。"
