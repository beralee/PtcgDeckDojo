## 气球炸弹 - 飘飘球
## 伤害 = 自身伤害指示物数量 x multiplier
## 使用 get_damage_bonus 将加值传递给 DamageCalculator
class_name AttackSelfDamageCounterMultiplier
extends BaseEffect

var damage_per_counter: int = 30


func _init(per_counter: int = 30) -> void:
	damage_per_counter = per_counter


func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
	var counter_count: int = attacker.damage_counters / 10
	return counter_count * damage_per_counter


func get_description() -> String:
	return "造成自身伤害指示物数量x%d伤害。" % damage_per_counter
