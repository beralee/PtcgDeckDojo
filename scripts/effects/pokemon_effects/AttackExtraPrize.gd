## 击倒多拿奖赏卡效果 - 多谢款待（铁臂膀ex）
## 若此攻击将防守方击倒，则额外多拿指定数量的奖赏卡
## 通过在防守方 effects 中添加标记，由 GameStateMachine 在判断击倒时处理
## 参数:
##   extra_prizes  额外多拿的奖赏卡数量（默认1）
class_name AttackExtraPrize
extends BaseEffect

## 额外多拿的奖赏卡数量
var extra_prizes: int = 1


func _init(extra: int = 1) -> void:
	extra_prizes = extra


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	# 在防守方身上标记：若被击倒，攻击方额外多拿奖赏卡
	# GameStateMachine 在判定击倒时需检查此标记
	defender.effects.append({
		"type": "extra_prize",
		"count": extra_prizes,
		"source": "attack",
	})


func get_description() -> String:
	return "多谢款待：若此招式击倒对手宝可梦，额外多拿%d张奖赏卡。" % extra_prizes
