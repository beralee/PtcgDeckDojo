class_name AttackIgnoreWeaknessResistanceAndEffects
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func ignores_weakness_and_resistance(_attacker: PokemonSlot, _state: GameState, attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func ignores_defender_effects(_attacker: PokemonSlot, _state: GameState, attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_description() -> String:
	return "This attack ignores Weakness, Resistance, and effects on the Defending Pokemon."
