## 备战区数量追加伤害效果 - 雷电回旋曲（雷公V）
## 统计指定方备战区的宝可梦数量，追加对应倍数伤害
## 参数:
##   damage_per_bench  每只备战宝可梦追加的伤害值（默认20）
##   count_side        统计哪方的备战区："self"=己方, "opponent"=对方, "both"=双方
class_name AttackBenchCountDamage
extends BaseEffect

## 每只备战宝可梦追加的伤害值
var damage_per_bench: int = 30
## 统计方："self"、"opponent" 或 "both"
var count_side: String = "both"


func _init(per_bench: int = 20, side: String = "both") -> void:
	damage_per_bench = per_bench
	count_side = side


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return 0
	var pi: int = top_card.owner_index
	var bench_count: int = 0
	match count_side:
		"self":
			bench_count = state.players[pi].bench.size()
		"opponent":
			bench_count = state.players[1 - pi].bench.size()
		"both":
			bench_count = state.players[pi].bench.size() + state.players[1 - pi].bench.size()
	return damage_per_bench * bench_count


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	var side_str: String = "己方" if count_side == "self" else "对方" if count_side == "opponent" else "双方"
	return "雷电回旋曲：%s备战区每有1只宝可梦，追加%d伤害。" % [side_str, damage_per_bench]
