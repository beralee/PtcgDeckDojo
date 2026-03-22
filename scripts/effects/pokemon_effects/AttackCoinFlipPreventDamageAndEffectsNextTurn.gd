class_name AttackCoinFlipPreventDamageAndEffectsNextTurn
extends BaseEffect

const PROTECTION_EFFECT_TYPE := "prevent_attack_damage_and_effects"

var coin_flipper: CoinFlipper
var attack_index_to_match: int = -1


func _init(flipper: CoinFlipper = null, match_attack_index: int = -1) -> void:
	coin_flipper = flipper if flipper != null else CoinFlipper.new()
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or not applies_to_attack_index(attack_index):
		return
	if not coin_flipper.flip():
		return
	attacker.effects.append({
		"type": PROTECTION_EFFECT_TYPE,
		"turn": state.turn_number,
	})


static func prevents_attack_damage(target: PokemonSlot, state: GameState) -> bool:
	if target == null:
		return false
	for effect_data: Dictionary in target.effects:
		if effect_data.get("type", "") == PROTECTION_EFFECT_TYPE and int(effect_data.get("turn", -999)) == state.turn_number - 1:
			return true
	return false


static func prevents_attack_effects(target: PokemonSlot, state: GameState) -> bool:
	return prevents_attack_damage(target, state) or EffectMistEnergy.has_mist_energy(target)


func get_description() -> String:
	return "Flip a coin. If heads, prevent all damage and effects of attacks during your opponent's next turn."
