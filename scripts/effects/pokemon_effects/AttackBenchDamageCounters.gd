## 备战区放置伤害指示物效果 - 将伤害指示物分配给对方备战宝可梦
## 适用: 振翼发"飞来横祸"(对对方备战区放置120个伤害指示物)
## 参数: damage_counters_total
class_name AttackBenchDamageCounters
extends BaseEffect

## 要分配的伤害指示物总量
var damage_counters_total: int = 120


func _init(total: int = 120) -> void:
	damage_counters_total = total


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var opp_pi: int = 1 - pi
	var opp_player: PlayerState = state.players[opp_pi]

	if opp_player.bench.is_empty():
		return

	# TODO: 需要UI交互 — 自动轮流分配，每次10个伤害指示物
	# 简化：每次给备战区宝可梦轮流放置10个指示物，直到总量耗尽
	var remaining: int = damage_counters_total
	var bench_count: int = opp_player.bench.size()
	var idx: int = 0
	while remaining > 0 and bench_count > 0:
		var chunk: int = min(10, remaining)
		opp_player.bench[idx % bench_count].damage_counters += chunk
		remaining -= chunk
		idx += 1


func get_description() -> String:
	return "对对方备战区分配%d个伤害指示物" % damage_counters_total
