## 投币失败则招式无效效果 - 投币为反面时撤销已造成的基础伤害
## 适用: 大牙狸"终结门牙"(投币反面时60伤害无效)、大尾狸"长尾粉碎"(投币反面时无效)
## 参数: base_damage, fail_action
class_name AttackCoinFlipOrFail
extends BaseEffect

## 招式的基础伤害（投币失败时需要撤销该伤害）
var base_damage: int = 60
## 失败处理方式: "no_damage"=完全撤销伤害; "half_damage"=只保留一半伤害
var fail_action: String = "no_damage"


func _init(base_dmg: int = 60, action: String = "no_damage") -> void:
	base_damage = base_dmg
	fail_action = action


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	# 投币决定招式是否有效
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var is_heads: bool = rng.randi_range(0, 1) == 1

	if is_heads:
		# 正面：招式正常生效，无需额外操作
		return

	# 反面：根据 fail_action 处理
	if fail_action == "no_damage":
		# 完全撤销基础伤害
		defender.damage_counters -= base_damage
		# 确保伤害计数不低于0
		if defender.damage_counters < 0:
			defender.damage_counters = 0
	elif fail_action == "half_damage":
		# 只保留一半伤害，撤销另一半
		var undo_amount: int = base_damage / 2
		defender.damage_counters -= undo_amount
		if defender.damage_counters < 0:
			defender.damage_counters = 0


func get_description() -> String:
	if fail_action == "no_damage":
		return "投币，反面时此招式伤害无效"
	return "投币，反面时此招式伤害减半"
