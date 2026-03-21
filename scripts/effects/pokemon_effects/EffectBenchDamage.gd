## 备战区伤害效果 - 对对方（或己方）备战宝可梦造成伤害
## 适用: "对对方1只备战宝可梦造成20伤害"、"对对方全部备战宝可梦各造成10伤害"
## 参数: bench_damage, target_all, target_side
class_name EffectBenchDamage
extends BaseEffect

## 对每只备战宝可梦的伤害
var bench_damage: int = 20
## 是否对全部备战宝可梦造成伤害（false = 仅1只，简化自动选第1只）
var target_all: bool = false
## 目标方: "opponent" 或 "self"
var target_side: String = "opponent"


func _init(damage: int = 20, all_bench: bool = false, side: String = "opponent") -> void:
	bench_damage = damage
	target_all = all_bench
	target_side = side


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var target_pi: int = 1 - pi if target_side == "opponent" else pi
	var target_player: PlayerState = _state.players[target_pi]

	if target_all:
		# 对全部备战宝可梦造成伤害
		for slot: PokemonSlot in target_player.bench:
			slot.damage_counters += bench_damage
	else:
		# 简化：对第一只备战宝可梦造成伤害
		if not target_player.bench.is_empty():
			target_player.bench[0].damage_counters += bench_damage


func get_description() -> String:
	var side_str: String = "对方" if target_side == "opponent" else "己方"
	if target_all:
		return "对%s全部备战宝可梦各造成%d伤害" % [side_str, bench_damage]
	return "对%s1只备战宝可梦造成%d伤害" % [side_str, bench_damage]
