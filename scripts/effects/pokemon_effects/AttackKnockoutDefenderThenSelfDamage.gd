class_name AttackKnockoutDefenderThenSelfDamage
extends BaseEffect

var self_damage: int = 200
var attack_index_to_match: int = -1


func _init(damage_to_self: int = 200, match_attack_index: int = -1) -> void:
	self_damage = damage_to_self
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or not applies_to_attack_index(attack_index):
		return
	if defender != null and not AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_effects(defender, state):
		defender.damage_counters = defender.get_max_hp()
	attacker.damage_counters += self_damage


func get_description() -> String:
	return "Knock Out the Defending Pokemon, then deal damage to this Pokemon."
