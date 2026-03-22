class_name AttackIgnoreWeakness
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func ignores_weakness(_attacker: PokemonSlot, _state: GameState, attack_index: int) -> bool:
	return applies_to_attack_index(attack_index)


func get_description() -> String:
	return "This attack ignores Weakness."
