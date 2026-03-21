## 无视防守方效果 - 在防守方身上标记本次攻击无视其防御效果
## 适用: 骑拉帝纳V"撕裂"
## 伤害计算时检查 defender.effects 中的此标记以跳过防守方的伤害修正
class_name AttackIgnoreDefenderEffects
extends BaseEffect


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	# 在防守方效果列表中添加标记，伤害计算阶段检查此标记
	# 标记包含回合号，以便下回合自动失效
	var marker: Dictionary = {
		"type": "ignore_effects_this_attack",
		"turn": state.turn_number
	}
	defender.effects.append(marker)


func get_description() -> String:
	return "此招式无视防守方宝可梦的效果"
