class_name AttackCoinFlipApplyStatus
extends BaseEffect

var status_name: String = "confused"
var coin_flipper: CoinFlipper


func _init(status: String = "confused", flipper: CoinFlipper = null) -> void:
	status_name = status
	coin_flipper = flipper if flipper != null else CoinFlipper.new()


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	# 薄雾能量免疫对手招式效果
	if defender != null and EffectMistEnergy.has_mist_energy(defender):
		return
	if coin_flipper.flip():
		defender.set_status(status_name, true)


func get_description() -> String:
	return "Flip a coin. If heads, apply %s." % status_name
