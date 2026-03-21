## 投币追加伤害效果 - 根据投币结果决定额外伤害
## 适用: "投币正面追加30"、"投3次硬币每正面+30"、"投币直到反面每正面+30"
## 参数: damage_per_heads, coin_count, flip_until_tails
class_name EffectCoinFlipDamage
extends BaseEffect

## 每个正面追加的伤害
var damage_per_heads: int = 30
## 投币次数（flip_until_tails=true 时忽略）
var coin_count: int = 1
## 是否投币直到反面
var flip_until_tails: bool = false


func _init(damage: int = 30, count: int = 1, until_tails: bool = false) -> void:
	damage_per_heads = damage
	coin_count = count
	flip_until_tails = until_tails


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	var heads: int = 0

	if flip_until_tails:
		# 投币直到反面
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		while rng.randi_range(0, 1) == 1:
			heads += 1
	else:
		# 投固定次数
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for _i: int in coin_count:
			if rng.randi_range(0, 1) == 1:
				heads += 1

	var extra_damage: int = heads * damage_per_heads
	defender.damage_counters += extra_damage


func get_description() -> String:
	if flip_until_tails:
		return "投币直到反面，每个正面追加%d伤害" % damage_per_heads
	if coin_count == 1:
		return "投币正面追加%d伤害" % damage_per_heads
	return "投%d次硬币，每个正面追加%d伤害" % [coin_count, damage_per_heads]
