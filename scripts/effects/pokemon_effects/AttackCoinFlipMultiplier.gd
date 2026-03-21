## Flip coins until tails. Damage is base damage times the number of heads.
class_name AttackCoinFlipMultiplier
extends BaseEffect

var damage_per_heads: int = 20
var coin_flipper: CoinFlipper = CoinFlipper.new()


func _init(damage: int = 20, flipper: CoinFlipper = null) -> void:
	damage_per_heads = damage
	if flipper != null:
		coin_flipper = flipper


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	var heads: int = coin_flipper.flip_until_tails()

	# The base damage has already been applied once by DamageCalculator.
	var delta: int = (heads * damage_per_heads) - damage_per_heads
	defender.damage_counters = max(0, defender.damage_counters + delta)


func get_description() -> String:
	return "Flip coins until tails. This attack does %d damage for each heads." % damage_per_heads
